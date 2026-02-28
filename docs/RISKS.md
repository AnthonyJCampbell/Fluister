# RISKS.md — Failure Modes & Mitigations

## R1: whisper.cpp Makefile build fails on arm64
**Likelihood:** Low (whisper.cpp has good Apple Silicon support)
**Impact:** High (blocks core functionality)
**Mitigation:** Pin to a known-good release tag. Test build early (Phase 2). If Makefile fails, try adjusting CFLAGS/compiler flags before considering cmake.

## R2: Carbon hotkey API removed in future macOS
**Likelihood:** Low for macOS 14–15 (still works as of Sequoia)
**Impact:** High (breaks core UX)
**Mitigation:** Spec requires Carbon. If it fails at runtime, fall back to showing a clear error and manual-trigger via menu.

## R3: Microphone permission denied or never prompted
**Likelihood:** Medium (depends on app signing/sandbox state)
**Impact:** High (can't record)
**Mitigation:** Explicitly request permission on first use. Check AVCaptureDevice.authorizationStatus. Show clear instructions to open System Settings.

## R4: Model download URLs become stale
**Likelihood:** Medium (HuggingFace URLs can change)
**Impact:** Medium (app works once model exists; just can't auto-download)
**Mitigation:** Pin URLs in ModelSources.swift. If URLs can't be verified during build, leave placeholder + clear user message. Document in RELEASE.md.

## R5: whisper-cli output format changes between versions
**Likelihood:** Low (pinning to specific commit)
**Impact:** Medium (parser breaks)
**Mitigation:** Pin whisper.cpp to exact commit/tag. Write parser tests against known output samples.

## R6: Large recordings cause memory issues during chunking
**Likelihood:** Low (10min of 16kHz mono audio ≈ 19MB)
**Impact:** Low
**Mitigation:** Stream-based chunking with AVAudioFile (reads in buffers, doesn't load entire file).

## R7: App not signed — macOS Gatekeeper blocks launch
**Likelihood:** High for distributed builds, Low for local dev
**Impact:** Medium
**Mitigation:** For dev: `xattr -cr` on built app. Notarization is out of scope for v1. Document workaround in README.
