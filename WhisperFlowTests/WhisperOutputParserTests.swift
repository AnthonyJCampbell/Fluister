import XCTest
@testable import Fluister

class WhisperOutputParserTests: XCTestCase {

    func testParseSingleLine() {
        let output = "Hello, this is a test."
        let result = WhisperOutputParser.parse(output)
        XCTAssertEqual(result, "Hello, this is a test.")
    }

    func testParseMultiLine() {
        let output = """
        Hello world.
        This is a test.
        """
        let result = WhisperOutputParser.parse(output)
        XCTAssertEqual(result, "Hello world. This is a test.")
    }

    func testParseWithTimestamps() {
        let output = """
        [00:00:00.000 --> 00:00:05.000]   Hello, this is a test.
        [00:00:05.000 --> 00:00:10.000]   Second sentence here.
        """
        let result = WhisperOutputParser.parse(output)
        XCTAssertEqual(result, "Hello, this is a test. Second sentence here.")
    }

    func testParseEmptyOutput() {
        let result = WhisperOutputParser.parse("")
        XCTAssertEqual(result, "")
    }

    func testParseWhitespaceOnly() {
        let result = WhisperOutputParser.parse("   \n  \n  ")
        XCTAssertEqual(result, "")
    }

    func testParseOnlyTranscriptText() {
        // whisper-cli metadata (whisper_*, system_info, main:, etc.) goes to stderr,
        // not stdout. The parser only receives stdout which contains transcript text.
        let output = """
        Hello world.
        This is more text.
        """
        let result = WhisperOutputParser.parse(output)
        XCTAssertEqual(result, "Hello world. This is more text.")
    }

    func testParseMixedTimestampAndPlainLines() {
        let output = """
        [00:00:00.000 --> 00:00:03.000]   First line.
        Second line without timestamps.
        [00:00:03.000 --> 00:00:06.000]   Third line.
        """
        let result = WhisperOutputParser.parse(output)
        XCTAssertEqual(result, "First line. Second line without timestamps. Third line.")
    }

    func testParseWithLeadingTrailingWhitespace() {
        let output = "   Hello world.   "
        let result = WhisperOutputParser.parse(output)
        XCTAssertEqual(result, "Hello world.")
    }

    func testConcatenateChunks() {
        let chunks = ["Hello world.", "This is chunk two.", "Final chunk."]
        let result = WhisperOutputParser.concatenateChunks(chunks)
        XCTAssertEqual(result, "Hello world. This is chunk two. Final chunk.")
    }

    func testConcatenateChunksWithWhitespace() {
        let chunks = ["  Hello world.  ", "  This is chunk two.  "]
        let result = WhisperOutputParser.concatenateChunks(chunks)
        XCTAssertEqual(result, "Hello world. This is chunk two.")
    }

    func testConcatenateChunksSkipsEmpty() {
        let chunks = ["Hello.", "", "  ", "World."]
        let result = WhisperOutputParser.concatenateChunks(chunks)
        XCTAssertEqual(result, "Hello. World.")
    }

    func testConcatenateSingleChunk() {
        let result = WhisperOutputParser.concatenateChunks(["Just one chunk."])
        XCTAssertEqual(result, "Just one chunk.")
    }

    func testConcatenateEmptyArray() {
        let result = WhisperOutputParser.concatenateChunks([])
        XCTAssertEqual(result, "")
    }
}
