import SwiftUI

struct CustomUISandboxView: View {
    @Environment(DuoState.self) private var state
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SectionCard(title: "折り目を避ける / 避けない", symbol: "rectangle.split.2x1") {
                    Text("同じ Canvas 描画。右は GeometryProxy.reservedRegions(kind: .division) で分割して描き直す。")
                        .font(.caption).foregroundStyle(.secondary)
                    let layout = hSizeClass == .regular ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 8))
                    layout {
                        FoldAwareChart(avoidFold: false).frame(minHeight: 160)
                        FoldAwareChart(avoidFold: true).frame(minHeight: 160)
                    }
                }

                SectionCard(title: "折り目衝突チェッカー", symbol: "exclamationmark.triangle") {
                    Text("各ボタンに .foldCollisionWarning() を付けている。アクティブな折り目(+margins)と交差すると赤枠。")
                        .font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                        ForEach(0..<12, id: \.self) { i in
                            Button("Btn \(i)") {}
                                .buttonStyle(.borderedProminent)
                                .frame(maxWidth: .infinity)
                                .foldCollisionWarning()
                        }
                    }
                    Text("折り目をまたぐ長いテキストの例。折り目の上に文字が乗るとどう見えるかを観察する。ここは意図的に幅いっぱいに書いています。")
                        .font(.callout)
                        .padding(8)
                        .background(.background, in: RoundedRectangle(cornerRadius: 8))
                        .foldCollisionWarning()
                }

                SectionCard(title: "ConcentricRectangle vs RoundedRectangle", symbol: "app.dashed") {
                    Text("画面の角に置くと ConcentricRectangle は端末の角丸に追従する。").font(.caption).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    ConcentricRectangle(corners: .concentric(minimum: 12), isUniform: true)
                        .fill(.teal.opacity(0.3))
                        .stroke(.teal, lineWidth: 2)
                        .overlay(Text("Concentric").font(.caption))
                        .frame(height: 90)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.pink.opacity(0.3))
                        .stroke(.pink, lineWidth: 2)
                        .overlay(Text("Rounded 12").font(.caption))
                        .frame(height: 90)
                }
                .padding(.horizontal, 4)
                Color.clear.frame(height: 20)
            }
            .padding()
        }
    }
}

/// 折り目を避けて描画する Canvas の例
struct FoldAwareChart: View {
    let avoidFold: Bool

    var body: some View {
        GeometryReader { proxy in
            let folds = proxy.reservedRegions(kind: .division).map { r -> CGRect in
                CGRect(x: r.frame.minX - r.margins.leading, y: r.frame.minY - r.margins.top,
                       width: r.frame.width + r.margins.leading + r.margins.trailing,
                       height: r.frame.height + r.margins.top + r.margins.bottom)
            }
            let rects = avoidFold ? Self.splitAvoiding(CGRect(origin: .zero, size: proxy.size), folds: folds) : [CGRect(origin: .zero, size: proxy.size)]
            Canvas { ctx, size in
                for (i, rect) in rects.enumerated() {
                    ctx.fill(Path(roundedRect: rect.insetBy(dx: 2, dy: 2), cornerRadius: 8), with: .color(avoidFold ? .green.opacity(0.12) : .pink.opacity(0.12)))
                    var wave = Path()
                    let n = 60
                    for k in 0...n {
                        let x = rect.minX + rect.width * CGFloat(k) / CGFloat(n)
                        let t = Double(k) / Double(n)
                        let y = rect.midY + sin(t * .pi * 4 + Double(i)) * rect.height * 0.3
                        if k == 0 { wave.move(to: CGPoint(x: x, y: y)) } else { wave.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    ctx.stroke(wave, with: .color(avoidFold ? .green : .pink), lineWidth: 2)
                    ctx.draw(Text(avoidFold ? "avoid #\(i) \(rect.width.pt)×\(rect.height.pt)" : "no avoid \(rect.width.pt)×\(rect.height.pt)").font(.caption2.monospaced()),
                             at: CGPoint(x: rect.midX, y: rect.minY + 12))
                }
                for f in folds {
                    ctx.stroke(Path(f), with: .color(.red), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 10))
    }

    /// 矩形を折り目で分割して、折り目を含まない矩形の配列にする
    static func splitAvoiding(_ rect: CGRect, folds: [CGRect]) -> [CGRect] {
        var result = [rect]
        for f in folds {
            var next: [CGRect] = []
            for r in result {
                guard r.intersects(f) else { next.append(r); continue }
                let vertical = f.height >= f.width
                if vertical {
                    let left = CGRect(x: r.minX, y: r.minY, width: max(0, f.minX - r.minX), height: r.height)
                    let right = CGRect(x: f.maxX, y: r.minY, width: max(0, r.maxX - f.maxX), height: r.height)
                    if left.width > 8 { next.append(left) }
                    if right.width > 8 { next.append(right) }
                } else {
                    let top = CGRect(x: r.minX, y: r.minY, width: r.width, height: max(0, f.minY - r.minY))
                    let bottom = CGRect(x: r.minX, y: f.maxY, width: r.width, height: max(0, r.maxY - f.maxY))
                    if top.height > 8 { next.append(top) }
                    if bottom.height > 8 { next.append(bottom) }
                }
            }
            result = next
        }
        return result
    }
}

/// アクティブな折り目と交差したら赤枠で警告する modifier
struct FoldCollisionWarning: ViewModifier {
    @Environment(DuoState.self) private var state
    @State private var frame: CGRect = .zero

    private var collides: Bool {
        state.activeDivisions.contains { $0.frameWithMargins.intersects(frame) }
    }

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
            .overlay {
                if collides {
                    RoundedRectangle(cornerRadius: 8).stroke(.red, lineWidth: 3)
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.caption).offset(x: 4, y: -6)
                        }
                }
            }
    }
}

extension View {
    func foldCollisionWarning() -> some View { modifier(FoldCollisionWarning()) }
}
