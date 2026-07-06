import AppKit
import SwiftUI

struct SettingsView: View {
  @EnvironmentObject private var store: NotesStore
  @EnvironmentObject private var backupService: GistBackupService
  @EnvironmentObject private var panelCoordinator: EdgePanelCoordinator
  @EnvironmentObject private var onboardingCoordinator: OnboardingCoordinator

  @AppStorage(EdgePanelSettings.Key.side) private var sideRaw = EdgeSide.right.rawValue
  @AppStorage(EdgePanelSettings.Key.screenPreference) private var screenPreference = ScreenPreference.main.rawValue
  @AppStorage(AppPreferences.Key.displaySpeed) private var displaySpeed = "standard"
  @AppStorage(AppPreferences.Key.menuBarIconVisible) private var menuBarIconVisible = true

  @AppStorage(AppPreferences.Key.themeName) private var themeName = "Edge"

  @AppStorage(AppPreferences.Key.newNoteLocation) private var newNoteLocation = "currentOrTop"
  @AppStorage(AppPreferences.Key.showVerticalScrollbars) private var showVerticalScrollbars = true

  @AppStorage(AppPreferences.Key.newFolderLocation) private var newFolderLocation = "bottom"
  @AppStorage(AppPreferences.Key.folderOpenMode) private var folderOpenMode = "single"

  @AppStorage(BackupSettings.Key.autoEnabled) private var autoBackupEnabled = false
  @AppStorage(BackupSettings.Key.token) private var githubToken = ""
  @AppStorage(BackupSettings.Key.gistID) private var gistID = ""
  @AppStorage(BackupSettings.Key.filename) private var filename = "edgenotes-backup.json"
  @AppStorage(BackupSettings.Key.intervalMinutes) private var intervalMinutes = 30.0

  var body: some View {
    TabView {
      generalTab
        .tabItem { Label("通用", systemImage: "gearshape") }

      appearanceTab
        .tabItem { Label("外观", systemImage: "paintpalette") }

      notesTab
        .tabItem { Label("笔记", systemImage: "note.text") }

      foldersTab
        .tabItem { Label("文件夹", systemImage: "folder") }

      backupTab
        .tabItem { Label("备份", systemImage: "arrow.triangle.2.circlepath") }

      dataTab
        .tabItem { Label("数据", systemImage: "externaldrive") }
    }
    .frame(width: 760, height: 600)
  }

  private var generalTab: some View {
    SettingsPage {
      SettingsSection(title: "窗口排列") {
        SettingsRow(title: "显示器") {
          Picker("", selection: $screenPreference) {
            Text("主显示器").tag(ScreenPreference.main.rawValue)
            Text("鼠标所在").tag(ScreenPreference.mouse.rawValue)
            ForEach(EdgeDisplayOptions.connectedDisplays) { display in
              Text(display.name).tag(display.id)
            }
          }
          .pickerStyle(.menu)
          .frame(width: 220)
          .onChange(of: screenPreference) { _, _ in
            panelCoordinator.refreshFromSettings()
          }
        }

        SettingsRow(title: "屏幕侧边") {
          HStack(spacing: 18) {
            SideSettingButton(side: .left, selected: sideRaw == EdgeSide.left.rawValue) {
              sideRaw = EdgeSide.left.rawValue
              panelCoordinator.refreshFromSettings()
            }
            SideSettingButton(side: .right, selected: sideRaw == EdgeSide.right.rawValue) {
              sideRaw = EdgeSide.right.rawValue
              panelCoordinator.refreshFromSettings()
            }
          }
        }
      }

      SettingsSection(title: "显示") {
        SettingsRow(title: "显示速度") {
          Picker("", selection: $displaySpeed) {
            Text("慢").tag("slow")
            Text("标准").tag("standard")
            Text("快").tag("fast")
          }
          .pickerStyle(.segmented)
          .frame(width: 180)
        }

        SettingsRow(title: "菜单栏图标") {
          Picker("", selection: $menuBarIconVisible) {
            Text("显示").tag(true)
            Text("隐藏").tag(false)
          }
          .pickerStyle(.segmented)
          .frame(width: 160)
        }
      }

      SettingsSection(title: "引导配置") {
        SettingsRow(title: "配置向导", detail: "重新选择显示器、侧边和基础显示选项。") {
          Button {
            AppPreferences.didCompleteOnboarding = false
            onboardingCoordinator.show()
          } label: {
            Text("重新打开")
          }
        }
      }
    }
  }

