import XCTest
@testable import Fluister

class PreferencesManagerTests: XCTestCase {
    var tempDir: URL!
    var pathManager: TestPathManager!
    var prefsManager: PreferencesManager!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        pathManager = TestPathManager(baseDir: tempDir)
        pathManager.ensureDirectoriesExist()
        prefsManager = PreferencesManager(pathManager: pathManager)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testDefaultsWhenNoFile() {
        let prefs = prefsManager.load()
        XCTAssertEqual(prefs.hotkey, "Control+Space")
        XCTAssertEqual(prefs.modelProfile, .fast)
        XCTAssertEqual(prefs.language, .english)
        XCTAssertFalse(prefs.launchAtLogin)
        XCTAssertEqual(prefs.uiPosition, .cursor)
    }

    func testSaveAndLoad() {
        var prefs = Preferences.defaults
        prefs.language = .dutch
        prefs.modelProfile = .balanced
        prefs.hotkey = "Command+Shift+D"

        prefsManager.save(prefs)

        let loaded = prefsManager.load()
        XCTAssertEqual(loaded.language, .dutch)
        XCTAssertEqual(loaded.modelProfile, .balanced)
        XCTAssertEqual(loaded.hotkey, "Command+Shift+D")
        // Unchanged fields preserved
        XCTAssertFalse(loaded.launchAtLogin)
        XCTAssertEqual(loaded.uiPosition, .cursor)
    }

    func testPartialUpdatePreservesOtherFields() {
        var prefs = Preferences.defaults
        prefs.language = .dutch
        prefsManager.save(prefs)

        var loaded = prefsManager.load()
        loaded.modelProfile = .balanced
        prefsManager.save(loaded)

        let final = prefsManager.load()
        XCTAssertEqual(final.language, .dutch)
        XCTAssertEqual(final.modelProfile, .balanced)
    }

    func testCorruptFileReturnsDefaults() {
        let url = pathManager.preferencesFile
        try? "{ not valid json".data(using: .utf8)?.write(to: url)

        let prefs = prefsManager.load()
        XCTAssertEqual(prefs.hotkey, "Control+Space")
    }

    func testTranscriptHistory() {
        prefsManager.addTranscript(text: "Hello world", durationMs: 5000, language: .english, model: "fast")
        prefsManager.addTranscript(text: "Second entry", durationMs: 3000, language: .dutch, model: "fast")

        let transcripts = prefsManager.loadTranscripts()
        XCTAssertEqual(transcripts.count, 2)
        XCTAssertEqual(transcripts[0].text, "Second entry") // Most recent first
        XCTAssertEqual(transcripts[1].text, "Hello world")
    }

    func testTranscriptHistoryMaxTen() {
        for i in 0..<15 {
            prefsManager.addTranscript(text: "Entry \(i)", durationMs: 1000, language: .english, model: "fast")
        }

        let transcripts = prefsManager.loadTranscripts()
        XCTAssertEqual(transcripts.count, 10)
        XCTAssertEqual(transcripts[0].text, "Entry 14") // Most recent
    }
}

/// Test-only PathManager that uses a custom temp directory
class TestPathManager: PathManager {
    private let baseDir: URL

    init(baseDir: URL) {
        self.baseDir = baseDir
        super.init()
    }

    override var appSupportDirectory: URL {
        return baseDir.appendingPathComponent("app_support")
    }

    override var modelsDirectory: URL {
        return baseDir.appendingPathComponent("models")
    }

    override var logsDirectory: URL {
        return baseDir.appendingPathComponent("logs")
    }

    override var tempDirectory: URL {
        return baseDir.appendingPathComponent("tmp")
    }
}
