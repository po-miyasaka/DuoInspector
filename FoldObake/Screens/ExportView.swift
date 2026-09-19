import SwiftUI
import UIKit

struct DuoReport: Codable {
    var tag: String
    var date: Date
    var posture: String?
    var windowSize: CGSize
    var contentSize: CGSize
    var safeArea: RectInsets
    var uikitSafeArea: RectInsets
    var hSizeClass: String
    var vSizeClass: String
    var orientation: String
    var idiom: String
    var displayScale: Double
    var screenBounds: CGRect
    var screenNativeBounds: CGRect
    var hingeStatus: String?
    var hingeAngle: Double?
    var uikitHingeStatus: String?
    var uikitHingeAngle: Double?
    var divisionRegions: [RegionInfo]
    var occlusionRegions: [RegionInfo]
    var uikitDivisionRegions: [RegionInfo]
    var visited: [String: PostureRecord]

    init(state: DuoState, tag: String) {
        self.tag = tag
        date = .now
        posture = state.posture?.title
        windowSize = state.windowSize
        contentSize = state.contentSize
        safeArea = RectInsets(state.safeAreaInsets)
        uikitSafeArea = RectInsets(state.uikitSafeAreaInsets)
        hSizeClass = state.hSizeClass.label
        vSizeClass = state.vSizeClass.label
        orientation = state.interfaceOrientation.label
        idiom = state.idiom.label
        displayScale = state.displayScale
        screenBounds = state.screenBounds
        screenNativeBounds = state.screenNativeBounds
        hingeStatus = state.hingeStatusValue?.label
        hingeAngle = state.hinge?.angle.degrees
        uikitHingeStatus = state.uikitHingeStatus?.label
        uikitHingeAngle = state.uikitHingeAngle
        divisionRegions = state.divisionRegions
        occlusionRegions = state.occlusionRegions
        uikitDivisionRegions = state.uikitDivisionRegions
        visited = Dictionary(uniqueKeysWithValues: state.visited.map { ($0.key.rawValue, $0.value) })
    }

    var json: String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return (try? enc.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    var markdown: String {
        var s = "## FoldObake report \(tag.isEmpty ? "" : "(\(tag))")\n"
        s += "- date: \(date.formatted(.iso8601))\n"
        s += "- posture: \(posture ?? "?")\n"
        s += "- window: \(windowSize.summary) / content: \(contentSize.summary)\n"
        s += "- sizeClass: h:\(hSizeClass) v:\(vSizeClass)\n"
        s += "- orientation: \(orientation), idiom: \(idiom), scale: \(displayScale.pt)\n"
        s += "- screen: \(screenBounds.size.summary) native: \(screenNativeBounds.size.summary)\n"
        s += "- safeArea (SwiftUI): \(safeArea.summary)\n"
        s += "- safeArea (UIKit): \(uikitSafeArea.summary)\n"
        s += "- hinge (SwiftUI): \(hingeStatus ?? "nil") \(hingeAngle.map { "\($0.pt)°" } ?? "")\n"
        s += "- hinge (UIKit): \(uikitHingeStatus ?? "nil") \(uikitHingeAngle.map { "\($0.pt)°" } ?? "")\n"
        s += "\n| kind | active | frame | margins |\n|---|---|---|---|\n"
        for r in divisionRegions + occlusionRegions {
            s += "| \(r.kind.rawValue) | \(r.isActive) | \(r.frame.summary) | \(r.margins.summary) |\n"
        }
        s += "\n### visited postures\n"
        for p in Posture.allCases {
            if let r = visited[p.rawValue] {
                s += "- ✅ \(p.title): h:\(r.hSizeClass) v:\(r.vSizeClass) window \(r.windowSize.summary) safe \(r.safeArea.summary) hinge \(r.hingeStatus?.label ?? "nil")\n"
            } else {
                s += "- ⬜️ \(p.title)\n"
            }
        }
        return s
    }
}

struct ExportView: View {
    @Environment(DuoState.self) private var state
    @State private var tag = ""
    @State private var format = 0
    @State private var message: String?

    private var report: DuoReport { DuoReport(state: state, tag: tag) }
    private var text: String { format == 0 ? report.markdown : report.json }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SectionCard(title: "タグ", symbol: "tag") {
                    TextField("例: 実機 半開き 横", text: $tag).textFieldStyle(.roundedBorder)
                    Text("Device Hub の姿勢名などを付けておくと、あとで照合しやすい。").font(.caption).foregroundStyle(.secondary)
                }
                SectionCard(title: "出力", symbol: "doc.text") {
                    Picker("format", selection: $format) {
                        Text("Markdown").tag(0)
                        Text("JSON").tag(1)
                    }.pickerStyle(.segmented)
                    HStack {
                        Button("コピー", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = text
                            message = "クリップボードにコピーしました"
                        }.buttonStyle(.borderedProminent)
                        ShareLink(item: text) { Label("共有", systemImage: "square.and.arrow.up") }.buttonStyle(.bordered)
                        Button("スクショ保存", systemImage: "camera") { saveScreenshot() }.buttonStyle(.bordered)
                    }
                    if let message { Text(message).font(.caption).foregroundStyle(.green) }
                    ScrollView(.horizontal) {
                        Text(text).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                    }
                    .frame(maxHeight: 400)
                }
            }
            .padding()
        }
    }

    private func saveScreenshot() {
        let card = ReportCard(report: report, state: state)
            .environment(state)
            .frame(width: max(320, state.windowSize.width))
        let renderer = ImageRenderer(content: card)
        renderer.scale = state.displayScale > 0 ? state.displayScale : 2
        if let image = renderer.uiImage {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            message = "写真に保存しました (\(Int(image.size.width))×\(Int(image.size.height)))"
        } else {
            message = "レンダリングに失敗"
        }
    }
}

/// スクショ用: 計測値 + ミニチュアのオーバーレイ
struct ReportCard: View {
    let report: DuoReport
    let state: DuoState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FoldObake \(report.tag)").font(.headline)
            Text(report.date.formatted()).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: 12) {
                // ミニチュア（実寸の 1/2）
                ZStack(alignment: .topLeading) {
                    Color(.systemBackground)
                    RegionOverlay(options: OverlayOptions(showGrid: true, showEffectiveRect: true))
                        .frame(width: state.windowSize.width, height: state.windowSize.height)
                }
                .frame(width: state.windowSize.width, height: state.windowSize.height)
                .scaleEffect(0.5, anchor: .topLeading)
                .frame(width: state.windowSize.width / 2, height: state.windowSize.height / 2)
                .border(.gray)
                VStack(alignment: .leading, spacing: 3) {
                    Group {
                        Text("posture: \(report.posture ?? "?")")
                        Text("window: \(report.windowSize.summary)")
                        Text("sizeClass: h:\(report.hSizeClass) v:\(report.vSizeClass)")
                        Text("safe: \(report.safeArea.summary)")
                        Text("hinge: \(report.hingeStatus ?? "nil") \(report.hingeAngle.map { "\($0.pt)°" } ?? "")")
                        ForEach(report.divisionRegions) { r in
                            Text("fold\(r.isActive ? "●" : "○"): \(r.frame.summary)")
                        }
                    }
                    .font(.system(size: 10, design: .monospaced))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}
