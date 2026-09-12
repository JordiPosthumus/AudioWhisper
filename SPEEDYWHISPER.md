# SpeedyWhisper

SpeedyWhisper is the personal Parakeet v2 fork of [AudioWhisper by mazdak and contributors](https://github.com/mazdak/AudioWhisper). The original license is retained in `LICENSE` and distributed in the app bundle alongside `CREDITS.md`.

## Recording and review

A 224 × 64 point floating recorder appears immediately for Express Mode and press-and-hold dictation. It stays near the bottom of the active screen without taking keyboard focus. Its orb and meter follow the recorder's actual microphone level; silence does not generate artificial waveform activity.

When transcription finishes, the window expands to a readable review card. Short text gets a shorter card; long text scrolls within a bounded height. Enter or Paste inserts into the captured application after checking permission and activation. Copy remains available. Escape cancels recording/processing or dismisses the preview. There is no timed dismissal or automatic paste before review.

The preview is a key-capable borderless window, so Enter and Escape reach it. While recording without focus, ordinary typing in another app passes through; only Escape dismisses the recorder globally. Clipboard content is restored immediately before posting a requested paste, so a copy made during a permission prompt cannot replace the reviewed text.

## Preserved behavior and identity

The established `com.audiowhisper.app` identifier, executable/module names, application-support paths, Python environment, cached Parakeet v2 model, audio capture settings, microphone boosting, history schema, and existing preferences remain in use. Microphone boosting stays enabled at the owner's request.

Settings/history opens at 620 × 520 points, with a 540 × 420 minimum. Three compact section controls replace the original sidebar. History has search, Copy, and a menu for the existing delete actions.

## Validation

The retained Swift suite covers recording, audio processing, history, daemon lifecycle, clipboard fallback, activation ordering, cancelled pastes, microphone meter bounds, and window geometry. The new view states can be rendered without opening a window or recording audio:

```sh
SPEEDYWHISPER_PREVIEW_DIR=/tmp/speedywhisper-preview swift test --filter RecorderPreviewRenderTests
```

These checks do not prove that a particular external editor accepts macOS synthetic paste events. See `docs/ACCEPTANCE.md` for the live workflow check.
