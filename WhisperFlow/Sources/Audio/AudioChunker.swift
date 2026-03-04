import AVFoundation
import Foundation

struct ChunkInfo {
    let url: URL
    let index: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
}

enum AudioChunkerError: Error, LocalizedError {
    case cannotOpenFile
    case cannotCreateOutputFile
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .cannotOpenFile: return "Cannot open audio file"
        case .cannotCreateOutputFile: return "Cannot create chunk file"
        case .invalidFormat: return "Invalid audio format"
        }
    }
}

class AudioChunker {
    static let chunkDuration: TimeInterval = 30.0
    static let overlapDuration: TimeInterval = 2.0
    static let chunkingThreshold: TimeInterval = 60.0

    /// Determine if a WAV file needs chunking (>60s)
    static func needsChunking(wavURL: URL) -> Bool {
        guard let file = try? AVAudioFile(forReading: wavURL) else { return false }
        let duration = Double(file.length) / file.fileFormat.sampleRate
        return duration > chunkingThreshold
    }

    /// Get the duration of a WAV file in seconds
    static func duration(of wavURL: URL) -> TimeInterval? {
        guard let file = try? AVAudioFile(forReading: wavURL) else { return nil }
        return Double(file.length) / file.fileFormat.sampleRate
    }

    /// Calculate chunk boundaries (start, end) with overlap
    static func calculateChunkBoundaries(totalDuration: TimeInterval) -> [(start: TimeInterval, end: TimeInterval)] {
        guard totalDuration > chunkingThreshold else {
            return [(start: 0, end: totalDuration)]
        }

        var chunks: [(start: TimeInterval, end: TimeInterval)] = []
        var currentStart: TimeInterval = 0

        while currentStart < totalDuration {
            let chunkEnd = min(currentStart + chunkDuration, totalDuration)
            chunks.append((start: currentStart, end: chunkEnd))

            // Next chunk starts (chunkDuration - overlap) after current start
            currentStart += chunkDuration - overlapDuration

            // Don't create tiny final chunks (< 5s)
            if currentStart < totalDuration && (totalDuration - currentStart) < 5.0 {
                // Extend the last chunk to cover the rest
                chunks[chunks.count - 1] = (start: chunks.last!.start, end: totalDuration)
                break
            }
        }

        return chunks
    }

    /// Split a WAV file into chunks, preserving the original sample format (16-bit PCM).
    /// The recording is already 16kHz mono Int16 WAV (converted by AudioRecorder via afconvert).
    /// We must write chunks in the same format — AVAudioFile.processingFormat silently
    /// converts to Float32, which crashes whisper-cli.
    static func splitWAV(url: URL, outputDirectory: URL) throws -> [ChunkInfo] {
        let inputFile: AVAudioFile
        do {
            inputFile = try AVAudioFile(forReading: url)
        } catch {
            throw AudioChunkerError.cannotOpenFile
        }

        let fileFormat = inputFile.fileFormat
        let sampleRate = fileFormat.sampleRate
        let totalDuration = Double(inputFile.length) / sampleRate

        // processingFormat is always Float32 canonical PCM (AVAudioFile requirement).
        // We need an explicit converter to go Float32 → Int16 so whisper-cli gets a
        // standard 16-bit WAV. Relying on AVAudioFile.write(from:) with a mismatched
        // buffer format produces silent format-conversion failures on some OS versions.
        let processingFormat = inputFile.processingFormat

        // Build the exact Int16 output format whisper-cli expects: 16kHz, mono, Int16 PCM.
        guard let int16Format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: fileFormat.channelCount,
            interleaved: true
        ) else {
            throw AudioChunkerError.invalidFormat
        }

        guard let converter = AVAudioConverter(from: processingFormat, to: int16Format) else {
            throw AudioChunkerError.invalidFormat
        }

        let boundaries = calculateChunkBoundaries(totalDuration: totalDuration)

        var chunks: [ChunkInfo] = []

        for (index, boundary) in boundaries.enumerated() {
            let startFrame = AVAudioFramePosition(boundary.start * sampleRate)
            let endFrame = min(AVAudioFramePosition(boundary.end * sampleRate), inputFile.length)
            let frameCount = AVAudioFrameCount(endFrame - startFrame)

            guard frameCount > 0 else { continue }

            let chunkFilename = String(format: "chunk_%03d.wav", index)
            let chunkURL = outputDirectory.appendingPathComponent(chunkFilename)

            // Seek and read into a Float32 processing buffer.
            inputFile.framePosition = startFrame
            guard let float32Buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: frameCount) else {
                throw AudioChunkerError.invalidFormat
            }
            try inputFile.read(into: float32Buffer, frameCount: frameCount)

            // Convert Float32 → Int16 explicitly so the on-disk WAV is unambiguously
            // 16-bit PCM regardless of AVAudioFile's internal conversion behaviour.
            guard let int16Buffer = AVAudioPCMBuffer(pcmFormat: int16Format, frameCapacity: float32Buffer.frameLength) else {
                throw AudioChunkerError.invalidFormat
            }
            // Reset converter state between chunks so no residual buffering
            // from a previous chunk bleeds into the next one.
            converter.reset()
            var convError: NSError?
            let status = converter.convert(to: int16Buffer, error: &convError) { _, outStatus in
                outStatus.pointee = .haveData
                return float32Buffer
            }
            if status == .error || convError != nil {
                throw convError ?? AudioChunkerError.invalidFormat
            }

            // Write the Int16 buffer using the matching format. AVAudioFile(forWriting:settings:)
            // will set processingFormat to Float32, but we bypass that by opening the file with
            // the int16Format directly so write(from:) receives a matching-format buffer and
            // performs no hidden conversion.
            // Use a fresh AVAudioFile scoped to this iteration so the WAV header is finalised
            // (file handle closed) before whisper-cli opens the file.
            do {
                let outputFile = try AVAudioFile(
                    forWriting: chunkURL,
                    settings: int16Format.settings,
                    commonFormat: .pcmFormatInt16,
                    interleaved: true
                )
                try outputFile.write(from: int16Buffer)
                // outputFile goes out of scope here; ARC closes and flushes it synchronously.
            }

            chunks.append(ChunkInfo(
                url: chunkURL,
                index: index,
                startTime: boundary.start,
                endTime: boundary.end
            ))
        }

        return chunks
    }
}
