import SwiftUI

/// 半円ゲージ。0°=閉じた状態、180°=全開。
struct HingeGauge: View {
    let angle: Double?
    let status: HingeStatusValue?

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height - 8)
            let radius = min(size.width / 2, size.height) - 16
            // 背景の弧
            var arc = Path()
            arc.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            ctx.stroke(arc, with: .color(.secondary.opacity(0.25)), style: StrokeStyle(lineWidth: 12, lineCap: .round))
            // 目盛り
            for deg in stride(from: 0, through: 180, by: 30) {
                let a = Angle.degrees(180 - Double(deg)).radians
                let p1 = CGPoint(x: center.x + cos(a) * (radius - 14), y: center.y - sin(a) * (radius - 14))
                let p2 = CGPoint(x: center.x + cos(a) * (radius + 14), y: center.y - sin(a) * (radius + 14))
                var tick = Path(); tick.move(to: p1); tick.addLine(to: p2)
                ctx.stroke(tick, with: .color(.secondary.opacity(0.5)), lineWidth: 1)
                let lp = CGPoint(x: center.x + cos(a) * (radius + 26), y: center.y - sin(a) * (radius + 26))
                ctx.draw(Text("\(deg)").font(.caption2).foregroundStyle(.secondary), at: lp)
            }
            if let angle {
                let clamped = max(0, min(180, angle))
                var val = Path()
                val.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(180 - clamped), clockwise: false)
                ctx.stroke(val, with: .color(status?.color ?? .accentColor), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                let a = Angle.degrees(180 - clamped).radians
                let tip = CGPoint(x: center.x + cos(a) * (radius - 4), y: center.y - sin(a) * (radius - 4))
                var needle = Path(); needle.move(to: center); needle.addLine(to: tip)
                ctx.stroke(needle, with: .color(.primary), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                ctx.fill(Path(ellipseIn: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)), with: .color(.primary))
            }
        }
        .frame(height: 130)
    }
}

/// 側面から見た本体のミニチュア。角度に応じて上半分が回転する。
struct HingeSideView: View {
    let angle: Double?

    var body: some View {
        Canvas { ctx, size in
            let hinge = CGPoint(x: size.width * 0.5, y: size.height * 0.7)
            let len = min(size.width, size.height) * 0.42
            let thickness: CGFloat = 10
            // 下側（固定）: 左へ伸びる
            let lower = CGRect(x: hinge.x - len, y: hinge.y - thickness / 2, width: len, height: thickness)
            ctx.fill(Path(roundedRect: lower, cornerRadius: 4), with: .color(.secondary))
            // 上側: 角度だけ回転
            let a = Angle.degrees(180 - (angle ?? 180)).radians
            var upper = ctx
            upper.translateBy(x: hinge.x, y: hinge.y)
            upper.rotate(by: .radians(-a))
            let upperRect = CGRect(x: -len, y: -thickness / 2, width: len, height: thickness)
            upper.fill(Path(roundedRect: upperRect, cornerRadius: 4), with: .color(.accentColor))
            // 内側ディスプレイの向きを示す線
            upper.stroke(Path { p in p.move(to: CGPoint(x: -len + 4, y: -thickness / 2 - 2)); p.addLine(to: CGPoint(x: -6, y: -thickness / 2 - 2)) }, with: .color(.green), lineWidth: 2)
            ctx.stroke(Path { p in p.move(to: CGPoint(x: lower.minX + 4, y: lower.minY - 2)); p.addLine(to: CGPoint(x: lower.maxX - 6, y: lower.minY - 2)) }, with: .color(.green), lineWidth: 2)
            ctx.fill(Path(ellipseIn: CGRect(x: hinge.x - 6, y: hinge.y - 6, width: 12, height: 12)), with: .color(.orange))
            ctx.draw(Text(angle.map { "\($0.pt)°" } ?? "–").font(.caption.monospacedDigit()), at: CGPoint(x: hinge.x, y: size.height - 10))
        }
        .frame(height: 120)
    }
}
