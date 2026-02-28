import Foundation

class PathManager {
    let isDevMode: Bool
    private let appName = "Fluister"
    private let repoRoot: URL

    init() {
        // Determine repo root from bundle location or env var
        if let envRoot = ProcessInfo.processInfo.environment["WHISPERFLOW_REPO_ROOT"] {
            self.repoRoot = URL(fileURLWithPath: envRoot)
            self.isDevMode = ProcessInfo.processInfo.environment["WHISPERFLOW_DEV_MODE"] == "1"
        } else {
            // App is at <repo>/build/Build/Products/Debug/WhisperFlow.app
            // Walk up from the bundle path looking for a parent that contains vendor/
            let bundleURL = URL(fileURLWithPath: Bundle.main.bundlePath)
            let resolved = PathManager.findRepoRoot(from: bundleURL)
            self.repoRoot = resolved.root
            self.isDevMode = resolved.devMode
        }
    }

    /// Walk up from a path looking for a parent directory that contains vendor/
    private static func findRepoRoot(from bundleURL: URL) -> (root: URL, devMode: Bool) {
        var candidate = bundleURL.deletingLastPathComponent()
        for _ in 0..<8 {
            if candidate.path == "/" { break }
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("vendor").path) {
                return (candidate, true)
            }
            candidate = candidate.deletingLastPathComponent()
        }
        // Fallback: not in a repo checkout
        return (URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
                ProcessInfo.processInfo.environment["WHISPERFLOW_DEV_MODE"] == "1")
    }

    // MARK: - Base Directories

    var appSupportDirectory: URL {
        if isDevMode {
            return repoLocalURL(path: ".local/app_support")
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            return appSupport.appendingPathComponent(appName)
        }
    }

    var modelsDirectory: URL {
        if isDevMode {
            return repoLocalURL(path: ".local/models")
        } else {
            return appSupportDirectory.appendingPathComponent("models")
        }
    }

    var logsDirectory: URL {
        if isDevMode {
            return repoLocalURL(path: ".local/logs")
        } else {
            let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            return library.appendingPathComponent("Logs").appendingPathComponent(appName)
        }
    }

    var tempDirectory: URL {
        if isDevMode {
            return repoLocalURL(path: ".local/tmp")
        } else {
            return FileManager.default.temporaryDirectory.appendingPathComponent(appName)
        }
    }

    // MARK: - Specific Files

    var preferencesFile: URL {
        return appSupportDirectory.appendingPathComponent("preferences.json")
    }

    var logFile: URL {
        return logsDirectory.appendingPathComponent("app.log")
    }

    var transcriptsFile: URL {
        return appSupportDirectory.appendingPathComponent("transcripts.json")
    }

    var clipboardHistoryFile: URL {
        return appSupportDirectory.appendingPathComponent("clipboard_history.json")
    }

    // MARK: - whisper-cli binary

    var whisperCliBinary: URL {
        // Look relative to the app bundle's location in dev mode
        if isDevMode {
            return repoLocalURL(path: "vendor/whisper.cpp/build/bin/whisper-cli")
        } else {
            // In production, expect it bundled or at a known path
            return repoLocalURL(path: "vendor/whisper.cpp/build/bin/whisper-cli")
        }
    }

    // MARK: - Helpers

    func ensureDirectoriesExist() {
        let dirs = [appSupportDirectory, modelsDirectory, logsDirectory, tempDirectory]
        for dir in dirs {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    func modelPath(for profile: ModelProfile) -> URL {
        let source = ModelSources.source(for: profile)
        return modelsDirectory.appendingPathComponent(source.filename)
    }

    private func repoLocalURL(path: String) -> URL {
        return repoRoot.appendingPathComponent(path)
    }
}
