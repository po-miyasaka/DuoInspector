import SwiftUI
import UIKit

struct SceneLabView: View {
    @Environment(DuoState.self) private var state
    @Environment(\.openWindow) private var openWindow
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @State private var results: [String] = []
    @State private var accessoryRegistration: UISceneAccessoryRegistration?
    @State private var tick = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                SectionCard(title: "Scene の状態", symbol: "macwindow.on.rectangle") {
                    InfoRow("supportsMultipleWindows (SwiftUI)", supportsMultipleWindows ? "true" : "false", color: supportsMultipleWindows ? .green : .red)
                    InfoRow("supportsMultipleScenes (UIKit)", UIApplication.shared.supportsMultipleScenes ? "true" : "false")
                    InfoRow("connectedScenes", "\(UIApplication.shared.connectedScenes.count)")
                    InfoRow("openSessions", "\(UIApplication.shared.openSessions.count)")
                    ForEach(Array(UIApplication.shared.connectedScenes.enumerated()), id: \.offset) { _, scene in
                        let ws = scene as? UIWindowScene
                        VStack(alignment: .leading, spacing: 2) {
                            Text("• \(scene.session.role.rawValue)").font(.caption.bold())
                            Text("  state: \(activationLabel(scene.activationState))  screen: \(ws?.screen.bounds.size.summary ?? "-")  windows: \(ws?.windows.count ?? 0)")
                                .font(.system(size: 11, design: .monospaced))
                        }
                    }
                    Text("tick \(tick)").font(.caption2).foregroundStyle(.tertiary)
                }

                SectionCard(title: "新しい Scene を開く", symbol: "plus.rectangle.on.rectangle") {
                    Text("スライド: 内側ディスプレイではマルチシーン可、折り畳み状態（外側）では失敗する可能性。")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("openWindow(id: \"aux\")  (SwiftUI)", systemImage: "macwindow.badge.plus") {
                        openWindow(id: "aux")
                        log("openWindow(id: aux) 呼び出し")
                    }
                    .buttonStyle(.borderedProminent)
                    Button("activateSceneSession (UIKit)", systemImage: "u.square") {
                        let request = UISceneSessionActivationRequest(role: .windowApplication)
                        UIApplication.shared.activateSceneSession(for: request) { error in
                            Task { @MainActor in self.log("activateSceneSession error: \(error.localizedDescription)") }
                        }
                        log("activateSceneSession 呼び出し")
                    }
                    .buttonStyle(.bordered)
                }

                SectionCard(title: "外側ディスプレイ: UISceneAccessory", symbol: "rectangle.on.rectangle.angled") {
                    Text("externalNonInteractive の Scene Accessory を登録して、閉じた状態で外側ディスプレイに時計を出す実験。").font(.caption).foregroundStyle(.secondary)
                    InfoRow("registration", accessoryRegistration == nil ? "なし" : "登録済")
                    if let r = accessoryRegistration {
                        InfoRow("isAvailable", r.isAvailable ? "true" : "false", color: r.isAvailable ? .green : .red)
                        InfoRow("isEnabled", r.isEnabled ? "true" : "false")
                    }
                    HStack {
                        Button("登録", systemImage: "plus") { registerAccessory() }.buttonStyle(.borderedProminent)
                        Button("解除", systemImage: "minus") { unregisterAccessory() }.buttonStyle(.bordered).disabled(accessoryRegistration == nil)
                    }
                }

                SectionCard(title: "結果ログ", symbol: "list.bullet") {
                    if results.isEmpty { Text("まだなし").font(.caption).foregroundStyle(.secondary) }
                    ForEach(Array(results.enumerated()), id: \.offset) { _, s in
                        Text(s).font(.system(size: 11, design: .monospaced))
                    }
                    ForEach(state.log.filter { $0.kind == .scene }.prefix(20)) { e in
                        Text("[\(e.date.formatted(.dateTime.hour().minute().second()))] \(e.message)").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                tick += 1
            }
        }
    }

    private func log(_ s: String) {
        results.insert("[\(Date.now.formatted(.dateTime.hour().minute().second()))] \(s)", at: 0)
    }

    private func activationLabel(_ s: UIScene.ActivationState) -> String {
        switch s {
        case .unattached: "unattached"
        case .foregroundActive: "foregroundActive"
        case .foregroundInactive: "foregroundInactive"
        case .background: "background"
        @unknown default: "?"
        }
    }

    private func hostViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?.rootViewController
    }

    private func registerAccessory() {
        guard let vc = hostViewController() else { log("rootViewController が見つからない"); return }
        let config = UISceneConfiguration(name: AppDelegate.accessoryConfigName, sessionRole: .windowExternalDisplayNonInteractive)
        config.delegateClass = AccessorySceneDelegate.self
        let accessory = UISceneAccessory.externalNonInteractive(sceneConfiguration: config, userInfo: ["kind": "clock"])
        let reg = vc.registerSceneAccessory(accessory)
        accessoryRegistration = reg
        log("registerSceneAccessory → available=\(reg.isAvailable) enabled=\(reg.isEnabled)")
    }

    private func unregisterAccessory() {
        guard let reg = accessoryRegistration, let vc = hostViewController() else { return }
        vc.unregisterSceneAccessory(reg)
        accessoryRegistration = nil
        log("unregisterSceneAccessory")
    }
}

/// openWindow(id: "aux") で開く補助ウィンドウ。自分の Scene の geometry を表示する。
struct AuxWindowView: View {
    var body: some View {
        NavigationStack {
            LocalGeometryPanel(name: "Aux Scene", color: .teal)
                .padding()
                .navigationTitle("Aux Window")
        }
    }
}

// MARK: - AppDelegate / Scene delegate

final class AppDelegate: NSObject, UIApplicationDelegate {
    static let accessoryConfigName = "AccessoryScene"

    func application(_ application: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if options.sceneAccessoryUserInfo != nil || connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            let config = UISceneConfiguration(name: Self.accessoryConfigName, sessionRole: connectingSceneSession.role)
            config.delegateClass = AccessorySceneDelegate.self
            return config
        }
        return UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    }
}

/// 外側ディスプレイに出す非対話コンテンツ（時計）
final class AccessorySceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        w.rootViewController = UIHostingController(rootView: AccessoryClockView())
        w.makeKeyAndVisible()
        window = w
    }
}

struct AccessoryClockView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(ctx.date.formatted(date: .omitted, time: .standard))
                        .font(.system(size: 48, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                }
                Text("Scene Accessory (externalNonInteractive)").font(.caption).foregroundStyle(.gray)
                LocalGeometryPanel(name: "Accessory", color: .teal).frame(height: 220).padding()
            }
        }
    }
}
