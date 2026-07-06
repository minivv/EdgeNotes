import Foundation

enum BackupSettings {
  enum Key {
    static let autoEnabled = "backup.autoEnabled"
    static let token = "backup.githubToken"
    static let gistID = "backup.gistID"
    static let filename = "backup.filename"
    static let intervalMinutes = "backup.intervalMinutes"
  }

  static var autoEnabled: Bool {
    UserDefaults.standard.bool(forKey: Key.autoEnabled)
  }

  static var token: String {
    UserDefaults.standard.string(forKey: Key.token) ?? ""
  }

  static var gistID: String {
    UserDefaults.standard.string(forKey: Key.gistID) ?? ""
  }

  static var filename: String {
    let value = UserDefaults.standard.string(forKey: Key.filename) ?? ""
    return value.isEmpty ? "edgenotes-backup.json" : value
  }

  static var intervalMinutes: Double {
    let value = UserDefaults.standard.double(forKey: Key.intervalMinutes)
    return value > 0 ? value : 30
  }
}
