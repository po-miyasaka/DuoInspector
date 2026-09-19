import SwiftUI

enum Screen: String, CaseIterable, Identifiable, Codable {
    case overlay, hinge, arrangement, sizeClass, toolbar, customUI, scene, export

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overlay: "Overlay"
        case .hinge: "Hinge"
        case .arrangement: "Arrangement"
        case .sizeClass: "図鑑"
        case .toolbar: "Toolbar"
        case .customUI: "Custom UI"
        case .scene: "Scene"
        case .export: "Export"
        }
    }

    var longTitle: String {
        switch self {
        case .overlay: "Overlay Inspector"
        case .hinge: "Hinge Monitor"
        case .arrangement: "Arrangement Playground"
        case .sizeClass: "Size Class 図鑑"
        case .toolbar: "Toolbar Lab"
        case .customUI: "Custom UI Sandbox"
        case .scene: "Scene Lab"
        case .export: "Export"
        }
    }

    var symbol: String {
        switch self {
        case .overlay: "square.stack.3d.up"
        case .hinge: "arrow.left.and.right.righttriangle.left.righttriangle.right"
        case .arrangement: "rectangle.split.2x1"
        case .sizeClass: "book.closed"
        case .toolbar: "slider.horizontal.below.rectangle"
        case .customUI: "paintbrush.pointed"
        case .scene: "macwindow.on.rectangle"
        case .export: "square.and.arrow.up"
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .overlay: OverlayInspectorView()
        case .hinge: HingeMonitorView()
        case .arrangement: ArrangementPlaygroundView()
        case .sizeClass: SizeClassMatrixView()
        case .toolbar: ToolbarLabView()
        case .customUI: CustomUISandboxView()
        case .scene: SceneLabView()
        case .export: ExportView()
        }
    }
}

enum NavStyle: String, CaseIterable, Identifiable {
    case tab, split, bare
    var id: String { rawValue }
    var title: String {
        switch self {
        case .tab: "TabView"
        case .split: "NavigationSplitView"
        case .bare: "なし (bare)"
        }
    }
    var symbol: String {
        switch self {
        case .tab: "rectangle.bottomthird.inset.filled"
        case .split: "sidebar.leading"
        case .bare: "rectangle"
        }
    }
}
