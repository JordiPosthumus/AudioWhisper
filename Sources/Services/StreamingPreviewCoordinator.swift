import Foundation
import Combine
import os.log

@MainActor
internal final class StreamingPreviewCoordinator: ObservableObject {
    @Published private(set) var stableText = ""
    @Published private(set) var draftText = ""
    @Published private(set) var isPreparing = false
    @Published private(set) var isEnabledForSession = false
    @Published private(set) var problem: String?

    private let capture: any PreviewAudioCapturing
    private let daemon: MLDaemonManager
    private let allowsCapture: Bool
    private var sessionID: UUID?
    private var worker: Task<Void, Never>?
    private var pendingPCM = Data()

    init(capture: (any PreviewAudioCapturing)? = nil, daemon: MLDaemonManager = .shared, allowsCapture: Bool = !AppEnvironment.isRunningTests) {
        self.capture = capture ?? LivePreviewAudioCapture()
        self.daemon = daemon
        self.allowsCapture = allowsCapture
    }

    func start(enabled: Bool) {
        stop()
        stableText = ""
        draftText = ""
        problem = nil
        isEnabledForSession = enabled
        guard enabled, allowsCapture else { return }
        let id = UUID()
        sessionID = id
        isPreparing = true
        do {
            try capture.start(onPCM: { [weak self] data in
                Task { @MainActor in self?.receive(data, sessionID: id) }
            }, onFailure: { [weak self] in
                Task { @MainActor in self?.fail(sessionID: id, reason: "Audio preview unavailable") }
            })
        } catch {
            fail(sessionID: id, reason: "Audio preview unavailable")
            return
        }
        worker = Task { [weak self, daemon] in
            do {
                try await daemon.startPreview(sessionID: id)
                try Task.checkCancellation()
                guard let self, self.sessionID == id else { return }
                self.isPreparing = false
                var sequence = 0
                while !Task.isCancelled, self.sessionID == id {
                    guard !self.pendingPCM.isEmpty else {
                        try await Task.sleep(for: .milliseconds(50))
                        continue
                    }
                    // One request in flight. Combine queued chunks without dropping samples.
                    let size = min(self.pendingPCM.count, 16_000 * 4 * 4)
                    let pcm = Data(self.pendingPCM.prefix(size))
                    self.pendingPCM.removeFirst(size)
                    let result = try await daemon.appendPreview(sessionID: id, sequence: sequence, pcm: pcm)
                    try Task.checkCancellation()
                    guard self.sessionID == id else { return }
                    guard result.active else { throw MLDaemonError.remoteError("Preview session ended") }
                    sequence += 1
                    self.stableText = result.stable
                    self.draftText = result.draft
                }
            } catch is CancellationError {
                // Final transcription or the next recording now owns presentation.
            } catch {
                Logger(subsystem: "com.audiowhisper.app", category: "StreamingPreview")
                    .error("Live preview failed: \(error.localizedDescription)")
                self?.fail(sessionID: id, reason: "Live preview unavailable")
            }
            await daemon.endPreview(sessionID: id)
        }
    }

    func stop() {
        capture.stop()
        let id = sessionID
        sessionID = nil
        worker?.cancel()
        worker = nil
        pendingPCM.removeAll(keepingCapacity: false)
        isPreparing = false
        if let id { Task { [daemon] in await daemon.endPreview(sessionID: id) } }
    }

    private func receive(_ data: Data, sessionID id: UUID) {
        guard sessionID == id else { return }
        // Preview lag must not create an unbounded queue or delay the complete final recording.
        guard pendingPCM.count + data.count <= 16_000 * 4 * 8 else {
            fail(sessionID: id, reason: "Preview is catching up—final text will still be copied")
            return
        }
        pendingPCM.append(data)
    }

    private func fail(sessionID id: UUID, reason: String) {
        guard sessionID == id else { return }
        stop()
        problem = reason
    }
}
