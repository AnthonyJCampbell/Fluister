import ServiceManagement
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !appState.modelAvailable {
                Button("Download Model (Recommended)") {
                    downloadModel()
                }
            }

            if appState.isDownloading {
                Text("Downloading: \(Int(appState.downloadProgress * 100))%")
                Button("Cancel Download") {
                    appState.modelManager?.cancelDownload()
                    appState.isDownloading = false
                    appState.downloadProgress = 0
                }
            }

            Divider()

            // Model profile submenu — uses @Published for reactive checkmarks
            Menu("Model") {
                Button(appState.selectedModelProfile == .fast ? "✓ Fast (Small)" : "  Fast (Small)") {
                    setModelProfile(.fast)
                }
                Button(appState.selectedModelProfile == .balanced ? "✓ Balanced (Medium)" : "  Balanced (Medium)") {
                    setModelProfile(.balanced)
                }
            }

            // Language submenu — uses @Published for reactive checkmarks
            Menu("Language") {
                Button(appState.selectedLanguage == .english ? "✓ English" : "  English") {
                    setLanguage(.english)
                }
                Button(appState.selectedLanguage == .dutch ? "✓ Dutch" : "  Dutch") {
                    setLanguage(.dutch)
                }
                Button(appState.selectedLanguage == .auto ? "✓ Auto" : "  Auto") {
                    setLanguage(.auto)
                }
            }

            Text("Hotkey: \(appState.preferencesManager?.load().hotkey ?? Preferences.defaults.hotkey)")
                .foregroundColor(.secondary)

            Divider()

            // Clipboard history
            Menu("Recent") {
                let history = appState.clipboardHistory
                if history.isEmpty {
                    Text("No recent items")
                } else {
                    ForEach(history) { entry in
                        let cleaned = entry.text.replacingOccurrences(of: "\n", with: " ")
                        let preview = cleaned.count > 50 ? cleaned.prefix(47) + "..." : cleaned.prefix(50)
                        let label = entry.isFluisterTranscription ? "🎙 \(preview)" : "  \(preview)"
                        Button(label) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(entry.text, forType: .string)
                        }
                    }
                }
            }

            Divider()

            Menu("Settings") {
                Button(appState.formattingEnabled ? "✓ Text Formatting" : "  Text Formatting") {
                    toggleFormatting()
                }

                Button(appState.launchAtLogin ? "✓ Launch at Login" : "  Launch at Login") {
                    toggleLaunchAtLogin()
                }

                Divider()

                Button("Open Logs") {
                    if let pathManager = appState.pathManager {
                        let logFile = pathManager.logFile
                        if !FileManager.default.fileExists(atPath: logFile.path) {
                            FileManager.default.createFile(atPath: logFile.path, contents: nil)
                        }
                        NSWorkspace.shared.selectFile(logFile.path, inFileViewerRootedAtPath: "")
                    }
                }
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private func downloadModel() {
        guard let modelManager = appState.modelManager else { return }

        appState.isDownloading = true
        appState.downloadProgress = 0

        modelManager.downloadModel(profile: appState.selectedModelProfile) { progress in
            DispatchQueue.main.async {
                self.appState.downloadProgress = progress
            }
        } completion: { result in
            DispatchQueue.main.async {
                self.appState.isDownloading = false
                self.appState.downloadProgress = 0
                switch result {
                case .success:
                    self.appState.modelAvailable = true
                    self.appState.logger?.log("Model download completed successfully")
                case .failure(let error):
                    self.appState.logger?.log("Model download failed: \(error)")
                }
            }
        }
    }

    private func setModelProfile(_ profile: ModelProfile) {
        var prefs = appState.preferencesManager?.load() ?? Preferences.defaults
        prefs.modelProfile = profile
        appState.preferencesManager?.save(prefs)
        appState.selectedModelProfile = profile
        appState.modelAvailable = appState.modelManager?.isModelAvailable(profile: profile) ?? false
    }

    private func setLanguage(_ language: Language) {
        var prefs = appState.preferencesManager?.load() ?? Preferences.defaults
        prefs.language = language
        appState.preferencesManager?.save(prefs)
        appState.selectedLanguage = language
    }

    private func toggleFormatting() {
        var prefs = appState.preferencesManager?.load() ?? Preferences.defaults
        prefs.formattingEnabled = !prefs.formattingEnabled
        appState.preferencesManager?.save(prefs)
        appState.formattingEnabled = prefs.formattingEnabled
    }

    private func toggleLaunchAtLogin() {
        do {
            if appState.launchAtLogin {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            appState.launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            appState.logger?.log("Failed to toggle launch at login: \(error)")
        }
    }
}
