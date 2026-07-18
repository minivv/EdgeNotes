import Foundation
import AppKit
import SwiftUI

struct ThemePreset: Identifiable, Hashable {
  var id: String { name }
  var name: String
  var background: Color
  var card: Color
  var text: Color
  var accent: Color
  var folderListBackground: Color?
  var folderHeaderText: Color?
  var folderHeaderButton: Color?
  var folderListText: Color?
  var folderListSecondaryText: Color?
  var folderListButton: Color?
  var noteColors: [Color] = []
  var noteTextColors: [Color?] = []
  var noteSecondaryTextColors: [Color?] = []
  var noteAccentColors: [Color?] = []
  var selectionToolbarBackground: Color?
  var selectionToolbarText: Color?
  var selectionToolbarAccent: Color?

  static let arctic = ThemePreset(name: "Arctic", background: Color(red: 0.93, green: 0.97, blue: 1.00), card: .white, text: Color(red: 0.18, green: 0.22, blue: 0.25), accent: Color(red: 0.26, green: 0.52, blue: 0.68))
  static let classic = ThemePreset(name: "Classic", background: .white, card: .white, text: Color(red: 0.12, green: 0.12, blue: 0.13), accent: Color(red: 0.37, green: 0.64, blue: 0.82))
  static let clean = ThemePreset(name: "Clean", background: Color(red: 0.98, green: 0.98, blue: 0.98), card: .white, text: Color(red: 0.08, green: 0.10, blue: 0.15), accent: .blue)
  static let cyberpunk = ThemePreset(name: "Cyberpunk", background: Color(red: 0.13, green: 0.08, blue: 0.25), card: Color(red: 0.18, green: 0.10, blue: 0.30), text: .white, accent: Color(red: 0.08, green: 1.00, blue: 0.56))
  static let darkBlue = ThemePreset(name: "Dark Blue", background: Color(red: 0.40, green: 0.50, blue: 0.64), card: Color(red: 0.48, green: 0.58, blue: 0.72), text: .white, accent: Color(red: 0.77, green: 1.00, blue: 0.16))
  static let smooth = ThemePreset(name: "Dark and Smooth", background: Color(red: 0.37, green: 0.38, blue: 0.39), card: Color(red: 0.44, green: 0.45, blue: 0.46), text: .white, accent: Color(red: 0.33, green: 0.85, blue: 1.00))
  static let defaultTheme = ThemePreset(name: "Default", background: Color(red: 0.95, green: 0.96, blue: 0.98), card: .white, text: Color(red: 0.13, green: 0.13, blue: 0.14), accent: Color(red: 0.20, green: 0.46, blue: 0.76))
  static let fresh = ThemePreset(name: "Fresh 2", background: Color(red: 1.00, green: 0.98, blue: 0.90), card: Color(red: 1.00, green: 0.99, blue: 0.94), text: Color(red: 0.12, green: 0.13, blue: 0.14), accent: Color(red: 0.31, green: 0.45, blue: 0.78))
  static let graphite = ThemePreset(name: "Graphite Gray", background: Color(red: 0.72, green: 0.78, blue: 0.86), card: Color(red: 0.82, green: 0.87, blue: 0.93), text: Color(red: 0.14, green: 0.18, blue: 0.22), accent: Color(red: 1.00, green: 0.24, blue: 0.37))
  static let edge = ThemePreset(name: "Edge", background: Color(red: 0.40, green: 0.50, blue: 0.61), card: Color(red: 0.47, green: 0.57, blue: 0.68), text: .white, accent: Color(red: 0.78, green: 1.00, blue: 0.16))

  static let builtInThemes: [ThemePreset] = [
    .arctic, .classic, .clean, .cyberpunk, .darkBlue,
    .smooth, .defaultTheme, .fresh, .graphite, .edge
  ]

  static let bundledThemes: [ThemePreset] = loadBundledThemes()

  static var allCases: [ThemePreset] {
    let bundledNames = Set(bundledThemes.map(\.name))
    return bundledThemes + builtInThemes.filter { !bundledNames.contains($0.name) }
  }

  static func named(_ name: String) -> ThemePreset {
    return allCases.first { $0.name == name } ?? .edge
  }

  static func named(_ name: String, customizationsData: String) -> ThemePreset {
    named(name).customized(using: ThemeCustomizations(json: customizationsData))
  }

