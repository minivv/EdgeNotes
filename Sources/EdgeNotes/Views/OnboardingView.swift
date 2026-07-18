import AppKit
import SwiftUI

private enum OnboardingStep: Int, CaseIterable {
  case hello
  case gist
  case theme
  case side
  case firstNote
}

struct OnboardingView: View {
  @EnvironmentObject private var store: NotesStore
  @EnvironmentObject private var panelCoordinator: EdgePanelCoordinator

  @AppStorage(EdgePanelSettings.Key.side) private var sideRaw = EdgeSide.right.rawValue
  @AppStorage(AppPreferences.Key.themeName) private var themeName = "Edge"
  @AppStorage(AppPreferences.Key.themeCustomizations) private var themeCustomizations = ""
  @AppStorage(BackupSettings.Key.token) private var githubToken = ""
  @AppStorage(BackupSettings.Key.gistID) private var gistID = ""
  @AppStorage(BackupSettings.Key.autoEnabled) private var autoBackupEnabled = false

  @State private var step: OnboardingStep = .hello
  @State private var selectedInstruction = 1

  var onFinish: () -> Void
  var onOpenPanel: () -> Void

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 18)
        .fill(Color(nsColor: .windowBackgroundColor))

      VStack(spacing: 0) {
        Spacer(minLength: 34)

        content
          .frame(maxWidth: .infinity)

        Spacer()

        HStack(spacing: 12) {
          if step.rawValue > 0 {
            Button("返回") {
              previous()
            }
          }

          Button(step == .firstNote ? "完成并打开侧边栏" : "继续") {
            next()
          }
          .keyboardShortcut(.defaultAction)
        }
        .padding(.bottom, 38)
      }
      .padding(.horizontal, 52)
    }
    .frame(minWidth: 840, minHeight: 520)
    .clipShape(RoundedRectangle(cornerRadius: 18))
  }

  @ViewBuilder
  private var content: some View {
    switch step {
    case .hello:
      VStack(spacing: 24) {
        AppIconPreview(size: 94)
        Text("你好！")
          .font(.system(size: 46, weight: .bold))
        Text("开始使用 EdgeNotes 前，\n先完成几个必要设置。")
          .font(.system(size: 23, weight: .semibold))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .lineSpacing(8)
      }

    case .gist:
      VStack(spacing: 28) {
        Image(systemName: "arrow.triangle.2.circlepath")
          .font(.system(size: 44, weight: .regular))
          .foregroundStyle(.blue)
        Text("GitHub Gist 备份")
          .font(.system(size: 44, weight: .bold))
        Text("用你自己的 GitHub Gist 保存备份，\n数据只按你的设置同步。")
          .font(.system(size: 21, weight: .semibold))
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .lineSpacing(7)

        VStack(spacing: 12) {
          HStack(spacing: 10) {
            SecureField("粘贴 GitHub token（需要 gist 权限）", text: $githubToken)
              .textFieldStyle(.roundedBorder)
            Button {
              openURL("https://github.com/settings/tokens?type=beta")
            } label: {
              Label("创建 Token", systemImage: "safari")
            }
          }

          HStack(spacing: 10) {
            TextField("Gist ID 可留空，首次备份会自动创建", text: $gistID)
              .textFieldStyle(.roundedBorder)
            Button {
              openURL("https://gist.github.com")
            } label: {
              Label("打开 Gist", systemImage: "safari")
            }
          }

          Toggle("开启定时自动备份", isOn: $autoBackupEnabled)
            .toggleStyle(.checkbox)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .frame(maxWidth: 650)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
      }

    case .theme:
      VStack(spacing: 24) {
        Text("主题")
          .font(.system(size: 46, weight: .bold))
        ScrollView {
          LazyVGrid(columns: Array(repeating: GridItem(.fixed(104), spacing: 18), count: 5), spacing: 20) {
          ForEach(ThemePreset.allCases) { baseTheme in
            let theme = baseTheme.customized(using: ThemeCustomizations(json: themeCustomizations))
              ThemeChoice(theme: theme, selected: themeName == theme.name) {
                themeName = theme.name
              }
            }
          }
          .padding(20)
        }
        .frame(maxWidth: 660, maxHeight: 286)
        .background(Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
      }

    case .side:
      VStack(spacing: 48) {
        Text("选择屏幕一侧")
          .font(.system(size: 46, weight: .bold))
        HStack(spacing: 20) {
          SideChoice(side: .left, selected: sideRaw == EdgeSide.left.rawValue) {
            sideRaw = EdgeSide.left.rawValue
            panelCoordinator.refreshFromSettings()
          }
          SideChoice(side: .right, selected: sideRaw == EdgeSide.right.rawValue) {
            sideRaw = EdgeSide.right.rawValue
            panelCoordinator.refreshFromSettings()
          }
        }
        .padding(22)
        .background(Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
      }

    case .firstNote:
      VStack(spacing: 32) {
        Text("创建你的第一条笔记")
          .font(.system(size: 46, weight: .bold))

        HStack(spacing: 26) {
          VStack(alignment: .leading, spacing: 14) {
            SetupInstructionButton(
              number: 1,
              title: "创建文件夹",
              detail: "点击顶部的加号，新文件夹会进入重命名状态。",
              selected: selectedInstruction == 1
            ) { selectedInstruction = 1 }
            SetupInstructionButton(
              number: 2,
              title: "打开文件夹",
              detail: "单击文件夹即可打开，不需要双击。",
              selected: selectedInstruction == 2
            ) { selectedInstruction = 2 }
            SetupInstructionButton(
              number: 3,
              title: "创建笔记",
              detail: "标题写完按回车，直接继续写卡片正文。",
              selected: selectedInstruction == 3
            ) { selectedInstruction = 3 }
          }
          .padding(16)
          .frame(width: 330, height: 250)
          .background(Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))

          PanelIllustration(stage: selectedInstruction)
            .frame(width: 410, height: 250)
        }
      }
    }
  }

  private func next() {
    guard let next = OnboardingStep(rawValue: step.rawValue + 1) else {
      onFinish()
      DispatchQueue.main.async {
        onOpenPanel()
      }
      return
    }
    step = next
  }

  private func previous() {
    guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
    step = previous
  }

  private func openURL(_ string: String) {
    guard let url = URL(string: string) else { return }
    NSWorkspace.shared.open(url)
  }
}

struct AppIconPreview: View {
  var size: CGFloat

  var body: some View {
    Group {
      if let image = EdgeNotesAssets.iconImage {
        Image(nsImage: image)
          .resizable()
          .interpolation(.high)
      } else {
        RoundedRectangle(cornerRadius: size * 0.22)
          .fill(Color(red: 0.40, green: 0.50, blue: 0.61))
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
    .shadow(color: .black.opacity(0.22), radius: 14, x: 0, y: 8)
  }
}

private enum EdgeNotesAssets {
  static var iconImage: NSImage? {
    if let image = NSImage(named: "EdgeNotesIcon") {
      return image
    }
    if let url = Bundle.main.url(forResource: "EdgeNotesIcon", withExtension: "png"),
       let image = NSImage(contentsOf: url) {
      return image
    }
    if let url = Bundle.module.url(forResource: "EdgeNotesIcon", withExtension: "png") {
      return NSImage(contentsOf: url)
    }
    return nil
  }
}

private struct ThemeChoice: View {
  var theme: ThemePreset
  var selected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 7) {
        ThemeCard(theme: theme)
          .frame(width: 94, height: 54)
          .overlay {
            RoundedRectangle(cornerRadius: 10)
              .stroke(selected ? Color.accentColor : Color.black.opacity(0.12), lineWidth: selected ? 2 : 1)
          }
        Text(theme.name)
          .font(.caption)
          .foregroundStyle(.primary)
          .lineLimit(1)
      }
    }
    .buttonStyle(.plain)
  }
}

