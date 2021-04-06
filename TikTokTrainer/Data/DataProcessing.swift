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
class ScoringFunction {
    var preRecordedVid: ProcessedVideo?
    var recordedVid: ProcessedVideo?

    // constants for scoring
    let rotationMultiplier: CGFloat = 180
    let rotationWeight: CGFloat = 2

    // Angle is measured for the middle joint in each triple
    // Bottom two measure rotation along z axis

    let jointTriples: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftWrist, .leftElbow, .leftShoulder),
        (.rightShoulder, .rightElbow, .rightWrist),
        (.neck, .leftShoulder, .leftElbow),
        (.nose, .neck, .leftShoulder),
        (.neck, .rightShoulder, .rightElbow),
        (.nose, .neck, .rightShoulder),
        (.leftAnkle, .leftKnee, .leftHip),
        (.leftKnee, .leftHip, .root),
        (.rightHip, .rightKnee, .rightAnkle),
        (.root, .rightHip, .rightKnee),
        (.leftShoulder, .leftHip, .leftKnee),
        (.rightKnee, .rightHip, .rightShoulder)
    ]

    let rotationTuples: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName, String)] = [
        (.leftShoulder, .rightShoulder, "y-axis"),
        (.neck, .root, "x-axis")
    ]

    // Class variable - both computeAngles and computeRotations can contribute to mistakes
    var mistakesArray: [(String, CMTime)] = []

    /// Initializes ScoringFunction with the two videos
    ///
    /// - Parameters:
    ///     - preRecordedVid: The video uploaded by the user and processed by the PoseNetProcessor
    ///     - recordedVid: The video recorded by the user and processed by the PoseNetProcessor
    required init(preRecordedVid: ProcessedVideo, recordedVid: ProcessedVideo) {
        self.preRecordedVid = preRecordedVid
        self.recordedVid = recordedVid
    }

    /// Computes angles of PoseNet data with trig
    /// Cycles through sets of joints to track which angles are available for capture, otherwise angle is marked as 0
    ///
    /// - Parameters:
    ///     - video: The video uploaded by the user and processed by the PoseNetProcessor
    private func computeAngles(video: ProcessedVideo) -> [[String: (CGFloat, CMTime)]] {
        var angles = [[String: (CGFloat, CMTime)]]()

        // Loops through data slices which contain pose points and computes joint angles
        for slice in video.data {
            var sliceData = [String: (CGFloat, CMTime)]()
            for triple in jointTriples {
                let pntOne = triple.0.rawValue
                let pntTwo = triple.1.rawValue
                let pntThree = triple.2.rawValue
                var angle: CGFloat = 0

                if slice.points[pntOne] != nil && slice.points[pntTwo] != nil && slice.points[pntThree] != nil {
                    angle = angleBetweenPoints(leftPoint: slice.points[pntThree]!, middlePoint: slice.points[pntTwo]!, rightPoint: slice.points[pntOne]!)
                }
                sliceData[pntTwo.rawValue] = (angle, slice.start)
            }
            angles.append(sliceData)
        }
        return angles
    }

    /// Computes rotations in PoseNet data
    ///
    /// - Parameters:
    ///     - video: The video uploaded by the user and processed by the PoseNetProcessor
    private func computeRotations(video: ProcessedVideo) -> [[String: CGFloat]] {
        var rotations = [[String: CGFloat]]()

        // Loop through data slices which have a previous frame and compute the change in distance
        for (index, slice) in video.data.enumerated() where index > 0 {
            var sliceData = [String: CGFloat]()
            let prevSlice = video.data[index - 1]

            for tuple in rotationTuples {
                let pntOne = tuple.0.rawValue
                let pntTwo = tuple.1.rawValue
                let axis = tuple.2
                var percentChange: CGFloat = 0

                if slice.points[pntOne] != nil && slice.points[pntTwo] != nil && prevSlice.points[pntOne] != nil && prevSlice.points[pntTwo] != nil {
                    percentChange = computePercentChange(cPointOne: slice.points[pntOne]!, cPointTwo: slice.points[pntTwo]!, pPointOne: prevSlice.points[pntOne]!, pPointTwo: prevSlice.points[pntTwo]!)
                }
                sliceData[axis] = percentChange
            }
            rotations.append(sliceData)
        }
        return rotations
    }

    private func angleBetweenPoints(leftPoint: VNRecognizedPoint, middlePoint: VNRecognizedPoint, rightPoint: VNRecognizedPoint) -> CGFloat {
        let leftCGPoint = leftPoint.location
        let middleCGPoint = middlePoint.location
        let rightCGPoint = rightPoint.location

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

    private func computePercentChange(cPointOne: VNRecognizedPoint, cPointTwo: VNRecognizedPoint, pPointOne: VNRecognizedPoint, pPointTwo: VNRecognizedPoint) -> CGFloat {
        let currPointOne = cPointOne.location
        let currPointTwo = cPointTwo.location
        let prevPointOne = pPointOne.location
        let prevPointTwo = pPointTwo.location

        let currDistance = CGPointDistance(from: currPointOne, to: currPointTwo)
        let prevDistance = CGPointDistance(from: prevPointOne, to: prevPointTwo)

        var percentChange: CGFloat = ((currDistance - prevDistance) / prevDistance)
        percentChange = percentChange > 2 ? 2 : percentChange

        return prevDistance == 0 ? 1 : percentChange
    }

    private func CGPointDistance(from: CGPoint, to: CGPoint) -> CGFloat {
        return sqrt((from.x - to.x) * (from.x - to.x) + (from.y - to.y) * (from.y - to.y))
    }

    private func computeAngleDifferences(preRecordedVid: ProcessedVideo, recordedVid: ProcessedVideo) -> [[String: CGFloat]] {

        let preRecordedPoses = computeAngles(video: preRecordedVid)
        let recordedPoses = computeAngles(video: recordedVid)
        let minSlices = min(preRecordedVid.data.count, recordedVid.data.count)

        var angleDifferences = [[String: CGFloat]]()

        for (row, poseAngles) in preRecordedPoses.enumerated() where row < minSlices {
            let slicesToCheck = 3
            // this also works well, need bigger sample size
            // let slicesToCheck = 10
            var sliceData = [String: CGFloat]()
            for angleTimeTuple in poseAngles {
                var lowestSliceScore = abs(angleTimeTuple.value.0 - recordedPoses[row][angleTimeTuple.key]!.0)
                for possibleSlice in (row < slicesToCheck ? 0 : row - slicesToCheck)...(row + slicesToCheck > minSlices - 1 ? minSlices - 1 : row + slicesToCheck) {
                    let sliceScore = abs(preRecordedPoses[possibleSlice][angleTimeTuple.key]!.0 - recordedPoses[possibleSlice][angleTimeTuple.key]!.0)
                    if sliceScore < lowestSliceScore {
                        lowestSliceScore = sliceScore
                    }
                }
                sliceData[angleTimeTuple.key] = lowestSliceScore
                if lowestSliceScore > 100 {
                    self.mistakesArray.append((angleTimeTuple.key, angleTimeTuple.value.1))
                }
            }
            angleDifferences.append(sliceData)
        }

        return angleDifferences
    }

    // Calls computeRotations which returns percent changes in torso width and height to measure rotations
    // and then uses data to compute the differences in such movement between the two videos
    private func computeRotationDifferences(preRecordedVid: ProcessedVideo, recordedVid: ProcessedVideo) -> [[CGFloat]] {
        let preRecordedRotations = computeRotations(video: preRecordedVid)
        let recordedRotations = computeRotations(video: recordedVid)
        let minSlices = min(preRecordedRotations.count, recordedRotations.count)
        var tempPercentDiff: CGFloat = 0

        var rotationDifferences = [[CGFloat]](
            repeating: [CGFloat](),
            count: minSlices
        )

        for (row, rotations) in preRecordedRotations.enumerated() where row < minSlices {
            for (_, rotation) in rotations.enumerated() {
                tempPercentDiff = abs(rotation.value - recordedRotations[row][rotation.key]!)
                // Values of tempPercentChange
                tempPercentDiff = tempPercentDiff < 0.1 ? 0 : tempPercentDiff - 0.1
                // This is where to add shifts or padding to angle differences
                // i.e. we can ignore 3 degree differences in the angle by subtracting 3 from the abs(...)
                rotationDifferences[row].append(tempPercentDiff)
            }
        }
        return rotationDifferences
    }

    /// Unweighted Mean Squared Error Function - A single data point is a vector of angle differences so each angle difference is squared, all of the differences are summed, and the result
    /// is sqrted and then added to the total error
    private func computeUnweightedAngleMSE() throws -> CGFloat {
        guard self.preRecordedVid != nil && self.recordedVid != nil else { throw ScoringFunctionError.improperVideo }

        let prVid = preRecordedVid!
        let rVid = recordedVid!
        // Computes the max error that can be achieved in one pose
        let maxError: CGFloat = sqrt(CGFloat(jointTriples.count) * (pow(180, 2)))

        let angleDifferences = computeAngleDifferences(preRecordedVid: prVid, recordedVid: rVid)
        var error: CGFloat = 0
        var tempSum: CGFloat = 0

        // For future modifications we can either "clip" or weight lower the super large error values and super small error values per set of angles
        // so that really bad movements don't penalize too much
        for angleSet in angleDifferences {
            for angle in angleSet {
                tempSum += pow(angle.value, 2)
            }
            error += sqrt(tempSum)
            tempSum = 0
        }
        // Instead of returning total error, return the normalized per pose error
        // This avoids super high errors for long videos and gives a better indication of how the overall performance was
        let length = CGFloat(angleDifferences.count)
        return (maxError - error/length)/maxError
    }

    /// Mean Squared Error Function w/ rotation - A single data point is a vector of angle differences and another of rotation values, so each angle difference is squared, all of the differences are summed, and the result
    /// is sqrted and then added to the total error, and the same process is repeated for rotations
    private func computeMSE() throws -> CGFloat {
        guard self.preRecordedVid != nil && self.recordedVid != nil else { throw ScoringFunctionError.improperVideo }

        let prVid = preRecordedVid!
        let rVid = recordedVid!
        // Computes the max error that can be achieved in one pose
        let maxError: CGFloat = sqrt(CGFloat(jointTriples.count) * (pow(180, 2))) + self.rotationWeight * sqrt(CGFloat(rotationTuples.count) * (pow(180, 2)))
        // reset mistakes
        self.mistakesArray = []

        // currently the diff arrays are computed separately so the error is || angleDiffs || + || rotationDiffs ||
        // but we could possibly append the arrays for computation and get || angleDiffs + rotDiffs || resulting
        // in a different score
        let angleDifferences = computeAngleDifferences(preRecordedVid: prVid, recordedVid: rVid)
        let rotationDifferences = computeRotationDifferences(preRecordedVid: prVid, recordedVid: rVid)
        var error: CGFloat = 0
        var tempSum: CGFloat = 0

        // For future modifications we can either "clip" or weight lower the super large error values and super small error values per set of angles
        // so that really bad movements don't penalize too much
        var lowError: CGFloat = 9999999999
        for angleSet in angleDifferences {
            for angle in angleSet {
                tempSum += pow(angle.value, 2)
            }
            error += sqrt(tempSum)
            if tempSum < lowError {
                lowError = tempSum
            }
            tempSum = 0
        }

        // Rotational differences come as values in [0, 1], and since angle values are in [0, 180] we scale the
        // value of the rotational difference by some weight (currently 180 so that the diff matches angles)
        // We can also scale the result of || rotDiffs || by some weight
        for rotations in rotationDifferences {
            for rotation in rotations {
                tempSum += pow(self.rotationMultiplier * rotation, 2)
            }
            error += self.rotationWeight * sqrt(tempSum)
            tempSum = 0
        }
        // Instead of returning total error, return the normalized per pose error
        // This avoids super high errors for long videos and gives a better indication of how the overall performance was
        let length = CGFloat(angleDifferences.count)
        return (maxError - error/length)/maxError
    }

    // computes score using any scoring function (currently MSE w/ rotations) and feeds result to callback

    func computeScore() -> Promise<(CGFloat, [(String, CMTime)])> {
        let promise = Promise<(CGFloat, [(String, CMTime)])> { fulfill, reject in
            do {
                let score = try self.computeMSE()
                return fulfill((score, self.mistakesArray))
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
