import SwiftUI

/// 自分自身の GeometryReader / Environment を表示するパネル。
/// ArrangementView の Primary/Secondary や別 Scene 内で使う（DuoState に依存しない）。
struct LocalGeometryPanel: View {
    let name: String
    let color: Color
    @Environment(\.horizontalSizeClass) private var h
    @Environment(\.verticalSizeClass) private var v
    @Environment(\.overlayArrangementZIndex) private var zIndex
    @Environment(\.toolbarVerticalEdge) private var toolbarEdge

    var body: some View {
        GeometryReader { proxy in
            let div = proxy.reservedRegions(kind: .division, options: [.includeInactive])
            let occ = proxy.reservedRegions(kind: .occlusion)
            let global = proxy.frame(in: .global)
            ZStack(alignment: .topLeading) {
                color.opacity(0.18)
                // ローカル座標での折り目を描画
                ForEach(div) { r in
                    Rectangle()
                        .fill(r.isActive ? Color.red.opacity(0.35) : .clear)
                        .stroke(r.isActive ? .red : .gray, style: StrokeStyle(lineWidth: 1.5, dash: r.isActive ? [] : [5, 4]))
                        .frame(width: r.frame.width, height: r.frame.height)
                        .offset(x: r.frame.minX, y: r.frame.minY)
                }
                ForEach(occ) { r in
                    Rectangle().fill(.yellow.opacity(0.5))
                        .frame(width: r.frame.width, height: r.frame.height)
                        .offset(x: r.frame.minX, y: r.frame.minY)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(name).font(.headline).foregroundStyle(color)
                    Group {
                        Text("size \(proxy.size.summary)")
                        Text("global \(global.summary)")
                        Text("safe T\(proxy.safeAreaInsets.top.pt) L\(proxy.safeAreaInsets.leading.pt) B\(proxy.safeAreaInsets.bottom.pt) R\(proxy.safeAreaInsets.trailing.pt)")
                        Text("sizeClass h:\(h.label) v:\(v.label)")
                        Text("overlayZIndex \(zIndex)")
                        Text("toolbarVerticalEdge \(toolbarEdge.map { $0 == .leading ? "leading" : "trailing" } ?? "nil")")
                        Text("division \(div.count) (active \(div.filter(\.isActive).count))")
                        ForEach(div) { r in
                            Text("  \(r.isActive ? "●" : "○") \(r.frame.summary) m:\(r.margins.top.pt)/\(r.margins.leading.pt)/\(r.margins.bottom.pt)/\(r.margins.trailing.pt)")
                        }
                        Text("occlusion \(occ.count)")
                    }
                    .font(.system(size: 11, design: .monospaced))
                }
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(6)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color, lineWidth: 2))
    }
}
