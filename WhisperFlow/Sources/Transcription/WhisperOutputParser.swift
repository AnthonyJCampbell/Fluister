import Foundation

/// Parses whisper-cli stdout into clean transcript text.
enum WhisperOutputParser {
    /// Parse the raw stdout from whisper-cli into transcript text.
    /// With --no-timestamps, whisper-cli outputs plain text lines to stdout.
    /// Metadata/info lines (whisper_*, system_info, main:, etc.) go to stderr,
    /// so they won't appear in stdout. We still strip timestamps as a safety net.
    static func parse(_ output: String) -> String {
        let lines = output.components(separatedBy: .newlines)
        var result: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines
            guard !trimmed.isEmpty else { continue }

            // Strip timestamp prefix if present: [00:00:00.000 --> 00:00:05.000]
            let timestampPattern = #"^\[[\d:.]+\s*-->\s*[\d:.]+\]\s*"#
            if let regex = try? NSRegularExpression(pattern: timestampPattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                let afterTimestamp = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: match.range.length)...])
                let cleaned = afterTimestamp.trimmingCharacters(in: .whitespaces)
                if !cleaned.isEmpty {
                    result.append(cleaned)
                }
            } else {
                result.append(trimmed)
            }
        }

        return result.joined(separator: " ")
    }

    /// Concatenate multiple chunk transcripts into a single transcript.
    static func concatenateChunks(_ chunks: [String]) -> String {
        return chunks
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
