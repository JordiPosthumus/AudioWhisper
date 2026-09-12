import CoreGraphics

/// Centralized layout metrics to avoid scattered magic numbers.
internal enum LayoutMetrics {
    enum RecordingWindow {
        static let size = CGSize(width: TranscriptPresentation.width, height: TranscriptPresentation.compactHeight)
        static let cornerRadius: CGFloat = 25
    }
    
    enum DashboardWindow {
        static let initialSize = CGSize(width: 620, height: 520)
        static let minimumSize = CGSize(width: 540, height: 420)
        static let previewSize = CGSize(width: 620, height: 520)
    }
    
    enum TranscriptionHistory {
        static let minimumSize = CGSize(width: 500, height: 340)
        static let previewSize = CGSize(width: 600, height: 480)
    }
    
}
