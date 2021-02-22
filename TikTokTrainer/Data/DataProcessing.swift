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

/// Process the PoseNet overlays on the pre-recorded and user-recorded videos and return a score
struct ScoringFunction {
    var preRecordedVid: ProcessedVideo?
    var recordedVid: ProcessedVideo?
    
    let jointTriples: [(VNRecognizedPointKey, VNRecognizedPointKey, VNRecognizedPointKey)] = [
        ((VNRecognizedPointKey(rawValue: "left_shoulder_1_joint"),
          VNRecognizedPointKey(rawValue: "left_forearm_joint"),
          VNRecognizedPointKey(rawValue: "left_hand_joint"))),
        
        ((VNRecognizedPointKey(rawValue: "right_shoulder_1_joint"),
          VNRecognizedPointKey(rawValue: "right_forearm_joint"),
          VNRecognizedPointKey(rawValue: "right_hand_joint"))),
        
        ((VNRecognizedPointKey(rawValue: "left_forearm_joint"),
          VNRecognizedPointKey(rawValue: "left_shoulder_1_joint"),
          VNRecognizedPointKey(rawValue: "neck_1_joint"))),
        
        ((VNRecognizedPointKey(rawValue: "left_shoulder_1_joint"),
          VNRecognizedPointKey(rawValue: "neck_1_joint"),
          VNRecognizedPointKey(rawValue: "head_joint"))),
        
        ((VNRecognizedPointKey(rawValue: "neck_1_joint"),
          VNRecognizedPointKey(rawValue: "right_shoulder_1_joint"),
          VNRecognizedPointKey(rawValue: "right_forearm_joint"))),
        
        ((VNRecognizedPointKey(rawValue: "head_joint"),
          VNRecognizedPointKey(rawValue: "neck_1_joint"),
          VNRecognizedPointKey(rawValue: "right_shoulder_1_joint")))
    ]
    
    /// Computes angles of PoseNet data with trig
    /// Cycles through sets of joints to track which angles are available for capture, otherwise angle is marked as 0
    ///
    /// - Parameters:
    ///     - video: The video uploaded by the user and processed by the PoseNetProcessor
    private func computeAngles(video: ProcessedVideo) -> Array<Array<CGFloat>> {
        var angles = [[CGFloat]]()
        angles.append([])
        var i = 0
        
        for slice in video.data {
            for triple in jointTriples {
                let pntOne = triple.0
                let pntTwo = triple.1
                let pntThree = triple.2
                var angle: CGFloat = 0
                
                if slice.points[pntOne] != nil && slice.points[pntTwo] != nil && slice.points[pntThree] != nil {
                    angle = angleBetweenPoints(leftPoint: slice.points[pntThree]!, middlePoint: slice.points[pntTwo]!, rightPoint: slice.points[pntOne]!)
                    print(pntTwo.rawValue + ": " + angle.description)
                }
                print()
                angles[i].append(angle)
            }
            angles.append([])
            i = i + 1
        }
        return angles
    }
    
    private func angleBetweenPoints(leftPoint: VNRecognizedPoint, middlePoint: VNRecognizedPoint, rightPoint: VNRecognizedPoint) -> CGFloat {
        return angleBetweenPoints(leftPoint: CGPoint(x: leftPoint.x, y: leftPoint.y), middlePoint: CGPoint(x: middlePoint.x, y: middlePoint.y), rightPoint: CGPoint(x: rightPoint.x, y: rightPoint.y))
    }
    
    private func angleBetweenPoints(leftPoint: CGPoint, middlePoint: CGPoint, rightPoint: CGPoint) -> CGFloat {
        let rightVector = (x: rightPoint.x - middlePoint.x, y: rightPoint.y - middlePoint.y)
        let leftVector = (x: leftPoint.x - middlePoint.x, y: leftPoint.y - middlePoint.y)
        let dotProduct = rightVector.x * leftVector.x + rightVector.y * leftVector.y
        let determinant = rightVector.x * leftVector.y - rightVector.y * leftVector.x
        var angle = atan2(determinant, dotProduct) * (180 / .pi)
        if angle < 0 {
            angle = angle + 360
        }
        return angle
    }
    
    private func computeAngleDifferences(preRecordedVid: ProcessedVideo, recordedVid: ProcessedVideo) -> Array<Array<CGFloat>> {
        let preRecordedPoses = computeAngles(video: preRecordedVid)
        let recordedPoses = computeAngles(video: recordedVid)
        var angleDifferences = [[CGFloat]]()
        let minSlices = min(preRecordedVid.data.count, recordedVid.data.count)
        
        for (i, poseAngles) in preRecordedPoses.enumerated() {
            if i < minSlices {
                angleDifferences.append([])
                for (j, angle) in poseAngles.enumerated() {
                    // This is where to add shifts or padding to angle differences
                    // i.e. we can ignore 3 degree differences in the angle by subtracting 3 from the abs(...)
                    angleDifferences[i].append(abs(angle - recordedPoses[i][j]))
                }
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
        let maxError: CGFloat = 402.5
        // ensures that there are an equivalent number of data slices
//        guard prVid.data.count == rVid.data.count else { throw ScoringFunctionError.videoLengthIncompatible }
        print(prVid.data.count)
        print(rVid.data.count)
        
        let angleDifferences = computeAngleDifferences(preRecordedVid: prVid, recordedVid: rVid)
        var error: CGFloat = 0
        var tempSum: CGFloat = 0
        
        // For future modifications we can either "clip" or weight lower the super large error values and super small error values per set of angles
        // so that really bad movements don't penalize too much
        for angleSet in angleDifferences {
            for angle in angleSet {
                tempSum = tempSum + pow(angle, 2)
            }
            error = error + sqrt(tempSum)
            tempSum = 0
        }
        // Instead of returning total error, return the normalized per pose error
        // This avoids super high errors for long videos and gives a better indication of how the overall performance was
        let length = CGFloat(angleDifferences.count)
        return (maxError - error/length)/maxError
    }
    
    // computes score using any scoring function (currently unweighted L2 MSE) and feeds result to callback
    func computeScore(callback: @escaping (Result<CGFloat, Error>) -> Void) {
        var score: CGFloat = 0
        do {
            score = try computeUnweightedMSE()
        } catch {
            print("Error computing score.\n Error: \(error)")
            return callback(.failure(error))
        }
        return callback(.success(score))
    }
}

enum ScoringFunctionError: Error {
    case videoLengthIncompatible
    case improperVideo
}
