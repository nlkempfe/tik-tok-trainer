//
//  TikTokTrainerTests.swift
//  TikTokTrainerTests
//
//  Created by Hunter Jarrell on 1/13/21.
//

import XCTest
@testable import Promises
@testable import TikTokTrainer

class TikTokTrainerTests: XCTestCase {
//    // This function takes a very long time to run on CI/CD so it is commented so you can run it locally
//    func testPoseNetProcessorPerformance() {
//        let url = Bundle.main.url(forResource: "TestDance", withExtension: "mov")!
//        let measureOptions = XCTMeasureOptions()
//        measureOptions.iterationCount = 2
//        self.measure(options: measureOptions) {
//            _ = PoseNetProcessor.run(url: url)
//
//            XCTAssert(waitForPromises(timeout: 200))
//        }
//    }
//
//    func testDataProcessorPerformance() {
//        let testUrl = Bundle.main.url(forResource: "TestDance", withExtension: "mov")!
//        let trueUrl = Bundle.main.url(forResource: "TrueDance", withExtension: "mov")!
//        let processedVideos: Promise<[ProcessedVideo]> = all(
//            PoseNetProcessor.run(url: testUrl),
//            PoseNetProcessor.run(url: trueUrl)
//        )
//        XCTAssert(waitForPromises(timeout: 200))
//        let testVideo = processedVideos.value![0]
//        let trueVideo = processedVideos.value![1]
//
//        let measureOptions = XCTMeasureOptions()
//        measureOptions.iterationCount = 2
//        self.measure(options: measureOptions) {
//            _ = ScoringFunction(preRecordedVid: testVideo, recordedVid: trueVideo).computeScore()
//
//            XCTAssert(waitForPromises(timeout: 200))
//        }
//    }
//
//    func testTotalProcessingPerformance() {
//        let measureOptions = XCTMeasureOptions()
//        measureOptions.iterationCount = 2
//        self.measure(options: measureOptions) {
//            let testUrl = Bundle.main.url(forResource: "TestDance", withExtension: "mov")!
//            let trueUrl = Bundle.main.url(forResource: "TrueDance", withExtension: "mov")!
//            let processedVideos: Promise<[ProcessedVideo]> = all(
//                PoseNetProcessor.run(url: testUrl),
//                PoseNetProcessor.run(url: trueUrl)
//            )
//            XCTAssert(waitForPromises(timeout: 200))
//            let testVideo = processedVideos.value![0]
//            let trueVideo = processedVideos.value![1]
//
//            _ = ScoringFunction(preRecordedVid: testVideo, recordedVid: trueVideo).computeScore()
//
//            XCTAssert(waitForPromises(timeout: 200))
//        }
//    }
}
