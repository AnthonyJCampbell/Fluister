import Foundation

class AppLogger {
    private let logFileURL: URL
    private let dateFormatter: DateFormatter
    private let queue = DispatchQueue(label: "com.fluister.logger", qos: .utility)

    init(pathManager: PathManager) {
        self.logFileURL = pathManager.logFile
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        // Ensure log directory and file exist
        try? FileManager.default.createDirectory(
            at: pathManager.logsDirectory,
            withIntermediateDirectories: true
        )
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
    }

    func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let entry = "[\(timestamp)] \(message)\n"

        queue.async { [weak self] in
            guard let self = self else { return }
            if let handle = try? FileHandle(forWritingTo: self.logFileURL) {
                handle.seekToEndOfFile()
                if let data = entry.data(using: .utf8) {
                    handle.write(data)
                }
                handle.closeFile()
            }
        }

        #if DEBUG
        print("[Fluister] \(message)")
        #endif
    }
}