  private var appearanceTab: some View {
    SettingsPage {
      SettingsSection(title: "主题") {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(108), spacing: 18), count: 5), spacing: 18) {
          ForEach(ThemePreset.allCases) { theme in
            Button {
              themeName = theme.name
            } label: {
              VStack(spacing: 8) {
                ThemeCard(theme: theme)
                  .frame(width: 96, height: 58)
                  .overlay {
                    RoundedRectangle(cornerRadius: 10)
                      .stroke(themeName == theme.name ? Color.accentColor : Color.black.opacity(0.10), lineWidth: themeName == theme.name ? 2.5 : 1)
                  }
                Text(theme.name)
                  .font(.caption)
                  .lineLimit(1)
              }
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.vertical, 6)
      }
    }
  }

  private var notesTab: some View {
    SettingsPage {
      SettingsSection(title: "新笔记") {
        SettingsRow(title: "默认位置") {
          Picker("", selection: $newNoteLocation) {
            Text("当前笔记上方").tag("currentOrTop")
            Text("底部").tag("bottom")
          }
          .pickerStyle(.segmented)
          .frame(width: 220)
        }
      }

      SettingsSection(title: "笔记列表") {
        SettingsRow(title: "显示垂直滚动条") {
          Toggle("", isOn: $showVerticalScrollbars)
            .labelsHidden()
        }
      }
    }
  }

  private var foldersTab: some View {
    SettingsPage {
      SettingsSection(title: "新文件夹") {
        SettingsRow(title: "默认位置") {
          Picker("", selection: $newFolderLocation) {
            Text("顶部").tag("top")
            Text("底部").tag("bottom")
          }
          .pickerStyle(.segmented)
          .frame(width: 160)
        }
      }

      SettingsSection(title: "打开文件夹") {
        SettingsRow(title: "打开方式") {
          Picker("", selection: $folderOpenMode) {
            Text("单击").tag("single")
            Text("双击").tag("double")
          }
          .pickerStyle(.segmented)
          .frame(width: 160)
        }
      }
    }
  }

  private var backupTab: some View {
    SettingsPage {
      GistHelpBox()

      SettingsSection(title: "GitHub Gist") {
        SettingsRow(title: "GitHub Token", detail: "需要 gist 权限；只保存在本机。") {
          HStack(spacing: 8) {
            SecureField("粘贴 token", text: $githubToken)
              .textFieldStyle(.roundedBorder)
              .frame(width: 260)
            Button {
              openURL("https://github.com/settings/tokens?type=beta")
            } label: {
              Image(systemName: "safari")
            }
            .help("打开 GitHub Token 页面")
          }
        }

        SettingsRow(title: "Gist ID", detail: "可以留空。首次备份会创建 secret gist 并自动写回。") {
          HStack(spacing: 8) {
            TextField("留空自动创建", text: $gistID)
              .textFieldStyle(.roundedBorder)
              .frame(width: 260)
            Button {
              openURL("https://gist.github.com")
            } label: {
              Image(systemName: "safari")
            }
            .help("打开 GitHub Gist")
          }
        }

        SettingsRow(title: "文件名") {
          TextField("edgenotes-backup.json", text: $filename)
            .textFieldStyle(.roundedBorder)
            .frame(width: 300)
        }

        SettingsRow(title: "自动备份") {
          Toggle("", isOn: $autoBackupEnabled)
            .labelsHidden()
        }

        SettingsRow(title: "间隔") {
          Stepper("每 \(Int(intervalMinutes)) 分钟", value: $intervalMinutes, in: 5...1440, step: 5)
        }
      }

      SettingsSection(title: "操作") {
        HStack(spacing: 12) {
          Button {
            Task {
              await backupService.backupNow()
              backupService.reschedule()
            }
          } label: {
            if backupService.isBackingUp {
              ProgressView()
                .controlSize(.small)
            } else {
              Text("立即备份")
            }
          }
          .disabled(backupService.isBackingUp)

          Text(backupService.lastStatus)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 42)
      }
    }
    .onChange(of: autoBackupEnabled) { _, _ in backupService.reschedule() }
    .onChange(of: githubToken) { _, _ in backupService.reschedule() }
    .onChange(of: gistID) { _, _ in backupService.reschedule() }
    .onChange(of: filename) { _, _ in backupService.reschedule() }
    .onChange(of: intervalMinutes) { _, _ in backupService.reschedule() }
  }

  private var dataTab: some View {
    SettingsPage {
      SettingsSection(title: "数据位置") {
        SettingsRow(title: "本地数据") {
          HStack(spacing: 8) {
            Text(store.dataDirectoryURL.path)
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
            Button {
              openDataFolder()
            } label: {
              Image(systemName: "magnifyingglass.circle.fill")
            }
            .help("在 Finder 中打开")
          }
          .frame(maxWidth: 440, alignment: .trailing)
        }
      }
    }
  }

  private func openURL(_ string: String) {
    guard let url = URL(string: string) else { return }
    NSWorkspace.shared.open(url)
  }

  private func openDataFolder() {
    try? FileManager.default.createDirectory(at: store.dataDirectoryURL, withIntermediateDirectories: true)
    NSWorkspace.shared.open(store.dataDirectoryURL)
  }
}

