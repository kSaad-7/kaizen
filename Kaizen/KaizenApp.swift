import AppKit
import SwiftUI

@main
struct KaizenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView()
                .environmentObject(appDelegate.sessionManager)
        } label: {
            MenuBarLabel()
                .environmentObject(appDelegate.sessionManager)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @EnvironmentObject private var sessionManager: SessionManager

    var body: some View {
        let active = sessionManager.hasActiveSession
        Image(nsImage: MenuBarIcon.image(active: active))
            .renderingMode(.original)
            .id(active)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let sessionManager = SessionManager()
    private var overlays: OverlayCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let coordinator = OverlayCoordinator(sessionManager: sessionManager)
        overlays = coordinator
        coordinator.start()
    }
}
