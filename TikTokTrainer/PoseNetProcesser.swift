//
//  PoseNetProcesser.swift
//  TikTokTrainer
//
//  Created by Hunter Jarrell on 2/11/21.
//

import Foundation
import Vision

struct VideoDataSlice {
    let start: CMTime
    let points: [VNRecognizedPointKey: VNRecognizedPoint]
}

struct ProcessedVideo {
    let url: URL
    var data: [VideoDataSlice] = []
}

/// Process a Video from a URL and calls a callback with the processed results
struct PoseNetProcessor {

    private static let poseNetQueue = DispatchQueue(label: "t3.posenetproc")
    private static let videoWriteBlockingQueue = DispatchQueue(label: "t3.videowriteblocking")

    /// Run PoseNet on the video at URL. This is run in an async workqueue and calls the callback on the main thread.
    ///
    /// Testing this function on an 18 second video takes about 9 seconds to fully process. Not sure how this will scale.
    ///
    /// - Parameters:
    ///     - url: The **URL** for the video to process
    ///     - callback: The callback to call when the results are done processing
    static func run(url: URL, callback: @escaping (Result<ProcessedVideo, Error>) -> Void) {
        var processedVideo = ProcessedVideo(url: url)
        let videoProcessor = VNVideoProcessor(url: url)
        let humanRequest = VNDetectHumanBodyPoseRequest(completionHandler: { request, err in
            /// Error on the request should fail the whole processing because this may be the sign of a bigger issue.
            guard err == nil else { return callback(.failure(err!)) }
            guard let observations =
                    request.results as? [VNRecognizedPointsObservation] else { return }

            observations.forEach {
                guard let recognizedPoints =
                        try? $0.recognizedPoints(forGroupKey: .all) else {
                    return
                }

                let slice = VideoDataSlice(start: $0.timeRange.start, points: recognizedPoints)
                /// Wrap the appending in a barrier queue incase there are concurrent issues with the data
                videoWriteBlockingQueue.async(flags: .barrier) {
                    processedVideo.data.append(slice)
                }
            }
        })

        poseNetQueue.async {
            do {
                try videoProcessor.addRequest(humanRequest, processingOptions: VNVideoProcessor.RequestProcessingOptions())
                try videoProcessor.analyze(CMTimeRange(start: CMTime.zero, end: CMTime.indefinite))
            } catch {
                print("Error processing PoseNet for Video with url \(url).\n Error: \(error)")
                DispatchQueue.main.async {
                    return callback(.failure(error))
                }
            }
            DispatchQueue.main.async {
                return callback(.success(processedVideo))
            }
        }
    }
}
