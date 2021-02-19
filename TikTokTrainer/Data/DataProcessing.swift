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
        let neck = result.points[.neck]!
        let nose = result.points[.nose]!
        
        var angle = angleBetweenPoints(leftPoint: leftWrist, middlePoint: leftElbow, rightPoint: leftShoulder)
        print("leftElbow: " + angle.description)
        angle = angleBetweenPoints(leftPoint: leftElbow, middlePoint: leftShoulder, rightPoint: neck)
        print("leftShoulder: " + angle.description)
        angle = angleBetweenPoints(leftPoint: nose, middlePoint: neck, rightPoint: leftShoulder)
        print("leftNeck: " + angle.description)
        print()
        
        return angle
    }
    
    func angleBetweenPoints(leftPoint: VNRecognizedPoint, middlePoint: VNRecognizedPoint, rightPoint: VNRecognizedPoint) -> CGFloat {
        return angleBetweenPoints(leftPoint: CGPoint(x: leftPoint.x, y: leftPoint.y), middlePoint: CGPoint(x: middlePoint.x, y: middlePoint.y), rightPoint: CGPoint(x: rightPoint.x, y: rightPoint.y))
    }
    
    func angleBetweenPoints(leftPoint: CGPoint, middlePoint: CGPoint, rightPoint: CGPoint) -> CGFloat {
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
    
}

