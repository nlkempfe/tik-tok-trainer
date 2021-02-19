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


struct ScoringFunction {
    var result: PoseNetResult?
    
    let armPairs: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
    ]
    
    func computeAngles(result: PoseNetResult) -> CGFloat {
        let leftShoulder = result.points[.leftShoulder]!
        let leftElbow = result.points[.leftElbow]!
        let leftWrist = result.points[.leftWrist]!
        
        let leftArmAngle: CGFloat = ((atan2(leftWrist.y - leftElbow.y, leftWrist.x - leftElbow.x)) - (atan2(leftElbow.y - leftShoulder.y, leftElbow.x - leftShoulder.x))) * (180 / .pi)
        
        print(leftArmAngle)
        return leftArmAngle
        
//        do {
//                    for slice in try result.get().data {
//                        print(String(slice.start.value) + ":")
//                        let leftElbow = angleBetweenPoints(leftPoint: slice.points[VNRecognizedPointKey(rawValue: "left_shoulder_1_joint")]!, middlePoint: slice.points[VNRecognizedPointKey(rawValue: "left_forearm_joint")]!, rightPoint: slice.points[VNRecognizedPointKey(rawValue: "left_hand_joint")]!)
//                        print("     left elbow: " + String(leftElbow))
//                        let leftShoulder = angleBetweenPoints(leftPoint: slice.points[VNRecognizedPointKey(rawValue: "neck_1_joint")]!, middlePoint: slice.points[VNRecognizedPointKey(rawValue: "left_shoulder_1_joint")]!, rightPoint: slice.points[VNRecognizedPointKey(rawValue: "left_forearm_joint")]!)
//                        print("     left shoulder: " + String(leftShoulder))
//                        let leftNeck = angleBetweenPoints(leftPoint: slice.points[VNRecognizedPointKey(rawValue: "left_shoulder_1_joint")]!, middlePoint: slice.points[VNRecognizedPointKey(rawValue: "neck_1_joint")]!, rightPoint: slice.points[VNRecognizedPointKey(rawValue: "head_joint")]!)
//                        print("     left neck: " + String(leftNeck))
//                        let rightNeck = angleBetweenPoints(leftPoint: slice.points[VNRecognizedPointKey(rawValue: "head_joint")]!, middlePoint: slice.points[VNRecognizedPointKey(rawValue: "neck_1_joint")]!, rightPoint: slice.points[VNRecognizedPointKey(rawValue: "right_shoulder_1_joint")]!)
//                        print("     right neck: " + String(rightNeck))
//                        let rightShoulder = angleBetweenPoints(leftPoint: slice.points[VNRecognizedPointKey(rawValue: "right_forearm_joint")]!, middlePoint: slice.points[VNRecognizedPointKey(rawValue: "right_shoulder_1_joint")]!, rightPoint: slice.points[VNRecognizedPointKey(rawValue: "neck_1_joint")]!)
//                        print("     right shoulder: " + String(rightShoulder))
//                        let rightElbow = angleBetweenPoints(leftPoint: slice.points[VNRecognizedPointKey(rawValue: "right_hand_joint")]!, middlePoint: slice.points[VNRecognizedPointKey(rawValue: "right_forearm_joint")]!, rightPoint: slice.points[VNRecognizedPointKey(rawValue: "right_shoulder_1_joint")]!)
//                        print("     right elbow: " + String(rightElbow))
//
//                    }
//                } catch {
//                    print(error)
//                }
//            }
//
//            static func angleBetweenPoints(leftPoint: VNRecognizedPoint, middlePoint: VNRecognizedPoint, rightPoint: VNRecognizedPoint) -> Float64 {
//                print("         right point: " + String(rightPoint.x) + ", " + String(rightPoint.y))
//                print("         middle point: " + String(middlePoint.x) + ", " + String(middlePoint.y))
//                print("         left vector: " + String(leftPoint.x) + ", " + String(leftPoint.y))
//                let rightVector = (x: rightPoint.x - middlePoint.x, y: rightPoint.y - middlePoint.y)
//                let leftVector = (x: leftPoint.x - middlePoint.x, y: leftPoint.y - middlePoint.y)
//                print("         right vector: " + String(rightVector.x) + ", " + String(rightVector.y))
//                print("         left vector: " + String(leftVector.x) + ", " + String(leftVector.y))
//                let dotProduct = rightVector.x * leftVector.x + rightVector.y * leftVector.y
//                let determinant = rightVector.x * leftVector.y - rightVector.y * leftVector.x
//                var angle = atan2(determinant, dotProduct)
//                if angle < 0 {
//                    angle = angle + 360
//                }
//                return angle
//            }
    }
    
}

