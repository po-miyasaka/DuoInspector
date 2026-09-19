import SwiftUI

/// SafeArea / 折り目 / カメラ領域 / グリッドを色分けして描くレイヤー。
/// ウィンドウ全体（ignoresSafeArea）に重ねて使う前提で、座標は DuoState のウィンドウ座標。
struct RegionOverlay: View {
    @Environment(DuoState.self) private var state
    var options: OverlayOptions? = nil

    private var opt: OverlayOptions { options ?? state.overlayOptions }

    static let safeTop = Color.blue
    static let safeBottom = Color.green
    static let safeLeading = Color.orange
    static let safeTrailing = Color.purple
    static let division = Color.red
    static let occlusion = Color.yellow
    static let effective = Color.green
    static let naive = Color.pink

    var body: some View {
        Canvas { ctx, size in
            let insets: EdgeInsets = opt.useUIKitValues
                ? RectInsets(state.uikitSafeAreaInsets).edgeInsets
                : state.safeAreaInsets
            let divisions = opt.useUIKitValues ? state.uikitDivisionRegions : state.divisionRegions
            let occlusions = opt.useUIKitValues ? state.uikitOcclusionRegions : state.occlusionRegions

            if opt.showGrid { drawGrid(ctx, size: size) }

            if opt.showSafeArea {
                let top = CGRect(x: 0, y: 0, width: size.width, height: insets.top)
                let bottom = CGRect(x: 0, y: size.height - insets.bottom, width: size.width, height: insets.bottom)
                let leading = CGRect(x: 0, y: 0, width: insets.leading, height: size.height)
                let trailing = CGRect(x: size.width - insets.trailing, y: 0, width: insets.trailing, height: size.height)
                fillBand(ctx, top, Self.safeTop, label: "top h=\(insets.top.pt)")
                fillBand(ctx, bottom, Self.safeBottom, label: "bottom h=\(insets.bottom.pt)")
                fillBand(ctx, leading, Self.safeLeading, label: "L w=\(insets.leading.pt)", vertical: true)
                fillBand(ctx, trailing, Self.safeTrailing, label: "R w=\(insets.trailing.pt)", vertical: true)
            }

            if opt.showOcclusion {
                for r in occlusions {
                    ctx.fill(Path(r.frame), with: .color(Self.occlusion.opacity(r.isActive ? 0.55 : 0.2)))
                    ctx.stroke(Path(r.frame), with: .color(Self.occlusion), lineWidth: 1.5)
                    if opt.showLabels { label(ctx, "cam \(r.frame.width.pt)×\(r.frame.height.pt)", at: CGPoint(x: r.frame.midX, y: r.frame.maxY + 10), color: Self.occlusion) }
                }
            }

            if opt.showDivision {
                for r in divisions where r.isActive || opt.showInactiveDivision {
                    if opt.showMargins {
                        let m = r.frameWithMargins
                        ctx.stroke(Path(m), with: .color(Self.division.opacity(0.7)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                    if r.isActive {
                        ctx.fill(Path(r.frame), with: .color(Self.division.opacity(0.35)))
                        stripes(ctx, r.frame, color: Self.division)
                        ctx.stroke(Path(r.frame), with: .color(Self.division), lineWidth: 2)
                    } else {
                        ctx.stroke(Path(r.frame), with: .color(.gray), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    }
                    if opt.showLabels {
                        let isVertical = r.frame.height > r.frame.width
                        let txt = "\(r.isActive ? "fold" : "fold(inactive)") w=\(r.frame.width.pt) h=\(r.frame.height.pt)"
                        let at = isVertical
                            ? CGPoint(x: r.frame.midX, y: r.frame.midY)
                            : CGPoint(x: r.frame.midX, y: r.frame.minY - 10)
                        label(ctx, txt, at: at, color: r.isActive ? Self.division : .gray, rotated: isVertical)
                    }
                }
            }

            if opt.showEffectiveRect {
                let rect = CGRect(x: insets.leading, y: insets.top,
                                  width: size.width - insets.leading - insets.trailing,
                                  height: size.height - insets.top - insets.bottom)
                ctx.stroke(Path(rect), with: .color(Self.effective), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                if opt.showLabels { label(ctx, "inset(by:) \(rect.width.pt)×\(rect.height.pt)", at: CGPoint(x: rect.midX, y: rect.minY + 12), color: Self.effective) }
            }
            if opt.showNaiveRect {
                let rect = CGRect(x: insets.leading, y: insets.top,
                                  width: size.width - insets.leading * 2,
                                  height: size.height - insets.top - insets.bottom)
                ctx.stroke(Path(rect), with: .color(Self.naive), style: StrokeStyle(lineWidth: 2, dash: [2, 4]))
                if opt.showLabels { label(ctx, "left*2 \(rect.width.pt)×\(rect.height.pt)", at: CGPoint(x: rect.midX, y: rect.minY + 28), color: Self.naive) }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func drawGrid(_ ctx: GraphicsContext, size: CGSize) {
        var path = Path()
        for x in stride(from: 0, through: size.width, by: 50) { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)) }
        for y in stride(from: 0, through: size.height, by: 50) { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)) }
        ctx.stroke(path, with: .color(.gray.opacity(0.35)), lineWidth: 0.5)
        var bold = Path()
        for x in stride(from: 0, through: size.width, by: 100) { bold.move(to: CGPoint(x: x, y: 0)); bold.addLine(to: CGPoint(x: x, y: size.height)) }
        for y in stride(from: 0, through: size.height, by: 100) { bold.move(to: CGPoint(x: 0, y: y)); bold.addLine(to: CGPoint(x: size.width, y: y)) }
        ctx.stroke(bold, with: .color(.gray.opacity(0.6)), lineWidth: 0.8)
        for x in stride(from: 100, through: size.width, by: 100) {
            ctx.draw(Text("\(Int(x))").font(.system(size: 9)).foregroundStyle(.gray), at: CGPoint(x: x, y: size.height / 2))
        }
        for y in stride(from: 100, through: size.height, by: 100) {
            ctx.draw(Text("\(Int(y))").font(.system(size: 9)).foregroundStyle(.gray), at: CGPoint(x: size.width / 2, y: y))
        }
    }

    private func fillBand(_ ctx: GraphicsContext, _ rect: CGRect, _ color: Color, label text: String, vertical: Bool = false) {
        guard rect.width > 0, rect.height > 0 else { return }
        ctx.fill(Path(rect), with: .color(color.opacity(0.3)))
        ctx.stroke(Path(rect), with: .color(color.opacity(0.8)), lineWidth: 1)
        guard opt.showLabels else { return }
        label(ctx, text, at: CGPoint(x: rect.midX, y: rect.midY), color: color, rotated: vertical)
    }

    private func stripes(_ ctx: GraphicsContext, _ rect: CGRect, color: Color) {
        var c = ctx
        c.clip(to: Path(rect))
        var p = Path()
        let step: CGFloat = 8
        var x = rect.minX - rect.height
        while x < rect.maxX + rect.height {
            p.move(to: CGPoint(x: x, y: rect.maxY))
            p.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += step
        }
        c.stroke(p, with: .color(color.opacity(0.6)), lineWidth: 1)
    }

    private func label(_ ctx: GraphicsContext, _ text: String, at point: CGPoint, color: Color, rotated: Bool = false) {
        let resolved = ctx.resolve(Text(text).font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundStyle(.white))
        let size = resolved.measure(in: CGSize(width: 400, height: 40))
        var c = ctx
        c.translateBy(x: point.x, y: point.y)
        if rotated { c.rotate(by: .degrees(-90)) }
        let bg = CGRect(x: -size.width / 2 - 4, y: -size.height / 2 - 2, width: size.width + 8, height: size.height + 4)
        c.fill(Path(roundedRect: bg, cornerRadius: 4), with: .color(color.opacity(0.85)))
        c.draw(resolved, at: .zero)
    }
}

/// 凡例
struct OverlayLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            legend(RegionOverlay.safeTop, "SafeArea top")
            legend(RegionOverlay.safeBottom, "SafeArea bottom")
            legend(RegionOverlay.safeLeading, "SafeArea leading")
            legend(RegionOverlay.safeTrailing, "SafeArea trailing")
            legend(RegionOverlay.division, "折り目 division (active)")
            legend(.gray, "折り目 division (inactive: 破線)")
            legend(RegionOverlay.occlusion, "カメラ occlusion")
            legend(RegionOverlay.effective, "bounds.inset(by: safeAreaInsets)")
            legend(RegionOverlay.naive, "誤: width − left×2")
        }
        .font(.caption)
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.5)).stroke(color).frame(width: 18, height: 12)
            Text(text)
        }
    }
}
