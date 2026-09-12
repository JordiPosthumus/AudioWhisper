import Foundation
import AVFoundation

// Standalone benchmark: compile with AudioProcessor.swift, with or without -DSTREAMING_PCM.
// Generation uses a fixed-size buffer and is measured separately from conversion.
let args = CommandLine.arguments
if args.count == 3 && args[1] == "--generate" {
    let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false)!
    let file = try AVAudioFile(forWriting: URL(fileURLWithPath: args[2]), settings: format.settings)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
    var remaining = 48_000 * 60 * 30
    var position = 0
    while remaining > 0 {
        let count = min(4096, remaining)
        buffer.frameLength = AVAudioFrameCount(count)
        for index in 0..<count {
            buffer.floatChannelData![0][index] = Float(sin(Double(position + index) * 2 * .pi * 440 / 48_000)) * 0.5
        }
        try file.write(from: buffer)
        position += count
        remaining -= count
    }
} else if args.count == 3 {
    let start = ContinuousClock.now
    let input = URL(fileURLWithPath: args[1])
    let output = URL(fileURLWithPath: args[2])
#if STREAMING_PCM
    try writeAudioPCM(url: input, to: output, samplingRate: 16_000)
#else
    let samples = try loadAudio(url: input, samplingRate: 16_000)
    let data = samples.withUnsafeBytes { Data($0) }
    try data.write(to: output)
#endif
    print("Conversion: \(start.duration(to: .now))")
} else {
    fatalError("Usage: benchmark --generate input.caf | benchmark input.caf output.raw")
}
