import Foundation

/// Drains both pipes concurrently so a verbose child cannot block on a full pipe.
internal enum ProcessOutput {
    private final class CapturedStream: @unchecked Sendable {
        let handle: FileHandle
        // Written by one reader, accessed only after the dispatch group completes.
        var data = Data()

        init(_ handle: FileHandle) { self.handle = handle }

        func read() {
            data = handle.readDataToEndOfFile()
            try? handle.close()
        }
    }

    static func run(
        _ command: String,
        _ arguments: [String],
        directory: URL? = nil
    ) -> (String, String, Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
        } catch {
            return ("", String(describing: error), 1)
        }

        let output = CapturedStream(stdout.fileHandleForReading)
        let errors = CapturedStream(stderr.fileHandleForReading)
        let readers = DispatchGroup()
        for stream in [output, errors] {
            DispatchQueue.global(qos: .utility).async(group: readers) { stream.read() }
        }
        process.waitUntilExit()
        readers.wait()
        return (
            String(decoding: output.data, as: UTF8.self),
            String(decoding: errors.data, as: UTF8.self),
            process.terminationStatus
        )
    }
}
