import AVFoundation
import Foundation

class AudioRecorder {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var recordingStartTime: Date?
    private var durationTimer: Timer?
    private var durationCallback: ((TimeInterval) -> Void)?
    private let pathManager: PathManager
    private let logger: AppLogger?
    private var currentOutputURL: URL?

    // Thread-safe recording flag using a lock
    private let stateLock = NSLock()
    private var _isRecording = false
    private var isRecording: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _isRecording }
        set { stateLock.lock(); _isRecording = newValue; stateLock.unlock() }
    }

    init(pathManager: PathManager, logger: AppLogger?) {
        self.pathManager = pathManager
        self.logger = logger
    }

    func startRecording(durationUpdate: @escaping (TimeInterval) -> Void) {
        guard !isRecording else { return }

        // Check microphone permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.startRecording(durationUpdate: durationUpdate)
                    }
                } else {
                    self?.logger?.log("Microphone permission denied")
                }
            }
            return
        case .denied, .restricted:
            logger?.log("Microphone permission denied/restricted")
            return
        @unknown default:
            return
        }

        durationCallback = durationUpdate

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Record in the NATIVE mic format (typically 48kHz float32).
        // We'll convert to 16kHz 16-bit WAV after recording stops.
        let rawURL = pathManager.tempDirectory.appendingPathComponent("raw_\(Int(Date().timeIntervalSince1970)).caf")

        do {
            audioFile = try AVAudioFile(forWriting: rawURL, settings: inputFormat.settings)
        } catch {
            logger?.log("Failed to create audio file: \(error)")
            return
        }

        currentOutputURL = rawURL

        // Install tap: write directly in native format (no conversion needed)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, self.isRecording else { return }
            do {
                try self.audioFile?.write(from: buffer)
            } catch {
                // Non-fatal: log and continue
            }
        }

        do {
            try engine.start()
        } catch {
            logger?.log("Failed to start audio engine: \(error)")
            return
        }

        audioEngine = engine
        isRecording = true
        recordingStartTime = Date()

        // Start duration timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let start = self?.recordingStartTime else { return }
            let elapsed = Date().timeIntervalSince(start)
            self?.durationCallback?(elapsed)
        }

        logger?.log("Recording started to: \(rawURL.lastPathComponent)")
    }

    func stopRecording(completion: @escaping (Result<URL, Error>) -> Void) {
        guard isRecording else {
            completion(.failure(NSError(domain: "AudioRecorder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not recording"])))
            return
        }

        isRecording = false
        durationTimer?.invalidate()
        durationTimer = nil

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioFile = nil // Close the raw file
        audioEngine = nil

        guard let rawURL = currentOutputURL, FileManager.default.fileExists(atPath: rawURL.path) else {
            completion(.failure(NSError(domain: "AudioRecorder", code: -2, userInfo: [NSLocalizedDescriptionKey: "Recording file not found"])))
            return
        }

        // Convert raw recording to 16kHz 16-bit mono WAV on a background thread
        let wavURL = rawURL.deletingLastPathComponent().appendingPathComponent(
            rawURL.lastPathComponent.replacingOccurrences(of: "raw_", with: "recording_").replacingOccurrences(of: ".caf", with: ".wav")
        )

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                try self?.convertToWhisperFormat(inputURL: rawURL, outputURL: wavURL)
                // Clean up raw file
                try? FileManager.default.removeItem(at: rawURL)

                self?.logger?.log("Recording stopped and converted: \(wavURL.lastPathComponent)")
                DispatchQueue.main.async {
                    completion(.success(wavURL))
                }
            } catch {
                self?.logger?.log("Audio conversion failed: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func cancelRecording() {
        isRecording = false
        durationTimer?.invalidate()
        durationTimer = nil

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioFile = nil
        audioEngine = nil

        // Clean up temp file
        if let url = currentOutputURL {
            try? FileManager.default.removeItem(at: url)
        }

        logger?.log("Recording cancelled")
    }

    // MARK: - Conversion

    /// Convert any audio file to 16kHz, 16-bit, mono WAV using macOS's built-in `afconvert`.
    /// This avoids AVAudioConverter/AVAudioFile crashes in Core Audio's CABufferList.
    /// Runs synchronously — call from a background thread.
    private func convertToWhisperFormat(inputURL: URL, outputURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = [
            inputURL.path,
            outputURL.path,
            "-f", "WAVE",       // WAV container
            "-d", "LEI16@16000", // Little-endian 16-bit integer at 16kHz
            "-c", "1"            // Mono
        ]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrStr = String(data: stderrData, encoding: .utf8) ?? "unknown error"
            throw NSError(domain: "AudioRecorder", code: -3, userInfo: [
                NSLocalizedDescriptionKey: "afconvert failed: \(stderrStr)"
            ])
        }
    }
}
