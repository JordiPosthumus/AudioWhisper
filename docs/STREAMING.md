# Live draft plus unchanged final transcription

The preview uses the installed Parakeet v2 model and parakeet-mlx 0.3.7 streaming API. No Python dependency, model, decoder setting, microphone-volume setting, or runtime manifest was upgraded or replaced. The existing runtime proved sufficient; a newer version is not required for this feature.

## Data flow

An optional AVAudioEngine microphone tap runs alongside the established AVAudioRecorder AAC capture. Only the preview is converted incrementally to mono Float32 at 16 kHz, on a serial worker queue. The existing recording format and full-audio conversion/final inference remain unchanged.

Preview packets contain 0.8 seconds of audio. The coordinator allows one request in flight, combines queued audio without dropping samples, and reports an unavailable preview if its queue exceeds eight seconds. This bound affects only provisional display; the complete AAC recording continues independently. The UI keeps final transcription available after preview errors or input-device changes.

The same JSON-RPC daemon and cached model serve both paths. Streaming uses separate shallow module wrappers with local attention, a 128-frame left cache, eight-frame provisional right context, and depth 1. All 697 trained parameter arrays share their original identities with the cached model; no second weight allocation or model reload is needed. These are preview-only settings. The final model's established attention objects and positional encoding are never replaced. Local preview attention keeps positional work bounded during long recordings. The eight-frame provisional region is shorter than an input packet; a longer region caused unstable early drafts in the installed library. We release the preview object directly rather than invoking the library context-manager exit, which would unnecessarily clear the shared MLX allocator cache. The full-audio request also clears any remaining preview state before running its unchanged transcription function.

Each recording has a session UUID and ordered packet sequence. Late packets and cleanup messages cannot enter or cancel a new session. Preview text never writes to the clipboard or history. Only the completed final pass does that.

## Presentation

A 380 × 180 point live display shows the last two lines of draft text and a waveform built from 48 actual microphone-level readings at the recorder's existing 10 Hz metering rate. In streaming-off mode the display is 380 × 112. No synthetic waveform activity is generated during silence. The display stays geometrically centered as its size changes.

The final text displays for `clamp(0.65 + words × 0.045, 0.85, 6)` seconds, with a single completion glow/check animation. Its text area is bounded for long transcripts. Starting another recording or dismissing the display cancels its previous dismissal task. No auto-paste or required confirmation key is introduced.

## Validation on this Mac

A 45.41-second fixture (the existing acceptance recording repeated with short silences) produced 57 draft updates. In a run without simultaneous compilation, median draft computation was 0.129 seconds, maximum 0.172 seconds, for 0.8-second input packets. This excludes capture/buffering time and is not a general accuracy benchmark. Draft words are provisional and can repeat or change; the independent final pass corrects them.

The final text matched exactly across cold, warm, and post-stream full passes. Cold final inference took 2.534 seconds, warm 1.014 seconds, and the two post-stream finals 1.084/0.949 seconds. The same loaded model and attention object identities were retained. Peak MLX allocation in that process was 2.93 GB. These measurements include one synthetic repetition fixture; real speech and competing workloads may differ.

An opt-in Swift integration test also sent partial audio through the actual coordinator and JSON-RPC process, observed words before supplying the complete recording, and verified identical final text and the same daemon PID. Other tests cover streaming off, cancellation, old-session isolation, preview failure fallback, settings persistence, and continuous conversion from mono/stereo 44.1/48 kHz audio. Offscreen renders cover listening, finalizing, final copy, and streaming off.

Physical microphone capture alongside the existing recorder requires a live-use check on the installed app; the automated capture tests use supplied audio buffers and do not request microphone access.
