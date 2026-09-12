import Foundation

internal enum TranscriptionProvider: String, CaseIterable, Codable, Sendable {
    // Legacy values remain readable in existing history; new recordings use Parakeet only.
    case openai = "openai"
    case gemini = "gemini" 
    case local = "local"
    case parakeet = "parakeet"
    
    var displayName: String {
        switch self {
        case .openai:
            return "OpenAI Whisper (Cloud)"
        case .gemini:
            return "Google Gemini (Cloud)"
        case .local:
            return "Whisper (Local)"
        case .parakeet:
            return "Parakeet"
        }
    }
}

internal enum ParakeetModel: String, Codable, Sendable {
    case v2English = "mlx-community/parakeet-tdt-0.6b-v2"

    var displayName: String { "Parakeet v2" }
    var repoId: String { rawValue }
}
