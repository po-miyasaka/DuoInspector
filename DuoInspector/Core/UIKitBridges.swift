import SwiftUI
import UIKit

/// UIKit 側の計測を担当する UIView。ウィンドウ全体を覆うように配置する。
/// - UIHingeInteraction でヒンジ更新を受け取る
/// - layoutSubviews + 定期ポーリングで reservedRegions / safeArea / 画面情報を読む
final class UIKitProbeUIView: UIView {
    var onHinge: ((UIHinge?) -> Void)?
    var onSnapshot: ((UIKitProbeSnapshot) -> Void)?
    private var timer: Timer?
    private var hingeInteraction: UIHingeInteraction?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        let interaction = UIHingeInteraction { [weak self] _, update in
            self?.onHinge?(update.hinge)
        }
        addInteraction(interaction)
        hingeInteraction = interaction
    }

    required init?(coder: NSCoder) { fatalError() }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        timer?.invalidate()
        guard window != nil else { return }
        let t = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.report() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        report()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        report()
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        report()
    }

    private func report() {
        let scene = window?.windowScene
        let screen = scene?.screen
        let snapshot = UIKitProbeSnapshot(
            division: reservedRegions(kind: .division, options: [.includeInactive]),
            occlusion: reservedRegions(kind: .occlusion, options: [.includeInactive]),
            safeAreaInsets: safeAreaInsets,
            bounds: bounds,
            orientation: scene?.interfaceOrientation ?? .unknown,
            idiom: traitCollection.userInterfaceIdiom,
            screenBounds: screen?.bounds ?? .zero,
            screenNativeBounds: screen?.nativeBounds ?? .zero,
            screenScale: screen?.scale ?? 0,
            traitH: traitCollection.horizontalSizeClass,
            traitV: traitCollection.verticalSizeClass,
            sceneCount: UIApplication.shared.connectedScenes.count
        )
        onSnapshot?(snapshot)
    }
}

struct UIKitProbeView: UIViewRepresentable {
    @Environment(DuoState.self) private var state

    func makeUIView(context: Context) -> UIKitProbeUIView {
        let v = UIKitProbeUIView()
        let state = self.state
        v.onHinge = { state.applyUIKitHinge($0) }
        v.onSnapshot = { state.applyUIKitProbe($0) }
        return v
    }

    func updateUIView(_ uiView: UIKitProbeUIView, context: Context) {}
}

extension UIUserInterfaceSizeClass {
    var label: String {
        switch self {
        case .compact: "compact"
        case .regular: "regular"
        case .unspecified: "unspecified"
        @unknown default: "?"
        }
    }
}

extension UIUserInterfaceIdiom {
    var label: String {
        switch self {
        case .phone: "phone"
        case .pad: "pad"
        case .tv: "tv"
        case .carPlay: "carPlay"
        case .mac: "mac"
        case .vision: "vision"
        case .unspecified: "unspecified"
        @unknown default: "?"
        }
    }
}
