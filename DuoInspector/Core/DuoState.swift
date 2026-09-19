import SwiftUI
import Observation

/// 折り目・カメラ領域の共通表現（SwiftUI / UIKit 両対応）。座標はウィンドウ座標。
struct RegionInfo: Identifiable, Hashable, Codable {
    enum Kind: String, Codable { case division, occlusion }
    let id: String
    let kind: Kind
    let frame: CGRect
    let margins: RectInsets
    let isActive: Bool

    init(_ r: ReservedRegion, index: Int) {
        id = "swiftui-\(r.kind == .division ? "div" : "occ")-\(index)"
        kind = r.kind == .division ? .division : .occlusion
        frame = r.frame
        margins = RectInsets(r.margins)
        isActive = r.isActive
    }

    init(_ r: UIView.ReservedRegion, index: Int) {
        id = "uikit-\(r.kind == .division ? "div" : "occ")-\(index)"
        kind = r.kind == .division ? .division : .occlusion
        frame = r.frame
        margins = RectInsets(r.margins)
        isActive = r.isActive
    }

    /// margins を含めた「避けるべき」矩形。
    var frameWithMargins: CGRect {
        CGRect(x: frame.minX - margins.leading,
               y: frame.minY - margins.top,
               width: frame.width + margins.leading + margins.trailing,
               height: frame.height + margins.top + margins.bottom)
    }
}

/// アプリ全体で共有する計測値の単一ソース。
@Observable
final class DuoState {
    // MARK: SwiftUI 側の計測値
    /// SafeArea を除いたコンテンツ領域のサイズ
    var contentSize: CGSize = .zero
    /// ウィンドウ全体のサイズ（ignoresSafeArea した GeometryReader）
    var windowSize: CGSize = .zero
    var safeAreaInsets: EdgeInsets = .init()
    var hSizeClass: UserInterfaceSizeClass?
    var vSizeClass: UserInterfaceSizeClass?
    var layoutDirection: LayoutDirection = .leftToRight
    var displayScale: CGFloat = 0
    var dynamicTypeSize: DynamicTypeSize = .large

    var hinge: DeviceHinge?
    var hingeCallbackCount = 0
    var hingeLastUpdate: Date?
    /// onHingeChange が一度でも呼ばれたか
    var hingeCallbackReceived = false

    /// 折り目（includeInactive 込み）。座標はウィンドウ座標。
    var divisionRegions: [RegionInfo] = []
    /// カメラ等（includeInactive 込み）。
    var occlusionRegions: [RegionInfo] = []

    // MARK: UIKit 側の計測値
    var uikitHingeStatus: HingeStatusValue?
    var uikitHingeAngle: Double?
    var uikitHingeCallbackCount = 0
    var uikitHingeLastUpdate: Date?
    var uikitDivisionRegions: [RegionInfo] = []
    var uikitOcclusionRegions: [RegionInfo] = []
    var uikitSafeAreaInsets: UIEdgeInsets = .zero
    var uikitViewBounds: CGRect = .zero
    var interfaceOrientation: UIInterfaceOrientation = .unknown
    var idiom: UIUserInterfaceIdiom = .unspecified
    var screenBounds: CGRect = .zero
    var screenNativeBounds: CGRect = .zero
    var screenScale: CGFloat = 0
    var traitHSizeClass: UIUserInterfaceSizeClass = .unspecified
    var traitVSizeClass: UIUserInterfaceSizeClass = .unspecified
    var sceneCount = 0

    // MARK: 表示設定
    var overlayEnabled = false
    var overlayOptions = OverlayOptions()
    var selectedScreen: Screen = .overlay
    /// Arrangement Playground の設定（デモツアーから操作できるよう state に置く）
    var arrangementStyle: ArrangementStyleChoice = .split
    var arrangementFramework = 0
    /// 起動引数 demo=1 で自動ツアーを回す
    var demoMode = false

    // MARK: 派生値
    var posture: Posture?
    var visited: [Posture: PostureRecord] = [:] {
        didSet { persistVisited() }
    }
    private(set) var log: [EventEntry] = []