  func noteFill(for color: NoteColor) -> Color {
    let index = noteColorIndex(for: color)

    if let index,
       noteColors.indices.contains(index) {
      return noteColors[index]
    }

    switch color {
    case .graphite:
      return background
    case .amber:
      return Color(red: 0.68, green: 0.41, blue: 0.26)
    case .mint:
      return Color(red: 0.28, green: 0.50, blue: 0.34)
    case .sky:
      return Color(red: 0.24, green: 0.43, blue: 0.62)
    case .rose:
      return Color(red: 0.63, green: 0.30, blue: 0.40)
    case .violet:
      return Color(red: 0.38, green: 0.28, blue: 0.55)
    }
  }

  func noteText(for color: NoteColor) -> Color {
    noteColorValue(noteTextColors, for: color) ?? text
  }

  func noteSecondaryText(for color: NoteColor) -> Color {
    noteColorValue(noteSecondaryTextColors, for: color) ?? noteText(for: color).opacity(0.66)
  }

  func noteAccent(for color: NoteColor) -> Color {
    noteColorValue(noteAccentColors, for: color) ?? accent
  }

  var headerText: Color {
    folderHeaderText ?? text
  }

  var headerSecondaryText: Color {
    headerText.opacity(0.66)
  }

  var headerAccent: Color {
    folderHeaderButton ?? accent
  }

  var folderFill: Color {
    folderListBackground ?? background
  }

  var folderText: Color {
    folderListText ?? text
  }

  var folderSecondaryText: Color {
    folderListSecondaryText ?? folderText.opacity(0.66)
  }

  var folderAccent: Color {
    folderListButton ?? accent
  }

  var toolbarFill: Color {
    selectionToolbarBackground ?? card
  }

  var toolbarText: Color {
    selectionToolbarText ?? text
  }

  var toolbarAccent: Color {
    selectionToolbarAccent ?? accent
  }

  func readableText(on surface: Color, preferred: Color? = nil, minimumContrast: Double = 4.5) -> Color {
    let preferred = preferred ?? text
    guard let surfaceColor = resolvedSurfaceColor(surface),
          let preferredColor = RGBAColor(preferred)
    else { return preferred }

    if preferredColor.contrastWhenDrawn(on: surfaceColor) >= minimumContrast {
      return preferred
    }

    let black = RGBAColor(red: 0, green: 0, blue: 0, alpha: 1)
    let white = RGBAColor(red: 1, green: 1, blue: 1, alpha: 1)
    return black.contrastRatio(with: surfaceColor) >= white.contrastRatio(with: surfaceColor)
      ? .black
      : .white
  }

  private func resolvedSurfaceColor(_ surface: Color) -> RGBAColor? {
    guard let surfaceColor = RGBAColor(surface) else { return nil }
    guard surfaceColor.alpha < 1, let backgroundColor = RGBAColor(background) else {
      return surfaceColor
    }
    return surfaceColor.composited(over: backgroundColor)
  }

  private func isReadable(_ foreground: Color, on surface: Color, minimumContrast: Double) -> Bool {
    guard let surfaceColor = resolvedSurfaceColor(surface),
          let foregroundColor = RGBAColor(foreground)
    else { return true }
    return foregroundColor.contrastWhenDrawn(on: surfaceColor) >= minimumContrast
  }

  private func noteColorIndex(for color: NoteColor) -> Int? {
    switch color {
    case .rose: 0
    case .mint: 1
    case .sky: 2
    case .amber: 3
    case .violet: 4
    case .graphite: 5
    }
  }

  private func noteColorValue(_ colors: [Color?], for color: NoteColor) -> Color? {
    guard let index = noteColorIndex(for: color),
          colors.indices.contains(index)
    else { return nil }
    return colors[index]
  }

  private static func loadBundledThemes() -> [ThemePreset] {
    guard let themesURL = Bundle.main.resourceURL?.appendingPathComponent("themes", isDirectory: true),
          let urls = try? FileManager.default.contentsOfDirectory(
            at: themesURL,
            includingPropertiesForKeys: nil
          )
    else { return [] }

    return urls
      .filter { ["edgetheme", "sntheme"].contains($0.pathExtension.lowercased()) }
      .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
      .compactMap(loadTheme)
  }