private struct SideChoice: View {
  var side: EdgeSide
  var selected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        ScreenPreview(side: side)
          .frame(width: 96, height: 58)
          .overlay {
            RoundedRectangle(cornerRadius: 10)
              .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 3)
          }
        Text(side == .left ? "左侧" : "右侧")
          .font(.caption.weight(.semibold))
      }
    }
    .buttonStyle(.plain)
  }
}

private struct ScreenPreview: View {
  var side: EdgeSide?

  var body: some View {
    RoundedRectangle(cornerRadius: 10)
      .fill(
        LinearGradient(
          colors: [Color(red: 0.75, green: 0.82, blue: 0.80), Color(red: 0.00, green: 0.48, blue: 0.85)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .overlay(alignment: side == .left ? .leading : .trailing) {
        if side != nil {
          VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
              RoundedRectangle(cornerRadius: 2)
                .fill(.white.opacity(0.88))
                .frame(width: 22, height: 8)
            }
          }
          .padding(.horizontal, 8)
        }
      }
  }
}

private struct SetupInstructionButton: View {
  var number: Int
  var title: String
  var detail: String
  var selected: Bool
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(alignment: .top, spacing: 12) {
        Text("\(number)")
          .font(.title3.weight(.semibold))
          .foregroundStyle(.secondary)
          .frame(width: 30, height: 30)
          .background(.white.opacity(0.5), in: Circle())
        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.headline)
          Text(detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(selected ? Color(red: 0.54, green: 0.67, blue: 0.82).opacity(0.45) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
  }
}

private struct PanelIllustration: View {
  var stage: Int

  var body: some View {
    ZStack(alignment: .topTrailing) {
      RoundedRectangle(cornerRadius: 20)
        .fill(Color(red: 0.38, green: 0.48, blue: 0.60))
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text(stage == 1 ? "新建文件夹" : "Project")
            .font(.title2.weight(.bold))
          Spacer()
          Image(systemName: "magnifyingglass")
          Image(systemName: "plus")
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))

        if stage == 1 {
          HStack {
            Image(systemName: "folder")
              .foregroundStyle(Color(red: 0.78, green: 1.00, blue: 0.18))
            Text("新建文件夹")
              .font(.headline)
            Spacer()
            Image(systemName: "pencil")
          }
          .foregroundStyle(.white)
          .padding(16)
          .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
        } else if stage == 2 {
          ForEach(["Project", "Ideas", "Inbox"], id: \.self) { name in
            HStack {
              Image(systemName: "folder")
                .foregroundStyle(Color(red: 0.78, green: 1.00, blue: 0.18))
              Text(name)
                .font(.headline)
              Spacer()
              Text(name == "Project" ? "3" : "0")
                .monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(14)
            .background(Color.white.opacity(name == "Project" ? 0.24 : 0.12), in: RoundedRectangle(cornerRadius: 12))
          }
        } else {
          VStack(alignment: .leading, spacing: 12) {
            Text("标题")
              .font(.headline)
            Text("在这里写 Markdown 正文...")
              .foregroundStyle(.white.opacity(0.78))
            Text("**预览会即时更新**")
              .font(.subheadline.weight(.semibold))
              .padding(10)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
          }
          .foregroundStyle(.white)
          .padding(16)
          .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
        }
      }
      .padding(18)
    }
    .clipped()
  }
}
