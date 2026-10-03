import Carbon.HIToolbox
import XCTest
@testable import Slashlate

final class HotkeySettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "SlashlateTests.HotkeySettings"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func hotkey(_ modifiers: Int, key: Int = kVK_ANSI_K, label: String = "K") -> TranslationHotkey? {
        TranslationHotkey(keyCode: UInt32(key), modifiers: UInt32(modifiers), keyLabel: label)
    }

    func testDefaultIsControlOptionT() {
        XCTAssertEqual(TranslationHotkey.translate.displayName, "⌃⌥T")
        XCTAssertEqual(TranslationHotkey.translate.keyCode, UInt32(kVK_ANSI_T))
    }

    func testDisplayNameUsesStandardModifierOrder() {
        XCTAssertEqual(hotkey(cmdKey | shiftKey | optionKey | controlKey)?.displayName, "⌃⌥⇧⌘K")
        XCTAssertEqual(hotkey(optionKey | shiftKey, key: kVK_Space, label: "Space")?.displayName, "⌥⇧Space")
    }

    func testRequiresControlOrOption() {
        XCTAssertNotNil(hotkey(controlKey))
        XCTAssertNotNil(hotkey(optionKey))
        XCTAssertNotNil(hotkey(cmdKey | optionKey))
        // These would hijack normal app shortcuts or typing.
        XCTAssertNil(hotkey(cmdKey), "⌘K")
        XCTAssertNil(hotkey(cmdKey | shiftKey), "⌘⇧K")
        XCTAssertNil(hotkey(shiftKey), "⇧K")
        XCTAssertNil(hotkey(0), "K")
    }

    func testRejectsUnsupportedModifiersAndEmptyLabel() {
        XCTAssertNil(hotkey(controlKey | alphaLock))
        XCTAssertNil(hotkey(controlKey, label: ""))
    }

    func testStoreReturnsDefaultWhenEmpty() {
        XCTAssertEqual(SettingsStore(defaults: defaults).hotkey, .translate)
    }

    func testStoreRoundTrip() throws {
        let store = SettingsStore(defaults: defaults)
        let custom = try XCTUnwrap(hotkey(controlKey | cmdKey))
        store.hotkey = custom
        XCTAssertEqual(SettingsStore(defaults: defaults).hotkey, custom)
    }

    func testStoreResetToDefaultRemovesValue() throws {
        let store = SettingsStore(defaults: defaults)
        store.hotkey = try XCTUnwrap(hotkey(optionKey))
        store.hotkey = .translate
        XCTAssertNil(defaults.data(forKey: "hotkey"))
        XCTAssertEqual(store.hotkey, .translate)
    }

    func testStoreIgnoresInvalidStoredHotkey() throws {
        // A ⌘-only shortcut written by hand (or by an older version) is not loaded.
        let json = #"{"keyCode":8,"modifiers":\#(cmdKey),"keyLabel":"C"}"#
        defaults.set(Data(json.utf8), forKey: "hotkey")
        XCTAssertEqual(SettingsStore(defaults: defaults).hotkey, .translate)

        defaults.set(Data("not json".utf8), forKey: "hotkey")
        XCTAssertEqual(SettingsStore(defaults: defaults).hotkey, .translate)
    }
}
