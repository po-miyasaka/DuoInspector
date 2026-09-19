import SwiftUI

enum AxisBehaviorChoice: String, CaseIterable, Identifiable {
    case automatic, horizontalOnly, verticalPreferred
    var id: String { rawValue }
    var value: ToolbarItemAxisBehavior {
        switch self {
        case .automatic: .automatic
        case .horizontalOnly: .horizontalOnly
        case .verticalPreferred: .verticalPreferred
        }
    }
}

enum CompressionChoice: String, CaseIterable, Identifiable {
    case automatic, prefersToolbarItems, prefersTabBar
    var id: String { rawValue }
    var value: ToolbarVerticalCompressionBehavior {
        switch self {
        case .automatic: .automatic
        case .prefersToolbarItems: .prefersToolbarItems
        case .prefersTabBar: .prefersTabBar
        }
    }
}

struct ToolbarLabView: View {
    @Environment(DuoState.self) private var state
    @State private var axis: AxisBehaviorChoice = .automatic
    @State private var compression: CompressionChoice = .automatic
    @State private var itemCount = 4
    @State private var lowPriorityOdd = true
    @State private var showBottomBar = true
    @State private var reportedEdge: String = "nil"
    @State private var tapped = "–"

    private static let icons = ["square.and.arrow.up", "heart", "bookmark", "trash", "pencil", "star", "bell", "flag"]

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SectionCard(title: "toolbarVerticalEdge", symbol: "slider.horizontal.below.rectangle") {
                    InfoRow("toolbar 内で読んだ値", reportedEdge, color: reportedEdge == "nil" ? .secondary : .green)
                    InfoRow("画面本体で読んだ値", edgeLabel(bodyEdge))
                    Text("半開き（laptop 姿勢）などでツールバーが縦（leading / trailing）に移ると値が入る想定。").font(.caption).foregroundStyle(.secondary)
                }
                SectionCard(title: "ToolbarItem 設定", symbol: "switch.2") {
                    Picker("axisBehavior", selection: $axis) {
                        ForEach(AxisBehaviorChoice.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(".axisBehavior(.\(axis.rawValue))").font(.caption.monospaced()).foregroundStyle(.secondary)
                    Picker("compression", selection: $compression) {
                        ForEach(CompressionChoice.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(".toolbarVerticalCompressionBehavior(.\(compression.rawValue))").font(.caption.monospaced()).foregroundStyle(.secondary)
                    Stepper("アイテム数: \(itemCount)", value: $itemCount, in: 1...8)
                    Toggle("奇数番目を visibilityPriority(.low)", isOn: $lowPriorityOdd)
                    Toggle("bottomBar にも置く", isOn: $showBottomBar)
                    InfoRow("最後にタップ", tapped)
                }
                SectionCard(title: "メモ", symbol: "note.text") {
                    Text("""
                    ・Label(title, systemImage:) を使うと、縦配置時にアイコン/テキストを OS が自動で切替える
                    ・visibilityPriority(.low) のアイテムはオーバーフロー時に先に隠れる
                    ・prefersTabBar / prefersToolbarItems は縦圧縮時にどちらを優先するか
                    """).font(.caption).foregroundStyle(.secondary)
                }
                Color.clear.frame(height: 200)
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EdgeReporter(edge: $reportedEdge)
            }
            ForEach(0..<itemCount, id: \.self) { i in
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        tapped = "top #\(i)"
                    } label: {
                        Label("Item \(i)", systemImage: Self.icons[i % Self.icons.count])
                    }
                }
                .visibilityPriority(lowPriorityOdd && i % 2 == 1 ? .low : .high)
                .axisBehavior(axis.value)
            }
            if showBottomBar {
                ToolbarItemGroup(placement: .bottomBar) {
                    ForEach(0..<min(itemCount, 5), id: \.self) { i in
                        Button {
                            tapped = "bottom #\(i)"
                        } label: {
                            Label("Bottom \(i)", systemImage: Self.icons[(i + 3) % Self.icons.count])
                        }
                    }
                }
                .axisBehavior(axis.value)
            }
        }
        .toolbarVerticalCompressionBehavior(compression.value)
    }

    @Environment(\.toolbarVerticalEdge) private var bodyEdge

    private func edgeLabel(_ e: HorizontalEdge?) -> String {
        switch e {
        case .leading?: "leading"
        case .trailing?: "trailing"
        case nil: "nil"
        }
    }
}

/// ツールバーの中に置いて toolbarVerticalEdge を読む
struct EdgeReporter: View {
    @Binding var edge: String
    @Environment(\.toolbarVerticalEdge) private var verticalEdge

    var body: some View {
        Text(label)
            .font(.caption2.monospaced())
            .foregroundStyle(.secondary)
            .onChange(of: verticalEdge, initial: true) { _, _ in edge = label }
    }

    private var label: String {
        switch verticalEdge {
        case .leading?: "leading"
        case .trailing?: "trailing"
        case nil: "nil"
        }
    }
}
