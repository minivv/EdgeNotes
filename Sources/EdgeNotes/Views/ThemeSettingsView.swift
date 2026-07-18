import SwiftUI

struct ThemeSettingsView: View {
  @AppStorage(AppPreferences.Key.themeName) private var themeName = "Edge"
  @AppStorage(AppPreferences.Key.themeCustomizations) private var customizationsData = ""
  @State private var selectedNoteColor = NoteColor.graphite
  @State private var adjustmentMode = ThemeAdjustmentMode.uniform

  private let columns = [
    GridItem(.flexible(), spacing: 18),
    GridItem(.flexible(), spacing: 18)
  ]

  private var customizations: ThemeCustomizations {
    ThemeCustomizations(json: customizationsData)
  }

  private var selectedTheme: ThemePreset {
    ThemePreset.named(themeName).customized(using: customizations)
  }

  var body: some View {
    SettingsPage {
      SettingsSection(title: "主题") {
        ScrollViewReader { proxy in
          ScrollView(.horizontal) {
            LazyHStack(spacing: 18) {
              ForEach(ThemePreset.allCases) { baseTheme in
                let theme = baseTheme.customized(using: customizations)
                Button {
                  themeName = baseTheme.name
                } label: {
                  VStack(spacing: 8) {
                    ThemeCard(theme: theme)
                      .frame(width: 96, height: 58)
                      .overlay {
                        RoundedRectangle(cornerRadius: 8)
                          .stroke(
                            themeName == baseTheme.name ? Color.accentColor : Color.black.opacity(0.10),
                            lineWidth: themeName == baseTheme.name ? 2.5 : 1
                          )
                      }
                    HStack(spacing: 4) {
                      Text(baseTheme.name)
                        .lineLimit(1)
                      if customizations.hasValues(for: baseTheme.name) {
                        Circle()
                          .fill(Color.accentColor)
                          .frame(width: 5, height: 5)
                      }
                    }
                    .font(.caption)
                    .frame(width: 104)
                  }
                }
                .buttonStyle(.plain)
                .id(baseTheme.name)
              }
            }
            .padding(.horizontal, 12)
          }
          .scrollIndicators(.hidden)
          .frame(height: 92)
          .onAppear {
            proxy.scrollTo(themeName, anchor: .center)
          }
          .onChange(of: themeName) { _, name in
            withAnimation(.easeOut(duration: 0.18)) {
              proxy.scrollTo(name, anchor: .center)
            }
          }
        }

        Divider()

        HStack {
          Text(themeName)
            .font(.system(size: 15, weight: .semibold))
          Spacer()
          Button {
            resetSelectedTheme()
          } label: {
            Label("恢复默认配色", systemImage: "arrow.counterclockwise")
          }
          .disabled(!customizations.hasValues(for: themeName))
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 42)
      }

      SettingsSection(title: "调整方式") {
        Picker("", selection: $adjustmentMode) {
          ForEach(ThemeAdjustmentMode.allCases) { mode in
            Text(mode.title).tag(mode)
          }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .padding(12)
      }

      if adjustmentMode == .uniform {
        SettingsSection(title: "统一调整") {
          uniformColorGrid([
            ("顶部背景", .background),
            ("列表背景", .card),
            ("主文字", .text),
            ("强调色", .accent)
          ])
        }
      } else {
        SettingsSection(title: "文件夹") {
          colorGrid([
            ("文件夹背景", .folderBackground),
            ("顶部文字", .folderHeaderText),
            ("顶部按钮", .folderHeaderAccent),
            ("列表文字", .folderText),
            ("次要文字", .folderSecondaryText),
            ("列表按钮", .folderAccent)
          ])
        }

        SettingsSection(title: "笔记") {
          HStack(spacing: 10) {
            ForEach(NoteColor.allCases) { noteColor in
              Button {
                selectedNoteColor = noteColor
              } label: {
                ColorSwatch(
                  color: noteColor,
                  fillColor: selectedTheme.noteFill(for: noteColor),
                  selectionColor: selectedTheme.noteText(for: noteColor),
                  isSelected: noteColor == selectedNoteColor
                )
              }
              .buttonStyle(.plain)
              .help(noteColorName(noteColor))
            }

            Text(noteColorName(selectedNoteColor))
              .font(.system(size: 13, weight: .medium))
              .foregroundStyle(.secondary)
            Spacer()
          }
          .padding(.horizontal, 12)
          .frame(minHeight: 44)

          Divider()

          colorGrid([
            ("卡片背景", .noteBackground),
            ("标题与正文", .noteText),
            ("次要文字", .noteSecondaryText),
            ("链接与按钮", .noteAccent)
          ], noteColor: selectedNoteColor)
        }

        SettingsSection(title: "选中文本工具栏") {
          ThemeToolbarPreview(theme: selectedTheme)
            .padding(.horizontal, 12)
            .padding(.top, 12)

          colorGrid([
            ("背景", .toolbarBackground),
            ("图标与文字", .toolbarText),
            ("边框强调", .toolbarAccent)
          ])
        }
      }
    }
  }

  private func colorGrid(
    _ options: [(String, ThemeColorRole)],
    noteColor: NoteColor? = nil
  ) -> some View {
    LazyVGrid(columns: columns, spacing: 0) {
      ForEach(options, id: \.1.rawValue) { option in
        ThemeColorPicker(
          title: option.0,
          selection: colorBinding(for: option.1, noteColor: noteColor)
        )
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
  }

  private func uniformColorGrid(_ options: [(String, ThemeColorRole)]) -> some View {
    LazyVGrid(columns: columns, spacing: 0) {
      ForEach(options, id: \.1.rawValue) { option in
        ThemeColorPicker(
          title: option.0,
          selection: uniformColorBinding(for: option.1)
        )
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
  }

  private func colorBinding(for role: ThemeColorRole, noteColor: NoteColor? = nil) -> Binding<Color> {
    Binding(
      get: {
        selectedTheme.editableColor(for: role, noteColor: noteColor)
      },
      set: { color in
        var next = customizations
        next.set(color, for: themeName, role: role, noteColor: noteColor)
        customizationsData = next.json
      }
    )
  }

  private func uniformColorBinding(for role: ThemeColorRole) -> Binding<Color> {
    Binding(
      get: {
        selectedTheme.editableColor(for: role)
      },
      set: { color in
        var next = customizations
        next.setUniform(color, for: themeName, role: role)
        customizationsData = next.json
      }
    )
  }

  private func resetSelectedTheme() {
    var next = customizations
    next.reset(themeName: themeName)
    customizationsData = next.json
  }

  private func noteColorName(_ color: NoteColor) -> String {
    switch color {
    case .graphite: "石墨"
    case .amber: "琥珀"
    case .mint: "薄荷"
    case .sky: "天蓝"
    case .rose: "玫瑰"
    case .violet: "紫罗兰"
    }
  }
}

private enum ThemeAdjustmentMode: String, CaseIterable, Identifiable {
  case uniform
  case detailed

  var id: String { rawValue }

  var title: String {
    switch self {
    case .uniform: "统一调整"
    case .detailed: "精细调整"
    }
  }
}

private struct ThemeColorPicker: View {
  var title: String
  @Binding var selection: Color

  var body: some View {
    ColorPicker(title, selection: $selection, supportsOpacity: true)
      .font(.system(size: 14, weight: .medium))
      .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
  }
}

private struct ThemeToolbarPreview: View {
  var theme: ThemePreset

  var body: some View {
    HStack(spacing: 3) {
      Text("B").fontWeight(.bold)
      Text("I").italic()
      Image(systemName: "list.bullet")
      Image(systemName: "checklist")
      Image(systemName: "quote.opening")
    }
    .font(.system(size: 13, weight: .semibold))
    .foregroundStyle(theme.toolbarText)
    .frame(height: 28)
    .padding(.horizontal, 8)
    .background(theme.toolbarFill, in: RoundedRectangle(cornerRadius: 8))
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .stroke(theme.toolbarAccent, lineWidth: 1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
