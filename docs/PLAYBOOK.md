# PLAYBOOK.md — Lessons & Guardrails

## Initial Guardrails (pre-build)
- **No cmake**: whisper.cpp must use Makefile build. Don't attempt cmake.
- **No global installs**: Everything stays in-repo.
- **xcodebuild only**: No Xcode UI. All builds via CLI.
- **Test pure logic only**: Don't waste time on UI/hardware tests.
- **Pin whisper.cpp**: Use a specific release tag, not HEAD.
- **DEV_MODE first**: All development uses repo-local paths.

## Lessons Learned During Build

### whisper.cpp version matters for Makefile builds
- v1.7.x moved to a modular ggml structure that requires cmake
- v1.5.5 is the last version with a clean standalone Makefile that builds `main` directly
- **Use v1.5.5** unless cmake becomes available
- Time saved: ~30 min by switching versions early instead of trying to hack cmake alternatives

### Xcode project generation without Xcode UI
- Ruby script to generate pbxproj works well for reproducible builds
- Key: generate deterministic UUIDs from file paths so re-running is safe
- Must list ALL source files explicitly in the build phase

### `open` doesn't pass environment variables
- macOS `open` command launches the app in its own environment
- Cannot rely on env vars set in shell (WHISPERFLOW_DEV_MODE etc.)
- Solution: auto-detect dev mode from app bundle path relative to repo

### Carbon hotkey API
- Works fine on macOS 14 despite being deprecated
- Need both kEventHotKeyPressed and kEventHotKeyReleased for hold-to-talk
- Unmanaged pointer dance required for the event handler callback

### Test structure for hosted unit tests
- Tests use BUNDLE_LOADER to test app internals
- PathManager needed override points (computed properties) for testability
- Created TestPathManager subclass with temp directory injection

## What NOT to Do
- Don't try cmake-dependent whisper.cpp versions without cmake installed
- Don't use `cd` in Bash tool — it changes CWD for subsequent commands
- Don't rely on environment variables passed through `open`
- Don't write UI automation tests — stick to pure logic unit tests
