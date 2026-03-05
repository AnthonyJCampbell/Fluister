import ServiceManagement
import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            Divider()

            // Model submenu
            Menu("Model") {
                ForEach(ModelProfile.allCases, id: \.self) { profile in
                    Button(modelMenuLabel(for: profile)) {
                        selectOrDownloadModel(profile)
                    }
                }
                if appState.isDownloading {
                    Button("  Cancel Download") {
                        appState.modelManager?.cancelDownload()
                        appState.isDownloading = false
                        appState.downloadingProfile = nil
                        appState.downloadProgress = 0
                    }
                }
            }

            // Language submenu
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

            // Speed mode submenu
            Menu("Speed") {
                Button(appState.speedMode == .fast ? "✓ Fast" : "  Fast") {
                    setSpeedMode(.fast)
                }
                Button(appState.speedMode == .accurate ? "✓ Accurate" : "  Accurate") {
                    setSpeedMode(.accurate)
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

    private func modelMenuLabel(for profile: ModelProfile) -> String {
        let isSelected = appState.selectedModelProfile == profile
        let check = isSelected ? "✓" : " "
        let name = profile.displayName

        if appState.downloadingProfile == profile {
            return "\(check) \(name)  ↓"
        }

        let isDownloaded = appState.modelManager?.isModelAvailable(profile: profile) ?? false
        if isDownloaded {
            return "\(check) \(name)"
        } else {
            let size = ModelSources.source(for: profile).sizeDescription
            return "\(check) \(name)  ⬇ \(size)"
        }
    }

    private func selectOrDownloadModel(_ profile: ModelProfile) {
        let isDownloaded = appState.modelManager?.isModelAvailable(profile: profile) ?? false
        setModelProfile(profile)
        if !isDownloaded {
            downloadModel(profile: profile)
        }
    }

    private func downloadModel(profile: ModelProfile) {
        guard let modelManager = appState.modelManager else { return }

        // Cancel any in-progress download first
        if appState.isDownloading {
            modelManager.cancelDownload()
        }

        appState.isDownloading = true
        appState.downloadingProfile = profile
        appState.downloadProgress = 0

        modelManager.downloadModel(profile: profile) { _ in
            // Progress not displayed in menu
        } completion: { result in
            DispatchQueue.main.async {
                self.appState.isDownloading = false
                self.appState.downloadingProfile = nil
                self.appState.downloadProgress = 0
                switch result {
                case .success:
                    self.appState.modelAvailable = true
                    self.appState.logger?.log("Model download completed: \(profile.rawValue)")
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

    private func setSpeedMode(_ mode: SpeedMode) {
        var prefs = appState.preferencesManager?.load() ?? Preferences.defaults
        prefs.speedMode = mode
        appState.preferencesManager?.save(prefs)
        appState.speedMode = mode
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

            if var prefs = appState.preferencesManager?.load() {
                prefs.launchAtLogin = appState.launchAtLogin
                appState.preferencesManager?.save(prefs)
            }
        } catch {
            appState.logger?.log("Failed to toggle launch at login: \(error)")
        }
    }
}
