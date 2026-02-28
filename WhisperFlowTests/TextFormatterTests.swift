import XCTest
@testable import Fluister

class TextFormatterTests: XCTestCase {

    // MARK: - Voice command tests

    func testNewLine() {
        let result = TextFormatter.format("hello new line world")
        XCTAssertEqual(result, "Hello\nWorld")
    }

    func testNewlineOneWord() {
        let result = TextFormatter.format("hello newline world")
        XCTAssertEqual(result, "Hello\nWorld")
    }

    func testNewParagraph() {
        let result = TextFormatter.format("hello new paragraph world")
        XCTAssertEqual(result, "Hello\n\nWorld")
    }

    func testNewPara() {
        let result = TextFormatter.format("hello new para world")
        XCTAssertEqual(result, "Hello\n\nWorld")
    }

    func testPeriod() {
        let result = TextFormatter.format("hello period world")
        XCTAssertEqual(result, "Hello. World")
    }

    func testFullStop() {
        let result = TextFormatter.format("hello full stop world")
        XCTAssertEqual(result, "Hello. World")
    }

    func testComma() {
        let result = TextFormatter.format("hello comma world")
        XCTAssertEqual(result, "Hello, world")
    }

    func testQuestionMark() {
        let result = TextFormatter.format("hello question mark")
        XCTAssertEqual(result, "Hello?")
    }

    func testExclamationMark() {
        let result = TextFormatter.format("hello exclamation mark")
        XCTAssertEqual(result, "Hello!")
    }

    func testExclamationPoint() {
        let result = TextFormatter.format("hello exclamation point")
        XCTAssertEqual(result, "Hello!")
    }

    func testColon() {
        let result = TextFormatter.format("dear sir colon")
        XCTAssertEqual(result, "Dear sir:")
    }

    func testSemicolon() {
        let result = TextFormatter.format("first semicolon second")
        XCTAssertEqual(result, "First; second")
    }

    // MARK: - Case insensitivity

    func testCaseInsensitive() {
        let result = TextFormatter.format("hello PERIOD world")
        XCTAssertEqual(result, "Hello. World")
    }

    func testMixedCaseInsensitive() {
        let result = TextFormatter.format("hello New Line world")
        XCTAssertEqual(result, "Hello\nWorld")
    }

    // MARK: - Auto-capitalization

    func testCapitalizeFirst() {
        let result = TextFormatter.format("hello world")
        XCTAssertEqual(result, "Hello world")
    }

    func testCapitalizeAfterPeriod() {
        let result = TextFormatter.format("hello. world")
        XCTAssertEqual(result, "Hello. World")
    }

    func testCapitalizeAfterQuestionMark() {
        let result = TextFormatter.format("why? because")
        XCTAssertEqual(result, "Why? Because")
    }

    func testCapitalizeAfterExclamation() {
        let result = TextFormatter.format("wow! great")
        XCTAssertEqual(result, "Wow! Great")
    }

    func testCapitalizeAfterNewline() {
        let result = TextFormatter.format("hello\nworld")
        XCTAssertEqual(result, "Hello\nWorld")
    }

    func testAlreadyCapitalized() {
        let result = TextFormatter.format("Hello. World")
        XCTAssertEqual(result, "Hello. World")
    }

    // MARK: - Punctuation spacing

    func testRemoveSpaceBeforePeriod() {
        let result = TextFormatter.format("hello . world")
        XCTAssertEqual(result, "Hello. World")
    }

    func testRemoveSpaceBeforeComma() {
        let result = TextFormatter.format("hello , world")
        XCTAssertEqual(result, "Hello, world")
    }

    func testEnsureSpaceAfterPunctuation() {
        let result = TextFormatter.format("hello.world")
        XCTAssertEqual(result, "Hello. World")
    }

    // MARK: - Combined / integration

    func testVoiceCommandsThenCapitalize() {
        let result = TextFormatter.format("hello period world")
        XCTAssertEqual(result, "Hello. World")
    }

    func testMultipleVoiceCommands() {
        let result = TextFormatter.format("hello comma how are you question mark")
        XCTAssertEqual(result, "Hello, how are you?")
    }

    func testNewParagraphWithCapitalization() {
        let result = TextFormatter.format("first new paragraph second")
        XCTAssertEqual(result, "First\n\nSecond")
    }

    func testComplexSentence() {
        let result = TextFormatter.format(
            "dear john comma I wanted to tell you something period new paragraph please call me exclamation mark"
        )
        XCTAssertEqual(result, "Dear john, I wanted to tell you something.\n\nPlease call me!")
    }

    // MARK: - Edge cases

    func testEmptyString() {
        let result = TextFormatter.format("")
        XCTAssertEqual(result, "")
    }

    func testWhitespaceOnly() {
        let result = TextFormatter.format("   ")
        XCTAssertEqual(result, "")
    }

    func testNoVoiceCommands() {
        let result = TextFormatter.format("Just a normal sentence")
        XCTAssertEqual(result, "Just a normal sentence")
    }

    func testWordBoundaryNewcomer() {
        let result = TextFormatter.format("the newcomer arrived")
        XCTAssertEqual(result, "The newcomer arrived")
    }

    func testWordBoundaryPeriodically() {
        let result = TextFormatter.format("periodically")
        XCTAssertEqual(result, "Periodically")
    }

    func testMultipleSpaces() {
        let result = TextFormatter.format("hello   world")
        XCTAssertEqual(result, "Hello world")
    }

    // MARK: - Real whisper output (punctuation around voice commands)

    func testWhisperAddsTrailingPunctuation() {
        // Whisper often adds periods/commas after voice command phrases
        let input = "Hey Mark, new line. I was wondering how you've been doing over the past couple of weeks. It's been a bit since we've chatted, and I was wondering if you had any updates on the project that we were talking about. New paragraph, kind of regards, new paragraph, Anthony."
        let result = TextFormatter.format(input)
        XCTAssertTrue(result.contains("\n"), "Should contain newline from 'new line' command")
        XCTAssertTrue(result.contains("\n\n"), "Should contain paragraph break from 'new paragraph' command")
        XCTAssertFalse(result.lowercased().contains("new line"), "Should not contain literal 'new line'")
        XCTAssertFalse(result.lowercased().contains("new paragraph"), "Should not contain literal 'new paragraph'")
    }

    func testVoiceCommandWithTrailingPeriod() {
        let result = TextFormatter.format("hello new line. world")
        XCTAssertEqual(result, "Hello\nWorld")
    }

    func testVoiceCommandWithTrailingComma() {
        let result = TextFormatter.format("hello new paragraph, world")
        XCTAssertEqual(result, "Hello\n\nWorld")
    }
}
