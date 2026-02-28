import XCTest
@testable import Fluister

class AudioChunkerTests: XCTestCase {

    func testShortRecordingNoChunking() {
        let boundaries = AudioChunker.calculateChunkBoundaries(totalDuration: 30)
        XCTAssertEqual(boundaries.count, 1)
        XCTAssertEqual(boundaries[0].start, 0)
        XCTAssertEqual(boundaries[0].end, 30)
    }

    func testExactly60SecondsNoChunking() {
        let boundaries = AudioChunker.calculateChunkBoundaries(totalDuration: 60)
        XCTAssertEqual(boundaries.count, 1)
        XCTAssertEqual(boundaries[0].start, 0)
        XCTAssertEqual(boundaries[0].end, 60)
    }

    func test61SecondsChunks() {
        let boundaries = AudioChunker.calculateChunkBoundaries(totalDuration: 61)
        // Should produce chunks with 30s duration and 2s overlap
        XCTAssertGreaterThan(boundaries.count, 1)
        // First chunk starts at 0
        XCTAssertEqual(boundaries[0].start, 0)
        XCTAssertEqual(boundaries[0].end, 30)
        // Second chunk starts at 28 (30 - 2 overlap)
        XCTAssertEqual(boundaries[1].start, 28)
    }

    func test120SecondsChunks() {
        let boundaries = AudioChunker.calculateChunkBoundaries(totalDuration: 120)
        // 120s with 30s chunks, 2s overlap
        // Chunks start at: 0, 28, 56, 84 -> covers to 120
        XCTAssertGreaterThanOrEqual(boundaries.count, 4)

        // Verify overlap: each chunk after the first starts 28s after previous
        for i in 1..<boundaries.count {
            XCTAssertEqual(boundaries[i].start, boundaries[i-1].start + 28, accuracy: 1.0)
        }

        // Last chunk should reach the end
        XCTAssertEqual(boundaries.last!.end, 120, accuracy: 1.0)
    }

    func testChunkOverlap() {
        let boundaries = AudioChunker.calculateChunkBoundaries(totalDuration: 90)
        // Verify overlap between consecutive chunks
        for i in 1..<boundaries.count {
            let prevEnd = boundaries[i-1].end
            let currStart = boundaries[i].start
            let overlap = prevEnd - currStart
            XCTAssertGreaterThanOrEqual(overlap, 2.0, "Chunks must have at least 2s overlap")
        }
    }

    func testChunksCoverEntireDuration() {
        let durations: [TimeInterval] = [61, 90, 120, 300, 600]
        for duration in durations {
            let boundaries = AudioChunker.calculateChunkBoundaries(totalDuration: duration)
            XCTAssertEqual(boundaries.first!.start, 0, "First chunk must start at 0 for duration \(duration)")
            XCTAssertEqual(boundaries.last!.end, duration, accuracy: 5.0, "Last chunk must reach end for duration \(duration)")
        }
    }

    func testVeryShortDuration() {
        let boundaries = AudioChunker.calculateChunkBoundaries(totalDuration: 1)
        XCTAssertEqual(boundaries.count, 1)
        XCTAssertEqual(boundaries[0].start, 0)
        XCTAssertEqual(boundaries[0].end, 1)
    }

    func test10MinuteRecording() {
        let boundaries = AudioChunker.calculateChunkBoundaries(totalDuration: 600)
        // 600s should produce about 600/28 ≈ 21-22 chunks
        XCTAssertGreaterThan(boundaries.count, 15)
        XCTAssertLessThan(boundaries.count, 25)
        XCTAssertEqual(boundaries.last!.end, 600, accuracy: 5.0)
    }
}
