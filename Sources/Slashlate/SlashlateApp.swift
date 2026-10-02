import SwiftUI

@main
struct SlashlateApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(systemName: "character.cursor.ibeam")
        }
        .menuBarExtraStyle(.window)
    }
}
