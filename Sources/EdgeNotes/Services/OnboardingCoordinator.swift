import AppKit
import SwiftUI

@MainActor
final class OnboardingCoordinator: ObservableObject {
  private var window: NSWindow?
  private weak var store: NotesStore?
  private weak var panelCoordinator: EdgePanelCoordinator?

  func configure(store: NotesStore, panelCoordinator: EdgePanelCoordinator) {
    self.store = store
    self.panelCoordinator = panelCoordinator
  }

  func showIfNeeded() {
    guard !AppPreferences.didCompleteOnboarding else { return }
    show()
  }

  func show() {
    guard let store, let panelCoordinator else { return }

    if let window {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 900, height: 560),
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.title = "EdgeNotes 设置"
    window.center()
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.level = .floating
    window.isMovableByWindowBackground = true
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(
      rootView: OnboardingView(
        onFinish: { [weak self] in
          self?.finish()
        },
        onOpenPanel: {
          panelCoordinator.showPanel(activate: true)
        }
      )
      .environmentObject(store)
      .environmentObject(panelCoordinator)
    )
    self.window = window
    window.makeKeyAndOrderFront(nil)
    window.orderFrontRegardless()
    NSApp.activate(ignoringOtherApps: true)
  }

  private func finish() {
    AppPreferences.didCompleteOnboarding = true
    window?.close()
    window = nil
    panelCoordinator?.refreshFromSettings()
  }
}
