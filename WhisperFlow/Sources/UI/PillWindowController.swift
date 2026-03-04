import AppKit
import SwiftUI

class PillWindowController {
    private var panel: NSPanel?
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func showPill() {
        if panel == nil {
            createPanel()
        }

        updatePillSize()
        panel?.orderFront(nil)
    }

    /// Recalculate pill size and position. Call when state changes.
    func updatePillSize() {
        guard let panel = panel else { return }

        // Use wider pill for error states so the message is readable
        let isError: Bool
        if case .error = appState.currentState { isError = true } else { isError = false }
        let pillWidth: CGFloat = isError ? 320 : 220
        let pillHeight: CGFloat = isError ? 70 : 60

        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = NSScreen.main?.frame ?? .zero

        var x = mouseLocation.x - pillWidth / 2
        var y = mouseLocation.y + 20

        // Keep on screen
        x = max(screenFrame.minX + 10, min(x, screenFrame.maxX - pillWidth - 10))
        y = max(screenFrame.minY + 10, min(y, screenFrame.maxY - pillHeight - 10))

        panel.setFrame(NSRect(x: x, y: y, width: pillWidth, height: pillHeight), display: true)
    }

    func hidePill() {
        panel?.orderOut(nil)
    }

    private func createPanel() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 60),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.becomesKeyOnlyIfNeeded = true

        let hostingView = NSHostingView(rootView: PillView().environmentObject(appState))
        panel.contentView = hostingView

        self.panel = panel
    }
}
