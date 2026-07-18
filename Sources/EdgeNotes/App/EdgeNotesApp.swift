import AppKit
import SwiftUI

@main
struct EdgeNotesApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var model = AppModel()

  var body: some Scene {
    Settings {
      SettingsView()
        .environmentObject(model.store)
        .environmentObject(model.backupService)
        .environmentObject(model.panelCoordinator)
        .environmentObject(model.onboardingCoordinator)
        .environmentObject(model.cliService)
    }
  }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }
}
