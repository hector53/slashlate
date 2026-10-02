import XCTest
@testable import Slashlate

final class TranslationTargetTests: XCTestCase {
    // MARK: - Helpers

    private func wholeField(_ value: String) throws -> TranslationTarget {
        try TranslationTarget(trigger: .wholeField, fieldValue: value, selectedUTF16Range: nil)
    }

    /// Builds a current-line target with the cursor right after the first
    /// occurrence of `cursorAfter` (or at the end of the value).
    private func currentLine(_ value: String, cursorAfter marker: String? = nil) throws -> TranslationTarget {
        let cursor: Int
        if let marker, let range = value.range(of: marker) {
            cursor = value[..<range.upperBound].utf16.count
        } else {
            cursor = value.utf16.count
        }
        return try TranslationTarget(
            trigger: .currentLine,
            fieldValue: value,
            selectedUTF16Range: cursor..<cursor
        )
    }

    private func assertError(
        _ expected: TranslationTargetError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () throws -> TranslationTarget
    ) {
        XCTAssertThrowsError(try body(), file: file, line: line) { error in
            XCTAssertEqual(error as? TranslationTargetError, expected, file: file, line: line)
        }
    }

    // MARK: - Whole field (///) - M1 behavior

    func testRemovesTriggerBeforeTranslating() throws {
        let target = try wholeField("hola mundo ///")
        XCTAssertEqual(target.scope, .wholeField)
        XCTAssertEqual(target.sourceText, "hola mundo")
        XCTAssertEqual(target.originalValue, "hola mundo ///")
    }

    func testKeepsInternalLineBreaks() throws {
        XCTAssertEqual(try wholeField("hola\n\nadiós///").sourceText, "hola\n\nadiós")
    }

    func testOnlyTheFinalTriggerIsRemoved() throws {
        XCTAssertEqual(try wholeField("ver https://x.dev/a///b ///").sourceText, "ver https://x.dev/a///b")
    }

    func testRejectsValueWithoutTriggerAtEnd() {
        assertError(.triggerNotFound) { try self.wholeField("hola /// mundo") }
        assertError(.triggerNotFound) { try self.wholeField("hola //") }
    }

    func testTriggerOnlyHasNothingToTranslate() {
        assertError(.nothingToTranslate) { try self.wholeField("  ///") }
    }

    func testWholeFieldTranslatesEveryLine() throws {
        let target = try wholeField("linea 1\nhola mundo\nlinea 3 ///")
        XCTAssertEqual(target.sourceText, "linea 1\nhola mundo\nlinea 3")
        XCTAssertEqual(
            target.replacement(with: "Line 1\nHello world\nLine 3"),
            FieldReplacement(value: "Line 1\nHello world\nLine 3", cursorUTF16Offset: nil)
        )
    }

    func testWholeFieldIgnoresCursorPosition() throws {
        // /// keeps working on controls without AXSelectedTextRange.
        let target = try TranslationTarget(
            trigger: .wholeField,
            fieldValue: "hola ///",
            selectedUTF16Range: 0..<4
        )
        XCTAssertEqual(target.sourceText, "hola")
    }

    // MARK: - Current line (//.)

    func testCurrentLineTranslatesOnlyTheLastLine() throws {
        let target = try currentLine("Esta línea debe permanecer en español.\nesta linea debe traducirse //.")
        XCTAssertEqual(target.scope, .currentLine)
        XCTAssertEqual(target.sourceText, "esta linea debe traducirse")
        XCTAssertEqual(
            target.replacement(with: "This line should be translated.").value,
            "Esta línea debe permanecer en español.\nThis line should be translated."
        )
    }

    func testCurrentLineWorksOnAMiddleLine() throws {
        let target = try currentLine("linea 1\nhola mundo //.\nlinea 3", cursorAfter: "//.")
        XCTAssertEqual(target.sourceText, "hola mundo")
        XCTAssertEqual(
            target.replacement(with: "Hello world."),
            FieldReplacement(value: "linea 1\nHello world.\nlinea 3", cursorUTF16Offset: 20)
        )
    }

    func testCurrentLineWithEmptyLinesAround() throws {
        let value = "\n\nlinea 1\n\n\nhola mundo //.\n\n\nlinea 3\n\n"
        let target = try currentLine(value, cursorAfter: "//.")
        XCTAssertEqual(target.sourceText, "hola mundo")
        XCTAssertEqual(
            target.replacement(with: "Hello world.").value,
            "\n\nlinea 1\n\n\nHello world.\n\n\nlinea 3\n\n"
        )
    }

