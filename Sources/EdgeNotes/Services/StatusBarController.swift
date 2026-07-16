import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
  private weak var panelCoordinator: EdgePanelCoordinator?
  private weak var settingsCoordinator: SettingsCoordinator?
  private weak var updateService: AppUpdateService?
  private var statusItem: NSStatusItem?
  private let menu = NSMenu()

  func configure(
    panelCoordinator: EdgePanelCoordinator,
    settingsCoordinator: SettingsCoordinator,
    updateService: AppUpdateService
  ) {
    self.panelCoordinator = panelCoordinator
    self.settingsCoordinator = settingsCoordinator
    self.updateService = updateService
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
    let versionItem = NSMenuItem(title: AppUpdateService.versionMenuTitle, action: nil, keyEquivalent: "")
    versionItem.isEnabled = false
    menu.addItem(versionItem)
    menu.addItem(.separator())
    menu.addItem(menuItem("显示侧边栏", action: #selector(showPanel)))
    menu.addItem(menuItem("检查更新", action: #selector(checkForUpdates)))
    menu.addItem(menuItem("反馈问题", action: #selector(openFeedback)))
    menu.addItem(menuItem("设置", action: #selector(openSettings)))
    menu.addItem(.separator())
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

  @objc private func checkForUpdates() {
    updateService?.checkForUpdates(manual: true)
  }

  @objc private func openFeedback() {
    updateService?.openFeedback()
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }
}
