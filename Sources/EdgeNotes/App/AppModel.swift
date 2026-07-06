import Foundation

@MainActor
final class AppModel: ObservableObject {
  let store: NotesStore
  let panelCoordinator: EdgePanelCoordinator
  let backupService: GistBackupService
  let onboardingCoordinator: OnboardingCoordinator
  let statusBarController: StatusBarController
  let settingsCoordinator: SettingsCoordinator

  init() {
    store = NotesStore()
    panelCoordinator = EdgePanelCoordinator()
    backupService = GistBackupService()
    onboardingCoordinator = OnboardingCoordinator()
    statusBarController = StatusBarController()
    settingsCoordinator = SettingsCoordinator()

    panelCoordinator.configure(store: store, settingsCoordinator: settingsCoordinator)
    backupService.configure(store: store)
    settingsCoordinator.configure(
      store: store,
      backupService: backupService,
      panelCoordinator: panelCoordinator,
      onboardingCoordinator: onboardingCoordinator
    )
    onboardingCoordinator.configure(store: store, panelCoordinator: panelCoordinator)
    statusBarController.configure(
      panelCoordinator: panelCoordinator,
      settingsCoordinator: settingsCoordinator
    )

    DispatchQueue.main.async { [onboardingCoordinator] in
      onboardingCoordinator.showIfNeeded()
    }
  }
}
