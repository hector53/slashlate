import XCTest
@testable import Slashlate

final class TranslationTargetTests: XCTestCase {
    // MARK: - Helpers

    private func wholeField(_ value: String) throws -> TranslationTarget {
        try TranslationTarget(request: .typed(.wholeField), fieldValue: value, selectedUTF16Range: nil)
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
            request: .typed(.currentLine),
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
            request: .typed(.wholeField),
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
            try TranslationTarget(request: .typed(.currentLine), fieldValue: "hola //.", selectedUTF16Range: nil)
        }
    }

    func testCurrentLineRejectsSelection() {
        assertError(.triggerNotFound) {
            try TranslationTarget(request: .typed(.currentLine), fieldValue: "hola //.", selectedUTF16Range: 0..<8)
        }
    }

    func testCurrentLineRejectsOutOfBoundsOrSplitCursor() {
        assertError(.triggerNotFound) {
            try TranslationTarget(request: .typed(.currentLine), fieldValue: "hola //.", selectedUTF16Range: 99..<99)
        }
        // Offset 1 is inside the surrogate pair of 👍.
        assertError(.triggerNotFound) {
            try TranslationTarget(request: .typed(.currentLine), fieldValue: "👍//.", selectedUTF16Range: 1..<1)
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

    // MARK: - Hotkey (selection or whole field)

    private func hotkey(_ value: String, selecting marker: String? = nil) throws -> TranslationTarget {
        var selection: Range<Int>?
        if let marker, let range = value.range(of: marker) {
            let start = value[..<range.lowerBound].utf16.count
            selection = start..<(start + marker.utf16.count)
        }
        return try TranslationTarget(request: .hotkey, fieldValue: value, selectedUTF16Range: selection)
    }

    func testHotkeyTranslatesOnlyTheSelection() throws {
        let target = try hotkey("Hi team,\nya terminé el cambio\nThanks", selecting: "ya terminé el cambio")
        XCTAssertEqual(target.scope, .selection)
        XCTAssertEqual(target.sourceText, "ya terminé el cambio")
        XCTAssertEqual(
            target.replacement(with: "I finished the change"),
            FieldReplacement(
                value: "Hi team,\nI finished the change\nThanks",
                cursorUTF16Offset: "Hi team,\nI finished the change".utf16.count
            )
        )
    }

    func testHotkeySelectionWithinALine() throws {
        let target = try hotkey("Ok, mañana lo reviso, thanks", selecting: "mañana lo reviso")
        XCTAssertEqual(target.replacement(with: "I'll review it tomorrow").value, "Ok, I'll review it tomorrow, thanks")
    }

    func testHotkeySelectionKeepsEdgeWhitespace() throws {
        let target = try hotkey("a\n  hola mundo \nb", selecting: "\n  hola mundo \n")
        XCTAssertEqual(target.sourceText, "hola mundo")
        XCTAssertEqual(target.replacement(with: "hello world").value, "a\n  hello world \nb")
    }

    func testHotkeyWithoutSelectionTranslatesWholeField() throws {
        let value = "linea 1\nlinea 2"
        let target = try TranslationTarget(request: .hotkey, fieldValue: value, selectedUTF16Range: 3..<3)
        XCTAssertEqual(target.scope, .wholeField)
        XCTAssertEqual(target.sourceText, "linea 1\nlinea 2")
        XCTAssertEqual(target.replacement(with: "Line 1\nLine 2").value, "Line 1\nLine 2")
    }

    func testHotkeyWithoutCursorInfoTranslatesWholeField() throws {
        let target = try hotkey("hola mundo")
        XCTAssertEqual(target.scope, .wholeField)
        XCTAssertEqual(target.sourceText, "hola mundo")
    }

    func testHotkeyDoesNotStripTriggerLikeText() throws {
        // Nothing was typed, so "///" or "//." is just text.
        XCTAssertEqual(try hotkey("ver https://x.dev ///").sourceText, "ver https://x.dev ///")
        XCTAssertEqual(try hotkey("Nota: //.").sourceText, "Nota: //.")
    }

    func testHotkeyEmptyFieldOrBlankSelectionHasNothingToTranslate() {
        assertError(.nothingToTranslate) { try self.hotkey("  \n ") }
        assertError(.nothingToTranslate) { try self.hotkey("a   b", selecting: "   ") }
    }

    func testHotkeyRejectsInvalidSelection() {
        assertError(.selectionUnavailable) {
            try TranslationTarget(request: .hotkey, fieldValue: "hola", selectedUTF16Range: 2..<99)
        }
        assertError(.selectionUnavailable) {
            try TranslationTarget(request: .hotkey, fieldValue: "👍 hola", selectedUTF16Range: 1..<7)
        }
    }

    func testHotkeySelectionDiscardedWhenTextChanges() throws {
        let target = try hotkey("uno dos tres", selecting: "dos")
        XCTAssertEqual(
            ReplacementDecision(originalValue: target.originalValue, isSameFocusedElement: true, currentValue: "uno dos tres!"),
            .textChanged
        )
    }

    func testHotkeyIsDefinedOnce() {
        XCTAssertEqual(TranslationHotkey.translate.displayName, "⌃⌥T")
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
