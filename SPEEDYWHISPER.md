# SpeedyWhisper

SpeedyWhisper is the personal Parakeet v2 fork of [AudioWhisper by mazdak and contributors](https://github.com/mazdak/AudioWhisper). The original license is retained in `LICENSE` and distributed in the app bundle alongside `CREDITS.md`.

## Recording and manual paste

A 224 × 64 point floating recorder appears immediately for Express Mode and press-and-hold dictation. It appears at the exact geometric center of the screen containing the pointer, without taking keyboard focus. It recenters for each new appearance. Its orb, timer, and meter follow the actual recording. Silence does not generate artificial waveform activity.

After recording stops, the same small bar shows transcription progress. Completion copies the transcript to the clipboard, plays the existing completion sound if enabled, and hides the bar immediately. The user presses ⌘V in their chosen application. There is no review panel, Enter-to-paste action, synthetic paste event, or Accessibility setup. A stale SmartPaste preference cannot require extra permissions.

The existing Parakeet backend processes the finished recording in one request. It does not currently emit partial words during recording. Model inference and microphone capture are unchanged.

## Preserved behavior and identity

The established `com.audiowhisper.app` identifier, executable/module names, application-support paths, Python environment, cached Parakeet v2 model, audio capture settings, microphone boosting, history schema, and existing preferences remain in use. Microphone boosting stays enabled at the owner's request.

Settings/history opens at 620 × 520 points, with a 540 × 420 minimum. Three compact section controls replace the original sidebar. History has search, Copy, and a menu for the existing delete actions.

## Validation

The retained Swift suite covers recording, audio processing, history, daemon lifecycle, clipboard replacement, microphone-only permission handling, microphone meter bounds, and window geometry. The new view states can be rendered without opening a window or recording audio:

```sh
SPEEDYWHISPER_PREVIEW_DIR=/tmp/speedywhisper-preview swift test --filter RecorderPreviewRenderTests
```

No synthetic paste events are used. See `docs/ACCEPTANCE.md` for the live workflow check.