    init() {
        loadVisited()
        // 検証用の起動引数: `screen=hinge nav=bare overlay=1`
        // （`-key value` 形式だと UserDefaults の引数ドメインに入り、アプリ内からの変更より優先されてしまうので使わない）
        for arg in ProcessInfo.processInfo.arguments {
            let parts = arg.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            switch parts[0] {
            case "screen":
                if let s = Screen(rawValue: parts[1]) { selectedScreen = s }
            case "nav":
                if NavStyle(rawValue: parts[1]) != nil { UserDefaults.standard.set(parts[1], forKey: "navStyle") }
            case "overlay":
                overlayEnabled = parts[1] == "1"
            case "demo":
                demoMode = parts[1] == "1"
            default: break
            }
        }
    }

    // MARK: 更新 API

    func applySafeAreaSnapshot(_ s: SafeAreaSnapshot) {
        if s.contentSize != contentSize {
            append(.size, "content \(contentSize.summary) → \(s.contentSize.summary)")
            contentSize = s.contentSize
        }
        if s.insets != safeAreaInsets {
            append(.safeArea, "\(RectInsets(safeAreaInsets).summary) → \(RectInsets(s.insets).summary)")
            safeAreaInsets = s.insets
        }
    }

    func applyWindowSnapshot(_ s: WindowSnapshot) {
        if s.size != windowSize {
            append(.size, "window \(windowSize.summary) → \(s.size.summary)")
            windowSize = s.size
        }
        let div = s.division.enumerated().map { RegionInfo($0.element, index: $0.offset) }
        let occ = s.occlusion.enumerated().map { RegionInfo($0.element, index: $0.offset) }
        if div != divisionRegions {
            append(.region, "division: \(Self.describe(div))")
            divisionRegions = div
        }
        if occ != occlusionRegions {
            append(.region, "occlusion: \(Self.describe(occ))")
            occlusionRegions = occ
        }
        updatePosture()
    }

    func applyHinge(old: DeviceHingeContext, new: DeviceHingeContext) {
        hingeCallbackReceived = true
        hingeCallbackCount += 1
        hingeLastUpdate = .now
        hinge = new.hinge
        append(.hinge, "\(Self.describe(old.hinge)) → \(Self.describe(new.hinge))")
        updatePosture()
    }

    func applyUIKitHinge(_ h: UIHinge?) {
        uikitHingeCallbackCount += 1
        uikitHingeLastUpdate = .now
        let status = h.map { HingeStatusValue($0.status) }
        // UIHinge.angle はラジアン（SwiftUI の DeviceHinge.angle は Angle）。度に揃える。
        let angle = h.map { Double($0.angle) * 180 / .pi }
        append(.uikitHinge, "\(uikitHingeStatus?.label ?? "nil") \(uikitHingeAngle?.pt ?? "-")° → \(status?.label ?? "nil") \(angle?.pt ?? "-")°")
        uikitHingeStatus = status
        uikitHingeAngle = angle
    }

    func applySizeClass(h: UserInterfaceSizeClass?, v: UserInterfaceSizeClass?) {
        guard h != hSizeClass || v != vSizeClass else { return }
        append(.sizeClass, "h:\(hSizeClass.label) v:\(vSizeClass.label) → h:\(h.label) v:\(v.label)")
        hSizeClass = h
        vSizeClass = v
        updatePosture()
    }

    func applyUIKitProbe(_ p: UIKitProbeSnapshot) {
        let div = p.division.enumerated().map { RegionInfo($0.element, index: $0.offset) }
        let occ = p.occlusion.enumerated().map { RegionInfo($0.element, index: $0.offset) }
        if div != uikitDivisionRegions { uikitDivisionRegions = div }
        if occ != uikitOcclusionRegions { uikitOcclusionRegions = occ }
        if p.safeAreaInsets != uikitSafeAreaInsets { uikitSafeAreaInsets = p.safeAreaInsets }
        if p.bounds != uikitViewBounds { uikitViewBounds = p.bounds }
        if p.orientation != interfaceOrientation {
            append(.orientation, "\(interfaceOrientation.label) → \(p.orientation.label)")
            interfaceOrientation = p.orientation
            updatePosture()
        }
        idiom = p.idiom
        screenBounds = p.screenBounds
        screenNativeBounds = p.screenNativeBounds
        screenScale = p.screenScale
        traitHSizeClass = p.traitH
        traitVSizeClass = p.traitV
        if p.sceneCount != sceneCount {
            append(.scene, "connected scenes: \(sceneCount) → \(p.sceneCount)")
            sceneCount = p.sceneCount
        }
    }