  private static func loadTheme(from url: URL) -> ThemePreset? {
    guard let data = try? Data(contentsOf: url),
          let theme = try? JSONDecoder().decode(ExternalTheme.self, from: data),
          let appearance = theme.resolvedAppearance(prefersDark: prefersDarkAppearance)
    else { return nil }

    let name = sanitizeThemeName(url.deletingPathExtension().lastPathComponent)
    let folderHeader = appearance.folders?.header
    let folderList = appearance.folders?.list
    let noteClean = appearance.folder?.notes?.clean
    let noteColors = appearance.folder?.notes?.colors ?? []

    return ThemePreset(
      name: name,
      background: Color(hex: folderHeader?.backgroundColor)
        ?? Color(hex: folderList?.backgroundColor)
        ?? Color(hex: noteClean?.backgroundColor)
        ?? .black,
      card: Color(hex: noteClean?.backgroundColor)
        ?? Color(hex: folderList?.backgroundColor)
        ?? .black,
      text: Color(hex: noteClean?.textColor)
        ?? Color(hex: folderList?.textColor)
        ?? Color(hex: folderHeader?.textColor)
        ?? .white,
      accent: Color(hex: noteClean?.linkColor)
        ?? Color(hex: noteClean?.buttonColor)
        ?? Color(hex: noteClean?.header?.textColor)
        ?? Color(hex: folderHeader?.buttonColor)
        ?? Color(hex: folderList?.buttonColor)
        ?? Color(hex: appearance.accentColor)
        ?? Color(hex: appearance.folders?.cleanFolderColor)
        ?? .accentColor,
      folderListBackground: Color(hex: folderList?.backgroundColor),
      folderHeaderText: Color(hex: folderHeader?.textColor),
      folderHeaderButton: Color(hex: folderHeader?.buttonColor),
      folderListText: Color(hex: folderList?.textColor),
      folderListSecondaryText: Color(hex: folderList?.secondaryTextColor),
      folderListButton: Color(hex: folderList?.buttonColor),
      noteColors: noteColors.compactMap { Color(hex: $0.backgroundColor) },
      noteTextColors: noteColors.map { Color(hex: $0.textColor) },
      noteSecondaryTextColors: noteColors.map { Color(hex: $0.secondaryTextColor) },
      noteAccentColors: noteColors.map {
        Color(hex: $0.linkColor)
          ?? Color(hex: $0.buttonColor)
          ?? Color(hex: $0.header?.textColor)
      }
    )
  }

  private static func sanitizeThemeName(_ name: String) -> String {
    name
  }

  private static var prefersDarkAppearance: Bool {
    NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
  }
}

private struct ExternalTheme: Decodable {
  var any: ExternalAppearance?
  var light: ExternalAppearance?
  var dark: ExternalAppearance?

  func resolvedAppearance(prefersDark: Bool) -> ExternalAppearance? {
    let preferred = prefersDark ? dark : light
    if let preferred {
      return any?.merged(with: preferred) ?? preferred
    }
    return any ?? dark ?? light
  }
}

private struct ExternalAppearance: Decodable {
  var systemAppearance: String?
  var accentColor: String?
  var folders: ExternalFolders?
  var folder: ExternalFolder?

  func merged(with override: ExternalAppearance) -> ExternalAppearance {
    ExternalAppearance(
      systemAppearance: override.systemAppearance ?? systemAppearance,
      accentColor: override.accentColor ?? accentColor,
      folders: folders.merged(with: override.folders),
      folder: folder.merged(with: override.folder)
    )
  }
}

private struct ExternalFolders: Decodable {
  var header: ExternalColorSet?
  var list: ExternalColorSet?
  var cleanFolderColor: String?

  func merged(with override: ExternalFolders) -> ExternalFolders {
    ExternalFolders(
      header: header.merged(with: override.header),
      list: list.merged(with: override.list),
      cleanFolderColor: override.cleanFolderColor ?? cleanFolderColor
    )
  }
}

private struct ExternalFolder: Decodable {
  var header: ExternalColorSet?
  var notes: ExternalNotes?

  func merged(with override: ExternalFolder) -> ExternalFolder {
    ExternalFolder(
      header: header.merged(with: override.header),
      notes: notes.merged(with: override.notes)
    )
  }
}

private struct ExternalNotes: Decodable {
  var clean: ExternalColorSet?
  var colors: [ExternalColorSet]?

