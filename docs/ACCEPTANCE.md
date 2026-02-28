# ACCEPTANCE.md — Acceptance Criteria Checklist

## Core (must pass for ship)
- [ ] App launches as menu bar icon (no dock icon)
- [ ] Global hotkey registers successfully
- [ ] Hold-to-talk: press → pill appears → recording starts
- [ ] Release: recording stops → transcription starts → transcript copied to clipboard
- [ ] Toast confirms "Copied"
- [ ] ESC cancels recording (clipboard unchanged)
- [ ] ESC cancels transcription (clipboard unchanged)
- [ ] Language selection persists across restarts
- [ ] Model download with progress works (when network available)
- [ ] SHA256 verification on downloaded model
- [ ] App usable offline after model exists
- [ ] Long recording (>60s) uses chunked transcription
- [ ] 10-minute hard cap with 9:30 warning
- [ ] Chunk progress shown (Chunk i/N)
- [ ] Hotkey rebind via Set Hotkey panel
- [ ] Open Logs reveals log file
- [ ] Microphone permission request on first use
- [ ] make build succeeds
- [ ] make test passes (all unit tests green)
- [ ] make run launches app
- [ ] scripts/healthcheck.sh exits 0
- [ ] scripts/acceptance.sh exits 0

## Nice to have (deferred OK)
- [ ] Recent transcripts submenu
- [ ] Launch at login toggle
- [ ] Balanced model profile download
