import XCTest
@testable import Slashlate

final class TriggerDetectorTests: XCTestCase {
    private func ingest(_ text: String, into detector: inout TriggerDetector) -> [TranslationTrigger] {
        text.compactMap { detector.ingest(String($0)) }
    }

    func testDetectsWholeFieldTrigger() {
        var detector = TriggerDetector()
        XCTAssertEqual(ingest("hola ///", into: &detector), [.wholeField])
    }

    func testDetectsCurrentLineTrigger() {
        var detector = TriggerDetector()
        XCTAssertEqual(ingest("hola //.", into: &detector), [.currentLine])
    }

    func testScopesComeFromTheTriggerDefinition() {
        XCTAssertEqual(TranslationTrigger.wholeField.scope, .wholeField)
        XCTAssertEqual(TranslationTrigger.currentLine.scope, .currentLine)
    }

    func testIgnoresPartialAndUnrelatedSequences() {
        var detector = TriggerDetector()
        XCTAssertEqual(ingest("a // b /. c .// d 1/2. https://x.dev", into: &detector), [])
    }

    func testDetectsTriggerTypedInOneEvent() {
        var detector = TriggerDetector()
        XCTAssertEqual(detector.ingest("x//."), .currentLine)
    }

    func testBufferResetsAfterTrigger() {
        var detector = TriggerDetector()
        // After "///" fires, a following "." must not complete "//.".
        XCTAssertEqual(ingest("///.", into: &detector), [.wholeField])
    }

    func testResetClearsPartialInput() {
        var detector = TriggerDetector()
        XCTAssertNil(detector.ingest("//"))
        detector.reset()
        XCTAssertNil(detector.ingest("."))
    }
}
