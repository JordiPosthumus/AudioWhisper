# AudioWhisper efficiency and reliability audit

Date: 2026-09-12. Baseline: upstream commit `71fed36` (2.1.0).

This pass changes the fork's source code. It does not install the app, restart existing services, change model selections, change inference limits or generation settings, or modify the owner's model files and caches. A pre-edit source archive was saved at `/tmp/AudioWhisper-before-audit-20260912-0929.tar`; the original Git commit also remains available.

## Measured result

The standalone PCM converter was compiled with Swift's release optimizations and measured on this Apple Silicon Mac using generated 30-minute, 48 kHz mono audio, converted to the same 16 kHz Float32 output. Five runs alternated the order of the original and streaming implementations. Audio generation and compilation are outside the measured conversion interval.

| Metric (median of five runs) | Original | Updated |
| --- | ---: | ---: |
| Peak process resident memory | 242,761,728 bytes | 13,238,272 bytes |
| Conversion time | 0.133369 s | 0.108031 s |

This is **94.5% less peak memory** and **19.0% less conversion time** for this benchmark. It measures the audio conversion step, not end-to-end model inference or total app memory. Filesystem caching and hardware affect timing.

Both outputs have SHA-256 `81ec2e27483be33a5e6feb23cf8d4cb4c92569171c6eeabde7ab87b6beae84ac`. Raw measurements are in `Benchmarks/AudioPCM/measurements-2026-09-12.json`.

Reproduce from the repository root with a full Xcode toolchain:

```sh
python3 Benchmarks/AudioPCM/run.py --output /tmp/audiowhisper-pcm-results.json
```

If Command Line Tools are selected, set `DEVELOPER_DIR` to the installed Xcode developer directory for that command. The benchmark creates its own temporary files and removes them when finished.

## Changes and evidence

| Problem | Change | Validation |
| --- | --- | --- |
| Parakeet retained all decoded samples, then copied them into a second full-size allocation. | Stream PCM through a 256 KiB sample buffer and remove the duplicated decoder. | Before/after benchmark, identical output hashes, resampling and multiple-buffer regression tests. |
| The native audio reader used a buffer pointer after leaving its borrowing scope. | Keep the native read and sample consumption inside the pointer's valid scope. | Existing audio tests and streamed/decoded sample comparison. |
| Invalid sample rates could reach native conversion and invalid allocation calculations. | Reject nonpositive rates before conversion. | Zero and negative rate regressions. |
| `AVAudioRecorder.record()` returning false was ignored. | Return failure, release the recorder, clear session state and partial output, and permit retry. | A mock recorder refuses the first start and accepts the next. |
| uv subprocesses were waited on before either output pipe was drained. | Drain stdout and stderr concurrently while the child runs. | Child emits 1 MiB to each pipe; both outputs and its nonzero exit status are preserved without deadlock. |
| Daemon writes could block its actor, and a closed pipe could terminate the app with SIGPIPE. | Serialize whole frames on a dedicated I/O queue; use a per-descriptor no-SIGPIPE setting and throwing writes. | A fake daemon blocks stdin while a 1 MB request is cancelled; shutdown does not crash. This test reproduced SIGPIPE before the descriptor fix. |
| Cancelled daemon requests retained their waiting continuations. | Remove/resume the cancelled caller while retaining the existing daemon process. | The pending count returns to zero and a subsequent ping uses the same process ID. This is a process-lifetime test, not a real-model cache benchmark. |
| A delayed termination callback could close a replacement daemon's pipes. | Tie lifecycle callbacks to a process generation and clean up outstanding requests on a detected exit. | Child-crash recovery test and subsequent successful ping. |
| Warmup accepted a false or missing success result; malformed scalar results could fail during JSON serialization. | Require successful warmup and allow scalar JSON through to normal decoding error handling. | False-success and scalar-response regressions. |
| Non-object JSON input could crash the Python daemon; model `print()` output could corrupt RPC frames. | Validate request shapes and redirect Python model logging to stderr while reserving stdout for responses. | Three protocol regressions; two reproduce errors against the original upstream RPC code. |
| Deleting K selected history rows performed K full-history fetches, saves and metrics rebuilds. | Delete the selection with one fetch, one save and one metrics rebuild. | Real in-memory SwiftData test checks selected IDs, duplicate IDs, missing IDs and rebuilt totals. Work changes from repeated O(KN) scans to O(N + K). |
| Mock pagination returned the first page when the offset was past the end. | Return an empty page, matching database pagination. | Offsets at and beyond the end. |
| Paste activation used the wrong notification center and did not retain its observer cleanup state. | Use the workspace notification center and a completion that runs once, removing both observer and timeout. | Immediate activation, unrelated notifications, matching notification, timeout and late-notification tests. |
| Activation timeout could paste into an app that never became active. | Report activation failure while keeping the transcript on the clipboard. | Inactive-target timeout regression. |
| Gemini files between 5 and 10 MiB were sent down a path that refused them. | Share the existing 5 MiB inline boundary between routing and validation; larger files use the file-upload path. | Mocked real request flow for a 6.4 MB WAV and a small WAV. |
| Gemini requests labelled all supported input formats as MP4. | Send the MIME type associated with the actual input extension. | Inline and uploaded WAV requests assert `audio/wav`. |
| The legacy provider overload defaulted to Gemini despite its documented OpenAI default. | Distinguish an absent preference from explicit false. | Provider tests now compare associated provider values, rather than treating every missing-key error as equal. |
| Empty ripple animations kept a 20 Hz cleanup timer alive. | Run a cancellable cleanup task only while ripples exist, keeping the same active cleanup interval and fade behavior. | Source/lifecycle review and compilation; idle energy use has not been profiled in Instruments. |
| The test launcher selected a nonexistent test class and could hide a failing exit status. | Run the full suite by default and forward arguments and exit status unchanged. | Stub Swift executable verifies argument forwarding and exit code 23. |
| Parallel tests interfered through shared preferences and the system clipboard. | Inject isolated preferences and a uniquely named pasteboard in the affected tests; use the intended in-memory database throughout history integration setup; retain production defaults. | Full parallel suite and actual network-request stubs. |

## Validation

- Debug and optimized release builds using the installed Xcode toolchain.
- 456 Swift XCTest cases passed with parallel execution and code coverage.
- Python unittest discovery: 15 tests, 11 passed and 4 legacy tests skipped. The skipped tests target the absent old `parakeet_transcribe` module; all three new daemon protocol tests pass without model dependencies.
- PCM regression comparison and five-run memory/time benchmark.
- Test launcher exit-status check and `git diff --check`.

The initial build failed because the selected Command Line Tools lack `actool`; using Xcode through a per-command `DEVELOPER_DIR` resolved that without changing system toolchain selection. Existing unrelated compiler warnings have not been reformatted or suppressed.

## Remaining validation and investigation

This audit does not establish that the entire app is bug-free. Live microphone recordings, actual focus/paste behavior across third-party apps, cloud provider integration with real credentials, and model inference throughput still need a live acceptance pass. Those actions have not been run against the installed app.

The next local-model investigation should cover the separate WhisperKit instances used by preload and transcription, duplicate concurrent model initialization, memory-pressure cache handling, and repeated dependency synchronization in Parakeet's transcription path. Those paths were inspected but their cache and dependency policies were not changed in this pass. Any such change needs an isolated real-model cold-to-warm measurement; process-start or mocked-model tests alone would not establish cache reuse or preserved inference behavior.

The cloud path still uses callback-based requests and does not yet propagate task cancellation to every network operation. History rendering still fetches all records; the new deletion path removes repeated scans but does not introduce UI pagination or change retention.
