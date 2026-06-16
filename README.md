# Tail

macOS game clipping. High-quality replay buffer + share links. Inspired by Medal.

## Status — Phase 1 spike (local clipping)

Native Swift + ScreenCaptureKit capture (display **or** a chosen window) + system
audio → VideoToolbox HW H.264 + AAC → in-RAM replay ring buffer → hotkey flush to
a synced `.mp4` (video + audio tracks). No backend yet.

Pick the capture source (display or game window) from the menu-bar 🎬 menu.

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
| `CaptureEngine.swift` | ScreenCaptureKit capture (display or window) + system audio |
| `Encoder.swift` | VideoToolbox H.264 HW encode, 1s keyframe interval |
| `ReplayBuffer.swift` | Video+audio rings; flush muxes H.264 + AAC into mp4 |
| `HotKey.swift` | Carbon global hotkey (no TCC permission needed) |
| `ReplayBuffer.swift` | Thread-safe ring of encoded frames; flush → mux mp4 |
| `main.swift` | Menu-bar app, F9 global hotkey |

## Roadmap

- **Phase 1** (now): local clipping spike ← you are here
- Phase 2: R2 storage + ffmpeg HLS transcode + short-link backend
- Phase 3: Next.js web player + Discord OG/oEmbed embed
- Phase 4: clip library UI, trim editor, accounts, 4K paid tier

## Known gaps (spike)

- Mic capture not wired yet — system audio only (mic = AVCaptureDevice, later).
- Requires full Xcode for eventual signed distribution; CLI tools fine for dev.
- `kill -USR1 <pid>` triggers a clip (dev/CI helper, no UI needed).
- **QuickTime mis-paces 120fps playback** (caps ~40fps → 3× slow). The clips are
  correct — container, browsers, and Discord play true 120fps at real duration.
  QuickTime alone can't preview high-fps; the Phase 3 web player handles preview.
  H.264 chosen over HEVC for universal browser/Discord playback (share feature).