  func merged(with override: ExternalNotes) -> ExternalNotes {
    ExternalNotes(
      clean: clean.merged(with: override.clean),
      colors: colors.merged(with: override.colors)
    )
  }
}

private struct ExternalColorSet: Decodable {
  var backgroundColor: String?
  var textColor: String?
  var secondaryTextColor: String?
  var buttonColor: String?
  var linkColor: String?
  var header: ExternalTextRole?

  func merged(with override: ExternalColorSet) -> ExternalColorSet {
    ExternalColorSet(
      backgroundColor: override.backgroundColor ?? backgroundColor,
      textColor: override.textColor ?? textColor,
      secondaryTextColor: override.secondaryTextColor ?? secondaryTextColor,
      buttonColor: override.buttonColor ?? buttonColor,
      linkColor: override.linkColor ?? linkColor,
      header: header.merged(with: override.header)
    )
  }
}

private struct ExternalTextRole: Decodable {
  var textColor: String?

  func merged(with override: ExternalTextRole) -> ExternalTextRole {
    ExternalTextRole(textColor: override.textColor ?? textColor)
  }
}

private extension Optional where Wrapped == ExternalAppearance {
  func merged(with override: ExternalAppearance?) -> ExternalAppearance? {
    guard let override else { return self }
    return self?.merged(with: override) ?? override
  }
}

private extension Optional where Wrapped == ExternalFolders {
  func merged(with override: ExternalFolders?) -> ExternalFolders? {
    guard let override else { return self }
    return self?.merged(with: override) ?? override
  }
}

private extension Optional where Wrapped == ExternalFolder {
  func merged(with override: ExternalFolder?) -> ExternalFolder? {
    guard let override else { return self }
    return self?.merged(with: override) ?? override
  }
}

private extension Optional where Wrapped == ExternalNotes {
  func merged(with override: ExternalNotes?) -> ExternalNotes? {
    guard let override else { return self }
    return self?.merged(with: override) ?? override
  }
}

private extension Optional where Wrapped == ExternalColorSet {
  func merged(with override: ExternalColorSet?) -> ExternalColorSet? {
    guard let override else { return self }
    return self?.merged(with: override) ?? override
  }
}

private extension Optional where Wrapped == ExternalTextRole {
  func merged(with override: ExternalTextRole?) -> ExternalTextRole? {
    guard let override else { return self }
    return self?.merged(with: override) ?? override
  }
}

private extension Array where Element == ExternalColorSet {
  func merged(with override: [ExternalColorSet]?) -> [ExternalColorSet] {
    guard let override else { return self }
    let count = Swift.max(self.count, override.count)
    return (0..<count).compactMap { index in
      switch (indices.contains(index) ? self[index] : nil, override.indices.contains(index) ? override[index] : nil) {
      case let (base?, item?):
        return base.merged(with: item)
      case let (_, item?):
        return item
      case let (base?, nil):
        return base
      case (nil, nil):
        return nil
      }
    }
  }
}

private extension Optional where Wrapped == [ExternalColorSet] {
  func merged(with override: [ExternalColorSet]?) -> [ExternalColorSet]? {
    guard let override else { return self }
    return self?.merged(with: override) ?? override
  }
}

extension Color {
  init?(hex: String?, opaque: Bool = false) {
    guard var value = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
      return nil
    }
    if value.hasPrefix("#") {
      value.removeFirst()
    }
    if value.count == 3 {
      value = value.map { "\($0)\($0)" }.joined()
    }
    guard value.count == 6 || value.count == 8,
          let integer = UInt64(value, radix: 16)
    else { return nil }

    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    if value.count == 8 {
      red = Double((integer & 0xff00_0000) >> 24) / 255
      green = Double((integer & 0x00ff_0000) >> 16) / 255
      blue = Double((integer & 0x0000_ff00) >> 8) / 255
      alpha = opaque ? 1 : Double(integer & 0x0000_00ff) / 255
    } else {
      red = Double((integer & 0xff0000) >> 16) / 255
      green = Double((integer & 0x00ff00) >> 8) / 255
      blue = Double(integer & 0x0000ff) / 255
      alpha = 1
    }

