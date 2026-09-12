# Parakeet-only AudioWhisper

This personal build keeps local Parakeet v2 dictation, the existing recording window and shortcuts, history search/copy/delete, launch at login, and existing recording preferences. It defers the new UI.

Removed: WhisperKit, OpenAI/Gemini transcription, semantic correction, model/provider setup screens, usage statistics, app categories, custom prompt handling, and advanced model controls. Swift dependencies now consist only of HotKey.

The recorder uses the system microphone. The former app picker did not configure the recorder; Recording settings now opens macOS Sound input settings to choose the actual input.

Microphone boosting remains explicitly enabled at the owner's request. File transcription, completion sounds, and optional Smart Paste also remain; their removal has not been authorized. Paste activation uses the tested activation waiter and only the captured target app.

Existing preferences, history, downloaded models, Hugging Face caches, Python environment, dependency versions, inference settings, and daemon cache behavior are preserved. The stored history schema and legacy provider/model metadata remain readable. New transcripts do not collect source-app icons or usage metrics. Legacy statistics remain on disk. The Python dependency manifest intentionally remains unchanged to avoid `uv sync` changing the established environment; unused correction packages are not imported by the slim daemon.

Validation: retained Swift tests, Python RPC regression tests, universal release build, and identical installed/slim transcripts from the existing cached Parakeet v2 model. Single-sample cold/warm timing verifies reuse, not a general performance guarantee. Live microphone capture and cross-app paste still require an interactive check in the installed build.
