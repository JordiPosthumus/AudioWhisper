import AppKit
import SwiftUI

internal struct LocalSetupView: View {
    @ObservedObject var setup: LocalSetupManager
    var onContinue: () -> Void
    var onResize: @MainActor (CGSize) -> Void = { _ in }

    private let cyan = Color(red: 0.25, green: 0.83, blue: 0.91)

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: setup.isReady ? "checkmark.circle.fill" : "waveform")
                    .font(.system(size: 34, weight: .medium)).foregroundStyle(cyan)
                VStack(alignment: .leading, spacing: 5) {
                    Text("ScribeKitt").font(.system(size: 29, weight: .bold))
                    Text("YOUR VOICE. YOUR MAC. YOUR WORDS.")
                        .font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary)
                }
            }

            Text(setup.isReady ? "You’re ready to dictate." : "A little setup. Then it’s all local.")
                .font(.system(size: 23, weight: .semibold))

            Text(setup.isReady
                 ? "Use the microphone menu or your recording shortcut. Speak, stop, then paste with ⌘V. Microphone access is requested when you first record."
                 : "ScribeKitt downloads its speech model and runtime once. Allow 6 GB of free space and internet access for setup. English dictation runs on your Mac afterward.")
                .font(.system(size: 14)).foregroundStyle(.secondary)
                .lineSpacing(4).fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 17) {
                ForEach(LocalSetupManager.Stage.allCases, id: \.rawValue) { stage in
                    HStack(spacing: 13) {
                        stageIcon(stage).frame(width: 22, height: 22)
                        Text(stage.title).font(.system(size: 14, weight: .medium))
                        Spacer()
                    }
                }
            }
            .padding(20)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 16))

            if case .failed(let message) = setup.state {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Setup couldn’t finish. You can try again.").foregroundStyle(.orange)
                    DisclosureGroup("Details") {
                        ScrollView { Text(message).font(.system(size: 11)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                            .frame(maxHeight: 80)
                    }.font(.system(size: 12))
                }
            } else if setup.state == .unsupported {
                Text("ScribeKitt requires an Apple Silicon Mac (M1 or newer).")
                    .font(.system(size: 14)).foregroundStyle(.orange)
            }

            HStack {
                Image(systemName: "lock.shield").foregroundStyle(cyan)
                Text(setup.isPreparing ? "Setup may take a few minutes." : "Your recordings are never uploaded.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
            }

            Button {
                if setup.isReady { onContinue() }
                else { Task { await setup.prepare() } }
            } label: {
                Text(buttonTitle).font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(cyan.opacity(setup.isPreparing ? 0.35 : 1), in: RoundedRectangle(cornerRadius: 11))
            }
            .buttonStyle(.plain).foregroundStyle(.black)
            .disabled(setup.isPreparing || setup.state == .unsupported)
            .keyboardShortcut(.defaultAction)
        }
        .padding(32).frame(width: 520)
        .background(Color(red: 0.035, green: 0.055, blue: 0.085))
        .preferredColorScheme(.dark)
        .fixedSize(horizontal: false, vertical: true)
        .background(GeometryReader { geometry in Color.clear.preference(key: SetupSizePreference.self, value: geometry.size) })
        .onPreferenceChange(SetupSizePreference.self) { size in Task { @MainActor in onResize(size) } }
    }

    private var buttonTitle: String {
        if setup.isReady { return "Start dictating" }
        if setup.isPreparing { return "Preparing ScribeKitt…" }
        if case .failed = setup.state { return "Try again" }
        return "Prepare ScribeKitt"
    }

    @ViewBuilder private func stageIcon(_ stage: LocalSetupManager.Stage) -> some View {
        if setup.isReady || completed(stage) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(cyan)
        } else if setup.state == .preparing(stage) {
            ProgressView().controlSize(.small)
        } else {
            Text("\(stage.rawValue + 1)").font(.system(size: 11, weight: .bold))
                .frame(width: 21, height: 21).background(.white.opacity(0.08), in: Circle()).foregroundStyle(.secondary)
        }
    }

    private func completed(_ stage: LocalSetupManager.Stage) -> Bool {
        if case .preparing(let current) = setup.state { return stage.rawValue < current.rawValue }
        return false
    }
}

private struct SetupSizePreference: PreferenceKey {
    static let defaultValue = CGSize.zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

@MainActor
internal final class LocalSetupWindowController {
    static let shared = LocalSetupWindowController()
    private var window: NSWindow?
    private var completion: (() -> Void)?

    func show(onContinue: @escaping () -> Void) {
        completion = onContinue
        if window == nil {
            let host = NSHostingView(rootView: LocalSetupView(setup: .shared, onContinue: { [weak self] in
                self?.window?.close()
                self?.completion?()
            }, onResize: { [weak self] size in
                guard size.width > 0, size.height > 0 else { return }
                self?.window?.setContentSize(size)
            }))
            let panel = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 520, height: 580),
                                 styleMask: [.titled, .closable], backing: .buffered, defer: false)
            panel.title = "Welcome to ScribeKitt"
            panel.contentView = host
            panel.setContentSize(host.fittingSize)
            panel.isReleasedWhenClosed = false
            panel.center()
            window = panel
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
