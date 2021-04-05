//
//  CameraPreviewTest.swift
//  TikTokTrainer
//
//  Created by Hunter Jarrell on 2/13/21.
//

import SwiftUI
import AVKit
import Vision

/// View the live feed from a camera with an overlayed PoseNet skeleton on top.
/// Uses a GeometryReady to determine where to draw the skeleton at.
struct CameraPreview: View {
    @Binding var currentImage: UIImage?
    @Binding var result: PoseNetResult?
    @Binding var orientation: AVCaptureDevice.Position

    let previewImageCoordName = "previewImageSpace"
    
    var imgOverlay: some View {
        return ZStack{
            if result != nil && !(result?.points.isEmpty ?? true) {
                 GeometryReader { geo in
                    PoseNetOverlay(result: result,
                                   currentImage: currentImage,
                                   width: geo.frame(in: .named(previewImageCoordName)).width,
                                   height: geo.frame(in: .named(previewImageCoordName)).height,
                                   isFrontCamera: orientation == .front)
                        .stroke(Color.blue, lineWidth: 4)
                }
            }
        }
    }

    var body: some View {
        ZStack {
            if currentImage != nil {
                Image(uiImage: currentImage!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .coordinateSpace(name: previewImageCoordName)
                    .overlay(imgOverlay)
            }
        }.drawingGroup()
    }
}

struct PoseNetOverlay: Shape {

    let drawingPairs: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.neck, .leftShoulder),
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        (.neck, .rightShoulder),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        (.neck, .root),
        (.root, .leftHip),
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.root, .rightHip),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle),
        (.neck, .nose),
        (.nose, .leftEye),
        (.leftEye, .leftEar),
        (.nose, .rightEye),
        (.rightEye, .rightEar)
    ]

    static let nodeSizeLen = 4.0
    let nodeSize = CGSize(width: nodeSizeLen, height: nodeSizeLen)
    var result: PoseNetResult?
    var currentImage: UIImage?
    var width: CGFloat
    var height: CGFloat
    var isFrontCamera: Bool

    /// Shift a **CGPoint** relative to the height and width of the image preview
    private func normalizePoint(pnt: CGPoint) -> CGPoint {
        let shifted: CGPoint = VNImagePointForNormalizedPoint(pnt, Int(width), Int(height))
        .applying(CGAffineTransform(scaleX: 1.0, y: -1.0))
        .applying(CGAffineTransform(translationX: 0, y: height))
        return shifted
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        guard result != nil && currentImage != nil && !(result?.points.isEmpty ?? true) else {
            return path
        }

        let poseResult = result!

        poseResult.points.forEach { (_, pnt) in
            let shifted = normalizePoint(pnt: pnt)
            path.move(to: shifted)
            path.addEllipse(in: CGRect(origin: shifted, size: nodeSize))
        }

        for (startJoint, endJoint) in drawingPairs {
            if poseResult.points[startJoint] != nil && poseResult.points[endJoint] != nil {
                let shiftedStart = normalizePoint(pnt: poseResult.points[startJoint]!)
                let shiftedEnd = normalizePoint(pnt: poseResult.points[endJoint]!)

                path.move(to: shiftedStart)
                path.addLine(to: shiftedEnd)
            }
        }

        return path
    }
}

struct CameraPreview_Previews: PreviewProvider {

    static var previews: some View {
        let resultTest = PoseNetResult(points: [
            .neck: CGPoint(x: 0.2, y: 0.3),
            .leftShoulder: CGPoint(x: 0.3, y: 0.3),
            .leftElbow: CGPoint(x: 0.35, y: 0.35),
            .leftHip: CGPoint(x: 0.1, y: 0.6)
        ],
        imageSize: nil)
        CameraPreview(currentImage: .constant(UIImage(contentsOfFile: Bundle.main.path(forResource: "TestImage", ofType: "PNG")!)), result: .constant(resultTest), orientation: .constant(.front))
    }
}