    func append(_ kind: EventKind, _ message: String) {
        log.insert(EventEntry(kind: kind, message: message), at: 0)
        if log.count > 500 { log.removeLast(log.count - 500) }
    }

    func clearLog() { log.removeAll() }

    func resetVisited() { visited = [:] }

    // MARK: 派生

    var hingeStatusValue: HingeStatusValue? { hinge.map { HingeStatusValue($0.status) } }

    /// 有効な折り目（isActive）だけ
    var activeDivisions: [RegionInfo] { divisionRegions.filter(\.isActive) }

    /// スライドで注意喚起されていた「safeAreaInsets.left * 2」の誤算と正しい幅
    var naiveWidth: CGFloat { windowSize.width - safeAreaInsets.leading * 2 }
    var correctWidth: CGFloat { windowSize.width - safeAreaInsets.leading - safeAreaInsets.trailing }

    private func updatePosture() {
        let p = Posture.estimate(hingeStatus: hingeStatusValue, windowSize: windowSize, orientation: interfaceOrientation)
        if p != posture {
            append(.posture, "\(posture?.title ?? "nil") → \(p?.title ?? "nil")")
            posture = p
        }
        guard let p, windowSize != .zero else { return }
        // 初回訪問時に記録。値が揃ってから記録したいので少し遅らせる。
        if visited[p] == nil {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                guard self.posture == p, self.visited[p] == nil else { return }
                self.visited[p] = self.makeRecord()
            }
        }
    }

    func makeRecord() -> PostureRecord {
        PostureRecord(
            date: .now,
            hSizeClass: hSizeClass.label,
            vSizeClass: vSizeClass.label,
            windowSize: windowSize,
            safeArea: RectInsets(safeAreaInsets),
            orientation: interfaceOrientation.label,
            hingeStatus: hingeStatusValue,
            hingeAngle: hinge.map { $0.angle.degrees },
            divisionFrames: divisionRegions.map(\.frame),
            occlusionFrames: occlusionRegions.map(\.frame)
        )
    }

    /// 現在の姿勢の記録を上書き
    func recordCurrentPosture() {
        guard let posture else { return }
        visited[posture] = makeRecord()
    }

    // MARK: 永続化

    private static let visitedKey = "visitedPostures.v1"

    private func persistVisited() {
        if let data = try? JSONEncoder().encode(visited) {
            UserDefaults.standard.set(data, forKey: Self.visitedKey)
        }
    }

    private func loadVisited() {
        if let data = UserDefaults.standard.data(forKey: Self.visitedKey),
           let v = try? JSONDecoder().decode([Posture: PostureRecord].self, from: data) {
            visited = v
        }
    }

    // MARK: 文字列化

    static func describe(_ h: DeviceHinge?) -> String {
        guard let h else { return "nil" }
        return "\(HingeStatusValue(h.status).label) \(h.angle.degrees.pt)°"
    }

    static func describe(_ regions: [RegionInfo]) -> String {
        regions.isEmpty ? "[]" : regions.map { "\($0.isActive ? "●" : "○")\($0.frame.summary)" }.joined(separator: ", ")
    }
}

/// オーバーレイ描画のオプション
struct OverlayOptions: Hashable {
    var showSafeArea = true
    var showDivision = true
    var showInactiveDivision = true
    var showOcclusion = true
    var showMargins = true
    var showGrid = false
    var showEffectiveRect = false
    var showNaiveRect = false
    var showLabels = true
    var useUIKitValues = false
}

// MARK: - スナップショット型（Equatable で onChange に流す）

struct SafeAreaSnapshot: Equatable {
    var contentSize: CGSize
    var insets: EdgeInsets
}

struct WindowSnapshot: Equatable {
    var size: CGSize
    var division: [ReservedRegion]
    var occlusion: [ReservedRegion]
}

struct UIKitProbeSnapshot {
    var division: [UIView.ReservedRegion]
    var occlusion: [UIView.ReservedRegion]
    var safeAreaInsets: UIEdgeInsets
    var bounds: CGRect
    var orientation: UIInterfaceOrientation
    var idiom: UIUserInterfaceIdiom
    var screenBounds: CGRect
    var screenNativeBounds: CGRect
    var screenScale: CGFloat
    var traitH: UIUserInterfaceSizeClass
    var traitV: UIUserInterfaceSizeClass
    var sceneCount: Int
}
