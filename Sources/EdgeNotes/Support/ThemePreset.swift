import Foundation
import SwiftUI

struct ThemePreset: Identifiable, Hashable {
  var id: String { name }
  var name: String
  var background: Color
  var card: Color
  var text: Color
  var accent: Color
  var noteColors: [Color] = []

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

  func noteFill(for color: NoteColor) -> Color {
    let index: Int? = switch color {
    case .rose: 0
    case .mint: 1
    case .sky: 2
    case .amber: 3
    case .violet: 4
    case .graphite: 5
    }

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
          let appearance = theme.any ?? theme.dark ?? theme.light
    else { return nil }

    let name = sanitizeThemeName(url.deletingPathExtension().lastPathComponent)
    let folderHeader = appearance.folders?.header
    let folderList = appearance.folders?.list
    let noteClean = appearance.folder?.notes?.clean
    let noteColors = appearance.folder?.notes?.colors ?? []

    return ThemePreset(
      name: name,
      background: Color(hex: folderHeader?.backgroundColor, opaque: true)
        ?? Color(hex: folderList?.backgroundColor, opaque: true)
        ?? Color(hex: noteClean?.backgroundColor, opaque: true)
        ?? .black,
      card: Color(hex: noteClean?.backgroundColor, opaque: true)
        ?? Color(hex: folderList?.backgroundColor, opaque: true)
        ?? .black,
      text: Color(hex: folderHeader?.textColor, opaque: true)
        ?? Color(hex: folderList?.textColor, opaque: true)
        ?? Color(hex: noteClean?.textColor, opaque: true)
        ?? .white,
      accent: Color(hex: folderHeader?.buttonColor, opaque: true)
        ?? Color(hex: folderList?.buttonColor, opaque: true)
        ?? Color(hex: appearance.folders?.cleanFolderColor, opaque: true)
        ?? Color(hex: noteClean?.buttonColor, opaque: true)
        ?? .accentColor,
      noteColors: noteColors.compactMap { Color(hex: $0.backgroundColor, opaque: true) }
    )
  }

  private static func sanitizeThemeName(_ name: String) -> String {
    name
  }
}

private struct ExternalTheme: Decodable {
  var any: ExternalAppearance?
  var light: ExternalAppearance?
  var dark: ExternalAppearance?
}

private struct ExternalAppearance: Decodable {
  var folders: ExternalFolders?
  var folder: ExternalFolder?
}

private struct ExternalFolders: Decodable {
  var header: ExternalColorSet?
  var list: ExternalColorSet?
  var cleanFolderColor: String?
}

private struct ExternalFolder: Decodable {
  var header: ExternalColorSet?
  var notes: ExternalNotes?
}

private struct ExternalNotes: Decodable {
  var clean: ExternalColorSet?
  var colors: [ExternalColorSet]?
}

private struct ExternalColorSet: Decodable {
  var backgroundColor: String?
  var textColor: String?
  var buttonColor: String?
}

private extension Color {
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
}

struct ThemeCard: View {
  var theme: ThemePreset

  var body: some View {
    RoundedRectangle(cornerRadius: 10)
      .fill(theme.card)
      .overlay(alignment: .topLeading) {
        VStack(alignment: .leading, spacing: 5) {
          RoundedRectangle(cornerRadius: 2)
            .fill(theme.accent)
            .frame(width: 28, height: 5)
          HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
              .fill(theme.text.opacity(0.85))
              .frame(width: 36, height: 4)
            RoundedRectangle(cornerRadius: 2)
              .fill(theme.accent.opacity(0.85))
              .frame(width: 18, height: 4)
          }
          RoundedRectangle(cornerRadius: 2)
            .fill(theme.text.opacity(0.85))
            .frame(width: 70, height: 4)
          HStack(spacing: 5) {
            ForEach(Array(previewColors.enumerated()), id: \.offset) { _, color in
              Circle()
                .fill(color.opacity(0.85))
                .frame(width: 5, height: 5)
            }
          }
          .padding(.top, 2)
        }
        .padding(10)
      }
      .background(theme.background, in: RoundedRectangle(cornerRadius: 10))
      .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
  }

  private var previewColors: [Color] {
    if !theme.noteColors.isEmpty {
      return Array(theme.noteColors.prefix(6))
    }
    return NoteColor.allCases.map(\.swatch)
  }
}
