# ScribeKitt

ScribeKitt is the personal Parakeet v2 fork of [AudioWhisper by mazdak and contributors](https://github.com/mazdak/AudioWhisper). The original license is retained in `LICENSE` and distributed in the app bundle alongside `CREDITS.md`.

## Recording and manual paste

The recorder appears at the center of the screen containing the pointer, without taking keyboard focus. A taller KITT-inspired voice modulator sits on the left: three narrow columns of red LED segments expand symmetrically with speech. Decorative amber/red lamps in the classic surrounding positions show locality, elapsed time, word count, and recording/live/final/copied status. They are indicators, not controls. The display uses the existing 10 Hz microphone meter with no animation clock.

The transcript appears on the right. Earlier words remain as the eight-second acoustic window advances. The panel starts at 640 × 300 points and expands up to 1000 × 840, constrained by the current screen's usable area. Normal-length transcripts display in full without scrolling. Beyond the screen-sized limit, a labelled excerpt shows the latest live words or the beginning of the final transcript; the clipboard and history keep the complete final text.

Stopping runs the established full-recording Parakeet pass, copies its text, and gives a glow/check confirmation. Short phrases remain for 0.85 seconds; longer text receives more scan time, up to six seconds. Pressing ⌘V dismisses the confirmation early when the existing passive keyboard listener receives the shortcut. Paste itself is never intercepted or generated. macOS requires Accessibility access to deliver other-app keyboard events; no new permission prompt is introduced. Menu/context-menu paste is not detected, and timed dismissal remains available.

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

## One-time setup

A new installation offers one Prepare ScribeKitt action for the local Python runtime and Parakeet v2 model. Existing installations bypass setup; no model selector or tuning controls are added. Recording shortcuts open setup until verification succeeds. Normal model loading resolves cached files explicitly offline and retains the same decoder defaults and model cache. See [first-launch validation](docs/FIRST-LAUNCH.md).
