import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
  private weak var panelCoordinator: EdgePanelCoordinator?
  private weak var settingsCoordinator: SettingsCoordinator?
  private var statusItem: NSStatusItem?
  private let menu = NSMenu()

  func configure(
    panelCoordinator: EdgePanelCoordinator,
    settingsCoordinator: SettingsCoordinator
  ) {
    self.panelCoordinator = panelCoordinator
    self.settingsCoordinator = settingsCoordinator
    menu.delegate = self
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(defaultsChanged),
      name: UserDefaults.didChangeNotification,
      object: nil
    )
    updateStatusItem()
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    rebuildMenu(menu)
  }

  private func updateStatusItem() {
    if isMenuBarIconVisible {
      if statusItem == nil {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "EdgeNotes") {
          image.isTemplate = true
          statusItem?.button?.image = image
        } else {
          statusItem?.button?.title = "E"
        }
        statusItem?.button?.imagePosition = .imageOnly
      }
      statusItem?.menu = menu
      rebuildMenu(menu)
    } else if let statusItem {
      NSStatusBar.system.removeStatusItem(statusItem)
      self.statusItem = nil
    }
  }

  private var isMenuBarIconVisible: Bool {
    guard UserDefaults.standard.object(forKey: AppPreferences.Key.menuBarIconVisible) != nil else {
      return true
    }
    return UserDefaults.standard.bool(forKey: AppPreferences.Key.menuBarIconVisible)
  }

  private func rebuildMenu(_ menu: NSMenu) {
    menu.removeAllItems()
    menu.addItem(menuItem("显示侧边栏", action: #selector(showPanel)))
    menu.addItem(menuItem("设置", action: #selector(openSettings)))
    menu.addItem(menuItem("退出 EdgeNotes", action: #selector(quit)))
  }

  private func menuItem(_ title: String, action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    return item
  }

  @objc private func defaultsChanged() {
    updateStatusItem()
  }

  @objc private func showPanel() {
    panelCoordinator?.showPanel(activate: true)
  }

  @objc private func openSettings() {
    settingsCoordinator?.show()
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }
}
