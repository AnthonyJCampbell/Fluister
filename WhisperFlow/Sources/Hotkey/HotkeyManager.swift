import Carbon
import AppKit

class HotkeyManager {
    var onHotkeyDown: (() -> Void)?
    var onHotkeyUp: (() -> Void)?
    var onEscapePressed: (() -> Void)?

    private var hotkeyRef: EventHotKeyRef?
    private var escapeHotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let logger: AppLogger?

    // Track key-down state for hold-to-talk
    private var isKeyDown = false

    // Prevent premature deallocation: the Carbon callback holds an unretained pointer to self,
    // so we must ensure self stays alive as long as the handler is installed.
    // The passRetained/passUnretained pattern is safe because we balance it in deinit.
    private var retainedSelf: Unmanaged<HotkeyManager>?

    init(logger: AppLogger?) {
        self.logger = logger
        installEventHandler()
    }

    deinit {
        unregisterAll()
        if let handlerRef = eventHandlerRef {
            RemoveEventHandler(handlerRef)
        }
        // Balance the passRetained from installEventHandler
        retainedSelf?.release()
    }

    /// Register a hotkey from a string like "Control+Option+Space"
    func registerHotkey(from hotkeyString: String) -> Bool {
        unregisterHotkey()

        guard let (modifiers, keyCode) = parseHotkeyString(hotkeyString) else {
            logger?.log("Failed to parse hotkey string: \(hotkeyString)")
            return false
        }

        let hotkeyID = EventHotKeyID(signature: OSType(0x5746_4C57), id: 1) // "WFLW"
        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr, hotKeyRef != nil else {
            logger?.log("Failed to register hotkey, status: \(status)")
            return false
        }

        self.hotkeyRef = hotKeyRef
        // ESC is NOT registered here — it's registered on-demand when recording starts
        return true
    }

    func unregisterHotkey() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
    }

    /// Register ESC as cancel key. Call when entering recording/transcribing state.
    func registerEscapeKey() {
        guard escapeHotkeyRef == nil else { return } // already registered
        let hotkeyID = EventHotKeyID(signature: OSType(0x5746_4C57), id: 2) // "WFLW" id=2
        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(
            UInt32(kVK_Escape),
            0,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status == noErr {
            self.escapeHotkeyRef = hotKeyRef
        }
    }

    /// Unregister ESC cancel key. Call when returning to idle state.
    func unregisterEscapeKey() {
        if let ref = escapeHotkeyRef {
            UnregisterEventHotKey(ref)
            escapeHotkeyRef = nil
        }
    }

    func showHotkeyCapturePanel() {
        let alert = NSAlert()
        alert.messageText = "Set Hotkey"
        alert.informativeText = "Press the key combination you want to use, then click OK.\n\nCurrent implementation uses Control+Option+Space.\nCustom hotkey capture will be available in a future update."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Private

    private func unregisterAll() {
        unregisterHotkey()
        unregisterEscapeKey()
    }

    private func installEventHandler() {
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        let handlerBlock: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            return manager.handleCarbonEvent(event!)
        }

        // Use passRetained to ensure self stays alive for the Carbon callback's lifetime.
        // We release in deinit to balance this.
        let retained = Unmanaged.passRetained(self)
        self.retainedSelf = retained

        InstallEventHandler(
            GetApplicationEventTarget(),
            handlerBlock,
            eventTypes.count,
            &eventTypes,
            retained.toOpaque(),
            &eventHandlerRef
        )
    }

    private func handleCarbonEvent(_ event: EventRef) -> OSStatus {
        var hotkeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotkeyID
        )

        guard status == noErr else { return OSStatus(eventNotHandledErr) }

        let eventKind = GetEventKind(event)

        if hotkeyID.id == 2 {
            // Escape key
            if eventKind == UInt32(kEventHotKeyPressed) {
                DispatchQueue.main.async { [weak self] in
                    self?.onEscapePressed?()
                }
            }
            return noErr
        }

        if hotkeyID.id == 1 {
            if eventKind == UInt32(kEventHotKeyPressed) {
                isKeyDown = true
                DispatchQueue.main.async { [weak self] in
                    self?.onHotkeyDown?()
                }
            } else if eventKind == UInt32(kEventHotKeyReleased) {
                if isKeyDown {
                    isKeyDown = false
                    DispatchQueue.main.async { [weak self] in
                        self?.onHotkeyUp?()
                    }
                }
            }
            return noErr
        }

        return OSStatus(eventNotHandledErr)
    }

    /// Parse "Control+Option+Space" into (carbonModifiers, keyCode)
    func parseHotkeyString(_ str: String) -> (UInt32, UInt32)? {
        let parts = str.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        guard !parts.isEmpty else { return nil }

        var modifiers: UInt32 = 0
        var keyName = ""

        for part in parts {
            switch part {
            case "control", "ctrl":
                modifiers |= UInt32(controlKey)
            case "option", "alt":
                modifiers |= UInt32(optionKey)
            case "command", "cmd":
                modifiers |= UInt32(cmdKey)
            case "shift":
                modifiers |= UInt32(shiftKey)
            default:
                keyName = part
            }
        }

        guard let keyCode = keyCodeFromName(keyName) else { return nil }
        return (modifiers, keyCode)
    }

    private func keyCodeFromName(_ name: String) -> UInt32? {
        switch name {
        case "space": return UInt32(kVK_Space)
        case "return", "enter": return UInt32(kVK_Return)
        case "tab": return UInt32(kVK_Tab)
        case "delete", "backspace": return UInt32(kVK_Delete)
        case "escape", "esc": return UInt32(kVK_Escape)
        case "f1": return UInt32(kVK_F1)
        case "f2": return UInt32(kVK_F2)
        case "f3": return UInt32(kVK_F3)
        case "f4": return UInt32(kVK_F4)
        case "f5": return UInt32(kVK_F5)
        case "f6": return UInt32(kVK_F6)
        case "f7": return UInt32(kVK_F7)
        case "f8": return UInt32(kVK_F8)
        case "a": return UInt32(kVK_ANSI_A)
        case "b": return UInt32(kVK_ANSI_B)
        case "c": return UInt32(kVK_ANSI_C)
        case "d": return UInt32(kVK_ANSI_D)
        case "e": return UInt32(kVK_ANSI_E)
        case "f": return UInt32(kVK_ANSI_F)
        case "g": return UInt32(kVK_ANSI_G)
        case "h": return UInt32(kVK_ANSI_H)
        case "i": return UInt32(kVK_ANSI_I)
        case "j": return UInt32(kVK_ANSI_J)
        case "k": return UInt32(kVK_ANSI_K)
        case "l": return UInt32(kVK_ANSI_L)
        case "m": return UInt32(kVK_ANSI_M)
        case "n": return UInt32(kVK_ANSI_N)
        case "o": return UInt32(kVK_ANSI_O)
        case "p": return UInt32(kVK_ANSI_P)
        case "q": return UInt32(kVK_ANSI_Q)
        case "r": return UInt32(kVK_ANSI_R)
        case "s": return UInt32(kVK_ANSI_S)
        case "t": return UInt32(kVK_ANSI_T)
        case "u": return UInt32(kVK_ANSI_U)
        case "v": return UInt32(kVK_ANSI_V)
        case "w": return UInt32(kVK_ANSI_W)
        case "x": return UInt32(kVK_ANSI_X)
        case "y": return UInt32(kVK_ANSI_Y)
        case "z": return UInt32(kVK_ANSI_Z)
        default: return nil
        }
    }
}
