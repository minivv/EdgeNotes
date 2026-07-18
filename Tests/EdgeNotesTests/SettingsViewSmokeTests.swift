import AppKit
import XCTest
@testable import EdgeNotes

final class SettingsViewSmokeTests: XCTestCase {
  @MainActor
  func testSettingsCoordinatorOpensWindowWithEveryRequiredEnvironmentObject() {
    _ = NSApplication.shared
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let store = NotesStore(storeURL: directory.appendingPathComponent("notes.json"))
    let backupService = GistBackupService()
    let panelCoordinator = EdgePanelCoordinator()
    let onboardingCoordinator = OnboardingCoordinator()
    let cliService = EdgeNotesCLIService(store: store, panelCoordinator: panelCoordinator)
    let settingsCoordinator = SettingsCoordinator()
    let savedPinnedValue = UserDefaults.standard.object(forKey: AppPreferences.Key.panelPinned)
    defer {
      settingsCoordinator.close()
      panelCoordinator.hidePanel()
      if let savedPinnedValue {
        UserDefaults.standard.set(savedPinnedValue, forKey: AppPreferences.Key.panelPinned)
      } else {
        UserDefaults.standard.removeObject(forKey: AppPreferences.Key.panelPinned)
      }
      try? FileManager.default.removeItem(at: directory)
    }

    panelCoordinator.configure(store: store, settingsCoordinator: settingsCoordinator)
    settingsCoordinator.configure(
      store: store,
      backupService: backupService,
      panelCoordinator: panelCoordinator,
      onboardingCoordinator: onboardingCoordinator,
      cliService: cliService
    )

    settingsCoordinator.show()
    RunLoop.main.run(until: Date().addingTimeInterval(0.05))

    XCTAssertTrue(settingsCoordinator.isWindowVisible)
    XCTAssertTrue(NSApp.windows.contains(where: { $0.title == "EdgeNotes 设置" && $0.isVisible }))
  }
}