    self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
  }

  var themeHex: String? {
    guard let converted = NSColor(self).usingColorSpace(.sRGB) else { return nil }
    let red = Int(round(converted.redComponent * 255))
    let green = Int(round(converted.greenComponent * 255))
    let blue = Int(round(converted.blueComponent * 255))
    let alpha = Int(round(converted.alphaComponent * 255))
    return String(format: "#%02X%02X%02X%02X", red, green, blue, alpha)
  }
}

private struct RGBAColor {
  var red: Double
  var green: Double
  var blue: Double
  var alpha: Double

  init?(_ color: Color) {
    guard let converted = NSColor(color).usingColorSpace(.sRGB) else {
      return nil
    }
    red = Double(converted.redComponent)
    green = Double(converted.greenComponent)
    blue = Double(converted.blueComponent)
    alpha = Double(converted.alphaComponent)
  }

  init(red: Double, green: Double, blue: Double, alpha: Double) {
    self.red = red
    self.green = green
    self.blue = blue
    self.alpha = alpha
  }

  func composited(over backdrop: RGBAColor) -> RGBAColor {
    let outputAlpha = alpha + backdrop.alpha * (1 - alpha)
    guard outputAlpha > 0 else {
      return RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
    }

    return RGBAColor(
      red: (red * alpha + backdrop.red * backdrop.alpha * (1 - alpha)) / outputAlpha,
      green: (green * alpha + backdrop.green * backdrop.alpha * (1 - alpha)) / outputAlpha,
      blue: (blue * alpha + backdrop.blue * backdrop.alpha * (1 - alpha)) / outputAlpha,
      alpha: outputAlpha
    )
  }

  func contrastWhenDrawn(on surface: RGBAColor) -> Double {
    let drawnColor = alpha < 1 ? composited(over: surface) : self
    return drawnColor.contrastRatio(with: surface)
  }

  func contrastRatio(with other: RGBAColor) -> Double {
    let first = relativeLuminance
    let second = other.relativeLuminance
    return (max(first, second) + 0.05) / (min(first, second) + 0.05)
  }

  private var relativeLuminance: Double {
    0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
  }

  private func linear(_ value: Double) -> Double {
    value <= 0.03928
      ? value / 12.92
      : pow((value + 0.055) / 1.055, 2.4)
  }
}

struct ThemeCard: View {
  var theme: ThemePreset

  var body: some View {
    RoundedRectangle(cornerRadius: 10)
      .fill(theme.background)
      .overlay {
        VStack(alignment: .leading, spacing: 5) {
          HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
              .fill(theme.headerAccent)
              .frame(width: 25, height: 5)
            RoundedRectangle(cornerRadius: 2)
              .fill(theme.headerText.opacity(0.55))
              .frame(width: 30, height: 4)
          }

          HStack(alignment: .top, spacing: 6) {
            previewCleanCard

            VStack(alignment: .leading, spacing: 4) {
              ForEach(Array(previewNoteColors.enumerated()), id: \.offset) { _, color in
                previewNoteStrip(fill: color.fill, text: color.text, width: color.width)
              }
            }
          }
        }
        .padding(8)
      }
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
  }

  private var previewCleanCard: some View {
    RoundedRectangle(cornerRadius: 4)
      .fill(theme.card)
      .frame(width: 36, height: 30)
      .overlay(alignment: .leading) {
        VStack(alignment: .leading, spacing: 4) {
          RoundedRectangle(cornerRadius: 2)
            .fill(theme.text.opacity(0.88))
            .frame(width: 22, height: 3)
          RoundedRectangle(cornerRadius: 2)
            .fill(theme.text.opacity(0.48))
            .frame(width: 27, height: 3)
        }
        .padding(.leading, 6)
      }
  }

  private func previewNoteStrip(fill: Color, text: Color, width: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: 3)
      .fill(fill)
      .frame(width: width, height: 7)
      .overlay(alignment: .leading) {
        RoundedRectangle(cornerRadius: 2)
          .fill(text.opacity(0.86))
          .frame(width: max(12, width - 14), height: 2.5)
          .padding(.leading, 5)
      }
  }

  private var previewNoteColors: [(fill: Color, text: Color, width: CGFloat)] {
    let noteColors = [NoteColor.rose, .mint, .sky].map { color in
      (
        fill: theme.noteFill(for: color),
        text: theme.noteText(for: color),
        width: color == .rose ? CGFloat(35) : CGFloat(29)
      )
    }
    return noteColors
  }
}
