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

    var body: some View {
        NavigationSplitView {
            List(DashboardNavItem.allCases, selection: $selectionModel.selectedNav) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .listStyle(.sidebar)
            // Remove the built-in sidebar toggle to keep the titlebar clean.
            .toolbar(removing: .sidebarToggle)
        } detail: {
            if let selectedNav = selectionModel.selectedNav {
                detailView(for: selectedNav)
                    .navigationTitle(selectedNav.rawValue)
            } else {
                Text("Select a section in the sidebar")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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
