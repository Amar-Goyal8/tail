# Tail

macOS game clipping. High-quality replay buffer + share links. Inspired by Medal.

## Status — Phase 1 spike (local clipping)

Native Swift + ScreenCaptureKit capture → CFR clock → VideoToolbox HW H.264
encode → in-RAM replay ring buffer → hotkey flush to `.mp4`. No backend yet.

Free-tier target: **1440p120** / **1080p240**. 4K reserved for paid (later).

## Run

```sh
./scripts/run.sh
```

Builds a `.app` bundle (ad-hoc signed) so macOS TCC can grant permissions.

First launch:
1. Grant **Screen Recording** (System Settings → Privacy & Security).
2. Grant **Input Monitoring** (for the F9 hotkey).
3. Relaunch.

Menu-bar 🎬 icon appears. Play. Press **F9** (or menu → Clip) to save the last 30s
to `~/Movies/Tail/`.

## Architecture

| File | Role |
|------|------|
| `Config.swift` | Resolution / FPS / bitrate / buffer presets |
| `CaptureEngine.swift` | ScreenCaptureKit capture + CFR clock (uniform frame timing) |
| `Encoder.swift` | VideoToolbox H.264 HW encode, 1s keyframe interval |
| `HotKey.swift` | Carbon global hotkey (no TCC permission needed) |
| `ReplayBuffer.swift` | Thread-safe ring of encoded frames; flush → mux mp4 |
| `main.swift` | Menu-bar app, F9 global hotkey |

## Roadmap

- **Phase 1** (now): local clipping spike ← you are here
- Phase 2: R2 storage + ffmpeg HLS transcode + short-link backend
- Phase 3: Next.js web player + Discord OG/oEmbed embed
- Phase 4: clip library UI, trim editor, accounts, 4K paid tier

## Known gaps (spike)

- Captures **main display** only — per-window/game picker is next (Phase 1.2).
- No audio yet (system + mic capture next).
- Requires full Xcode for eventual signed distribution; CLI tools fine for dev.
- **QuickTime mis-paces 120fps playback** (caps ~40fps → 3× slow). The clips are
  correct — container, browsers, and Discord play true 120fps at real duration.
  QuickTime alone can't preview high-fps; the Phase 3 web player handles preview.
  H.264 chosen over HEVC for universal browser/Discord playback (share feature).
