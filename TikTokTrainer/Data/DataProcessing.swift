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

typealias ScoreResult = (CGFloat, [CGFloat])
/// Process the PoseNet overlays on the pre-recorded and user-recorded videos and return a score
class ScoringFunction {
    var preRecordedVid: ProcessedVideo?
    var recordedVid: ProcessedVideo?

    // Angle is measured for the middle joint in each triple
    // Bottom two measure rotation along z axis

    let jointTriples: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        // Arm joints
        (.leftWrist, .leftElbow, .leftShoulder),
        (.rightShoulder, .rightElbow, .rightWrist),
        (.neck, .leftShoulder, .leftElbow),
        (.neck, .rightShoulder, .rightElbow),
        // Neck joints
        (.nose, .neck, .leftShoulder),
        (.nose, .neck, .rightShoulder),
        // Waist joints - to track rotation
        (.leftShoulder, .leftHip, .leftKnee),
        (.rightKnee, .rightHip, .rightShoulder),
        // Leg joints
        (.rightHip, .rightKnee, .rightAnkle),
        (.leftAnkle, .leftKnee, .leftHip),
        (.leftKnee, .leftHip, .root),
        (.root, .rightHip, .rightKnee)
    ]

    let rotationTuples: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName, String)] = [
        (.leftShoulder, .rightShoulder, "y-axis"),
        (.neck, .root, "x-axis")
    ]

    // Class variable - both computeAngles and computeRotations can contribute to mistakes
    var mistakesArray: [CGFloat] = []
    
    // constants for scoring
    let rotationMultiplier: CGFloat = 180
    let rotationWeight: CGFloat = 0.25
    let numArmBodyJoints: Int = 4
    let armJointWeight: CGFloat = 10
    let otherBodyJointWeight: CGFloat = 1
    let anglePadding: CGFloat = 10
    let rotPadding: CGFloat = 0.1
    
    var numArmJointsPresent: CGFloat = 0
    var numOtherJointsPresent: CGFloat = 0
    var armJointKeys: Set<String> = []
    
    // if joint angle can't be calculated assign negative value (since computeAngle only returns positive values)
    let invalidJoint: CGFloat = -42
    let invalidJointPresent: CGFloat = 90
    
    // The number of slices to check ahead of the current frame in the recordedVid
    let slicesToCheck = 3

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
    private func computeAngles(video: ProcessedVideo) -> [[String: CGFloat]] {
        var angles = [[String: CGFloat]]()
        angles.reserveCapacity(video.data.count)

        // Loops through data slices which contain pose points and computes joint angles
        for slice in video.data {
            var sliceData = [String: CGFloat]()
            
            for triple in jointTriples {
                let pntOne = triple.0.rawValue
                let pntTwo = triple.1.rawValue
                let pntThree = triple.2.rawValue
                var angle: CGFloat = 0

                // Compute the angle if required joints are present
                if slice.points[pntOne] != nil && slice.points[pntTwo] != nil && slice.points[pntThree] != nil {
                    angle = angleBetweenPoints(leftPoint: slice.points[pntThree]!, middlePoint: slice.points[pntTwo]!, rightPoint: slice.points[pntOne]!)
                } else {
                    angle = self.invalidJoint
                }
                
                // Key is all joints
                sliceData[pntOne.rawValue + " / " + pntTwo.rawValue + " / " + pntThree.rawValue] = angle
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
        
        for (index, jointTriple) in self.jointTriples.enumerated() where index < self.numArmBodyJoints {
            self.armJointKeys.insert(jointTriple.0.rawValue.rawValue + " / " + jointTriple.1.rawValue.rawValue + " / " + jointTriple.2.rawValue.rawValue)
        }

        for (row, poseAngles) in preRecordedPoses.enumerated() where row < minSlices {
            let slicesToCheck = 3
            // this also works well, need bigger sample size
            // let slicesToCheck = 10
            var sliceData = [String: CGFloat]()
            for (key, angle) in poseAngles {
                
                // penalizes a user for not showing joint on screen if uploaded video contains it or ignores joints that aren't on the screen
                if angle == self.invalidJoint && recordedPoses[row][key] != self.invalidJoint {
                    sliceData[key] = self.invalidJointPresent
                    continue
                } else if angle == self.invalidJoint && recordedPoses[row][key] == self.invalidJoint {
                    continue
                }
                
                if armJointKeys.contains(key) {
                    self.numArmJointsPresent += CGFloat(1)
                } else {
                    self.numOtherJointsPresent += CGFloat(1)
                }
                
                var lowestSliceScore = abs(angle - recordedPoses[row][key]!)
                for possibleSlice in (row < slicesToCheck ? 0 : row - slicesToCheck)...(row + slicesToCheck > minSlices - 1 ? minSlices - 1 : row + slicesToCheck) {
                    let sliceScore = abs(preRecordedPoses[possibleSlice][key]! - recordedPoses[possibleSlice][key]!)
                    if sliceScore < lowestSliceScore {
                        lowestSliceScore = sliceScore
                    }
                }
                sliceData[key] = lowestSliceScore < self.anglePadding ? CGFloat(0) : lowestSliceScore - self.anglePadding
                if lowestSliceScore > 90 {
                    let currTime = CGFloat(CMTimeGetSeconds(recordedVid.data[row].start))
                    // Second condition doesn't add mistakes if they happen in successive frames because this is almost guaranteed - want to isolate when the mistake started
                    if self.mistakesArray.count == 0 || currTime - self.mistakesArray.last! >= 0.5 {
                        self.mistakesArray.append(currTime)
                        break
                    }
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
                tempPercentDiff = tempPercentDiff < self.rotPadding ? 0 : tempPercentDiff - self.rotPadding
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

        // reset mistakes
        self.mistakesArray = []

        if prVid.data.count <= self.slicesToCheck || rVid.data.count <= self.slicesToCheck {
            return CGFloat(0)
        }

        // currently the diff arrays are computed separately so the error is || angleDiffs || + || rotationDiffs ||
        // but we could possibly append the arrays for computation and get || angleDiffs + rotDiffs || resulting
        // in a different score
        let angleDifferences = computeAngleDifferences(preRecordedVid: prVid, recordedVid: rVid)
        let rotationDifferences = computeRotationDifferences(preRecordedVid: prVid, recordedVid: rVid)
        var error: CGFloat = 0
        
        
        let avgNumArmJoints: CGFloat = self.numArmJointsPresent / CGFloat(angleDifferences.count)
        let avgNumOtherJoints: CGFloat = self.numOtherJointsPresent / CGFloat(angleDifferences.count)
        print(avgNumArmJoints)
        print(avgNumOtherJoints)

        // Computes the max error that can be achieved in one pose
        let maxError: CGFloat = self.armJointWeight * sqrt(avgNumArmJoints * (pow(180, 2))) + self.otherBodyJointWeight * sqrt(avgNumOtherJoints * pow(100, 2)) + self.rotationWeight * sqrt(CGFloat(rotationTuples.count) * (pow(180, 2)))
        self.numArmJointsPresent = 0
        self.numOtherJointsPresent = 0

        // For future modifications we can either "clip" or weight lower the super large error values and super small error values per set of angles
        // so that really bad movements don't penalize too much
        for angleSet in angleDifferences {
            var tempArmSum: CGFloat = 0
            var tempOtherJointSum: CGFloat = 0
            
            // Separate arm and other body joint weights
            for (key, angleDiff) in angleSet {
                if self.armJointKeys.contains(key) {
                    tempArmSum += pow(angleDiff, 2)
                } else {
                    tempOtherJointSum += pow(angleDiff, 2)
                }
            }
            error += self.armJointWeight * sqrt(tempArmSum) + self.otherBodyJointWeight * sqrt(tempOtherJointSum)
        }

        // Rotational differences come as values in [0, 1], and since angle values are in [0, 180] we scale the
        // value of the rotational difference by some weight (currently 180 so that the diff matches angles)
        // We can also scale the result of || rotDiffs || by some weight
        for rotations in rotationDifferences {
            var tempSum: CGFloat = 0
            for rotation in rotations {
                tempSum += pow(self.rotationMultiplier * rotation, 2)
            }
            error += self.rotationWeight * sqrt(tempSum)
        }
        
        // Instead of returning total error, return the normalized per pose error
        // This avoids super high errors for long videos and gives a better indication of how the overall performance was
        let length = CGFloat(angleDifferences.count)
        print(self.mistakesArray)
        print((maxError - error/length)/maxError)
        return (maxError - error/length)/maxError
    }

    // computes score using any scoring function (currently MSE w/ rotations) and feeds result to callback

    func computeScore() -> Promise<(CGFloat, [CGFloat])> {
        let promise = Promise<(CGFloat, [CGFloat])> { fulfill, reject in
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


////
////  DataProcessing.swift
////  TikTokTrainer
////
////  Created by Ankit  on 2/18/21.
////
//
//import Foundation
//import SwiftUI
//import AVKit
//import Vision
//import Promises
//import Accelerate
//
//typealias ScoreResult = (Float, [Float])
///// Process the PoseNet overlays on the pre-recorded and user-recorded videos and return a score
//class ScoringFunction {
//    let preRecordedVid: ProcessedVideo
//    let recordedVid: ProcessedVideo
//
//    // constants for scoring
//    let rotationMultiplier: Float = 180
//    let rotationWeight: Float = 0.25
//    let numUpperBodyJoints: Int = 6
//    let upperBodyJointWeight: Float = 20
//    let lowerBodyJointWeight: Float = 0.5
//    let anglePadding: Float = 10
//    let rotPadding: Float = 0.1
//
//    // Angle is measured for the middle joint in each triple
//    // Bottom two measure rotation along z axis
//
//    let jointTriples: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
//        (.leftWrist, .leftElbow, .leftShoulder),
//        (.rightShoulder, .rightElbow, .rightWrist),
//        (.neck, .leftShoulder, .leftElbow),
//        (.nose, .neck, .leftShoulder),
//        (.neck, .rightShoulder, .rightElbow),
//        (.nose, .neck, .rightShoulder),
//        (.leftAnkle, .leftKnee, .leftHip),
//        (.leftKnee, .leftHip, .root),
//        (.rightHip, .rightKnee, .rightAnkle),
//        (.root, .rightHip, .rightKnee),
//        (.leftShoulder, .leftHip, .leftKnee),
//        (.rightKnee, .rightHip, .rightShoulder)
//    ]
//
//    let rotationTuples: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName, String)] = [
//        (.leftShoulder, .rightShoulder, "y-axis"),
//        (.neck, .root, "x-axis")
//    ]
//
//    // Class variable - both computeAngles and computeRotations can contribute to mistakes
//    var mistakesArray: [Float] = []
//
//    // The number of slices to check ahead of the current frame in the recordedVid
//    let slicesToCheck = 3
//
//    /// Initializes ScoringFunction with the two videos
//    ///
//    /// - Parameters:
//    ///     - preRecordedVid: The video uploaded by the user and processed by the PoseNetProcessor
//    ///     - recordedVid: The video recorded by the user and processed by the PoseNetProcessor
//    required init(preRecordedVid: ProcessedVideo, recordedVid: ProcessedVideo) {
//        self.preRecordedVid = preRecordedVid
//        self.recordedVid = recordedVid
//    }
//
//    /// Computes angles of PoseNet data with trig
//    /// Cycles through sets of joints to track which angles are available for capture, otherwise angle is marked as 0
//    ///
//    /// - Parameters:
//    ///     - video: The video uploaded by the user and processed by the PoseNetProcessor
//    private func computeAngles(video: ProcessedVideo) -> [[Float]] {
//        var angles = [[Float]]()
//        angles.reserveCapacity(video.data.count)
//
//        // Loops through data slices which contain pose points and computes joint angles
//        for slice in video.data {
//            var sliceData = [Float]()
//            sliceData.reserveCapacity(self.jointTriples.count)
//            for triple in jointTriples {
//                let jntOne = triple.0.rawValue
//                let jntTwo = triple.1.rawValue
//                let jntThree = triple.2.rawValue
//                var angle: Float = 0.0
//
//                guard let pntOne = slice.points[jntOne] else { break; }
//                guard let pntTwo = slice.points[jntTwo] else { break; }
//                guard let pntThree = slice.points[jntThree] else { break; }
//
//                if pntOne.confidence > 0.2 && pntTwo.confidence > 0.2 && pntThree.confidence > 0.2 {
//                    angle = angleBetweenPoints(leftCGPoint: pntThree.location, middleCGPoint: pntTwo.location, rightCGPoint: pntOne.location)
//                }
//                sliceData.append(angle)
//            }
//            angles.append(sliceData)
//        }
//        return angles
//    }
//
//    /// Computes rotations in PoseNet data
//    ///
//    /// - Parameters:
//    ///     - video: The video uploaded by the user and processed by the PoseNetProcessor
//    private func computeRotations(video: ProcessedVideo) -> [[Float]] {
//        var rotations = [[Float]]()
//        // reserveCapacity will shorten the time for appending
//        rotations.reserveCapacity(video.data.count)
//
//        // Loop through data slices which have a previous frame and compute the change in distance
//        for (index, slice) in video.data.enumerated() where index > 0 {
//            var sliceData = [Float]()
//            sliceData.reserveCapacity(self.jointTriples.count)
//            let prevSlice = video.data[index - 1]
//
//            for tuple in rotationTuples {
//                let pntOne = tuple.0.rawValue
//                let pntTwo = tuple.1.rawValue
//                var percentChange: Float = 0
//
//                if slice.points[pntOne] != nil && slice.points[pntTwo] != nil && prevSlice.points[pntOne] != nil && prevSlice.points[pntTwo] != nil {
//                    percentChange = computePercentChange(cPointOne: slice.points[pntOne]!, cPointTwo: slice.points[pntTwo]!, pPointOne: prevSlice.points[pntOne]!, pPointTwo: prevSlice.points[pntTwo]!)
//                }
//                sliceData.append(percentChange)
//            }
//            rotations.append(sliceData)
//        }
//        return rotations
//    }
//
//    internal func angleBetweenPoints(leftCGPoint: CGPoint, middleCGPoint: CGPoint, rightCGPoint: CGPoint) -> Float {
//        let rightVector = (x: rightCGPoint.x - middleCGPoint.x, y: rightCGPoint.y - middleCGPoint.y)
//        let leftVector = (x: leftCGPoint.x - middleCGPoint.x, y: leftCGPoint.y - middleCGPoint.y)
//        let dotProduct = rightVector.x * leftVector.x + rightVector.y * leftVector.y
//        let determinant = rightVector.x * leftVector.y - rightVector.y * leftVector.x
//        var angle = atan2(determinant, dotProduct) * (180 / .pi)
//        if angle < 0 {
//            angle += 360
//        }
//        return Float(angle)
//    }
//
//    private func computePercentChange(cPointOne: VNRecognizedPoint, cPointTwo: VNRecognizedPoint, pPointOne: VNRecognizedPoint, pPointTwo: VNRecognizedPoint) -> Float {
//        let currPointOne = cPointOne.location
//        let currPointTwo = cPointTwo.location
//        let prevPointOne = pPointOne.location
//        let prevPointTwo = pPointTwo.location
//
//        let currDistance = CGPointDistance(from: currPointOne, to: currPointTwo)
//        let prevDistance = CGPointDistance(from: prevPointOne, to: prevPointTwo)
//
//        var percentChange: Float = ((currDistance - prevDistance) / prevDistance)
//        percentChange = percentChange > 2 ? 2 : percentChange
//
//        return prevDistance == 0 ? 1 : percentChange
//    }
//
//    private func CGPointDistance(from: CGPoint, to: CGPoint) -> Float {
//        return Float(sqrt((from.x - to.x) * (from.x - to.x) + (from.y - to.y) * (from.y - to.y)))
//    }
//
//    private func computeAngleDifferences(preRecordedVid: ProcessedVideo, recordedVid: ProcessedVideo) -> Float {
//        let preRecordedPoses = computeAngles(video: preRecordedVid)
//        let recordedPoses = computeAngles(video: recordedVid)
//        let minSlices = min(preRecordedVid.data.count, recordedVid.data.count)
//
//        var angleScore: Float = 0.0
//        var angleDiffShifts = [[[Float]]]()
//
//        // Compute slicesToCheck + 1 many arrays of angle differences so that the frame by frame values can be compared and the lowest error frame can be assigned - closest pose matching
//        for shift in 0 ... slicesToCheck {
//            var angleDiffs = [[Float]]()
//            angleDiffs.reserveCapacity(minSlices)
//            for (row, (preAngleSlice, recAngleSlice)) in zip(preRecordedPoses, recordedPoses.dropFirst(shift)).enumerated() where row < minSlices - shift {
//                let tempArr = vDSP.subtract(preAngleSlice, recAngleSlice).map { abs($0) < self.anglePadding ? 0.0 : abs($0) - self.anglePadding }
//                angleDiffs.append(tempArr)
//            }
//            angleDiffShifts.append(angleDiffs)
//        }
//
//        // Do the comparison of each frame by analyzing the error value to find the lowest one
//        for angleSlice in 0 ... angleDiffShifts[slicesToCheck].count - 1 {
//            var minSliceScore: Float = 100000000
//            var lowArr: [Float] = []
//            for index in 0 ... slicesToCheck {
//                // Current slice of data in one of the shifted frames (composed of data containing angle differences between recorded frame and one of the shifted pre-recorded frames)
//                let tempArr = angleDiffShifts[index][angleSlice]
//                let sqTempArr = tempArr.map{ $0 * $0 }
//                // Upper body angles
//                let tempUpperArr = sqTempArr[..<self.numUpperBodyJoints]
//                // Lower body angles
//                let tempLowerArr = sqTempArr[self.numUpperBodyJoints...]
//                print(sqrt(tempUpperArr.reduce(0.0, +)))
//                print(sqrt(tempLowerArr.reduce(0.0, +)))
//                let tempScore = self.upperBodyJointWeight * sqrt(tempUpperArr.reduce(0.0, +)) + self.lowerBodyJointWeight * sqrt(tempLowerArr.reduce(0.0, +))
//                if tempScore < minSliceScore {
//                    minSliceScore = tempScore
//                    lowArr = tempArr
//                }
//            }
//            angleScore += minSliceScore
//
//            // Compute whether there are mistakes in the current slice
//            for angleDiff in lowArr {
//                if angleDiff > 90 {
//                    let currTime = Float(CMTimeGetSeconds(recordedVid.data[angleSlice].start))
//                    // Second condition doesn't add mistakes if they happen in successive frames because this is almost guaranteed - want to isolate when the mistake started
//                    if self.mistakesArray.count == 0 || currTime - self.mistakesArray.last! >= 0.5 {
//                        self.mistakesArray.append(currTime)
//                        break
//                    }
//                }
//            }
//        }
//
//        // returning the error from the angles because the computation to find the lowest error frame by frame is already being done
//        return angleScore
//    }
//
//    // Calls computeRotations which returns percent changes in torso width and height to measure rotations
//    // and then uses data to compute the differences in such movement between the two videos
//    private func computeRotationDifferences(preRecordedVid: ProcessedVideo, recordedVid: ProcessedVideo) -> [[Float]] {
//        let preRecordedRotations = computeRotations(video: preRecordedVid)
//        let recordedRotations = computeRotations(video: recordedVid)
//        let minSlices = min(preRecordedRotations.count, recordedRotations.count)
//
//        var rotationDifferences = [[Float]]()
//        rotationDifferences.reserveCapacity(minSlices)
//
//        for (row, (preRotSlice, recRotSlice)) in zip(preRecordedRotations, recordedRotations).enumerated() where row < minSlices {
//            let tempArr = vDSP.subtract(preRotSlice, recRotSlice).map { abs($0) < self.rotPadding ? 0.0 : abs($0) - self.rotPadding }
//            rotationDifferences.append(tempArr)
//        }
//
//        return rotationDifferences
//    }
//
//    /// Unweighted Mean Squared Error Function - A single data point is a vector of angle differences so each angle difference is squared, all of the differences are summed, and the result
//    /// is sqrted and then added to the total error
//    private func computeUnweightedAngleMSE() throws -> Float {
//        let prVid = preRecordedVid
//        let rVid = recordedVid
//        // Computes the max error that can be achieved in one pose
//        let maxError: Float = sqrt(Float(jointTriples.count) * (pow(180, 2)))
//
//        // computeAngleDifferences returns the score
//        let angleError = computeAngleDifferences(preRecordedVid: prVid, recordedVid: rVid)
//
//        // For future modifications we can either "clip" or weight lower the super large error values and super small error values per set of angles
//        // so that really bad movements don't penalize too much
//        // Instead of returning total error, return the normalized per pose error
//        // This avoids super high errors for long videos and gives a better indication of how the overall performance was
//        let length = Float(recordedVid.data.count)
//        return (maxError - angleError/length)/maxError
//    }
//
//    /// Mean Squared Error Function w/ rotation - A single data point is a vector of angle differences and another of rotation values, so each angle difference is squared, all of the differences are summed, and the result
//    /// is sqrted and then added to the total error, and the same process is repeated for rotations
//    private func computeMSE() throws -> Float {
//        let prVid = preRecordedVid
//        let rVid = recordedVid
//        // Computes the max error that can be achieved in one pose
//        let maxError: Float = self.upperBodyJointWeight * sqrt(Float(self.numUpperBodyJoints) * pow(180, 2)) + self.lowerBodyJointWeight * sqrt(Float(jointTriples.count - self.numUpperBodyJoints) * pow(180, 2)) + self.rotationWeight * sqrt(Float(rotationTuples.count) * (pow(180, 2)))
//        // reset mistakes
//        self.mistakesArray = []
//
//        if prVid.data.count <= self.slicesToCheck || rVid.data.count <= self.slicesToCheck {
//            return Float(0.0)
//        }
//
//        // currently the diff arrays are computed separately so the error is || angleDiffs || + || rotationDiffs ||
//        // but we could possibly append the arrays for computation and get || angleDiffs + rotDiffs || resulting
//        // in a different score
//        let angleScore = computeAngleDifferences(preRecordedVid: prVid, recordedVid: rVid)
//        let rotationDifferences = computeRotationDifferences(preRecordedVid: prVid, recordedVid: rVid)
//        var error: Float = angleScore
//
//        // For future modifications we can either "clip" or weight lower the super large error values and super small error values per set of angles
//        // so that really bad movements don't penalize too much
//        // Rotational differences usually come as values in [0, 1], and since angle values are in [0, 360] we scale the
//        // value of the rotational difference by some weight (currently 180 so that the diff matches angles)
//        // We can also scale the result of || rotDiffs || by some weight
//        for rotations in rotationDifferences {
//            let tempSum = rotations.map { pow(self.rotationMultiplier * $0, 2) }.reduce(0, +)
//            error += self.rotationWeight * sqrt(tempSum)
//        }
//
//        // Instead of returning total error, return the normalized per pose error
//        // This avoids super high errors for long videos and gives a better indication of how the overall performance was
//        let length = Float(rVid.data.count)
//        print(self.mistakesArray)
//        print((maxError - error/length)/maxError)
//        return (maxError - error/length)/maxError
//    }
//
//    // computes score using any scoring function (currently MSE w/ rotations) and feeds result to callback
//    func computeScore() -> Promise<ScoreResult> {
//        let promise = Promise<ScoreResult> { fulfill, reject in
//            do {
//                let score = try self.computeMSE()
//                return fulfill((score, self.mistakesArray))
//            } catch {
//                print("Error computing score.\n Error: \(error)")
//                return reject(error)
//            }
//        }
//        return promise
//    }
//}
//
//enum ScoringFunctionError: Error {
//    case videoLengthIncompatible
//    case improperVideo
//}
