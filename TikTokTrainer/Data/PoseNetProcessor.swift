//
//  PoseNetProcesser.swift
//  TikTokTrainer
//
//  Created by Hunter Jarrell on 2/11/21.
//

import Foundation
import Vision
import Promises

struct VideoDataSlice {
    let start: CMTime
    let points: [VNRecognizedPointKey: VNRecognizedPoint]
}

struct ProcessedVideo {
    let url: URL
    var data: [VideoDataSlice] = []
}

protocol PoseNetProcessorProtocol {
    static func run(url: URL) -> Promise<ProcessedVideo>
}

/// Process a Video from a URL and calls a callback with the processed results
struct PoseNetProcessor: PoseNetProcessorProtocol {

    private static let videoWriteBlockingQueue = DispatchQueue(label: "t3.videowriteblocking")

    /// Run PoseNet on the video at URL. This is run in an async workqueue and returns the promise on the main thread.
    ///
    /// Testing this function on an 18 second video takes about 9 seconds to fully process. Not sure how this will scale.
    ///
    /// - Parameters:
    ///     - url: The **URL** for the video to process
    static func run(url: URL) -> Promise<ProcessedVideo> {
        let promise = Promise<ProcessedVideo> { fulfill, reject in
            var processedVideo = ProcessedVideo(url: url)
            let procOpts = VNVideoProcessor.RequestProcessingOptions()
            procOpts.cadence = VNVideoProcessor.FrameRateCadence(2)
            let videoProcessor = VNVideoProcessor(url: url)
            let humanRequest = VNDetectHumanBodyPoseRequest(completionHandler: { request, err in
                /// Error on the request should fail the whole processing because this may be the sign of a bigger issue.
                guard err == nil else { return reject(err!) }
                guard let observations =
                        request.results as? [VNRecognizedPointsObservation] else { return }

                observations.forEach {
                    guard let recognizedPoints =
                            try? $0.recognizedPoints(forGroupKey: .all) else {
                        return
                    }

                    let slice = VideoDataSlice(start: $0.timeRange.start, points: recognizedPoints)
                    videoWriteBlockingQueue.async {
                        processedVideo.data.append(slice)
                    }
                }
            })

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try videoProcessor.addRequest(humanRequest, processingOptions: procOpts)
                    try videoProcessor.analyze(CMTimeRange(start: CMTime.zero, end: CMTime.indefinite))
                } catch {
                    print("Error processing PoseNet for Video with url \(url).\n Error: \(error)")
                    return reject(error)
                }
                return fulfill(processedVideo)
            }
        }
        return promise
    }
}
