import SwiftUI

/// ラベル + 等幅の値
struct InfoRow: View {
    let label: String
    let value: String
    var color: Color? = nil

    init(_ label: String, _ value: String, color: Color? = nil) {
        self.label = label
        self.value = value
        self.color = color
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(color ?? .primary)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}

/// 小さなバッジ
struct MetricBadge: View {
    let title: String
    let value: String
    var color: Color = .accentColor

    var body: some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.system(.headline, design: .monospaced)).foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Size Class バッジ（例: hC / vR）
struct SizeClassBadge: View {
    let h: UserInterfaceSizeClass?
    let v: UserInterfaceSizeClass?

    var body: some View {
        HStack(spacing: 4) {
            Text("h").font(.caption2).foregroundStyle(.secondary)
            Text(h.label).font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(h == .regular ? .green : .orange)
            Text("v").font(.caption2).foregroundStyle(.secondary)
            Text(v.label).font(.system(.caption, design: .monospaced).bold())
                .foregroundStyle(v == .regular ? .green : .orange)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(.thinMaterial, in: Capsule())
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    var symbol: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let symbol {
                Label(title, systemImage: symbol).font(.headline)
            } else {
                Text(title).font(.headline)
            }
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }
}
