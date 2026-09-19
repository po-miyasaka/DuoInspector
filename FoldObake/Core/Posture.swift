import SwiftUI

/// iPhone Duo の 6 姿勢。
enum Posture: String, CaseIterable, Identifiable, Codable {
    case outerPortrait
    case outerLandscape
    case innerPortrait
    case innerLandscape
    case halfOpenPortrait
    case halfOpenLandscape

    var id: String { rawValue }

    var title: String {
        switch self {
        case .outerPortrait: "外側 / 縦"
        case .outerLandscape: "外側 / 横"
        case .innerPortrait: "内側(全開) / 縦"
        case .innerLandscape: "内側(全開) / 横"
        case .halfOpenPortrait: "半開き / 縦"
        case .halfOpenLandscape: "半開き / 横"
        }
    }

    var symbol: String {
        switch self {
        case .outerPortrait: "iphone"
        case .outerLandscape: "iphone.landscape"
        case .innerPortrait: "ipad"
        case .innerLandscape: "ipad.landscape"
        case .halfOpenPortrait: "laptopcomputer"
        case .halfOpenLandscape: "laptopcomputer.and.iphone"
        }
    }

    /// 期待値（スライド「速習 iPhone Duo 対応」の記載）。実測と照合する用。
    var expectedSizeClasses: String {
        switch self {
        case .outerPortrait: "h: compact / v: regular"
        case .outerLandscape: "h: compact / v: compact"
        case .innerPortrait, .halfOpenPortrait: "h: regular / v: regular"
        case .innerLandscape, .halfOpenLandscape: "h: compact / v: compact（スライド記載。実測と比較）"
        }
    }

    /// ヒンジ状態・サイズ・向きから姿勢を推定する。
    static func estimate(hingeStatus: HingeStatusValue?, windowSize: CGSize, orientation: UIInterfaceOrientation) -> Posture? {
        guard windowSize.width > 0, windowSize.height > 0 else { return nil }
        let landscape: Bool
        switch orientation {
        case .landscapeLeft, .landscapeRight: landscape = true
        case .portrait, .portraitUpsideDown: landscape = false
        default: landscape = windowSize.width > windowSize.height
        }
        // 実測: 内側 669×951pt (2007×2853 @3x)、外側 466×678pt (1398×2034 @3x)
        let shortSide = min(windowSize.width, windowSize.height)
        let looksInner = shortSide >= 600
        switch hingeStatus {
        case .closed:
            return landscape ? .outerLandscape : .outerPortrait
        case .partiallyOpen:
            return landscape ? .halfOpenLandscape : .halfOpenPortrait
        case .fullyOpen:
            return landscape ? .innerLandscape : .innerPortrait
        case .unknown, .none:
            if looksInner { return landscape ? .innerLandscape : .innerPortrait }
            return landscape ? .outerLandscape : .outerPortrait
        }
    }
}

/// SwiftUI / UIKit 両方のヒンジ状態を共通表現にしたもの。
enum HingeStatusValue: String, Codable, Hashable {
    case unknown, closed, partiallyOpen, fullyOpen

    init(_ status: DeviceHinge.Status) {
        switch status {
        case .closed: self = .closed
        case .partiallyOpen: self = .partiallyOpen
        case .fullyOpen: self = .fullyOpen
        default: self = .unknown
        }
    }

    init(_ status: UIHinge.Status) {
        switch status {
        case .closed: self = .closed
        case .partiallyOpen: self = .partiallyOpen
        case .fullyOpen: self = .fullyOpen
        case .unknown: self = .unknown
        @unknown default: self = .unknown
        }
    }

    var label: String {
        switch self {
        case .unknown: "unknown"
        case .closed: "closed"
        case .partiallyOpen: "partiallyOpen"
        case .fullyOpen: "fullyOpen"
        }
    }

    var color: Color {
        switch self {
        case .unknown: .gray
        case .closed: .red
        case .partiallyOpen: .orange
        case .fullyOpen: .green
        }
    }
}

/// 姿勢ごとに初回訪問時の計測値を記録する。
struct PostureRecord: Codable, Hashable {
    var date: Date
    var hSizeClass: String
    var vSizeClass: String
    var windowSize: CGSize
    var safeArea: RectInsets
    var orientation: String
    var hingeStatus: HingeStatusValue?
    var hingeAngle: Double?
    var divisionFrames: [CGRect]
    var occlusionFrames: [CGRect]
}

struct RectInsets: Codable, Hashable {
    var top: Double
    var leading: Double
    var bottom: Double
    var trailing: Double

    init(_ e: EdgeInsets) {
        top = e.top; leading = e.leading; bottom = e.bottom; trailing = e.trailing
    }
    init(_ e: UIEdgeInsets) {
        top = e.top; leading = e.left; bottom = e.bottom; trailing = e.right
    }
    var edgeInsets: EdgeInsets { .init(top: top, leading: leading, bottom: bottom, trailing: trailing) }
    var summary: String { "T\(top.pt) L\(leading.pt) B\(bottom.pt) R\(trailing.pt)" }
}

extension Double {
    /// pt 表示用の短い書式。
    var pt: String {
        self == self.rounded() ? String(Int(self)) : String(format: "%.1f", self)
    }
}

extension CGFloat {
    var pt: String { Double(self).pt }
}

extension CGRect {
    var summary: String { "x\(minX.pt) y\(minY.pt) w\(width.pt) h\(height.pt)" }
}

extension CGSize {
    var summary: String { "\(width.pt)×\(height.pt)" }
}

extension UIInterfaceOrientation {
    var label: String {
        switch self {
        case .portrait: "portrait"
        case .portraitUpsideDown: "portraitUpsideDown"
        case .landscapeLeft: "landscapeLeft"
        case .landscapeRight: "landscapeRight"
        case .unknown: "unknown"
        @unknown default: "?"
        }
    }
}

extension UserInterfaceSizeClass {
    var label: String {
        switch self {
        case .compact: "compact"
        case .regular: "regular"
        @unknown default: "?"
        }
    }
    var short: String { self == .compact ? "C" : "R" }
}

extension Optional where Wrapped == UserInterfaceSizeClass {
    var label: String { self?.label ?? "nil" }
    var short: String { self?.short ?? "–" }
}
