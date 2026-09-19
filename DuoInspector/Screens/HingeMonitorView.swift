import SwiftUI

struct HingeMonitorView: View {
    @Environment(DuoState.self) private var state
    @State private var filter: Set<EventKind> = Set(EventKind.allCases)

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SectionCard(title: "ヒンジ (SwiftUI onHingeChange)", symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(state.hingeStatusValue?.label ?? (state.hingeCallbackReceived ? "hinge = nil" : "未受信"))
                                .font(.title2.bold())
                                .foregroundStyle(state.hingeStatusValue?.color ?? .gray)
                            Text(state.hinge.map { "\($0.angle.degrees.pt)°" } ?? "–")
                                .font(.system(size: 44, weight: .bold, design: .rounded).monospacedDigit())
                            Text("callbacks: \(state.hingeCallbackCount)").font(.caption).foregroundStyle(.secondary)
                            if let d = state.hingeLastUpdate {
                                Text("last: \(d.formatted(date: .omitted, time: .standard))").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        HingeSideView(angle: state.hinge.map { $0.angle.degrees }).frame(width: 150)
                    }
                    HingeGauge(angle: state.hinge.map { $0.angle.degrees }, status: state.hingeStatusValue)
                }

                SectionCard(title: "SwiftUI vs UIKit", symbol: "u.square") {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                        GridRow { Text("").font(.caption); Text("SwiftUI").font(.caption.bold()); Text("UIKit").font(.caption.bold()) }
                        GridRow {
                            Text("status").font(.callout)
                            Text(state.hingeStatusValue?.label ?? "nil").font(.system(.callout, design: .monospaced))
                            Text(state.uikitHingeStatus?.label ?? "nil").font(.system(.callout, design: .monospaced))
                        }
                        GridRow {
                            Text("angle").font(.callout)
                            Text(state.hinge.map { $0.angle.degrees.pt } ?? "–").font(.system(.callout, design: .monospaced))
                            Text(state.uikitHingeAngle?.pt ?? "–").font(.system(.callout, design: .monospaced))
                        }
                        GridRow {
                            Text("callbacks").font(.callout)
                            Text("\(state.hingeCallbackCount)").font(.system(.callout, design: .monospaced))
                            Text("\(state.uikitHingeCallbackCount)").font(.system(.callout, design: .monospaced))
                        }
                        GridRow {
                            Text("last").font(.callout)
                            Text(state.hingeLastUpdate.map { $0.formatted(.dateTime.hour().minute().second().secondFraction(.fractional(2))) } ?? "–").font(.system(.caption2, design: .monospaced))
                            Text(state.uikitHingeLastUpdate.map { $0.formatted(.dateTime.hour().minute().second().secondFraction(.fractional(2))) } ?? "–").font(.system(.caption2, design: .monospaced))
                        }
                        GridRow {
                            Text("sizeClass").font(.callout)
                            Text("\(state.hSizeClass.short)/\(state.vSizeClass.short)").font(.system(.callout, design: .monospaced))
                            Text("\(state.traitHSizeClass.label.prefix(1).uppercased())/\(state.traitVSizeClass.label.prefix(1).uppercased())").font(.system(.callout, design: .monospaced))
                        }
                        GridRow {
                            Text("division").font(.callout)
                            Text("\(state.divisionRegions.count) (●\(state.activeDivisions.count))").font(.system(.callout, design: .monospaced))
                            Text("\(state.uikitDivisionRegions.count) (●\(state.uikitDivisionRegions.filter(\.isActive).count))").font(.system(.callout, design: .monospaced))
                        }
                    }
                    Text("UIKit 側は UIHingeInteraction の updateHandler。UIHinge.angle は**ラジアン**で返るので度に換算して表示（SwiftUI は Angle）。")
                        .font(.caption).foregroundStyle(.secondary)
                }

                SectionCard(title: "イベントログ (\(filteredLog.count))", symbol: "list.bullet.rectangle") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(EventKind.allCases) { k in
                                Button {
                                    if filter.contains(k) { filter.remove(k) } else { filter.insert(k) }
                                } label: {
                                    Label(k.label, systemImage: k.symbol)
                                        .font(.caption)
                                        .padding(.horizontal, 8).padding(.vertical, 5)
                                        .background(filter.contains(k) ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.12), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    HStack {
                        Button("すべて", systemImage: "checkmark.circle") { filter = Set(EventKind.allCases) }
                        Button("なし", systemImage: "circle") { filter = [] }
                        Spacer()
                        Button("クリア", systemImage: "trash", role: .destructive) { state.clearLog() }
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredLog.prefix(200)) { e in
                            HStack(alignment: .top, spacing: 6) {
                                Text(e.date.formatted(.dateTime.hour().minute().second().secondFraction(.fractional(2))))
                                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                                Image(systemName: e.kind.symbol).font(.caption2).frame(width: 14)
                                Text(e.message).font(.system(size: 11, design: .monospaced))
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private var filteredLog: [EventEntry] { state.log.filter { filter.contains($0.kind) } }
}
