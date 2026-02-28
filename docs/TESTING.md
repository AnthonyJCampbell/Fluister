# TESTING.md — Test Strategy & Coverage Map

## Strategy
Unit tests for pure logic only. No UI automation, no timing-sensitive tests, no network tests.

## What We Test

### AudioChunker (chunking boundaries)
- Short recording (<60s): no chunking, single file returned
- Exactly 60s: no chunking (boundary)
- 61s: chunks into 30s segments with 2s overlap
- 120s: correct chunk count and overlap boundaries
- Edge: empty file, very short file (<1s)

### WhisperOutputParser (stdout parsing)
- Clean single-line output
- Multi-line output (concatenated)
- Output with timestamps (stripped)
- Empty output (error case)
- Output with leading/trailing whitespace

### PreferencesManager (JSON persistence)
- Write then read: round-trip fidelity
- Default values when file missing
- Corrupt file handling (reset to defaults)
- Individual field updates preserve other fields

### TranscriptionEngine (concatenation)
- Single chunk result: returned as-is
- Multiple chunk results: joined with single space
- Chunk with leading/trailing whitespace: trimmed before join
- Empty chunk result: skipped in concatenation

## What We Don't Test (and why)
- **UI rendering** — SwiftUI/AppKit visual tests are brittle and slow
- **Audio recording** — requires hardware mic, non-deterministic
- **Hotkey registration** — requires Carbon event loop, OS-level
- **Model download** — network-dependent
- **whisper-cli invocation** — requires built binary + model file (integration, not unit)
- **Clipboard operations** — requires running app context

## Coverage Target
100% of pure logic modules (Chunker, Parser, Preferences). 0% of UI/hardware/OS integration (tested manually via smoke script).
