import Foundation

enum ModelProfile: String, Codable {
    case fast
    case balanced
}

enum Language: String, Codable {
    case english = "en"
    case dutch = "nl"
    case auto = "auto"
}

enum UIPosition: String, Codable {
    case cursor
    case menuBar = "menu_bar"
}

struct Preferences: Codable {
    var hotkey: String
    var modelProfile: ModelProfile
    var language: Language
    var launchAtLogin: Bool
    var uiPosition: UIPosition
    var formattingEnabled: Bool

    static let defaults = Preferences(
        hotkey: "Control+Space",
        modelProfile: .fast,
        language: .english,
        launchAtLogin: false,
        uiPosition: .cursor,
        formattingEnabled: true
    )

    enum CodingKeys: String, CodingKey {
        case hotkey
        case modelProfile = "model_profile"
        case language
        case launchAtLogin = "launch_at_login"
        case uiPosition = "ui_position"
        case formattingEnabled = "formatting_enabled"
    }

    init(hotkey: String, modelProfile: ModelProfile, language: Language,
         launchAtLogin: Bool, uiPosition: UIPosition, formattingEnabled: Bool = true) {
        self.hotkey = hotkey
        self.modelProfile = modelProfile
        self.language = language
        self.launchAtLogin = launchAtLogin
        self.uiPosition = uiPosition
        self.formattingEnabled = formattingEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hotkey = try container.decode(String.self, forKey: .hotkey)
        modelProfile = try container.decode(ModelProfile.self, forKey: .modelProfile)
        language = try container.decode(Language.self, forKey: .language)
        launchAtLogin = try container.decode(Bool.self, forKey: .launchAtLogin)
        uiPosition = try container.decode(UIPosition.self, forKey: .uiPosition)
        formattingEnabled = try container.decodeIfPresent(Bool.self, forKey: .formattingEnabled) ?? true
    }
}

struct TranscriptEntry: Codable, Identifiable {
    var id: String { entryId ?? createdAt }
    let entryId: String?
    let createdAt: String
    let text: String
    let durationMs: Int
    let languageUsed: String
    let modelUsed: String
    let error: String?

    enum CodingKeys: String, CodingKey {
        case entryId = "entry_id"
        case createdAt = "created_at"
        case text
        case durationMs = "duration_ms"
        case languageUsed = "language_used"
        case modelUsed = "model_used"
        case error
    }
}

struct ClipboardEntry: Codable, Identifiable {
    var id: String { entryId }
    let entryId: String
    let createdAt: String
    let text: String
    let isFluisterTranscription: Bool

    enum CodingKeys: String, CodingKey {
        case entryId = "entry_id"
        case createdAt = "created_at"
        case text
        case isFluisterTranscription = "is_fluister_transcription"
    }
}

class PreferencesManager {
    private let pathManager: PathManager

    init(pathManager: PathManager) {
        self.pathManager = pathManager
    }

    func load() -> Preferences {
        let url = pathManager.preferencesFile
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let prefs = try? JSONDecoder().decode(Preferences.self, from: data) else {
            return Preferences.defaults
        }
        return prefs
    }

    func save(_ prefs: Preferences) {
        let url = pathManager.preferencesFile
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(prefs) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func loadTranscripts() -> [TranscriptEntry] {
        let url = pathManager.transcriptsFile
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let transcripts = try? JSONDecoder().decode([TranscriptEntry].self, from: data) else {
            return []
        }
        return transcripts
    }

    func loadClipboardHistory() -> [ClipboardEntry] {
        let url = pathManager.clipboardHistoryFile
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([ClipboardEntry].self, from: data) else {
            return []
        }
        return entries
    }

    func addClipboardEntry(text: String, isFluister: Bool) {
        var entries = loadClipboardHistory()

        // Skip duplicates of the most recent entry
        if let latest = entries.first, latest.text == text {
            return
        }

        let formatter = ISO8601DateFormatter()
        let entry = ClipboardEntry(
            entryId: UUID().uuidString,
            createdAt: formatter.string(from: Date()),
            text: text,
            isFluisterTranscription: isFluister
        )

        entries.insert(entry, at: 0)
        if entries.count > 20 {
            entries = Array(entries.prefix(20))
        }

        let url = pathManager.clipboardHistoryFile
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func addTranscript(text: String, durationMs: Int, language: Language, model: String) {
        var transcripts = loadTranscripts()

        let formatter = ISO8601DateFormatter()
        let entry = TranscriptEntry(
            entryId: UUID().uuidString,
            createdAt: formatter.string(from: Date()),
            text: text,
            durationMs: durationMs,
            languageUsed: language.rawValue,
            modelUsed: model,
            error: nil
        )

        transcripts.insert(entry, at: 0)
        // Keep last 10
        if transcripts.count > 10 {
            transcripts = Array(transcripts.prefix(10))
        }

        let url = pathManager.transcriptsFile
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(transcripts) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
