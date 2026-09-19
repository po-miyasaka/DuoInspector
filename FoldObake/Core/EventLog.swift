import Foundation

/// ログの種類。フィルタ用。
enum EventKind: String, CaseIterable, Identifiable, Codable {
    case hinge        // SwiftUI onHingeChange
    case uikitHinge   // UIKit UIHingeInteraction
    case sizeClass
    case region       // reservedRegions の変化
    case size         // ルートサイズ変化
    case safeArea
    case orientation
    case scene
    case posture

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hinge: "Hinge(SwiftUI)"
        case .uikitHinge: "Hinge(UIKit)"
        case .sizeClass: "SizeClass"
        case .region: "Region"
        case .size: "Size"
        case .safeArea: "SafeArea"
        case .orientation: "Orientation"
        case .scene: "Scene"
        case .posture: "Posture"
        }
    }

    var symbol: String {
        switch self {
        case .hinge: "arrow.left.and.right.righttriangle.left.righttriangle.right"
        case .uikitHinge: "u.square"
        case .sizeClass: "rectangle.split.2x1"
        case .region: "rectangle.dashed"
        case .size: "arrow.up.left.and.arrow.down.right"
        case .safeArea: "rectangle.inset.filled"
        case .orientation: "rotate.right"
        case .scene: "macwindow.on.rectangle"
        case .posture: "iphone.gen3"
        }
    }
}

struct EventEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let date: Date
    let kind: EventKind
    let message: String

    init(kind: EventKind, message: String, date: Date = .now) {
        self.id = UUID()
        self.date = date
        self.kind = kind
        self.message = message
    }
}
