import Foundation

enum TextFormatter {
    static func format(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        var result = text
        result = replaceVoiceCommands(result)
        result = cleanPunctuationSpacing(result)
        result = autoCapitalize(result)
        result = normalizeWhitespace(result)
        return result
    }

    // MARK: - Voice command substitution

    private static let voiceCommands: [(pattern: String, replacement: String)] = [
        ("new paragraph", "\n\n"),
        ("new para", "\n\n"),
        ("new line", "\n"),
        ("newline", "\n"),
        ("exclamation mark", "!"),
        ("exclamation point", "!"),
        ("question mark", "?"),
        ("full stop", "."),
        ("period", "."),
        ("semicolon", ";"),
        ("comma", ","),
        ("colon", ":"),
    ]

    private static func replaceVoiceCommands(_ text: String) -> String {
        var result = text
        for cmd in voiceCommands {
            let escaped = NSRegularExpression.escapedPattern(for: cmd.pattern)
            // Consume optional trailing punctuation that Whisper adds after voice commands
            guard let regex = try? NSRegularExpression(pattern: "(?i)\\b\(escaped)\\b[.,;:!?]*") else { continue }
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: cmd.replacement
            )
        }
        return result
    }

    // MARK: - Punctuation spacing

    private static func cleanPunctuationSpacing(_ text: String) -> String {
        var result = text
        // Remove spaces before punctuation
        if let regex = try? NSRegularExpression(pattern: "\\s+([.!?,;:])") {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1"
            )
        }
        // Ensure space after punctuation when followed by a letter (not after newlines)
        if let regex = try? NSRegularExpression(pattern: "([.!?,;:])([A-Za-z])") {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: "$1 $2"
            )
        }
        return result
    }

    // MARK: - Auto-capitalization

    private static func autoCapitalize(_ text: String) -> String {
        var result = text

        // Capitalize first letter
        if let firstLetterIdx = result.firstIndex(where: { $0.isLetter }) {
            result.replaceSubrange(
                firstLetterIdx ... firstLetterIdx,
                with: String(result[firstLetterIdx]).uppercased()
            )
        }

        // Capitalize after sentence-ending punctuation + whitespace
        result = regexReplaceWithTransform(result, pattern: "([.!?])\\s+(\\p{Ll})") { match in
            let prefix = match.dropLast(1)
            let letter = match.last!
            return String(prefix) + String(letter).uppercased()
        }

        // Capitalize after newlines
        result = regexReplaceWithTransform(result, pattern: "\\n\\s*(\\p{Ll})") { match in
            let prefix = match.dropLast(1)
            let letter = match.last!
            return String(prefix) + String(letter).uppercased()
        }

        return result
    }

    // MARK: - Whitespace normalization

    private static func normalizeWhitespace(_ text: String) -> String {
        var result = text
        // Clean spaces around newlines, preserving newline count
        result = regexReplaceWithTransform(result, pattern: " *(\n+) *") { match in
            let newlineCount = match.filter { $0 == "\n" }.count
            return String(repeating: "\n", count: newlineCount)
        }
        // Collapse multiple spaces to one
        if let regex = try? NSRegularExpression(pattern: "[ ]{2,}") {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: " "
            )
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    /// Regex replace where each match is transformed by a closure.
    private static func regexReplaceWithTransform(
        _ text: String,
        pattern: String,
        transform: (String) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)
        var result = text
        // Iterate matches in reverse to preserve indices
        for match in regex.matches(in: text, range: fullRange).reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let matched = String(result[range])
            result.replaceSubrange(range, with: transform(matched))
        }
        return result
    }
}
