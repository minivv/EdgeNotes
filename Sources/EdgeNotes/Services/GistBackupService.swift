import Combine
import Foundation

@MainActor
final class GistBackupService: ObservableObject {
  @Published private(set) var isBackingUp = false
  @Published private(set) var lastStatus = "Backup is not configured."
  @Published private(set) var lastBackupDate: Date?
  @Published private(set) var lastGistURL: URL?

  private let client = GistClient()
  private weak var store: NotesStore?
  private var timer: Timer?

  func configure(store: NotesStore) {
    self.store = store
    reschedule()
  }

  func reschedule() {
    timer?.invalidate()
    timer = nil

    guard BackupSettings.autoEnabled else {
      if !isBackingUp {
        lastStatus = "Automatic backup is off."
      }
      return
    }

    guard !BackupSettings.token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      lastStatus = "Add a GitHub token to enable automatic backup."
      return
    }

    let interval = max(300, BackupSettings.intervalMinutes * 60)
    timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in
        await self?.backupNow()
      }
    }
    lastStatus = "Next automatic backup is scheduled."
  }

  func backupNow() async {
    guard !isBackingUp else { return }
    guard let store else {
      lastStatus = "Notes store is not ready."
      return
    }

    let token = BackupSettings.token.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !token.isEmpty else {
      lastStatus = "GitHub token is missing."
      return
    }

    isBackingUp = true
    defer { isBackingUp = false }

    do {
      let data = try store.exportBackupData()
      guard let content = String(data: data, encoding: .utf8) else {
        lastStatus = "Could not encode backup JSON."
        return
      }

      let result = try await client.upsertBackup(
        token: token,
        gistID: BackupSettings.gistID,
        filename: BackupSettings.filename,
        content: content
      )

      UserDefaults.standard.set(result.gistID, forKey: BackupSettings.Key.gistID)
      lastBackupDate = Date()
      lastGistURL = result.htmlURL
      lastStatus = "Backup completed."
    } catch {
      lastStatus = error.localizedDescription
    }
  }

  deinit {
    timer?.invalidate()
  }
}
