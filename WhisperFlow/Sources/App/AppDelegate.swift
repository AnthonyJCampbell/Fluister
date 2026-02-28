import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var hotkeyManager: HotkeyManager?
    private var audioRecorder: AudioRecorder?
    private var transcriptionEngine: TranscriptionEngine?
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

        // Initialize transcription engine
        transcriptionEngine = TranscriptionEngine(pathManager: pathManager, logger: logger)
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

        recorder.startRecording { [weak self] duration in
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
        }
    }

    private func stopRecordingAndTranscribe() {
        guard appState.currentState == .recording else { return }
        guard let recorder = audioRecorder, let engine = transcriptionEngine else { return }

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
            transcriptionEngine?.cancel()
        default:
            break
        }

        returnToIdle()
    }

    /// Simulate ⌘V to paste the clipboard into whatever text field is focused.
    /// Requires Accessibility permissions (macOS will prompt on first use).
    private func simulatePaste() {
        // Small delay to ensure the pasteboard is ready and the app regains focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let src = CGEventSource(stateID: .combinedSessionState)

            // Key code 9 = "V" on all keyboard layouts
            guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false) else {
                self.appState.logger?.log("WARNING: Failed to create CGEvent for paste")
                return
            }

            keyDown.flags = .maskCommand
            keyUp.flags = .maskCommand

            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)

            self.appState.logger?.log("Auto-pasted via ⌘V")
        }
    }

    /// Centralized idle-return: hides pill, resets state, unregisters ESC
    private func returnToIdle() {
        appState.currentState = .idle
        appState.showTimeWarning = false
        pillWindowController?.hidePill()
        hotkeyManager?.unregisterEscapeKey()
    }
}
