import Foundation
import AudioToolbox

internal enum AudioLoadError: Error {
    case openFailed(OSStatus)
    case getPropertyFailed(OSStatus)
    case setPropertyFailed(OSStatus)
    case readFailed(OSStatus)
    case unsupportedFormat
    case unknown(OSStatus)
}

internal func loadAudio(url: URL, samplingRate: Int) throws -> [Float] {
    var samples: [Float] = []
    try readAudioChunks(url: url, samplingRate: samplingRate) { chunk in
        samples.append(contentsOf: chunk)
    }
    return samples
}

/// Writes the same mono Float32 samples as loadAudio without retaining the entire recording.
internal func writeAudioPCM(url: URL, to destination: URL, samplingRate: Int) throws {
    guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
        throw CocoaError(.fileWriteUnknown)
    }
    do {
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }
        try readAudioChunks(url: url, samplingRate: samplingRate) { chunk in
            try output.write(contentsOf: Data(buffer: chunk))
        }
    } catch {
        try? FileManager.default.removeItem(at: destination)
        throw error
    }
}

/// The borrowed buffer is valid only for the duration of consume.
private func readAudioChunks(
    url: URL,
    samplingRate: Int,
    consume: (UnsafeBufferPointer<Float>) throws -> Void
) throws {
    guard samplingRate > 0 else { throw AudioLoadError.unsupportedFormat }
    var extAudioFile: ExtAudioFileRef?
    
    // Open the audio file
    var status = ExtAudioFileOpenURL(url as CFURL, &extAudioFile)
    guard status == noErr, let extFile = extAudioFile else {
        throw AudioLoadError.openFailed(status)
    }
    defer { ExtAudioFileDispose(extFile) }
    
    var propertySize: UInt32

    // Define client format: mono, float32, target sample rate, interleaved/packed
    var clientFormat = AudioStreamBasicDescription(
        mSampleRate: Float64(samplingRate),
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
        mBytesPerPacket: 4,
        mFramesPerPacket: 1,
        mBytesPerFrame: 4,
        mChannelsPerFrame: 1,
        mBitsPerChannel: 32,
        mReserved: 0
    )
    
    propertySize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    status = ExtAudioFileSetProperty(extFile, kExtAudioFileProperty_ClientDataFormat, propertySize, &clientFormat)
    guard status == noErr else {
        throw AudioLoadError.setPropertyFailed(status)
    }
    
    // Keep memory bounded independently of the recording's duration.
    let bufferFrameSize = 65_536
    var buffer = [Float](repeating: 0, count: bufferFrameSize)
    try buffer.withUnsafeMutableBufferPointer { samples in
        while true {
            try Task.checkCancellation()
            var numFrames = UInt32(bufferFrameSize)
            var audioBufferList = AudioBufferList(
                mNumberBuffers: 1,
                mBuffers: AudioBuffer(
                    mNumberChannels: 1,
                    mDataByteSize: UInt32(bufferFrameSize * MemoryLayout<Float>.size),
                    mData: samples.baseAddress
                )
            )
            // Keep the pointer within its borrowing scope during the native read.
            status = ExtAudioFileRead(extFile, &numFrames, &audioBufferList)
            guard status == noErr else { throw AudioLoadError.readFailed(status) }
            guard numFrames > 0 else { break }
            try consume(UnsafeBufferPointer(start: samples.baseAddress, count: Int(numFrames)))
        }
    }
}
