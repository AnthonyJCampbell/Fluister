import AppKit
import Foundation

class ClipboardMonitor {
    private let preferencesManager: PreferencesManager
    private let logger: AppLogger?
    private weak var appState: AppState?
    private var timer: Timer?
    private var lastChangeCount: Int
    private var nextIsFluister = false

    init(preferencesManager: PreferencesManager, logger: AppLogger?, appState: AppState) {
        self.preferencesManager = preferencesManager
        self.logger = logger
        self.appState = appState
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        // Load existing history into appState
        appState?.clipboardHistory = preferencesManager.loadClipboardHistory()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Call this before writing a Fluister transcription to the pasteboard.
    func markNextAsFluister() {
        nextIsFluister = true
    }

    private func checkClipboard() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            nextIsFluister = false
            return
        }

        let isFluister = nextIsFluister
        nextIsFluister = false

        preferencesManager.addClipboardEntry(text: text, isFluister: isFluister)
        appState?.clipboardHistory = preferencesManager.loadClipboardHistory()

        if isFluister {
            logger?.log("Clipboard history: added Fluister transcription")
        }
    }
}
