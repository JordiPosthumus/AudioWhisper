import Foundation
import os.log
import AudioToolbox

internal enum ParakeetError: Error, LocalizedError, Equatable {
    case pythonNotFound(path: String)
    case scriptNotFound
    case transcriptionFailed(String)
    case invalidResponse(String)
    case dependencyMissing(String, installCommand: String)
    case processTimedOut(TimeInterval)
    case modelNotReady
    
    var errorDescription: String? {
        switch self {
        case .pythonNotFound(let path):
            return "Python runtime not available at: \(path)\n\nFix:\n• Open the existing local Python runtime"
        case .scriptNotFound:
            return "Parakeet transcription script not found in app bundle"
        case .transcriptionFailed(let message):
            return "Parakeet transcription failed: \(message)"
        case .invalidResponse(let message):
            return "Invalid response from Parakeet: \(message)"
        case .dependencyMissing(let dependency, _):
            return "\(dependency) is not installed\n\nFix: Open the existing local Python runtime"
        case .processTimedOut(let timeout):
            return "Transcription timed out after \(timeout) seconds\n\nTry with a shorter audio file or check system resources"
        case .modelNotReady:
            return "Parakeet v2 is not available in the local model cache. Restore the existing model installation before transcribing."
        }
    }
}

internal struct ParakeetResponse: Codable {
    let text: String
    let success: Bool
    let error: String?
}

internal class ParakeetService {
    private let logger = Logger(subsystem: "com.audiowhisper.app", category: "ParakeetService")
    private let daemon = MLDaemonManager.shared
    private let cacheRoot: URL

    init(cacheRoot: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cache/huggingface/hub")) {
        self.cacheRoot = cacheRoot
    }

    func transcribe(audioFileURL: URL, pythonPath _: String? = nil) async throws -> String {
        // Step 0: Do not download here; just verify model cache exists
        guard isModelCached() else {
            throw ParakeetError.modelNotReady
        }

        // Step 1: Process audio with Swift AudioProcessor to create raw PCM data
        let pcmDataURL = try await processAudioToRawPCM(audioFileURL: audioFileURL)
        defer {
            // Clean up the temporary PCM file
            try? FileManager.default.removeItem(at: pcmDataURL)
        }
        
        // Step 2: Call Python with the raw PCM data instead of original audio
        return try await transcribeWithRawPCM(pcmDataURL: pcmDataURL)
    }

    private var selectedRepo: String {
        ParakeetModel.v2English.rawValue
    }

    private func isModelCached() -> Bool {
        let repo = selectedRepo
        let escaped = repo.replacingOccurrences(of: "/", with: "--")
        let base = cacheRoot.appendingPathComponent("models--\(escaped)")
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: base.path, isDirectory: &isDir), isDir.boolValue else { return false }
        let refsMain = base.appendingPathComponent("refs/main")
        guard let rev = try? String(contentsOf: refsMain, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines), !rev.isEmpty else {
            return false
        }
        let snap = base.appendingPathComponent("snapshots/\(rev)")
        guard FileManager.default.fileExists(atPath: snap.path, isDirectory: &isDir), isDir.boolValue else { return false }
        // Look for at least one weights file under snapshot or blobs
        let snapFiles = (try? FileManager.default.contentsOfDirectory(atPath: snap.path)) ?? []
        let blobsFiles = (try? FileManager.default.contentsOfDirectory(atPath: base.appendingPathComponent("blobs").path)) ?? []
        let hasWeights = snapFiles.contains { $0.hasSuffix(".safetensors") } || blobsFiles.contains { $0.hasSuffix(".safetensors") }
        return hasWeights
    }
    
    internal func processAudioToRawPCM(audioFileURL: URL) async throws -> URL {
        // Create temporary file for raw PCM data
        let tempPCMURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio_pcm_\(UUID().uuidString).raw")
        
        do {
            try writeAudioPCM(url: audioFileURL, to: tempPCMURL, samplingRate: 16000)

            return tempPCMURL
            
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw ParakeetError.transcriptionFailed("Audio processing failed: \(error.localizedDescription)")
        }
    }
    
    private func transcribeWithRawPCM(pcmDataURL: URL) async throws -> String {
        do {
            let text = try await daemon.transcribe(repo: selectedRepo, pcmPath: pcmDataURL.path)
            logger.info("Parakeet transcription successful")
            return text
        } catch {
            logger.error("Parakeet transcription error: \(error.localizedDescription)")
            throw error
        }
    }
    
    func validateSetup(pythonPath _: String? = nil) async throws {
        guard isModelCached() else {
            throw ParakeetError.modelNotReady
        }

        do {
            try await daemon.warmup(type: "parakeet", repo: selectedRepo)
        } catch {
            logger.error("Parakeet warmup failed: \(error.localizedDescription)")
            throw ParakeetError.transcriptionFailed("Parakeet daemon unavailable: \(error.localizedDescription)")
        }
    }
}
