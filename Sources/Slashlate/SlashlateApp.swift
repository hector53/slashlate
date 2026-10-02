import SwiftUI

@main
struct SlashlateApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(systemName: menuBarSymbol)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarSymbol: String {
        if appState.isTranslating {
            return "ellipsis.circle"
        }
        if appState.hasUnseenAlert {
            return "exclamationmark.triangle.fill"
        }
        return "character.cursor.ibeam"
    }
}
