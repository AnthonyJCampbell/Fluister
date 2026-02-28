import SwiftUI
import AppKit

@main
struct FluisterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appDelegate.appState)
        } label: {
            Image(systemName: "waveform")
        }
        .menuBarExtraStyle(.menu)
    }
}
