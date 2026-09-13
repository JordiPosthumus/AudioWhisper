import Foundation

/// Centralized defaults so "fresh install" behavior is deterministic and consistent across the app.
///
/// Notes:
/// - We use `register(defaults:)` (registration domain) rather than eagerly writing values, so we don't
///   accidentally clobber user preferences or treat a first-run as "already configured".
/// - AppStorage initial values across the app should match these constants.
internal enum AppDefaults {
    internal enum Keys {
        static let transcriptionProvider = "transcriptionProvider"
        static let selectedParakeetModel = "selectedParakeetModel"


        static let startAtLogin = "startAtLogin"
        static let playCompletionSound = "playCompletionSound"
        static let transcriptionHistoryEnabled = "transcriptionHistoryEnabled"
        static let transcriptionRetentionPeriod = "transcriptionRetentionPeriod"
        static let enableSmartPaste = "enableSmartPaste"
        static let immediateRecording = "immediateRecording"
        static let transcriptionStreaming = "transcriptionStreaming"
        static let addTrailingSpace = "addTrailingSpace"
        static let globalHotkey = "globalHotkey"

        static let pressAndHoldEnabled = "pressAndHoldEnabled"
        static let pressAndHoldKeyIdentifier = "pressAndHoldKeyIdentifier"
        static let pressAndHoldMode = "pressAndHoldMode"

    }

    // Chosen defaults.
    internal static let defaultTranscriptionProvider: TranscriptionProvider = .parakeet
    internal static let defaultParakeetModel: ParakeetModel = .v2English

    internal static func streamingEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: Keys.transcriptionStreaming) as? Bool ?? true
    }

    internal static func register() {
        UserDefaults.standard.register(defaults: [
            Keys.transcriptionProvider: defaultTranscriptionProvider.rawValue,
            Keys.selectedParakeetModel: defaultParakeetModel.rawValue,


            Keys.startAtLogin: false,
            Keys.playCompletionSound: true,
            Keys.transcriptionHistoryEnabled: false,
            Keys.transcriptionRetentionPeriod: RetentionPeriod.oneMonth.rawValue,
            Keys.enableSmartPaste: false,
            Keys.immediateRecording: false,
            Keys.transcriptionStreaming: true,
            Keys.addTrailingSpace: true,
            Keys.globalHotkey: "⌘⇧Space",

            Keys.pressAndHoldEnabled: PressAndHoldConfiguration.defaults.enabled,
            Keys.pressAndHoldKeyIdentifier: PressAndHoldConfiguration.defaults.key.rawValue,
            Keys.pressAndHoldMode: PressAndHoldConfiguration.defaults.mode.rawValue

        ])
    }
}
