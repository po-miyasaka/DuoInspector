import SwiftUI

/// ルート View に付けて DuoState を更新し続ける modifier。
struct DuoProbeModifier: ViewModifier {
    @Environment(DuoState.self) private var state
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.verticalSizeClass) private var vSizeClass
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.displayScale) private var displayScale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content
            // SafeArea を尊重した GeometryReader: コンテンツサイズと insets
            .background {
                GeometryReader { proxy in
                    let snap = SafeAreaSnapshot(contentSize: proxy.size, insets: proxy.safeAreaInsets)
                    Color.clear
                        .onChange(of: snap, initial: true) { _, new in state.applySafeAreaSnapshot(new) }
                }
            }
            // ウィンドウ全体の GeometryReader: 折り目・カメラ領域はこの座標系で記録
            .background {
                GeometryReader { proxy in
                    let snap = WindowSnapshot(
                        size: proxy.size,
                        division: proxy.reservedRegions(kind: .division, options: [.includeInactive]),
                        occlusion: proxy.reservedRegions(kind: .occlusion, options: [.includeInactive])
                    )
                    Color.clear
                        .onChange(of: snap, initial: true) { _, new in state.applyWindowSnapshot(new) }
                }
                .ignoresSafeArea()
            }
            // UIKit 側の計測
            .background {
                UIKitProbeView().ignoresSafeArea()
            }
            .onHingeChange { old, new in
                state.applyHinge(old: old, new: new)
            }
            .onChange(of: hSizeClass, initial: true) { _, _ in state.applySizeClass(h: hSizeClass, v: vSizeClass) }
            .onChange(of: vSizeClass, initial: true) { _, _ in state.applySizeClass(h: hSizeClass, v: vSizeClass) }
            .onChange(of: layoutDirection, initial: true) { _, v in state.layoutDirection = v }
            .onChange(of: displayScale, initial: true) { _, v in state.displayScale = v }
            .onChange(of: dynamicTypeSize, initial: true) { _, v in state.dynamicTypeSize = v }
    }
}

extension View {
    func duoProbe() -> some View { modifier(DuoProbeModifier()) }
}
