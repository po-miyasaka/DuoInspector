import SwiftUI

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = DuoState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(state)
        }
        // Scene Lab から openWindow(id:) で開く補助ウィンドウ
        WindowGroup(id: "aux") {
            AuxWindowView()
        }
    }
}
