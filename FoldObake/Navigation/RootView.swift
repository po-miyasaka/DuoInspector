import SwiftUI

struct RootView: View {
    @Environment(DuoState.self) private var state
    @AppStorage("navStyle") private var navStyle: NavStyle = .tab

    var body: some View {
        @Bindable var state = state
        Group {
            switch navStyle {
            case .tab: RootTabView(selection: $state.selectedScreen)
            case .split: RootSplitView(selection: $state.selectedScreen)
            case .bare: RootBareView(selection: $state.selectedScreen)
            }
        }
        .duoProbe()
        .task { if state.demoMode { await runDemoTour() } }
        .overlay {
            if state.overlayEnabled || state.selectedScreen == .overlay {
                RegionOverlay()
            }
        }
    }
}

extension RootView {
    /// 起動引数 demo=1 のときに画面・オプションを自動で切替える（録画用）
    func runDemoTour() async {
        func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
        func go(_ screen: Screen) { withAnimation { state.selectedScreen = screen } }
        navStyle = .tab
        state.overlayEnabled = false
        await wait(1)
        // Overlay: オプションを順に ON
        go(.overlay)
        await wait(1.5)
        withAnimation { state.overlayOptions.showGrid = true }; await wait(1.2)
        withAnimation { state.overlayOptions.showEffectiveRect = true }; await wait(1.2)
        withAnimation { state.overlayOptions.showNaiveRect = true }; await wait(1.5)
        withAnimation { state.overlayOptions.showGrid = false; state.overlayOptions.showNaiveRect = false; state.overlayOptions.showEffectiveRect = false }
        await wait(0.8)
        go(.hinge); await wait(3)
        // Arrangement: スタイルを順に
        go(.arrangement); await wait(1.2)
        for style in ArrangementStyleChoice.allCases {
            withAnimation { state.arrangementStyle = style }; await wait(1.3)
        }
        withAnimation { state.arrangementFramework = 1 }; await wait(1)
        for style in ArrangementStyleChoice.allCases {
            withAnimation { state.arrangementStyle = style }; await wait(1.2)
        }
        withAnimation { state.arrangementFramework = 0; state.arrangementStyle = .split }
        go(.sizeClass); await wait(2.5)
        go(.toolbar); await wait(2.5)
        go(.customUI); await wait(2.5)
        go(.scene); await wait(2)
        go(.export); await wait(2)
        // ナビ切替 + 全画面オーバーレイ
        go(.overlay); await wait(0.8)
        withAnimation { state.overlayEnabled = true }; await wait(0.8)
        go(.hinge); await wait(1.5)
        withAnimation { navStyle = .split }; await wait(2.5)
        withAnimation { navStyle = .bare }; await wait(2.5)
        withAnimation { navStyle = .tab; state.overlayEnabled = false }
        go(.overlay)
        state.demoMode = false
    }
}

/// 各画面の共通ツールバー: ナビ切替・オーバーレイ切替・Size Class バッジ
struct CommonToolbar: ToolbarContent {
    @Environment(DuoState.self) private var state
    @AppStorage("navStyle") private var navStyle: NavStyle = .tab

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            SizeClassBadge(h: state.hSizeClass, v: state.vSizeClass)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("ナビ", selection: $navStyle) {
                    ForEach(NavStyle.allCases) { s in Label(s.title, systemImage: s.symbol).tag(s) }
                }
                Toggle(isOn: Binding(get: { state.overlayEnabled }, set: { state.overlayEnabled = $0 })) {
                    Label("全画面にオーバーレイ", systemImage: "square.stack.3d.up")
                }
            } label: {
                Image(systemName: "gearshape")
            }
        }
    }
}

struct RootTabView: View {
    @Binding var selection: Screen

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Screen.allCases) { screen in
                Tab(screen.title, systemImage: screen.symbol, value: screen) {
                    NavigationStack {
                        screen.view
                            .navigationTitle(screen.longTitle)
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar { CommonToolbar() }
                    }
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }
}

struct RootSplitView: View {
    @Binding var selection: Screen

    var body: some View {
        NavigationSplitView {
            List(Screen.allCases, selection: Binding<Screen?>(get: { selection }, set: { if let s = $0 { selection = s } })) { screen in
                Label(screen.longTitle, systemImage: screen.symbol).tag(screen)
            }
            .navigationTitle("FoldObake")
        } detail: {
            NavigationStack {
                selection.view
                    .navigationTitle(selection.longTitle)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { CommonToolbar() }
            }
        }
    }
}

/// ナビゲーションの chrome を一切使わないモード。タブバー/ナビバーの影響を除いた素の値を観察する。
struct RootBareView: View {
    @Binding var selection: Screen
    @Environment(DuoState.self) private var state
    @AppStorage("navStyle") private var navStyle: NavStyle = .tab
    @State private var showPicker = false

    var body: some View {
        selection.view
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 8) {
                    SizeClassBadge(h: state.hSizeClass, v: state.vSizeClass)
                    Button {
                        showPicker = true
                    } label: {
                        Image(systemName: selection.symbol)
                            .font(.title3)
                            .padding(12)
                            .background(.regularMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
            }
            .sheet(isPresented: $showPicker) {
                NavigationStack {
                    List {
                        Section("画面") {
                            ForEach(Screen.allCases) { screen in
                                Button {
                                    selection = screen
                                    showPicker = false
                                } label: {
                                    Label(screen.longTitle, systemImage: screen.symbol)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                        Section("ナビ") {
                            Picker("ナビ", selection: $navStyle) {
                                ForEach(NavStyle.allCases) { s in Label(s.title, systemImage: s.symbol).tag(s) }
                            }
                            .pickerStyle(.inline)
                            .labelsHidden()
                            Toggle(isOn: Binding(get: { state.overlayEnabled }, set: { state.overlayEnabled = $0 })) {
                                Label("全画面にオーバーレイ", systemImage: "square.stack.3d.up")
                            }
                        }
                    }
                    .navigationTitle("FoldObake")
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { showPicker = false } } }
                }
                .presentationDetents([.medium, .large])
            }
    }
}
