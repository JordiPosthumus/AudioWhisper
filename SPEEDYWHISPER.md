# SpeedyWhisper

SpeedyWhisper is the personal Parakeet v2 fork of [AudioWhisper by mazdak and contributors](https://github.com/mazdak/AudioWhisper). The original license is retained in `LICENSE` and distributed in the app bundle alongside `CREDITS.md`.

## Recording and manual paste

The recorder appears at the exact center of the screen containing the pointer, without taking keyboard focus. Its KITT-inspired dashboard voice display has three vertical columns of red LED segments that light symmetrically from the center with speech. The central column follows the current microphone level; the shorter flanking columns use brief averages of recent readings. A single canvas updates from the existing 10 Hz audio meter, with no animation timer. The timer in the header tracks the recording. Two compact lines show live Parakeet text; draft words are tinted cyan. The listening display is 380 × 194 points with streaming, or 380 × 126 without it.

Stopping still runs the established full-recording Parakeet pass. The final text is copied immediately, the view gives a single glow/check confirmation, and then dismisses automatically. Short phrases remain for 0.85 seconds; longer text receives more scan time, up to six seconds. The user presses ⌘V in their chosen application. There is no Paste button, synthetic paste event, or Accessibility setup. Reduce Motion is respected.

Transcription Streaming defaults on. Its saved Preferences toggle applies to the next recording. Turning it off starts no preview microphone tap or preview model requests; the existing final pass remains available in both modes.

See `docs/STREAMING.md` for the isolated preview lifecycle and validation measurements.

## Preserved behavior and identity

The established `com.audiowhisper.app` identifier, executable/module names, application-support paths, Python environment, cached Parakeet v2 model, audio capture settings, microphone boosting, history schema, and existing preferences remain in use. Microphone boosting stays enabled at the owner's request.

Settings/history opens at 620 × 520 points, with a 540 × 420 minimum. Three compact section controls replace the original sidebar. History has search, Copy, and a menu for the existing delete actions.

## Validation

The retained Swift suite covers recording, audio processing, history, daemon lifecycle, clipboard replacement, microphone-only permission handling, microphone meter bounds, and window geometry. The new view states can be rendered without opening a window or recording audio:

```sh
SPEEDYWHISPER_PREVIEW_DIR=/tmp/speedywhisper-preview swift test --filter RecorderPreviewRenderTests
```

No synthetic paste events are used. See `docs/ACCEPTANCE.md` for the live workflow check.
