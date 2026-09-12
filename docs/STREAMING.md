# Live draft plus unchanged final transcription

The preview uses the installed Parakeet v2 model with its normal full-attention decoder. No Python dependency, model, decoder setting, microphone-volume setting, or runtime manifest is upgraded or replaced.

## Data flow

An optional AVAudioEngine microphone tap runs alongside the established AVAudioRecorder AAC capture. Only the preview is converted incrementally to mono Float32 at 16 kHz, on a serial worker queue. The existing recording format and full-audio conversion/final inference remain unchanged.

Preview packets contain 0.8 seconds of audio. The coordinator allows one request in flight, combines queued audio without dropping samples, and reports an unavailable preview if its queue exceeds eight seconds. This bound affects only provisional display; the complete AAC recording continues independently. The UI keeps final transcription available after preview errors or input-device changes.

The same JSON-RPC daemon and cached model serve both paths. Each update decodes the most recent eight seconds of preview audio using the same log-mel conversion and normal model generation as the final pass. This is a rolling live preview, not the library's cached streaming approximation. No model weights, attention objects, positional encoding, or allocator cache are replaced or cleared. The window bounds preview inference work during long recordings; it does not limit the complete recording or final transcript. Time-aligned token runs join overlapping windows so earlier live words remain in memory while newer words can be revised. Timestamps disambiguate repeated phrases. This adds text continuity without another inference pass or an acoustic context change.

The earlier 210.8 streaming approximation produced severe recognition errors on ordinary dictation. Re-decoding a rolling window lets new context correct partial words without carrying an erroneous streaming decoder state into the next update. All live words are provisional. The beginning of a rolling window can cut through a word, and the newest word may still be incomplete. Only the independent final pass produces the complete transcript.

Each recording has a session UUID and ordered packet sequence. Late packets and cleanup messages cannot enter or cancel a new session. Preview text never writes to the clipboard or history. Only the completed final pass does that. The full-audio request releases preview PCM before running its unchanged transcription function.

## Presentation

A tall KITT-style voice display sits to the left of the transcript. Three narrow red LED columns and decorative status lamps use the reference dashboard arrangement. The surrounding lamps show local processing, timer, word count, and recording/live/final/copied state; none are controls. The voice display uses the existing 10 Hz meter and has no independent animation clock, particles, or blur passes.

The panel begins at 640 × 300 points and expands to fit its text, widening before becoming excessively tall. Its limit is 1000 × 840 points or the current visible screen area minus margins, whichever is smaller. Normal transcripts fit without a scroll view or a two-line limit. At the limit, the app explicitly labels its excerpt: latest words during recording, beginning of the complete text after copying. The clipboard/history content is never truncated. Font measurement is cached between transcript changes so meter updates do not repeatedly measure the whole text.

The final text displays for `clamp(0.65 + words × 0.045, 0.85, 6)` seconds, with a single completion glow/check animation. Starting another recording or dismissing the display cancels the previous dismissal task.

The existing passive keyboard listener recognizes ⌘V and paste-and-match-style modifier variants, without consuming the key event. It dismisses only the matching copied transcript, ignores ordinary typing and in-progress recordings, and handles a paste arriving while history is still saving. Each notification carries the clipboard change count to prevent a late event dismissing a newer transcript. This detects the shortcut, not confirmation from the destination app that insertion succeeded. macOS delivers global keyboard events only when [Accessibility access permits it](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/EventOverview/MonitoringEvents/MonitoringEvents.html). No new permission prompt, synthetic paste event, clipboard-read polling, or menu-paste detection is introduced. Timed dismissal remains the fallback.

## Validation on this Mac

The full 210.12 panel, with a long transcript and changing 10 Hz meter fixtures, used 0.3191 CPU seconds over eight active seconds (3.99% of one CPU core) in an isolated optimized SwiftUI preview. The idle phase used 0.0053 CPU seconds over four seconds (0.13% of one core). This measures the preview process, excluding WindowServer/GPU and transcription work. No microphone or model was accessed during the graphics check.

On two local dictation recordings of about eight seconds each, the former streaming approximation produced badly incorrect text; normal rolling-window decoding recovered the spoken sentences. Median preview computation was 0.128 and 0.099 seconds respectively, with a maximum of 0.276 seconds. These figures exclude capture/buffering time and are not a general accuracy benchmark. The recordings and their transcripts are not included in the repository.

A 45.41-second repeated acceptance fixture produced 57 rolling updates: median computation 0.488 seconds, maximum 0.583 seconds, below the 0.8-second packet interval in that run. Final text matched exactly before and after preview, with the same cached model and attention identities. Warm final inference took 1.786 seconds before preview and 1.923/1.571 seconds afterward; peak MLX allocation was 2.93 GB. Timing varies with speech and competing workloads.

An opt-in Swift integration test sends partial audio through the actual coordinator and JSON-RPC process, observes words before supplying the complete recording, and verifies that packet-by-packet preview of a short fixture converges exactly to normal full-attention transcription. It also verifies identical final text and the same daemon PID. Other tests cover streaming off, cancellation, old-session isolation, preview failure fallback, settings persistence, and continuous conversion from mono/stereo 44.1/48 kHz audio. Offscreen renders cover listening, finalizing, final copy, and streaming off.

The user confirmed that live dictation works correctly after the 210.9 decoder correction.

For 210.12, a 45.41-second repeated fixture retained all earlier live words and matched the final words after case/punctuation normalization. A separate 20.57-second local dictation produced 53 preview words matching all 53 final words after the same normalization; median update computation was 0.104 seconds, maximum 0.120 seconds. Preview PCM stayed at 512,000 bytes (eight seconds of mono Float32); final output was identical before and after preview. The private recording/transcripts are not committed.

Regression coverage includes accumulated text across overlapping windows, repeated-phrase alignment, early draft correction, silence, full short-draft convergence, full visibility for a 220-word transcript, screen-bounded overflow with explicit labelling, and native paste-key pass-through. Offscreen renders include long live text and long final text on a smaller screen. Physical cross-app paste dismissal requires the user's live check and macOS keyboard-event access.
