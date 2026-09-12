# SpeedyWhisper

<p align="center"><img src="SpeedyWhisperIcon.png" width="128" alt="SpeedyWhisper app icon"></p>

A small, local macOS dictation app: watch your words appear while you speak, then paste with ⌘V.

<p align="center"><img src="docs/images/showcase.png" width="960" alt="Native macOS dictation panel with a red KITT-style voice display, status indicators, and a live transcript"></p>
<p align="center"><em>The native recorder interface with sample text. Live words appear beside the voice display; the panel expands for longer dictations.</em></p>

**Built on [AudioWhisper by mazdak and contributors](https://github.com/mazdak/AudioWhisper).** The original [MIT license](LICENSE) is preserved. See [Credits](CREDITS.md).

## Daily use

- Start dictation with your existing hotkey or press-and-hold shortcut.
- A centered floating recorder places a tall KITT-style voice display and decorative status lamps beside the transcript. The text area grows as you speak; earlier words remain visible as the live draft advances.
- Stop recording. The existing full-audio Parakeet pass produces the final text, copies it, and shows a brief animated confirmation that dismisses itself.
- The completed text is copied to your clipboard. Press **⌘V** yourself wherever you want to paste. **Escape** cancels recording.
- History, recording preferences, and launch at login live in a compact settings window.

Recording, live text, and manual paste require no Accessibility setup. Auto-hide on the ⌘V shortcut also works when macOS allows the existing global keyboard listener; otherwise the brief timed dismissal remains. The app never sends paste keystrokes. Turn **Transcription Streaming** off in Preferences to use record-then-transcribe without live audio processing. The setting is saved and applies to the next recording.

## This fork

SpeedyWhisper uses the existing local **Parakeet v2** installation on Apple Silicon. It removes cloud transcription, WhisperKit, semantic correction, statistics, app categories, and model setup screens. File transcription, completion sounds, and microphone boosting remain.

This is a personal build for an established AudioWhisper installation. It expects the existing cached `mlx-community/parakeet-tdt-0.6b-v2` model and app-managed Python environment. It does not include a new model-download wizard. macOS 14 or newer is required.

The original bundle identifier and application-support paths remain in use to preserve history, preferences, and runtime compatibility. The installed app is `/Applications/SpeedyWhisper.app`. Its internal identifier and data folders keep their original names to retain existing history, preferences, and model files.

## Build

```sh
swift build
swift test
CODE_SIGN_IDENTITY=- scripts/build.sh
```

The release script produces `SpeedyWhisper.app`. An installed `uv` executable or a copy in `Sources/Resources/bin/uv` is needed for runtime packaging. The existing Python dependency manifest is deliberately preserved; removing unused packages from the live environment is a separate change.

See [the streaming design and measured validation](docs/STREAMING.md), [the interface notes](SPEEDYWHISPER.md), [the reduction scope](SLIM_BUILD.md), and [the logo source and generation prompt](docs/branding/logo-prompt.md).
