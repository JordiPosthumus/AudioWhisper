# First-launch setup and release validation

ScribeKitt 210.13 adds a single first-run action for new Apple Silicon installations. It prepares the existing Python 3.11 runtime manifest, downloads the two Parakeet v2 files (`config.json` and `model.safetensors`), and verifies offline decoding with a one-second synthetic silent fixture. The fixture is deleted afterward and never enters the clipboard or history. A working existing model/runtime bypasses this flow without dependency syncing or model loading at app startup.

The setup action alone can download model files. Normal transcription resolves the existing snapshot explicitly with `local_files_only=True` and passes its directory to Parakeet with the same default arguments as before. This fixes an import-time offline-flag issue in the Hub library that previously allowed an online metadata lookup. The in-process model cache and final generation function remain intact. Existing local-directory model loading remains supported.

Recording and file-transcription entry points direct new users to setup until it succeeds. Microphone permission is deferred until the user proceeds from setup to recording. Errors are shown with retry and details. Duplicate button presses cannot create concurrent setup jobs. Completed downloads are reused on retry. No recording is uploaded, and no model chooser or inference-tuning settings are added.

## Checks on the development Mac

An isolated clean-install integration downloaded a managed Python interpreter, dependencies, and the model into a new temporary directory. The runtime completed at 23.56 seconds, the model download completed at 48.18 seconds, and initial verification completed at 63.92 seconds. The 5.18-second acceptance clip transcribed successfully; the next pass returned exactly the same text. The temporary installation and download caches occupied about 3.8 GB. Setup asks users to allow 6 GB for working space. Download speed varies by connection.

The fresh model snapshot matched the established installation's snapshot (`8ae155301e23d820d82aa60d24817c900e69e487`). The owner's runtime, model files and preferences were not used as the clean setup's writable directories.

After the offline-loader correction, a separate process explicitly rejected network metadata calls. The cached model loaded successfully with **zero network metadata attempts**. The same probe failed against the previous loader after one attempted lookup.

Unit coverage includes an existing-installation bypass, ordered preparation, failure/retry, repeated clicks, unsupported architecture, incomplete cache detection, local-only cache reuse, local-directory loading, and environment restoration after failure. Native renders cover setup, success and error states as well as the recorder and long transcripts.

The clean integration can be opted into with `SCRIBEKITT_FRESH_TEST_ROOT`; it requires dedicated temporary Application Support, model, uv-cache and managed-Python paths. Ordinary test runs do not download models.

## Distribution status

The source and local build are validated on the development Mac. This does not constitute a test on every supported macOS release or microphone. No Developer ID signing identity is available in the current environment. A broadly distributed binary still needs Developer ID signing, Apple notarization, and a clean-Mac launch check of that exact distributed artifact. The local ad-hoc build is for testing.

## Final offline performance check

Both the fresh runtime and the established runtime passed 57 preview updates across a 45.41-second fixture while all network metadata requests were rejected. Each retained the same cached model and attention objects, and final text stayed identical before and after preview. The short transcript also matched the result recorded before the rebrand/loader fix.

- Fresh runtime: preview computation median 0.095 seconds, maximum 0.109 seconds per 0.8-second audio update; warm final transcription of the 45.41-second fixture took 0.405 seconds. Zero network metadata requests.
- Established runtime: preview computation median 0.110 seconds, maximum 0.124 seconds per 0.8-second audio update; warm final transcription of the 45.41-second fixture took 0.437 seconds. Zero network metadata requests.

These are local measurements on the development Mac, not latency guarantees for other hardware. The graphics path is unchanged by the rebrand; its existing full-panel benchmark is documented in [STREAMING.md](STREAMING.md).

Final validation: 293 Swift tests passed and two opt-in/snapshot checks were skipped in the full suite; the clean-download integration passed separately. All 19 Python protocol, setup and loader checks passed. The universal release build passed. Existing final-inference, preview-decoding, runtime-manifest and runtime-bootstrap source files remain byte-for-byte unchanged; the loader change is limited to locating the cached snapshot.
