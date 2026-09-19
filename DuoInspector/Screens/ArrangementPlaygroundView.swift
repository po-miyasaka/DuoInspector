import SwiftUI
import UIKit

enum ArrangementStyleChoice: String, CaseIterable, Identifiable {
    case split, splitH, splitV, overlay
    var id: String { rawValue }
    var title: String {
        switch self {
        case .split: ".split"
        case .splitH: ".split.axes(.horizontal)"
        case .splitV: ".split.axes(.vertical)"
        case .overlay: ".overlay"
        }
    }
    var short: String {
        switch self {
        case .split: "split"
        case .splitH: "split H"
        case .splitV: "split V"
        case .overlay: "overlay"
        }
    }
}

struct ArrangementPlaygroundView: View {
    @Environment(DuoState.self) private var state
    @State private var showSecondary = true
    @State private var swapped = false
    @State private var uikitInfo = ArrangementUIKitInfo()

    private var framework: Int { state.arrangementFramework }
    private var style: ArrangementStyleChoice { state.arrangementStyle }

    var body: some View {
        @Bindable var state = state
        VStack(spacing: 8) {
            VStack(spacing: 6) {
                Picker("Framework", selection: $state.arrangementFramework) {
                    Text("SwiftUI ArrangementView").tag(0)
                    Text("UIKit UIArrangementVC").tag(1)
                }
                .pickerStyle(.segmented)
                Picker("Style", selection: $state.arrangementStyle) {
                    ForEach(ArrangementStyleChoice.allCases) { s in Text(s.short).tag(s) }
                }
                .pickerStyle(.segmented)
                HStack {
                    Toggle("Secondary", isOn: $showSecondary).toggleStyle(.button)
                    Button("入替", systemImage: "arrow.left.arrow.right") { swapped.toggle() }.buttonStyle(.bordered)
                    Spacer()
                    Text(style.title).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)

            if framework == 0 {
                swiftUIArrangement
            } else {
                VStack(spacing: 4) {
                    ArrangementVCRepresentable(style: style, showSecondary: showSecondary, swapped: swapped, info: uikitInfo)
                    HStack(spacing: 12) {
                        Text("primary: \(uikitInfo.primary)")
                        Text("secondary: \(uikitInfo.secondary)")
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    Text("state(for:) → zIndex / splitAxis / isHidden").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.bottom, 8)
    }

    private var primaryPanel: some View {
        LocalGeometryPanel(name: swapped ? "Secondary(入替後)" : "Primary", color: swapped ? .purple : .blue)
    }
    private var secondaryPanel: some View {
        LocalGeometryPanel(name: swapped ? "Primary(入替後)" : "Secondary", color: swapped ? .blue : .purple)
    }

    @ViewBuilder
    private var swiftUIArrangement: some View {
        let base = ArrangementView {
            primaryPanel
        } secondary: {
            if showSecondary { secondaryPanel }
        }
        switch style {
        case .split: base.arrangementViewStyle(.split)
        case .splitH: base.arrangementViewStyle(.split.axes(.horizontal))
        case .splitV: base.arrangementViewStyle(.split.axes(.vertical))
        case .overlay: base.arrangementViewStyle(.overlay)
        }
    }
}

@Observable
final class ArrangementUIKitInfo {
    var primary = "–"
    var secondary = "–"
}

/// UIArrangementViewController を SwiftUI に埋め込み、state(for:) を観察する。
struct ArrangementVCRepresentable: UIViewControllerRepresentable {
    let style: ArrangementStyleChoice
    let showSecondary: Bool
    let swapped: Bool
    let info: ArrangementUIKitInfo

    func makeUIViewController(context: Context) -> ObservableArrangementVC {
        let vc = ObservableArrangementVC()
        vc.onLayout = { [weak vc] in
            guard let vc else { return }
            info.primary = Self.describe(vc.state(for: .primary))
            info.secondary = Self.describe(vc.state(for: .secondary))
        }
        apply(vc)
        return vc
    }

    func updateUIViewController(_ vc: ObservableArrangementVC, context: Context) {
        apply(vc)
    }

    private func apply(_ vc: ObservableArrangementVC) {
        let key = "\(style.rawValue)-\(showSecondary)-\(swapped)"
        guard vc.configKey != key else { return }
        vc.configKey = key
        let p = UIHostingController(rootView: LocalGeometryPanel(name: swapped ? "Secondary(入替後)" : "Primary", color: swapped ? .purple : .blue))
        let s = UIHostingController(rootView: LocalGeometryPanel(name: swapped ? "Primary(入替後)" : "Secondary", color: swapped ? .blue : .purple))
        p.view.backgroundColor = .clear
        s.view.backgroundColor = .clear
        vc.setViewController(p, for: .primary)
        vc.setViewController(showSecondary ? s : nil, for: .secondary)
        switch style {
        case .split: vc.updateArrangement(UISplitArrangement.split, animated: true)
        case .splitH: vc.updateArrangement(UISplitArrangement.split.axes(.horizontal), animated: true)
        case .splitV: vc.updateArrangement(UISplitArrangement.split.axes(.vertical), animated: true)
        case .overlay: vc.updateArrangement(UIOverlayArrangement.overlay, animated: true)
        }
    }

    static func describe(_ s: UIArrangementViewController.ViewState?) -> String {
        guard let s else { return "nil" }
        let axis: String
        switch s.splitAxis {
        case .horizontal: axis = "H"
        case .vertical: axis = "V"
        case .both: axis = "HV"
        default: axis = "none"
        }
        return "z\(s.zIndex) axis:\(axis) hidden:\(s.isHidden)"
    }
}

final class ObservableArrangementVC: UIArrangementViewController {
    var configKey = ""
    var onLayout: (() -> Void)?

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        onLayout?()
    }
}
