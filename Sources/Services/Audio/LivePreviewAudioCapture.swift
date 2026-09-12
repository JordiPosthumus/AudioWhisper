import AVFoundation
import Foundation

@MainActor
internal protocol PreviewAudioCapturing: AnyObject {
    func start(onPCM: @escaping @Sendable (Data) -> Void, onFailure: @escaping @Sendable () -> Void) throws
    func stop()
}

/// An optional preview tap. The existing AAC recorder remains the final-pass source.
@MainActor
internal final class LivePreviewAudioCapture: PreviewAudioCapturing {
    private var engine: AVAudioEngine?
    private var processor: PreviewAudioProcessor?
    private var configurationObserver: NSObjectProtocol?

    func start(onPCM: @escaping @Sendable (Data) -> Void, onFailure: @escaping @Sendable () -> Void) throws {
        stop()
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw AudioLoadError.unsupportedFormat }
        let processor = try PreviewAudioProcessor(format: format, onPCM: onPCM, onFailure: onFailure)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            processor.receive(buffer)
        }
        do {
            engine.prepare()
            try engine.start()
            self.engine = engine
            self.processor = processor
            configurationObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { _ in
                onFailure()
            }
        } catch {
            input.removeTap(onBus: 0)
            processor.invalidate()
            throw error
        }
    }

    func stop() {
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }
        configurationObserver = nil
        processor?.invalidate()
        if let engine {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        engine = nil
        processor = nil
    }
}

/// Conversion happens on one serial queue, never on the audio callback or main thread.
private final class PreviewAudioProcessor: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.audiowhisper.preview-audio", qos: .userInitiated)
    private let lock = NSLock()
    private var valid = true
    private let converter: PreviewPCMConverter
    private var pending = Data()
    private let onPCM: @Sendable (Data) -> Void
    private let onFailure: @Sendable () -> Void
    private let chunkBytes = 12_800 * MemoryLayout<Float>.size // 0.8 seconds at 16 kHz

    init(format: AVAudioFormat, onPCM: @escaping @Sendable (Data) -> Void, onFailure: @escaping @Sendable () -> Void) throws {
        converter = try PreviewPCMConverter(inputFormat: format)
        self.onPCM = onPCM
        self.onFailure = onFailure
    }

    func invalidate() { lock.withLock { valid = false } }

    func receive(_ buffer: AVAudioPCMBuffer) {
        guard lock.withLock({ valid }),
              let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else { return }
        copy.frameLength = buffer.frameLength
        let source = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: buffer.audioBufferList))
        let target = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for index in source.indices {
            guard let from = source[index].mData, let to = target[index].mData else { return }
            memcpy(to, from, Int(source[index].mDataByteSize))
        }
        queue.async { [self] in
            guard lock.withLock({ valid }) else { return }
            do {
                pending.append(try converter.convert(copy))
                while pending.count >= chunkBytes {
                    onPCM(Data(pending.prefix(chunkBytes)))
                    pending.removeFirst(chunkBytes)
                }
            } catch {
                invalidate()
                onFailure()
            }
        }
    }
}

/// Stateful sample-rate conversion keeps continuity between native microphone buffers.
internal final class PreviewPCMConverter {
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat

    init(inputFormat: AVAudioFormat) throws {
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0,
              let output = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: inputFormat, to: output) else { throw AudioLoadError.unsupportedFormat }
        self.converter = converter
        self.outputFormat = output
    }

    func convert(_ input: AVAudioPCMBuffer) throws -> Data {
        let capacity = AVAudioFrameCount(ceil(Double(input.frameLength) * 16_000 / input.format.sampleRate)) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { throw AudioLoadError.unsupportedFormat }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            if supplied { inputStatus.pointee = .noDataNow; return nil }
            supplied = true
            inputStatus.pointee = .haveData
            return input
        }
        if let error { throw error }
        guard status != .error, let samples = output.floatChannelData?[0] else { throw AudioLoadError.unsupportedFormat }
        return Data(bytes: samples, count: Int(output.frameLength) * MemoryLayout<Float>.size)
    }
}