    func testCurrentLineRemovesOnlyTheTrigger() throws {
        let target = try currentLine("a\nver https://x.dev/a///b y 3//2 //.\nb", cursorAfter: " //.")
        XCTAssertEqual(target.sourceText, "ver https://x.dev/a///b y 3//2")
    }

    func testCurrentLineTriggerWithoutSpace() throws {
        XCTAssertEqual(try currentLine("hola mundo//.").sourceText, "hola mundo")
    }

    func testCurrentLineKeepsSurroundingTextByteForByte() throws {
        // Unicode, CRLF, tabs and trailing spaces outside the line must survive.
        let before = "Primera línea café 👍🏽  \r\n\tsegunda\t\r\n"
        let after = "\r\núltima 🇲🇽 línea   \n"
        let target = try currentLine(before + "  hola mundo //." + after, cursorAfter: "//.")

        let result = target.replacement(with: "Hello world.")
        XCTAssertEqual(result.value, before + "  Hello world." + after)
        XCTAssertTrue(result.value.utf8.starts(with: before.utf8))
        XCTAssertTrue(result.value.utf8.reversed().starts(with: after.utf8.reversed()))
        XCTAssertEqual(
            result.cursorUTF16Offset,
            (before + "  Hello world.").utf16.count
        )
    }

    func testCurrentLineIncludesTextAfterCursorOnSameLine() throws {
        let target = try currentLine("x\nhola //.mundo\ny", cursorAfter: "//.")
        XCTAssertEqual(target.sourceText, "hola mundo")
        XCTAssertEqual(target.replacement(with: "hello world").value, "x\nhello world\ny")
    }

    func testCurrentLineTriggerOnlyHasNothingToTranslate() {
        assertError(.nothingToTranslate) { try self.currentLine("hola\n  //.\nadiós", cursorAfter: "//.") }
    }

    func testCurrentLineRequiresCursorPosition() {
        assertError(.cursorUnavailable) {
            try TranslationTarget(trigger: .currentLine, fieldValue: "hola //.", selectedUTF16Range: nil)
        }
    }

    func testCurrentLineRejectsSelection() {
        assertError(.triggerNotFound) {
            try TranslationTarget(trigger: .currentLine, fieldValue: "hola //.", selectedUTF16Range: 0..<8)
        }
    }

    func testCurrentLineRejectsOutOfBoundsOrSplitCursor() {
        assertError(.triggerNotFound) {
            try TranslationTarget(trigger: .currentLine, fieldValue: "hola //.", selectedUTF16Range: 99..<99)
        }
        // Offset 1 is inside the surrogate pair of 👍.
        assertError(.triggerNotFound) {
            try TranslationTarget(trigger: .currentLine, fieldValue: "👍//.", selectedUTF16Range: 1..<1)
        }
    }

    func testTriggerElsewhereInTextDoesNotActivate() {
        // The cursor is not right after a //. (user moved it, or the trigger
        // is pasted text elsewhere in the field).
        assertError(.triggerNotFound) { try self.currentLine("hola //. mundo\notra linea") }
        assertError(.triggerNotFound) { try self.currentLine("linea //.\nhola mundo", cursorAfter: "hola") }
    }

    func testURLsDoNotActivateCurrentLine() {
        var detector = TriggerDetector()
        for character in "mira https://example.com/a/b//c y http://x.dev" {
            XCTAssertNil(detector.ingest(String(character)))
        }

        // Even if "//." is typed right after a URL scheme, it is not a trigger.
        assertError(.triggerNotFound) { try self.currentLine("abre https://.") }
    }

    func testURLsInTheLineAreKept() throws {
        XCTAssertEqual(
            try currentLine("mira https://x.dev/docs //.").sourceText,
            "mira https://x.dev/docs"
        )
    }

    // MARK: - Async safety (snapshot validation)

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

    func testCurrentLineDiscardedWhenUserEditsAnotherLineDuringRequest() throws {
        let target = try currentLine("linea 1\nhola mundo //.\nlinea 3", cursorAfter: "//.")
        XCTAssertEqual(
            ReplacementDecision(
                originalValue: target.originalValue,
                isSameFocusedElement: true,
                currentValue: "linea 1 editada\nhola mundo //.\nlinea 3"
            ),
            .textChanged
        )
    }

    func testCurrentLineDiscardedWhenFocusMovesToAnotherElement() throws {
        let target = try currentLine("linea 1\nhola mundo //.", cursorAfter: "//.")
        XCTAssertEqual(
            ReplacementDecision(
                originalValue: target.originalValue,
                isSameFocusedElement: false,
                currentValue: target.originalValue
            ),
            .focusChanged
        )
    }
}
