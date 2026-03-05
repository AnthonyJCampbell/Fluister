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

    /// Callback for real-time audio level (0.0–1.0) used by WaveformView.
    var audioLevelCallback: ((Float) -> Void)?

    /// The format whisper-cli expects: 16kHz, 16-bit signed integer, mono.
    /// By recording directly in this format we skip the post-recording afconvert step entirely.
    private static let whisperFormat = AVAudioFormat(
        commonFormat: .pcmFormatInt16,
        sampleRate: 16000,
        channels: 1,
        interleaved: true
    )!

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

    func startRecording(durationUpdate: @escaping (TimeInterval) -> Void,
                        onError: ((String) -> Void)? = nil) {
        guard !isRecording else { return }

        // Check microphone permission
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.startRecording(durationUpdate: durationUpdate, onError: onError)
                    }
                } else {
                    self?.logger?.log("Microphone permission denied")
                    DispatchQueue.main.async {
                        onError?("Microphone access denied. Enable in System Settings → Privacy & Security.")
                    }
                }
            }
            return
        case .denied, .restricted:
            logger?.log("Microphone permission denied/restricted")
            onError?("Microphone access denied. Enable in System Settings → Privacy & Security.")
            return
        @unknown default:
            return
        }

        durationCallback = durationUpdate

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Build converter: native mic format (e.g. 48kHz Float32 stereo) → 16kHz Int16 mono.
        // We tap in the native format (required — AVAudioEngine crashes if the tap format
        // differs in sample rate on some hardware) and convert each buffer in the callback.
        guard let converter = AVAudioConverter(from: inputFormat, to: AudioRecorder.whisperFormat) else {
            logger?.log("Failed to create audio converter")
            onError?("Failed to initialize audio converter")
            return
        }

        // Record directly as a 16kHz 16-bit mono WAV — no post-conversion (afconvert) needed.
        let wavURL = pathManager.tempDirectory.appendingPathComponent("recording_\(Int(Date().timeIntervalSince1970)).wav")

        do {
            audioFile = try AVAudioFile(
                forWriting: wavURL,
                settings: AudioRecorder.whisperFormat.settings,
                commonFormat: .pcmFormatInt16,
                interleaved: true
            )
        } catch {
            logger?.log("Failed to create audio file: \(error)")
            return
        }

        currentOutputURL = wavURL

        // Install tap in native mic format. Inside the callback we:
        // 1. Compute RMS for waveform visualization
        // 2. Convert to 16kHz Int16 mono and write directly to the WAV file
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self, self.isRecording else { return }

            // Compute RMS audio level for waveform visualization
            if let channelData = buffer.floatChannelData {
                let frameLength = Int(buffer.frameLength)
                if frameLength > 0 {
                    var sum: Float = 0
                    for frame in 0..<frameLength {
                        let sample = channelData[0][frame]
                        sum += sample * sample
                    }
                    let rms = sqrt(sum / Float(frameLength))
                    let normalizedLevel = min(1.0, rms * 5)
                    self.audioLevelCallback?(normalizedLevel)
                }
            }

            // Convert native format → 16kHz Int16 mono and write to WAV
            // Estimate output frame count based on sample rate ratio
            let ratio = 16000.0 / inputFormat.sampleRate
            let outputFrames = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
            guard outputFrames > 0,
                  let int16Buffer = AVAudioPCMBuffer(
                      pcmFormat: AudioRecorder.whisperFormat,
                      frameCapacity: outputFrames
                  ) else { return }

            var convError: NSError?
            let status = converter.convert(to: int16Buffer, error: &convError) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            guard status != .error, convError == nil else { return }

            do {
                try self.audioFile?.write(from: int16Buffer)
            } catch {
                // Non-fatal: log and continue
            }
        }

        do {
            try engine.start()
        } catch {
            logger?.log("Failed to start audio engine: \(error)")
            inputNode.removeTap(onBus: 0)
            onError?("Failed to start audio: \(error.localizedDescription)")
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

        logger?.log("Recording started (16kHz Int16 WAV): \(wavURL.lastPathComponent)")
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
        audioFile = nil // Close the WAV file (flushes header)
        audioEngine = nil

        guard let wavURL = currentOutputURL, FileManager.default.fileExists(atPath: wavURL.path) else {
            completion(.failure(NSError(domain: "AudioRecorder", code: -2, userInfo: [NSLocalizedDescriptionKey: "Recording file not found"])))
            return
        }

        // No conversion needed — the file is already in whisper-cli format.
        logger?.log("Recording stopped: \(wavURL.lastPathComponent)")
        completion(.success(wavURL))
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
}
