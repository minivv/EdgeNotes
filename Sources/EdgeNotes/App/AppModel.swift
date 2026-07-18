import Foundation

@MainActor
final class AppModel: ObservableObject {
  let store: NotesStore
  let panelCoordinator: EdgePanelCoordinator
  let backupService: GistBackupService
  let onboardingCoordinator: OnboardingCoordinator
  let statusBarController: StatusBarController
  let settingsCoordinator: SettingsCoordinator
  let updateService: AppUpdateService
  let cliService: EdgeNotesCLIService

  init() {
    let notesStore = NotesStore()
    let edgePanelCoordinator = EdgePanelCoordinator()
    store = notesStore
    panelCoordinator = edgePanelCoordinator
    backupService = GistBackupService()
    onboardingCoordinator = OnboardingCoordinator()
    statusBarController = StatusBarController()
    settingsCoordinator = SettingsCoordinator()
    updateService = AppUpdateService()
    cliService = EdgeNotesCLIService(store: notesStore, panelCoordinator: edgePanelCoordinator)

    panelCoordinator.configure(store: store, settingsCoordinator: settingsCoordinator)
    backupService.configure(store: store)
    settingsCoordinator.configure(
      store: store,
      backupService: backupService,
      panelCoordinator: panelCoordinator,
      onboardingCoordinator: onboardingCoordinator,
      cliService: cliService
    )
    onboardingCoordinator.configure(store: store, panelCoordinator: panelCoordinator)
    statusBarController.configure(
      panelCoordinator: panelCoordinator,
      settingsCoordinator: settingsCoordinator,
      updateService: updateService
    )
    cliService.startIfInstalled()

    DispatchQueue.main.async { [onboardingCoordinator] in
      onboardingCoordinator.showIfNeeded()
    }
    DispatchQueue.main.async { [updateService] in
      updateService.checkForUpdatesIfNeeded()
    }
  }
}
