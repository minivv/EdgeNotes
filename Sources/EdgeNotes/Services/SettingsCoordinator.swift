import AppKit
import SwiftUI

@MainActor
final class SettingsCoordinator: ObservableObject {
  private weak var store: NotesStore?
  private weak var backupService: GistBackupService?
  private weak var panelCoordinator: EdgePanelCoordinator?
  private weak var onboardingCoordinator: OnboardingCoordinator?
  private weak var cliService: EdgeNotesCLIService?
  private var window: NSWindow?

  var isWindowVisible: Bool {
    window?.isVisible == true
  }

  func configure(
    store: NotesStore,
    backupService: GistBackupService,
    panelCoordinator: EdgePanelCoordinator,
    onboardingCoordinator: OnboardingCoordinator,
    cliService: EdgeNotesCLIService
  ) {
    self.store = store
    self.backupService = backupService
    self.panelCoordinator = panelCoordinator
    self.onboardingCoordinator = onboardingCoordinator
    self.cliService = cliService
  }

  func show() {
    guard let store,
          let backupService,
          let panelCoordinator,
          let onboardingCoordinator,
          let cliService
    else { return }
    panelCoordinator.showPinnedForSettingsPreview()

    if let window {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 820, height: 680),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.title = "EdgeNotes 设置"
    window.minSize = NSSize(width: 820, height: 640)
    window.center()
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(
      rootView: SettingsView()
        .environmentObject(store)
        .environmentObject(backupService)
        .environmentObject(panelCoordinator)
        .environmentObject(onboardingCoordinator)
        .environmentObject(cliService)
    )
    self.window = window
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  func close() {
    window?.close()
  }
}
