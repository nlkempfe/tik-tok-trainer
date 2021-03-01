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
    func testPoseNetProcessorPerformance() {
        let url = Bundle.main.url(forResource: "TestDance", withExtension: "mov")!
        let measureOptions = XCTMeasureOptions()
        measureOptions.iterationCount = 2
        self.measure(options: measureOptions) {
            _ = PoseNetProcessor.run(url: url)

            XCTAssert(waitForPromises(timeout: 200))
        }
    }
}
