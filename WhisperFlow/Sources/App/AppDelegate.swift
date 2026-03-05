import AppKit
import ServiceManagement
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var hotkeyManager: HotkeyManager?
    private var audioRecorder: AudioRecorder?
    private var pillWindowController: PillWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)

        // Initialize managers
        let pathManager = PathManager()
        pathManager.ensureDirectoriesExist()

        let preferencesManager = PreferencesManager(pathManager: pathManager)
        let logger = AppLogger(pathManager: pathManager)

        appState.pathManager = pathManager
        appState.preferencesManager = preferencesManager
        appState.logger = logger

        logger.log("Fluister launched")
        logger.log("DEV_MODE: \(pathManager.isDevMode)")

        // Initialize pill window
        pillWindowController = PillWindowController(appState: appState)

        // Initialize audio recorder
        audioRecorder = AudioRecorder(pathManager: pathManager, logger: logger)
        appState.audioRecorder = audioRecorder

        // Initialize transcription engine (local whisper-cli)
        let transcriptionEngine = TranscriptionEngine(pathManager: pathManager, logger: logger)
        appState.transcriptionEngine = transcriptionEngine

        // Initialize hotkey manager
        hotkeyManager = HotkeyManager(logger: logger)
        appState.hotkeyManager = hotkeyManager

        // Toggle mode: first press starts recording, second press stops and transcribes
        hotkeyManager?.onHotkeyDown = { [weak self] in
            self?.toggleRecording()
        }
        // onHotkeyUp not used in toggle mode
        hotkeyManager?.onEscapePressed = { [weak self] in
            self?.cancelCurrentOperation()
        }

        // Register hotkey from preferences
        let prefs = preferencesManager.load()
        let registered = hotkeyManager?.registerHotkey(from: prefs.hotkey) ?? false
        if !registered {
            logger.log("WARNING: Failed to register hotkey '\(prefs.hotkey)'")
            DispatchQueue.main.async {
                self.appState.hotkeyRegistrationFailed = true
            }
        } else {
            logger.log("Hotkey registered: \(prefs.hotkey)")
        }

        // Sync reactive state from persisted preferences
        appState.selectedModelProfile = prefs.modelProfile
        appState.selectedLanguage = prefs.language
        appState.formattingEnabled = prefs.formattingEnabled
        appState.speedMode = prefs.speedMode

        // Sync launch-at-login: re-register with SMAppService if the user
        // previously enabled it but the registration was lost (e.g. after
        // rebuild, app relocation, or macOS update).
        syncLaunchAtLogin(prefs: prefs, preferencesManager: preferencesManager, logger: logger)

        // Check model availability
        let modelManager = ModelManager(pathManager: pathManager, logger: logger)
        appState.modelManager = modelManager
        appState.modelAvailable = modelManager.isModelAvailable(profile: prefs.modelProfile)

        // Start clipboard monitor
        let clipboardMonitor = ClipboardMonitor(
            preferencesManager: preferencesManager, logger: logger, appState: appState
        )
        appState.clipboardMonitor = clipboardMonitor
        clipboardMonitor.start()
    }

    private func toggleRecording() {
        switch appState.currentState {
        case .idle:
            startRecording()
        case .recording:
            stopRecordingAndTranscribe()
        default:
            // If transcribing or in error/success state, ignore the keypress
            break
        }
    }

    private func startRecording() {
        // Guard: must be idle (prevents race condition with double-tap)
        guard appState.currentState == .idle else { return }
        guard let recorder = audioRecorder else { return }

        let prefs = appState.preferencesManager?.load() ?? Preferences.defaults
        guard appState.modelManager?.isModelAvailable(profile: prefs.modelProfile) == true else {
            appState.currentState = .error("No model downloaded. Use menu to download.")
            pillWindowController?.showPill()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.pillWindowController?.hidePill()
                self.appState.currentState = .idle
            }
            return
        }

        // Transition to recording IMMEDIATELY (same runloop tick) to prevent race
        appState.currentState = .recording
        appState.recordingDuration = 0

        appState.logger?.log("Recording started")

        // Register ESC as cancel key while recording
        hotkeyManager?.registerEscapeKey()

        pillWindowController?.showPill()

        recorder.audioLevelCallback = { [weak self] level in
            DispatchQueue.main.async {
                self?.appState.audioLevel = level
            }
        }

        recorder.startRecording(
            durationUpdate: { [weak self] duration in
                DispatchQueue.main.async {
                    self?.appState.recordingDuration = duration
                    // 9:30 warning
                    if duration >= 570 && duration < 571 {
                        self?.appState.showTimeWarning = true
                    }
                    // 10 minute hard cap
                    if duration >= 600 {
                        self?.stopRecordingAndTranscribe()
                    }
                }
            },
            onError: { [weak self] message in
                guard let self = self else { return }
                if message.contains("Microphone access denied") {
                    self.returnToIdle()
                    self.promptMicrophonePermission()
                } else {
                    self.appState.currentState = .error(message)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        self.returnToIdle()
                    }
                }
            }
        )
    }

    private func stopRecordingAndTranscribe() {
        guard appState.currentState == .recording else { return }
        guard let recorder = audioRecorder, let engine = appState.transcriptionEngine else { return }

        appState.logger?.log("Recording stopped, starting transcription")

        recorder.stopRecording { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let wavPath):
                DispatchQueue.main.async {
                    self.appState.currentState = .transcribing
                    self.appState.currentChunk = 0
                    self.appState.totalChunks = 0
                }

                let prefs = self.appState.preferencesManager?.load() ?? Preferences.defaults

                engine.transcribe(
                    wavPath: wavPath,
                    language: prefs.language,
                    modelProfile: prefs.modelProfile,
                    speedMode: prefs.speedMode,
                    progressCallback: { current, total in
                        DispatchQueue.main.async {
                            self.appState.currentChunk = current
                            self.appState.totalChunks = total
                        }
                    }
                ) { transcriptionResult in
                    DispatchQueue.main.async {
                        switch transcriptionResult {
                        case .success(let text):
                            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty {
                                self.appState.currentState = .error("No speech detected")
                                self.appState.logger?.log("Transcription returned empty text")
                            } else {
                                let finalText = prefs.formattingEnabled
                                    ? TextFormatter.format(trimmed)
                                    : trimmed

                                self.appState.clipboardMonitor?.markNextAsFluister()
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(finalText, forType: .string)
                                self.appState.currentState = .success
                                self.appState.logger?.log("Transcription copied to clipboard: \(finalText.prefix(50))...")

                                // Auto-paste into the active text field
                                self.simulatePaste()

                                // Save to history
                                self.appState.preferencesManager?.addTranscript(
                                    text: finalText,
                                    durationMs: Int(self.appState.recordingDuration * 1000),
                                    language: prefs.language,
                                    model: prefs.modelProfile.rawValue
                                )
                            }

                        case .failure(let error):
                            self.appState.currentState = .error(error.localizedDescription)
                            self.appState.logger?.log("Transcription error: \(error)")
                        }

                        // Auto-hide pill after delay and return to idle
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.returnToIdle()
                        }
                    }
                }

            case .failure(let error):
                DispatchQueue.main.async {
                    self.appState.currentState = .error(error.localizedDescription)
                    self.appState.logger?.log("Recording error: \(error)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.returnToIdle()
                    }
                }
            }
        }
    }

    private func cancelCurrentOperation() {
        appState.logger?.log("Operation cancelled by user")

        switch appState.currentState {
        case .recording:
            audioRecorder?.cancelRecording()
        case .transcribing:
            appState.transcriptionEngine?.cancel()
        default:
            break
        }

        returnToIdle()
    }

    private func promptMicrophonePermission() {
        let alert = NSAlert()
        alert.messageText = "Microphone Access Required"
        alert.informativeText = "Fluister needs microphone access to record your voice. Please enable it in System Settings."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
        }
    }

    /// Simulate ⌘V to paste the clipboard into whatever text field is focused.
    ///
    /// Uses CGEvent with `.cgSessionEventTap` to inject into the active user-session
    /// event stream. Requires Accessibility permission, which is now tracked by the
    /// stable "Fluister Dev Signing" certificate identity — so the grant persists
    /// across rebuilds and never needs to be re-granted.
    private func simulatePaste() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        guard AXIsProcessTrustedWithOptions(options as CFDictionary) else {
            appState.logger?.log("Auto-paste skipped: Accessibility not granted (prompted user)")
            return
        }

        // 100ms delay lets the pasteboard write propagate before the keypress fires.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let src = CGEventSource(stateID: .combinedSessionState)
            guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true),
                  let keyUp   = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false) else {
                self.appState.logger?.log("WARNING: Failed to create CGEvent for paste")
                return
            }
            keyDown.flags = .maskCommand
            keyUp.flags   = .maskCommand
            keyDown.post(tap: .cgSessionEventTap)
            keyUp.post(tap: .cgSessionEventTap)
            self.appState.logger?.log("Auto-pasted via ⌘V (cgSessionEventTap)")
        }
    }

    /// Centralized idle-return: hides pill, resets state, unregisters ESC
    private func returnToIdle() {
        appState.currentState = .idle
        appState.showTimeWarning = false
        appState.audioLevel = 0
        pillWindowController?.hidePill()
        hotkeyManager?.unregisterEscapeKey()
    }

    /// Ensure SMAppService registration matches the user's saved preference.
    /// SMAppService registrations can be lost after a rebuild, app relocation,
    /// or macOS update — this re-registers when needed.
    private func syncLaunchAtLogin(prefs: Preferences, preferencesManager: PreferencesManager, logger: AppLogger) {
        let systemEnabled = SMAppService.mainApp.status == .enabled
        let userWants = prefs.launchAtLogin

        if userWants && !systemEnabled {
            do {
                try SMAppService.mainApp.register()
                logger.log("Re-registered launch-at-login (was lost)")
            } catch {
                logger.log("Failed to re-register launch-at-login: \(error)")
            }
        } else if !userWants && systemEnabled {
            do {
                try SMAppService.mainApp.unregister()
                logger.log("Unregistered launch-at-login (pref was disabled)")
            } catch {
                logger.log("Failed to unregister launch-at-login: \(error)")
            }
        }

        appState.launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
