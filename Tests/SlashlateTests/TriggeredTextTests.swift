import XCTest
@testable import Slashlate

final class TriggeredTextTests: XCTestCase {
    func testRemovesTriggerBeforeTranslating() throws {
        let text = try XCTUnwrap(TriggeredText(fieldValue: "hola mundo ///", trigger: "///"))
        XCTAssertEqual(text.sourceText, "hola mundo")
        XCTAssertEqual(text.originalValue, "hola mundo ///")
    }

    func testKeepsInternalLineBreaks() throws {
        let text = try XCTUnwrap(TriggeredText(fieldValue: "hola\n\nadiós///", trigger: "///"))
        XCTAssertEqual(text.sourceText, "hola\n\nadiós")
    }

    func testOnlyTheFinalTriggerIsRemoved() throws {
        let text = try XCTUnwrap(TriggeredText(fieldValue: "ver https://x.dev/a///b ///", trigger: "///"))
        XCTAssertEqual(text.sourceText, "ver https://x.dev/a///b")
    }

    func testRejectsValueWithoutTriggerAtEnd() {
        XCTAssertNil(TriggeredText(fieldValue: "hola /// mundo", trigger: "///"))
        XCTAssertNil(TriggeredText(fieldValue: "hola //", trigger: "///"))
    }

    func testTriggerOnlyHasNothingToTranslate() throws {
        let text = try XCTUnwrap(TriggeredText(fieldValue: "  ///", trigger: "///"))
        XCTAssertFalse(text.hasTextToTranslate)
    }

    func testReplacesWhenFieldIsUnchanged() {
        XCTAssertEqual(
            ReplacementDecision(originalValue: "hola ///", isSameFocusedElement: true, currentValue: "hola ///"),
            .replace
        )
    }

    func testDoesNotReplaceWhenUserKeptTyping() {
        XCTAssertEqual(
            ReplacementDecision(originalValue: "hola ///", isSameFocusedElement: true, currentValue: "hola /// y más"),
            .textChanged
        )
    }

    func testDoesNotReplaceWhenUserDeletedText() {
        XCTAssertEqual(
            ReplacementDecision(originalValue: "hola mundo ///", isSameFocusedElement: true, currentValue: "hola"),
            .textChanged
        )
    }

    func testDoesNotReplaceWhenValueUnreadable() {
        XCTAssertEqual(
            ReplacementDecision(originalValue: "hola ///", isSameFocusedElement: true, currentValue: nil),
            .textChanged
        )
    }

    func testDoesNotReplaceWhenFocusMoved() {
        XCTAssertEqual(
            ReplacementDecision(originalValue: "hola ///", isSameFocusedElement: false, currentValue: "hola ///"),
            .focusChanged
        )
    }
}
