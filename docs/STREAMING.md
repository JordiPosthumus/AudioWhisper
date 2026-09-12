# Live draft plus unchanged final transcription

The preview uses the installed Parakeet v2 model with its normal full-attention decoder. No Python dependency, model, decoder setting, microphone-volume setting, or runtime manifest is upgraded or replaced.

## Data flow

An optional AVAudioEngine microphone tap runs alongside the established AVAudioRecorder AAC capture. Only the preview is converted incrementally to mono Float32 at 16 kHz, on a serial worker queue. The existing recording format and full-audio conversion/final inference remain unchanged.

Preview packets contain 0.8 seconds of audio. The coordinator allows one request in flight, combines queued audio without dropping samples, and reports an unavailable preview if its queue exceeds eight seconds. This bound affects only provisional display; the complete AAC recording continues independently. The UI keeps final transcription available after preview errors or input-device changes.

The same JSON-RPC daemon and cached model serve both paths. Each update decodes the most recent eight seconds of preview audio using the same log-mel conversion and normal model generation as the final pass. This is a rolling live preview, not the library's cached streaming approximation. No model weights, attention objects, positional encoding, or allocator cache are replaced or cleared. The window bounds preview work during long recordings; it does not limit the complete recording or final transcript.

The earlier 210.8 streaming approximation produced severe recognition errors on ordinary dictation. Re-decoding a rolling window lets new context correct partial words without carrying an erroneous streaming decoder state into the next update. All live words are provisional. The beginning of a rolling window can cut through a word, and the newest word may still be incomplete. Only the independent final pass produces the complete transcript.

Each recording has a session UUID and ordered packet sequence. Late packets and cleanup messages cannot enter or cancel a new session. Preview text never writes to the clipboard or history. Only the completed final pass does that. The full-audio request releases preview PCM before running its unchanged transcription function.

## Presentation

A 380 × 194 point live display shows the last two lines of draft text and a waveform built from 48 actual microphone-level readings at the recorder's existing 10 Hz metering rate. In streaming-off mode the display is 380 × 126. The KITT-inspired voice modulator has three centered columns of 20 red LED segments. The center column follows the present microphone level, and the flanks use short averages of real readings. Lights expand above and below the center with speech. A single 340 × 51 point canvas updates only from the existing 10 Hz audio meter, with no animation timeline, particles, or blur passes. Silence leaves only faint unlit segments. These are visual level envelopes, not frequency bands. The display stays geometrically centered as its size changes.

The final text displays for `clamp(0.65 + words × 0.045, 0.85, 6)` seconds, with a single completion glow/check animation. Its text area is bounded for long transcripts. Starting another recording or dismissing the display cancels its previous dismissal task. No auto-paste or required confirmation key is introduced.

## Validation on this Mac

The 210.11 voice display was measured in an isolated optimized SwiftUI preview with changing 10 Hz meter fixtures: 0.15284 CPU seconds over eight active seconds (1.91% of one CPU core), and 0.00405 CPU seconds over four idle seconds (0.10% of one core). This measures the preview process, not the separate WindowServer/GPU or transcription workload. No microphone or model was used for this graphics check.

On two local dictation recordings of about eight seconds each, the former streaming approximation produced badly incorrect text; normal rolling-window decoding recovered the spoken sentences. Median preview computation was 0.128 and 0.099 seconds respectively, with a maximum of 0.276 seconds. These figures exclude capture/buffering time and are not a general accuracy benchmark. The recordings and their transcripts are not included in the repository.

A 45.41-second repeated acceptance fixture produced 57 rolling updates: median computation 0.488 seconds, maximum 0.583 seconds, below the 0.8-second packet interval in that run. Final text matched exactly before and after preview, with the same cached model and attention identities. Warm final inference took 1.786 seconds before preview and 1.923/1.571 seconds afterward; peak MLX allocation was 2.93 GB. Timing varies with speech and competing workloads.

An opt-in Swift integration test sends partial audio through the actual coordinator and JSON-RPC process, observes words before supplying the complete recording, and verifies that packet-by-packet preview of a short fixture converges exactly to normal full-attention transcription. It also verifies identical final text and the same daemon PID. Other tests cover streaming off, cancellation, old-session isolation, preview failure fallback, settings persistence, and continuous conversion from mono/stereo 44.1/48 kHz audio. Offscreen renders cover listening, finalizing, final copy, and streaming off.

The user confirmed that live dictation works correctly after the 210.9 decoder correction.
