import Foundation
import SwiftUI

enum ThemeColorRole: String, CaseIterable {
  case background
  case card
  case text
  case accent
  case folderBackground
  case folderHeaderText
  case folderHeaderAccent
  case folderText
  case folderSecondaryText
  case folderAccent
  case noteBackground
  case noteText
  case noteSecondaryText
  case noteAccent
  case toolbarBackground
  case toolbarText
  case toolbarAccent

  func storageKey(noteColor: NoteColor? = nil) -> String {
    guard let noteColor else { return rawValue }
    return "note.\(noteColor.rawValue).\(rawValue)"
  }
}

struct ThemeCustomizations: Codable, Equatable {
  private(set) var valuesByTheme: [String: [String: String]] = [:]

  init() {}

  init(json: String) {
    guard let data = json.data(using: .utf8),
          let decoded = try? JSONDecoder().decode(Self.self, from: data)
    else { return }
    self = decoded
  }

  func color(for themeName: String, role: ThemeColorRole, noteColor: NoteColor? = nil) -> Color? {
    Color(hex: valuesByTheme[themeName]?[role.storageKey(noteColor: noteColor)])
  }

  func hasValues(for themeName: String) -> Bool {
    !(valuesByTheme[themeName]?.isEmpty ?? true)
  }

  mutating func set(
    _ color: Color,
    for themeName: String,
    role: ThemeColorRole,
    noteColor: NoteColor? = nil
  ) {
    guard let value = color.themeHex else { return }
    valuesByTheme[themeName, default: [:]][role.storageKey(noteColor: noteColor)] = value
  }

  mutating func reset(themeName: String) {
    valuesByTheme.removeValue(forKey: themeName)
  }

  mutating func setUniform(_ color: Color, for themeName: String, role: ThemeColorRole) {
    set(color, for: themeName, role: role)

    switch role {
    case .background:
      break
    case .card:
      set(color, for: themeName, role: .folderBackground)
      set(color, for: themeName, role: .noteBackground, noteColor: .graphite)
    case .text:
      set(color, for: themeName, role: .folderHeaderText)
      set(color, for: themeName, role: .folderText)
      set(color, for: themeName, role: .toolbarText)
      set(color, for: themeName, role: .noteText, noteColor: .graphite)
    case .accent:
      set(color, for: themeName, role: .folderHeaderAccent)
      set(color, for: themeName, role: .folderAccent)
      set(color, for: themeName, role: .toolbarAccent)
      set(color, for: themeName, role: .noteAccent, noteColor: .graphite)
    default:
      break
    }
  }

  var json: String {
    guard let data = try? JSONEncoder().encode(self),
          let value = String(data: data, encoding: .utf8)
    else { return "" }
    return value
  }
}

extension ThemePreset {
  func customized(using customizations: ThemeCustomizations) -> ThemePreset {
    var theme = self
    let noteColorOrder: [NoteColor] = [.rose, .mint, .sky, .amber, .violet, .graphite]
    let customText = customizations.color(for: name, role: .text)
    let customAccent = customizations.color(for: name, role: .accent)

    theme.background = customizations.color(for: name, role: .background) ?? background
    theme.card = customizations.color(for: name, role: .card) ?? card
    theme.text = customText ?? text
    theme.accent = customAccent ?? accent
    theme.folderListBackground = customizations.color(for: name, role: .folderBackground) ?? folderListBackground
    theme.folderHeaderText = customizations.color(for: name, role: .folderHeaderText) ?? customText ?? folderHeaderText
    theme.folderHeaderButton = customizations.color(for: name, role: .folderHeaderAccent) ?? customAccent ?? folderHeaderButton
    theme.folderListText = customizations.color(for: name, role: .folderText) ?? customText ?? folderListText
    theme.folderListSecondaryText = customizations.color(for: name, role: .folderSecondaryText)
      ?? customText?.opacity(0.66)
      ?? folderListSecondaryText
    theme.folderListButton = customizations.color(for: name, role: .folderAccent) ?? customAccent ?? folderListButton
    theme.selectionToolbarBackground = customizations.color(for: name, role: .toolbarBackground)
      ?? selectionToolbarBackground
      ?? card
    theme.selectionToolbarText = customizations.color(for: name, role: .toolbarText) ?? customText ?? selectionToolbarText
    theme.selectionToolbarAccent = customizations.color(for: name, role: .toolbarAccent) ?? customAccent ?? selectionToolbarAccent
    theme.noteColors = noteColorOrder.map { theme.noteFill(for: $0) }
    theme.noteTextColors = noteColorOrder.map { noteText(for: $0) }
    theme.noteSecondaryTextColors = noteColorOrder.map { noteSecondaryText(for: $0) }
    theme.noteAccentColors = noteColorOrder.map { noteAccent(for: $0) }

    for noteColor in NoteColor.allCases {
      if let color = customizations.color(for: name, role: .noteBackground, noteColor: noteColor) {
        theme.setNoteColor(color, for: noteColor)
      }
      if let color = customizations.color(for: name, role: .noteText, noteColor: noteColor) {
        theme.setOptionalNoteColor(color, role: .text, for: noteColor)
      }
      if let color = customizations.color(for: name, role: .noteSecondaryText, noteColor: noteColor) {
        theme.setOptionalNoteColor(color, role: .secondaryText, for: noteColor)
      }
      if let color = customizations.color(for: name, role: .noteAccent, noteColor: noteColor) {
        theme.setOptionalNoteColor(color, role: .accent, for: noteColor)
      }
    }

    return theme
  }

  func editableColor(for role: ThemeColorRole, noteColor: NoteColor? = nil) -> Color {
    switch role {
    case .background: background
    case .card: card
    case .text: text
    case .accent: accent
    case .folderBackground: folderListBackground ?? background
    case .folderHeaderText: folderHeaderText ?? text
    case .folderHeaderAccent: folderHeaderButton ?? accent
    case .folderText: folderListText ?? text
    case .folderSecondaryText: folderListSecondaryText ?? folderText.opacity(0.66)
    case .folderAccent: folderListButton ?? accent
    case .noteBackground: noteFill(for: noteColor ?? .graphite)
    case .noteText: noteText(for: noteColor ?? .graphite)
    case .noteSecondaryText: noteSecondaryText(for: noteColor ?? .graphite)
    case .noteAccent: noteAccent(for: noteColor ?? .graphite)
    case .toolbarBackground: toolbarFill
    case .toolbarText: selectionToolbarText ?? text
    case .toolbarAccent: selectionToolbarAccent ?? accent
    }
  }

  private func noteIndex(for color: NoteColor) -> Int {
    switch color {
    case .rose: 0
    case .mint: 1
    case .sky: 2
    case .amber: 3
    case .violet: 4
    case .graphite: 5
    }
  }

  private mutating func setNoteColor(_ color: Color, for noteColor: NoteColor) {
    let index = noteIndex(for: noteColor)
    noteColors[index] = color
  }

  private mutating func setOptionalNoteColor(_ color: Color, role: NoteTextRole, for noteColor: NoteColor) {
    let index = noteIndex(for: noteColor)
    switch role {
    case .text:
      noteTextColors[index] = color
    case .secondaryText:
      noteSecondaryTextColors[index] = color
    case .accent:
      noteAccentColors[index] = color
    }
  }

  private enum NoteTextRole {
    case text
    case secondaryText
    case accent
  }
}
