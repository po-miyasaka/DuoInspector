import SwiftUI

struct OverlayInspectorView: View {
    @Environment(DuoState.self) private var state
    @State private var tapWindow: CGPoint?

    var body: some View {
        @Bindable var state = state
        ScrollView {
            VStack(spacing: 12) {
                SectionCard(title: "現在の状態", symbol: "iphone.gen3") {
                    HStack(spacing: 8) {
                        MetricBadge(title: "posture", value: state.posture?.title ?? "?", color: .indigo)
                        MetricBadge(title: "hinge", value: state.hingeStatusValue?.label ?? "nil", color: state.hingeStatusValue?.color ?? .gray)
                        MetricBadge(title: "angle", value: state.hinge.map { "\($0.angle.degrees.pt)°" } ?? "–", color: .orange)
                    }
                    InfoRow("window", state.windowSize.summary)
                    InfoRow("content(safe内)", state.contentSize.summary)
                    InfoRow("sizeClass", "h:\(state.hSizeClass.label) v:\(state.vSizeClass.label)")
                    InfoRow("orientation", state.interfaceOrientation.label)
                    InfoRow("idiom / scale", "\(state.idiom.label) / @\(state.displayScale.pt)x")
                    InfoRow("screen.bounds", state.screenBounds.size.summary)
                    InfoRow("screen.nativeBounds", state.screenNativeBounds.size.summary)
                }

                SectionCard(title: "SafeArea (pt)", symbol: "rectangle.inset.filled") {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                        GridRow { Text("").font(.caption); Text("SwiftUI").font(.caption.bold()); Text("UIKit").font(.caption.bold()) }
                        safeRow("top", state.safeAreaInsets.top, state.uikitSafeAreaInsets.top, RegionOverlay.safeTop)
                        safeRow("leading", state.safeAreaInsets.leading, state.uikitSafeAreaInsets.left, RegionOverlay.safeLeading)
                        safeRow("bottom", state.safeAreaInsets.bottom, state.uikitSafeAreaInsets.bottom, RegionOverlay.safeBottom)
                        safeRow("trailing", state.safeAreaInsets.trailing, state.uikitSafeAreaInsets.right, RegionOverlay.safeTrailing)
                    }
                    Divider()
                    InfoRow("正: inset(by:).width", state.correctWidth.pt, color: RegionOverlay.effective)
                    InfoRow("誤: width − left×2", state.naiveWidth.pt, color: state.naiveWidth == state.correctWidth ? .secondary : RegionOverlay.naive)
                    if state.naiveWidth != state.correctWidth {
                        Text("左右の SafeArea が非対称なので left×2 ではズレます（差 \((state.naiveWidth - state.correctWidth).pt)pt）")
                            .font(.caption).foregroundStyle(RegionOverlay.naive)
                    }
                }

                SectionCard(title: "折り目 division", symbol: "rectangle.split.2x1") {
                    if state.divisionRegions.isEmpty {
                        Text("なし（includeInactive でも 0 件）").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(state.divisionRegions) { r in regionRows(r) }
                    if state.uikitDivisionRegions != state.divisionRegions {
                        Divider()
                        Text("UIKit 側の値").font(.caption.bold())
                        ForEach(state.uikitDivisionRegions) { r in regionRows(r) }
                    }
                }

                SectionCard(title: "カメラ occlusion", symbol: "camera") {
                    if state.occlusionRegions.isEmpty {
                        Text("なし").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(state.occlusionRegions) { r in regionRows(r) }
                }

                SectionCard(title: "タップ座標", symbol: "hand.tap") {
                    if let p = tapWindow {
                        InfoRow("window", "(\(p.x.pt), \(p.y.pt))")
                        InfoRow("safe-relative", "(\((p.x - state.safeAreaInsets.leading).pt), \((p.y - state.safeAreaInsets.top).pt))")
                        let hits = state.activeDivisions.filter { $0.frameWithMargins.contains(p) }
                        InfoRow("折り目に乗っている", hits.isEmpty ? "no" : "YES", color: hits.isEmpty ? .green : .red)
                    } else {
                        Text("画面のどこかを長押し(0.2s)すると座標を表示").font(.caption).foregroundStyle(.secondary)
                    }
                }

                SectionCard(title: "オーバーレイ表示", symbol: "square.stack.3d.up") {
                    Toggle("全画面にオーバーレイを表示", isOn: $state.overlayEnabled)
                    Toggle("SafeArea", isOn: $state.overlayOptions.showSafeArea)
                    Toggle("折り目 division", isOn: $state.overlayOptions.showDivision)
                    Toggle("  非アクティブな折り目も", isOn: $state.overlayOptions.showInactiveDivision)
                    Toggle("  margins も描く", isOn: $state.overlayOptions.showMargins)
                    Toggle("カメラ occlusion", isOn: $state.overlayOptions.showOcclusion)
                    Toggle("有効矩形 inset(by:)", isOn: $state.overlayOptions.showEffectiveRect)
                    Toggle("誤算矩形 left×2", isOn: $state.overlayOptions.showNaiveRect)
                    Toggle("50pt グリッド", isOn: $state.overlayOptions.showGrid)
                    Toggle("ラベル", isOn: $state.overlayOptions.showLabels)
                    Toggle("UIKit の値で描く", isOn: $state.overlayOptions.useUIKitValues)
                    Divider()
                    OverlayLegend()
                }
            }
            .padding()
        }
        .gesture(
            LongPressGesture(minimumDuration: 0.2)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                .onEnded { value in
                    if case .second(true, let drag?) = value { tapWindow = drag.location }
                }
        )
    }

    private func safeRow(_ name: String, _ a: CGFloat, _ b: CGFloat, _ color: Color) -> some View {
        GridRow {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.5)).stroke(color).frame(width: 14, height: 10)
                Text(name)
            }.font(.callout)
            Text(a.pt).font(.system(.body, design: .monospaced))
            Text(b.pt).font(.system(.body, design: .monospaced)).foregroundStyle(a == b ? Color.secondary : Color.red)
        }
    }

    @ViewBuilder
    private func regionRows(_ r: RegionInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Circle().fill(r.isActive ? RegionOverlay.division : .gray).frame(width: 8, height: 8)
                Text(r.isActive ? "active" : "inactive").font(.caption.bold()).foregroundStyle(r.isActive ? RegionOverlay.division : .gray)
                Spacer()
                Text(r.id).font(.caption2).foregroundStyle(.secondary)
            }
            InfoRow("frame", r.frame.summary)
            InfoRow("width × height", "\(r.frame.width.pt) × \(r.frame.height.pt)")
            InfoRow("margins", r.margins.summary)
            InfoRow("frame+margins", "\(r.frameWithMargins.width.pt) × \(r.frameWithMargins.height.pt)")
        }
        .padding(.vertical, 4)
    }
}
