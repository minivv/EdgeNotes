import AppKit
import Foundation

@MainActor
final class AppUpdateService {
  private enum Constants {
    static let latestReleaseURL = URL(string: "https://api.github.com/repos/minivv/EdgeNotes/releases/latest")!
    static let feedbackURL = URL(string: "https://weispot.vercel.app/projects/edgenotes#feedback")!
    static let releaseAssetName = "EdgeNotes-macOS.zip"
    static let appName = "EdgeNotes"
  }

  private var isChecking = false

  static var currentVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
  }

  static var versionMenuTitle: String {
    "EdgeNotes \(currentVersion)"
  }

  func checkForUpdatesIfNeeded() {
    guard shouldRunDailyCheck else { return }
    checkForUpdates(manual: false)
  }

  func checkForUpdates(manual: Bool) {
    guard !isChecking else {
      if manual {
        showMessage(title: "正在检查更新", message: "EdgeNotes 正在连接 GitHub Releases。")
      }
      return
    }

    isChecking = true
    Task {
      defer { isChecking = false }
      do {
        let release = try await fetchLatestRelease()
        markDailyCheckCompleted()
        handle(release: release, manual: manual)
      } catch {
        if manual {
          showMessage(title: "检查更新失败", message: error.localizedDescription)
        }
      }
    }
  }

  func openFeedback() {
    NSWorkspace.shared.open(Constants.feedbackURL)
  }

  private var shouldRunDailyCheck: Bool {
    guard let lastCheck = UserDefaults.standard.object(forKey: AppPreferences.Key.lastUpdateCheck) as? Date else {
      return true
    }
    return Date().timeIntervalSince(lastCheck) >= 24 * 60 * 60
  }

  private func markDailyCheckCompleted() {
    UserDefaults.standard.set(Date(), forKey: AppPreferences.Key.lastUpdateCheck)
  }

  private func fetchLatestRelease() async throws -> GitHubRelease {
    var request = URLRequest(url: Constants.latestReleaseURL)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("EdgeNotes", forHTTPHeaderField: "User-Agent")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
          (200..<300).contains(httpResponse.statusCode)
    else {
      throw UpdateError.invalidResponse
    }
    return try JSONDecoder().decode(GitHubRelease.self, from: data)
  }

  private func handle(release: GitHubRelease, manual: Bool) {
    let current = SemanticVersion(AppUpdateService.currentVersion)
    let latest = SemanticVersion(release.versionString)

    guard latest > current else {
      if manual {
        showMessage(
          title: "已经是最新版本",
          message: "当前版本是 \(AppUpdateService.currentVersion)，GitHub 最新版本是 \(release.tagName)。"
        )
      }
      return
    }

    presentUpdateAlert(for: release)
  }

  private func presentUpdateAlert(for release: GitHubRelease) {
    NSApp.activate(ignoringOtherApps: true)

    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = "EdgeNotes \(release.versionString) 可用"
    alert.informativeText = releaseNotesText(for: release)

    if release.macOSAsset != nil {
      alert.addButton(withTitle: "自动升级")
    }
    alert.addButton(withTitle: "打开 Release")
    alert.addButton(withTitle: "稍后")

    let response = alert.runModal()
    if release.macOSAsset != nil, response == .alertFirstButtonReturn {
      Task {
        await downloadAndInstall(release)
      }
      return
    }

    let openReleaseResponse: NSApplication.ModalResponse = release.macOSAsset == nil
      ? .alertFirstButtonReturn
      : .alertSecondButtonReturn
    if response == openReleaseResponse {
      NSWorkspace.shared.open(release.htmlURL)
    }
  }

  private func releaseNotesText(for release: GitHubRelease) -> String {
    let body = (release.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let notes = body.isEmpty ? "这个版本没有填写 release notes。" : body
    let truncatedNotes = notes.count > 4000 ? String(notes.prefix(4000)) + "\n\n..." : notes
    return "当前版本：\(AppUpdateService.currentVersion)\n最新版本：\(release.tagName)\n\n\(truncatedNotes)"
  }

  private func downloadAndInstall(_ release: GitHubRelease) async {
    guard let asset = release.macOSAsset else {
      NSWorkspace.shared.open(release.htmlURL)
      return
    }

    do {
      let newAppURL = try await downloadAndExtract(asset: asset)
      try installAndRelaunch(newAppURL: newAppURL)
    } catch {
      showMessage(title: "自动升级失败", message: error.localizedDescription)
    }
  }

  private func downloadAndExtract(asset: GitHubReleaseAsset) async throws -> URL {
    let fileManager = FileManager.default
    let tempDirectory = fileManager.temporaryDirectory
      .appendingPathComponent("EdgeNotesUpdate-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

    let (downloadURL, _) = try await URLSession.shared.download(from: asset.downloadURL)
    let zipURL = tempDirectory.appendingPathComponent(Constants.releaseAssetName)
    try fileManager.moveItem(at: downloadURL, to: zipURL)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    process.arguments = ["-x", "-k", zipURL.path, tempDirectory.path]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw UpdateError.unzipFailed
    }

    let appURL = tempDirectory.appendingPathComponent("\(Constants.appName).app", isDirectory: true)
    guard fileManager.fileExists(atPath: appURL.path) else {
      throw UpdateError.appBundleNotFound
    }
    return appURL
  }

  private func installAndRelaunch(newAppURL: URL) throws {
    let currentAppURL = Bundle.main.bundleURL
    guard currentAppURL.pathExtension == "app" else {
      throw UpdateError.notRunningFromAppBundle
    }

    let parentDirectory = currentAppURL.deletingLastPathComponent()
    guard FileManager.default.isWritableFile(atPath: parentDirectory.path) else {
      throw UpdateError.installLocationNotWritable
    }

    let scriptURL = newAppURL.deletingLastPathComponent().appendingPathComponent("install-edgenotes-update.sh")
    let script = """
    #!/bin/zsh
    set -e

    current_app="$1"
    new_app="$2"
    app_name="\(Constants.appName)"
    temp_app="${current_app}.updating"

    for _ in {1..80}; do
      if ! /usr/bin/pgrep -x "$app_name" >/dev/null; then
        break
      fi
      /bin/sleep 0.25
    done

    /bin/rm -rf "$temp_app"
    /usr/bin/ditto "$new_app" "$temp_app"
    /bin/rm -rf "$current_app"
    /bin/mv "$temp_app" "$current_app"
    /usr/bin/open "$current_app"
    /bin/rm -rf "$(dirname "$new_app")"
    """
    try script.write(to: scriptURL, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.arguments = [scriptURL.path, currentAppURL.path, newAppURL.path]
    try process.run()
    NSApp.terminate(nil)
  }

  private func showMessage(title: String, message: String) {
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = title
    alert.informativeText = message
    alert.addButton(withTitle: "好")
    alert.runModal()
  }
}

private struct GitHubRelease: Decodable {
  var tagName: String
  var name: String?
  var body: String?
  var htmlURL: URL
  var assets: [GitHubReleaseAsset]

  var versionString: String {
    tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
  }

  var macOSAsset: GitHubReleaseAsset? {
    assets.first { $0.name == "EdgeNotes-macOS.zip" }
  }

  enum CodingKeys: String, CodingKey {
    case tagName = "tag_name"
    case name
    case body
    case htmlURL = "html_url"
    case assets
  }
}

private struct GitHubReleaseAsset: Decodable {
  var name: String
  var downloadURL: URL

  enum CodingKeys: String, CodingKey {
    case name
    case downloadURL = "browser_download_url"
  }
}

private enum UpdateError: LocalizedError {
  case invalidResponse
  case unzipFailed
  case appBundleNotFound
  case notRunningFromAppBundle
  case installLocationNotWritable

  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      return "GitHub Releases 返回了无效响应。"
    case .unzipFailed:
      return "无法解压更新包。"
    case .appBundleNotFound:
      return "更新包里没有找到 EdgeNotes.app。"
    case .notRunningFromAppBundle:
      return "当前不是从 EdgeNotes.app 启动，无法自动替换应用。"
    case .installLocationNotWritable:
      return "当前应用所在目录不可写。请打开 Release 页面手动下载并替换应用。"
    }
  }
}

private struct SemanticVersion: Comparable {
  var parts: [Int]

  init(_ rawValue: String) {
    let normalized = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
    parts = normalized
      .split(separator: ".")
      .map { component in
        let digits = component.prefix { $0.isNumber }
        return Int(digits) ?? 0
      }
  }

  static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
    let count = max(lhs.parts.count, rhs.parts.count)
    for index in 0..<count {
      let left = index < lhs.parts.count ? lhs.parts[index] : 0
      let right = index < rhs.parts.count ? rhs.parts[index] : 0
      if left != right {
        return left < right
      }
    }
    return false
  }
}
