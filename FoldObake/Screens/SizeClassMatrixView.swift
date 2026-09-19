import SwiftUI

struct SizeClassMatrixView: View {
    @Environment(DuoState.self) private var state

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                HStack {
                    Text("\(state.visited.count) / \(Posture.allCases.count) 姿勢を訪問")
                        .font(.headline)
                    Spacer()
                    Button("今の姿勢を再記録", systemImage: "arrow.clockwise") { state.recordCurrentPosture() }
                        .buttonStyle(.bordered).font(.caption)
                    Button("リセット", systemImage: "trash", role: .destructive) { state.resetVisited() }
                        .buttonStyle(.bordered).font(.caption)
                }
                Text("Device Hub で open / close / fold / rotate を切替えると、初回訪問時の値が自動で記録されます。")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)

                ForEach(Posture.allCases) { p in
                    postureCard(p)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func postureCard(_ p: Posture) -> some View {
        let isCurrent = state.posture == p
        let record = state.visited[p]
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: p.symbol).foregroundStyle(isCurrent ? .white : .accentColor)
                Text(p.title).font(.headline)
                if isCurrent { Text("NOW").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2).background(.white.opacity(0.3), in: Capsule()) }
                Spacer()
                Image(systemName: record == nil ? "circle" : "checkmark.circle.fill")
                    .foregroundStyle(record == nil ? Color.secondary : Color.green)
            }
            Text("期待: \(p.expectedSizeClasses)").font(.caption).foregroundStyle(isCurrent ? .white.opacity(0.9) : .secondary)
            if let r = record {
                Group {
                    InfoRow("sizeClass", "h:\(r.hSizeClass) v:\(r.vSizeClass)")
                    InfoRow("window", r.windowSize.summary)
                    InfoRow("safeArea", r.safeArea.summary)
                    InfoRow("orientation", r.orientation)
                    InfoRow("hinge", "\(r.hingeStatus?.label ?? "nil") \(r.hingeAngle.map { "\($0.pt)°" } ?? "")")
                    InfoRow("division", r.divisionFrames.isEmpty ? "none" : r.divisionFrames.map { "\($0.width.pt)×\($0.height.pt)" }.joined(separator: ", "))
                    InfoRow("occlusion", r.occlusionFrames.isEmpty ? "none" : r.occlusionFrames.map { "\($0.width.pt)×\($0.height.pt)" }.joined(separator: ", "))
                    InfoRow("記録", r.date.formatted(date: .abbreviated, time: .shortened))
                }
                .foregroundStyle(isCurrent ? .white : .primary)
            } else {
                Text("未訪問").font(.caption).foregroundStyle(isCurrent ? .white : .secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isCurrent ? Color.accentColor : Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(isCurrent ? .white : .primary)
    }
}
