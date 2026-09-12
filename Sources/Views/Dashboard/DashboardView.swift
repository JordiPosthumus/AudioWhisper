import SwiftUI
import AppKit

// MARK: - Navigation Item
internal enum DashboardNavItem: String, CaseIterable, Identifiable, Hashable {
    case transcripts = "Transcripts"
    case recording = "Recording"
    case preferences = "Preferences"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .transcripts: return "doc.text"
        case .recording: return "waveform"
        case .preferences: return "slider.horizontal.3"
        }
    }
}

// MARK: - Main Dashboard View
internal struct DashboardView: View {
    @ObservedObject var selectionModel: DashboardSelectionModel

    init(selectionModel: DashboardSelectionModel = DashboardSelectionModel()) {
        self.selectionModel = selectionModel
    }

    private var selection: Binding<DashboardNavItem> {
        Binding(
            get: { selectionModel.selectedNav ?? .recording },
            set: { selectionModel.selectedNav = $0 }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: selection) {
                ForEach(DashboardNavItem.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 400)
            .padding(16)

            Divider()
            detailView(for: selection.wrappedValue)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func detailView(for item: DashboardNavItem) -> some View {
        switch item {
        case .transcripts:
            DashboardTranscriptsView()
        case .recording:
            DashboardRecordingView()
        case .preferences:
            DashboardPreferencesView()
        }
    }
}

// MARK: - Preview
#Preview("Dashboard") {
    DashboardView()
        .frame(width: LayoutMetrics.DashboardWindow.previewSize.width,
               height: LayoutMetrics.DashboardWindow.previewSize.height)
}
