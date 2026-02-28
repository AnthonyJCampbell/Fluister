import Foundation

class ModelManager {
    private let pathManager: PathManager
    private let logger: AppLogger?
    private var downloadDelegate: DownloadDelegate?
    private var session: URLSession?

    init(pathManager: PathManager, logger: AppLogger?) {
        self.pathManager = pathManager
        self.logger = logger
    }

    func isModelAvailable(profile: ModelProfile) -> Bool {
        let modelPath = pathManager.modelPath(for: profile)
        return FileManager.default.fileExists(atPath: modelPath.path)
    }

    func downloadModel(
        profile: ModelProfile,
        progressCallback: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        let source = ModelSources.source(for: profile)
        let destinationURL = pathManager.modelPath(for: profile)

        logger?.log("Starting model download: \(source.filename) from \(source.url)")

        let delegate = DownloadDelegate(
            expectedSHA256: source.sha256,
            destinationURL: destinationURL,
            logger: logger,
            progressCallback: progressCallback,
            completion: completion
        )
        self.downloadDelegate = delegate

        let config = URLSessionConfiguration.default
        let urlSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        self.session = urlSession

        let task = urlSession.downloadTask(with: source.url)
        task.resume()
    }

    func cancelDownload() {
        session?.invalidateAndCancel()
        session = nil
        downloadDelegate = nil
        logger?.log("Model download cancelled")
    }
}

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    private let expectedSHA256: String
    private let destinationURL: URL
    private let logger: AppLogger?
    private let progressCallback: (Double) -> Void
    private let completion: (Result<URL, Error>) -> Void
    private var hasCompleted = false

    init(expectedSHA256: String, destinationURL: URL, logger: AppLogger?,
         progressCallback: @escaping (Double) -> Void,
         completion: @escaping (Result<URL, Error>) -> Void) {
        self.expectedSHA256 = expectedSHA256
        self.destinationURL = destinationURL
        self.logger = logger
        self.progressCallback = progressCallback
        self.completion = completion
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.progressCallback(progress)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Verify SHA256 using streaming (not loading entire file into memory)
        if !expectedSHA256.isEmpty {
            let hash = streamingSHA256(url: location)
            if hash != expectedSHA256 {
                try? FileManager.default.removeItem(at: location)
                let error = NSError(domain: "ModelManager", code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "SHA256 mismatch. Expected: \(expectedSHA256), Got: \(hash)"])
                logger?.log("SHA256 verification failed")
                completeOnMain(.failure(error))
                return
            }
        }

        // Move to final destination
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)
            logger?.log("Model saved to: \(destinationURL.path)")
            completeOnMain(.success(destinationURL))
        } catch {
            logger?.log("Failed to move model file: \(error)")
            completeOnMain(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            logger?.log("Download failed: \(error)")
            completeOnMain(.failure(error))
        }
    }

    private func completeOnMain(_ result: Result<URL, Error>) {
        guard !hasCompleted else { return }
        hasCompleted = true
        DispatchQueue.main.async {
            self.completion(result)
        }
    }

    /// Stream-based SHA256 to avoid loading entire model (~466MB+) into memory
    private func streamingSHA256(url: URL) -> String {
        guard let stream = InputStream(url: url) else { return "" }
        stream.open()
        defer { stream.close() }

        var context = CC_SHA256_CTX()
        CC_SHA256_Init(&context)

        let bufferSize = 1024 * 1024 // 1MB chunks
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let bytesRead = stream.read(buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                CC_SHA256_Update(&context, buffer, CC_LONG(bytesRead))
            } else {
                break
            }
        }

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256_Final(&hash, &context)

        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
