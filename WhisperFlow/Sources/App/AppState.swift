import Foundation
import ServiceManagement
import SwiftUI

enum AppFlowState: Equatable {
    case idle
    case recording
    case transcribing
    case success
    case error(String)

    static func == (lhs: AppFlowState, rhs: AppFlowState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.recording, .recording),
             (.transcribing, .transcribing), (.success, .success):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

class AppState: ObservableObject {
    @Published var currentState: AppFlowState = .idle
    @Published var recordingDuration: TimeInterval = 0
    @Published var currentChunk: Int = 0
    @Published var totalChunks: Int = 0
    @Published var modelAvailable: Bool = false
    @Published var hotkeyRegistrationFailed: Bool = false
    @Published var showTimeWarning: Bool = false
    @Published var downloadProgress: Double = 0
    @Published var isDownloading: Bool = false
    @Published var downloadingProfile: ModelProfile? = nil
    @Published var selectedModelProfile: ModelProfile = Preferences.defaults.modelProfile
    @Published var selectedLanguage: Language = Preferences.defaults.language
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @Published var formattingEnabled: Bool = Preferences.defaults.formattingEnabled
    @Published var audioLevel: Float = 0
    @Published var clipboardHistory: [ClipboardEntry] = []

    var pathManager: PathManager?
    var preferencesManager: PreferencesManager?
    var logger: AppLogger?
    var hotkeyManager: HotkeyManager?
    var audioRecorder: AudioRecorder?
    var transcriptionEngine: TranscriptionEngine?
    var modelManager: ModelManager?
    var clipboardMonitor: ClipboardMonitor?
}
