import SwiftUI

enum NoteColor: String, Codable, CaseIterable, Identifiable {
  case graphite
  case amber
  case mint
  case sky
  case rose
  case violet

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .graphite: "Graphite"
    case .amber: "Amber"
    case .mint: "Mint"
    case .sky: "Sky"
    case .rose: "Rose"
    case .violet: "Violet"
    }
  }

  var swatch: Color {
    switch self {
    case .graphite: Color.secondary
    case .amber: Color.orange
    case .mint: Color.green
    case .sky: Color.blue
    case .rose: Color.pink
    case .violet: Color.purple
    }
  }

  var softFill: Color {
    swatch.opacity(rawValue == "graphite" ? 0.08 : 0.14)
  }
}
