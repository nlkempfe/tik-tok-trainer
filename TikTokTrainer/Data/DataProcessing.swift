//
//  DataProcessing.swift
//  TikTokTrainer
//
//  Created by Ankit  on 2/18/21.
//

import Foundation
import SwiftUI
import AVKit
import Vision
import Promises

/// Process the PoseNet overlays on the pre-recorded and user-recorded videos and return a score
struct ScoringFunction {
    var preRecordedVid: ProcessedVideo?
    var recordedVid: ProcessedVideo?
    
    let jointTriples: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftWrist, .leftElbow, .leftShoulder),
        (.rightShoulder, .rightElbow, .rightWrist),
        (.neck, .leftShoulder, .leftElbow),
        (.nose, .neck, .leftShoulder),
        (.neck, .rightShoulder, .rightElbow),
        (.nose, .neck, .rightShoulder)
    ]
    
    /// Computes angles of PoseNet data with trig
    /// Cycles through sets of joints to track which angles are available for capture, otherwise angle is marked as 0
    ///
    /// - Parameters:
    ///     - video: The video uploaded by the user and processed by the PoseNetProcessor
    private func computeAngles(video: ProcessedVideo) -> [[String: CGFloat]] {
        var angles = [[String: CGFloat]]()
        
        // Loops through data slices which contain pose points and computes joint angles
        for slice in video.data {
            var sliceData = [String: CGFloat]()
            for triple in jointTriples {
                let pntOne = triple.0.rawValue
                let pntTwo = triple.1.rawValue
                let pntThree = triple.2.rawValue
                var angle: CGFloat = 0
                
                if slice.points[pntOne] != nil && slice.points[pntTwo] != nil && slice.points[pntThree] != nil {
                    angle = angleBetweenPoints(leftPoint: slice.points[pntThree]!, middlePoint: slice.points[pntTwo]!, rightPoint: slice.points[pntOne]!)
                }
                sliceData[pntTwo.rawValue] = angle
            }
            angles.append(sliceData)
        }
        return angles
    }
    
    private func angleBetweenPoints(leftPoint: VNRecognizedPoint, middlePoint: VNRecognizedPoint, rightPoint: VNRecognizedPoint) -> CGFloat {
        let leftCGPoint = CGPoint(x: leftPoint.x, y: leftPoint.y)
        let middleCGPoint = CGPoint(x: middlePoint.x, y: middlePoint.y)
        let rightCGPoint = CGPoint(x: rightPoint.x, y: rightPoint.y)
        
        let rightVector = (x: rightCGPoint.x - middleCGPoint.x, y: rightCGPoint.y - middleCGPoint.y)
        let leftVector = (x: leftCGPoint.x - middleCGPoint.x, y: leftCGPoint.y - middleCGPoint.y)
        let dotProduct = rightVector.x * leftVector.x + rightVector.y * leftVector.y
        let determinant = rightVector.x * leftVector.y - rightVector.y * leftVector.x
        var angle = atan2(determinant, dotProduct) * (180 / .pi)
        if angle < 0 {
            angle += 360
        }
        return angle
    }
    
    
    private func computeAngleDifferences(preRecordedVid: ProcessedVideo, recordedVid: ProcessedVideo) -> [[CGFloat]] {
        let preRecordedPoses = computeAngles(video: preRecordedVid)
        let recordedPoses = computeAngles(video: recordedVid)
        let minSlices = min(preRecordedVid.data.count, recordedVid.data.count)
        
        var angleDifferences = [[CGFloat]](
            repeating: [CGFloat](),
            count: minSlices
        )
        
        for (row, poseAngles) in preRecordedPoses.enumerated() where row < minSlices {
            for (_, angle) in poseAngles.enumerated() {
                // This is where to add shifts or padding to angle differences
                // i.e. we can ignore 3 degree differences in the angle by subtracting 3 from the abs(...)
                angleDifferences[row].append(abs(angle.value - recordedPoses[row][angle.key]!))
            }
        }
        return angleDifferences
    }
    
    /// Unweighted Mean Squared Error Function - A single data point is a vector of angle differences so each angle difference is squared, all of the differences are summed, and the result
    /// is sqrted and then added to the total error
    ///
    /// - Parameters:
    ///     - preRecordedVid: The video uploaded by the user and processed by the PoseNetProcessor
    ///     - recordedVid: The video recorded by the user using T3 and processed by the PoseNetProcessor
    private func computeUnweightedMSE() throws -> CGFloat {
        guard self.preRecordedVid != nil && self.recordedVid != nil else { throw ScoringFunctionError.improperVideo }
        
        let prVid = preRecordedVid!
        let rVid = recordedVid!
        // Computes the max error that can be achieved in one pose
        let maxError: CGFloat = CGFloat(sqrt(Double(jointTriples.count) * (pow(180, 2))))
        // ensures that there are an equivalent number of data slices
        //        guard prVid.data.count == rVid.data.count else { throw ScoringFunctionError.videoLengthIncompatible }
        
        let angleDifferences = computeAngleDifferences(preRecordedVid: prVid, recordedVid: rVid)
        var error: CGFloat = 0
        var tempSum: CGFloat = 0
        
        // For future modifications we can either "clip" or weight lower the super large error values and super small error values per set of angles
        // so that really bad movements don't penalize too much
        for angleSet in angleDifferences {
            for angle in angleSet {
                tempSum += pow(angle, 2)
            }
            error += sqrt(tempSum)
            tempSum = 0
        }
        // Instead of returning total error, return the normalized per pose error
        // This avoids super high errors for long videos and gives a better indication of how the overall performance was
        let length = CGFloat(angleDifferences.count)
        return (maxError - error/length)/maxError
    }
    
    // computes score using any scoring function (currently unweighted L2 MSE) and feeds result to callback
    func computeScore() -> Promise<CGFloat> {
        let promise = Promise<CGFloat> { fulfill, reject in
            do {
                let score = try computeUnweightedMSE()
                return fulfill(score)
            } catch {
                print("Error computing score.\n Error: \(error)")
                return reject(error)
            }
        }
        return promise
    }
}

enum ScoringFunctionError: Error {
    case videoLengthIncompatible
    case improperVideo
}
