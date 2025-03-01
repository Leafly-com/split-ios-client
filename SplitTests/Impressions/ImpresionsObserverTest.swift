//
//  ImpresionsObserverTest.swift
//  SplitTests
//
//  Created by Javier Avrudsky on 16/06/2021.
//  Copyright © 2021 Split. All rights reserved.
//

import Foundation

import XCTest
@testable import Split

class ImpressionsObserverTest: XCTestCase {

    var storage = HashedImpressionsStorageMock()

    func testBasicFunctionality() {
        let observer = DefaultImpressionsObserver(storage: storage)
        let impression = KeyImpression(featureName: "someKey", keyName: "someFeature", bucketingKey: nil, treatment: "on", label: "in segment all", time: Date().unixTimestamp(), changeNumber: 1234, previousTime: nil, storageId: nil)


        // Add 5 new impressions so that the old one is evicted and re-try the test.
        for imp in generateImpressions(count: 5) {
            _ = observer.testAndSet(impression: imp)
        }
        XCTAssertNil(observer.testAndSet(impression: impression))
        XCTAssertEqual(observer.testAndSet(impression: impression), impression.time)
    }

    func testConcurrencyVsAccuracy() throws {
        let observer = DefaultImpressionsObserver(storage: storage)
        let impressions = SynchronizedList<KeyImpression>()


        let operationQueue = OperationQueue()
        for _ in 0..<5 {
            operationQueue.addOperation {
                self.caller(observer: observer, count: 1000, impressions: impressions)
            }
        }
        operationQueue.waitUntilAllOperationsAreFinished()

        for imp in impressions.all {
            XCTAssertTrue(imp.previousTime == nil || imp.previousTime ?? 0 <= imp.time)
        }
    }

    func testSave() throws {
        let observer = DefaultImpressionsObserver(storage: storage)

        observer.saveHashes()

        XCTAssertTrue(storage.saveCalled)
    }

    func caller(observer: DefaultImpressionsObserver, count: Int, impressions: SynchronizedList<KeyImpression> ) {

        for _ in 0..<count {
            var impression = KeyImpression(featureName: "feature_\(Int.random(in: 1..<10))",
                                           keyName: "key_\(Int.random(in: 1..<100))",
                                           treatment: Bool.random() ? "on" : "off",
                                           label: "label_\(Int.random(in: 1..<5))",
                                           time: Date().unixTimestamp(),
                                           changeNumber: 1234567)

            impression.previousTime = observer.testAndSet(impression: impression)
            impressions.append(impression)
        }
    }

    func generateImpressions(count: Int) -> [KeyImpression] {
        var impressions = [KeyImpression]()
        for i in 0..<count {
            let impression = KeyImpression(featureName: "feature_\(i)",
                                           keyName: "key_\(i)",
                                           treatment: (i % 2 == 0 ? "on" : "off"),
                                           label:  (i % 2 == 0 ? "in segment all" : "whitelisted"),
                                           time:  Date().unixTimestamp(),
                                           changeNumber: Int64(i * i))
            impressions.append(impression)
        }
        return impressions
    }
}

