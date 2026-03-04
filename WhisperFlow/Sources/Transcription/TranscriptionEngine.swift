import Foundation

enum TranscriptionError: Error, LocalizedError {
    case whisperCliNotFound
    case modelNotFound
    case processTimeout
    case overallTimeout
    case processCrashed(Int32)
    case processFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .whisperCliNotFound: return "whisper-cli binary not found"
        case .modelNotFound: return "Model file not found"
        case .processTimeout: return "Chunk timed out — try the Fast model for long recordings"
        case .overallTimeout: return "Overall transcription timed out (15min)"
        case .processCrashed(let signal): return "whisper-cli crashed (signal \(signal))"
        case .processFailed(let msg): return "Transcription failed: \(msg)"
        case .cancelled: return "Transcription cancelled"
        }
    }
}

class TranscriptionEngine {
    private let pathManager: PathManager
    private let logger: AppLogger?
    private var currentProcess: Process?
    private var isCancelled = false

    private let perChunkTimeout: TimeInterval = 120
    private let overallTimeout: TimeInterval = 900 // 15 minutes

    init(pathManager: PathManager, logger: AppLogger?) {
        self.pathManager = pathManager
        self.logger = logger
    }

    func transcribe(
        wavPath: URL,
        language: Language,
        modelProfile: ModelProfile,
        progressCallback: @escaping (Int, Int) -> Void,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        isCancelled = false

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let whisperCli = self.pathManager.whisperCliBinary
            guard FileManager.default.isExecutableFile(atPath: whisperCli.path) else {
                completion(.failure(TranscriptionError.whisperCliNotFound))
                return
            }

            let modelPath = self.pathManager.modelPath(for: modelProfile)
            guard FileManager.default.fileExists(atPath: modelPath.path) else {
                completion(.failure(TranscriptionError.modelNotFound))
                return
            }

            let overallDeadline = Date().addingTimeInterval(self.overallTimeout)

            do {
                if AudioChunker.needsChunking(wavURL: wavPath) {
                    // Chunked transcription
                    let chunkDir = self.pathManager.tempDirectory.appendingPathComponent("chunks_\(Int(Date().timeIntervalSince1970))")
                    try FileManager.default.createDirectory(at: chunkDir, withIntermediateDirectories: true)

                    let chunks = try AudioChunker.splitWAV(url: wavPath, outputDirectory: chunkDir)
                    self.logger?.log("Split into \(chunks.count) chunks")

                    var transcripts: [String] = []

                    for (i, chunk) in chunks.enumerated() {
                        guard !self.isCancelled else {
                            completion(.failure(TranscriptionError.cancelled))
                            return
                        }

                        guard Date() < overallDeadline else {
                            completion(.failure(TranscriptionError.overallTimeout))
                            return
                        }

                        progressCallback(i + 1, chunks.count)

                        let text = try self.runWhisperCli(
                            wavPath: chunk.url,
                            modelPath: modelPath,
                            language: language,
                            timeout: self.perChunkTimeout
                        )
                        transcripts.append(text)
                    }

                    // Clean up chunk files
                    try? FileManager.default.removeItem(at: chunkDir)

                    let result = WhisperOutputParser.concatenateChunks(transcripts)
                    completion(.success(result))

                } else {
                    // Single file transcription
                    progressCallback(1, 1)

                    let text = try self.runWhisperCli(
                        wavPath: wavPath,
                        modelPath: modelPath,
                        language: language,
                        timeout: self.perChunkTimeout
                    )
                    completion(.success(text))
                }

                // Clean up original recording
                try? FileManager.default.removeItem(at: wavPath)

            } catch {
                completion(.failure(error))
            }
        }
    }

    func cancel() {
        isCancelled = true
        currentProcess?.terminate()
        logger?.log("Transcription cancelled")
    }

    // MARK: - Private

    private func runWhisperCli(wavPath: URL, modelPath: URL, language: Language, timeout: TimeInterval) throws -> String {
        guard !isCancelled else { throw TranscriptionError.cancelled }

        let process = Process()
        process.executableURL = pathManager.whisperCliBinary

        // Set working directory to whisper.cpp dir so Metal shader (ggml-metal.metal) can be found
        let whisperDir = pathManager.whisperCliBinary
            .deletingLastPathComponent() // bin/
            .deletingLastPathComponent() // build/
            .deletingLastPathComponent() // whisper.cpp/
        process.currentDirectoryURL = whisperDir

        // Tell ggml-metal where to find the .metal shader and its #include'd headers.
        // Both ggml-metal.metal and ggml-common.h live in the whisper.cpp root.
        // Without this, Metal compilation fails with "ggml-common.h not found".
        var env = ProcessInfo.processInfo.environment
        env["GGML_METAL_PATH_RESOURCES"] = whisperDir.path
        process.environment = env

        var args = [
            "-m", modelPath.path,
            "-f", wavPath.path,
            "--no-timestamps"
        ]

        if language != .auto {
            args.append(contentsOf: ["-l", language.rawValue])
        }

        process.arguments = args

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        currentProcess = process

        logger?.log("Running whisper-cli: \(args.joined(separator: " "))")

        do {
            try process.run()
        } catch {
            throw TranscriptionError.processFailed(error.localizedDescription)
        }

        // Read pipes in background BEFORE waitUntilExit to prevent deadlock.
        // If whisper-cli fills the pipe buffer (~64KB) and we haven't read it,
        // the process blocks on write and waitUntilExit never returns.
        var stdoutData = Data()
        var stderrData = Data()

        let stdoutReadGroup = DispatchGroup()
        let stderrReadGroup = DispatchGroup()

        stdoutReadGroup.enter()
        DispatchQueue.global().async {
            stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            stdoutReadGroup.leave()
        }

        stderrReadGroup.enter()
        DispatchQueue.global().async {
            stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            stderrReadGroup.leave()
        }

        // Timeout handling — track whether we triggered it
        var didTimeout = false
        let timeoutItem = DispatchWorkItem {
            if process.isRunning {
                didTimeout = true
                process.terminate()
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

        process.waitUntilExit()
        timeoutItem.cancel()

        // Wait for pipe reads to complete
        stdoutReadGroup.wait()
        stderrReadGroup.wait()

        currentProcess = nil

        if isCancelled {
            throw TranscriptionError.cancelled
        }

        // Distinguish our timeout (SIGTERM) from a crash (SIGSEGV, SIGABRT, etc.)
        if process.terminationReason == .uncaughtSignal {
            let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""
            if didTimeout {
                logger?.log("whisper-cli timed out after \(Int(timeout))s, stderr: \(stderrStr)")
                throw TranscriptionError.processTimeout
            } else {
                let signal = process.terminationStatus
                logger?.log("whisper-cli crashed with signal \(signal), stderr: \(stderrStr)")
                throw TranscriptionError.processCrashed(signal)
            }
        }

        if process.terminationStatus != 0 {
            let fullStderr = String(data: stderrData, encoding: .utf8) ?? "unknown error"
            logger?.log("whisper-cli failed (exit \(process.terminationStatus)), stderr: \(fullStderr)")
            // Extract the last meaningful line for display — full stderr is too noisy for the pill
            let shortMessage = fullStderr
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .last(where: { !$0.isEmpty }) ?? "exit code \(process.terminationStatus)"
            throw TranscriptionError.processFailed(shortMessage)
        }

        let rawOutput = String(data: stdoutData, encoding: .utf8) ?? ""

        // Log stderr for diagnostics (Metal status, warnings, etc.)
        let stderrStr = String(data: stderrData, encoding: .utf8) ?? ""
        if stderrStr.contains("metal") || stderrStr.contains("Metal") {
            if stderrStr.contains("failed") || stderrStr.contains("error") {
                logger?.log("WARNING: Metal GPU acceleration failed — using CPU fallback")
            } else {
                logger?.log("Metal GPU acceleration active")
            }
        }

        logger?.log("whisper-cli raw output length: \(rawOutput.count)")

        return WhisperOutputParser.parse(rawOutput)
    }
}