private struct SettingsPage<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        content
      }
      .padding(.horizontal, 72)
      .padding(.vertical, 34)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(Color(nsColor: .windowBackgroundColor))
  }
}

private struct SettingsSection<Content: View>: View {
  var title: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.headline)
      VStack(spacing: 0) {
        content
      }
      .padding(.vertical, 2)
      .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
      .overlay {
        RoundedRectangle(cornerRadius: 8)
          .stroke(.separator.opacity(0.45), lineWidth: 1)
      }
    }
  }
}

private struct SettingsRow<Trailing: View>: View {
  var title: String
  var detail: String?
  @ViewBuilder var trailing: Trailing

  init(title: String, detail: String? = nil, @ViewBuilder trailing: () -> Trailing) {
    self.title = title
    self.detail = detail
    self.trailing = trailing()
  }

  var body: some View {
    HStack(spacing: 20) {
      VStack(alignment: .leading, spacing: 3) {
        Text(title)
          .font(.system(size: 15, weight: .medium))
        if let detail {
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Spacer()
      trailing
    }
    .padding(.horizontal, 12)
    .frame(minHeight: 42)
  }
}

private struct SideSettingButton: View {
  var side: EdgeSide
  var selected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 6) {
        ScreenPreviewForSettings(side: side)
          .frame(width: 86, height: 52)
          .overlay {
            RoundedRectangle(cornerRadius: 10)
              .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 3)
          }
        Text(side == .left ? "左侧" : "右侧")
          .foregroundStyle(.secondary)
      }
    }
    .buttonStyle(.plain)
  }
}

private struct ScreenPreviewForSettings: View {
  var side: EdgeSide

  var body: some View {
    RoundedRectangle(cornerRadius: 10)
      .fill(
        LinearGradient(
          colors: [Color(red: 0.75, green: 0.82, blue: 0.78), Color(red: 0.04, green: 0.51, blue: 0.86)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .overlay(alignment: side == .left ? .leading : .trailing) {
        VStack(spacing: 4) {
          ForEach(0..<3, id: \.self) { _ in
            RoundedRectangle(cornerRadius: 2)
              .fill(.white.opacity(0.9))
              .frame(width: 20, height: 7)
          }
        }
        .padding(.horizontal, 8)
      }
  }
}

private struct GistHelpBox: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Image(systemName: "info.circle.fill")
          .foregroundStyle(.yellow)
        Text("Gist 自动备份")
          .font(.headline)
      }
      Text("1. 打开 GitHub Token 页面，创建一个只带 gist 权限的 token。")
      Text("2. 粘贴 token；Gist ID 可留空，首次备份会自动创建 secret gist。")
      Text("3. 开启自动备份后，EdgeNotes 会按间隔更新同一个 Gist。")
    }
    .font(.system(size: 14))
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.yellow.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
  }
}
