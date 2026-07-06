import Foundation
import AppKit

enum EdgeSide: String, CaseIterable, Identifiable {
  case left
  case right

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .left: "Left"
    case .right: "Right"
    }
  }
}

enum EdgePanelSettings {
  enum Key {
    static let side = "edgePanel.side"
    static let panelWidth = "edgePanel.panelWidth"
    static let openBarVisible = "edgePanel.openBarVisible"
    static let screenPreference = "edgePanel.screenPreference"
  }

  static var side: EdgeSide {
    get {
      let value = UserDefaults.standard.string(forKey: Key.side) ?? EdgeSide.right.rawValue
      return EdgeSide(rawValue: value) ?? .right
    }
    set {
      UserDefaults.standard.set(newValue.rawValue, forKey: Key.side)
    }
  }

  static var panelWidth: Double {
    get {
      let value = UserDefaults.standard.double(forKey: Key.panelWidth)
      return value > 0 ? value : 388
    }
    set {
      UserDefaults.standard.set(newValue, forKey: Key.panelWidth)
    }
  }

  static var openBarVisible: Bool {
    get {
      guard UserDefaults.standard.object(forKey: Key.openBarVisible) != nil else {
        return true
      }
      return UserDefaults.standard.bool(forKey: Key.openBarVisible)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: Key.openBarVisible)
    }
  }

  static var screenPreference: String {
    get {
      UserDefaults.standard.string(forKey: Key.screenPreference) ?? ScreenPreference.main.rawValue
    }
    set {
      UserDefaults.standard.set(newValue, forKey: Key.screenPreference)
    }
  }
}

enum ScreenPreference: String {
  case main
  case mouse

  static let displayPrefix = "display:"
}

struct EdgeDisplayOption: Identifiable, Hashable {
  var id: String
  var name: String
}

extension NSScreen {
  var edgeNotesDisplayID: String? {
    guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
      return nil
    }
    return "\(number.uint32Value)"
  }
}

enum EdgeDisplayOptions {
  static var connectedDisplays: [EdgeDisplayOption] {
    NSScreen.screens.enumerated().map { index, screen in
      let id = screen.edgeNotesDisplayID ?? "index-\(index)"
      let name = displayName(for: screen, index: index)
      return EdgeDisplayOption(id: ScreenPreference.displayPrefix + id, name: name)
    }
  }

  private static func displayName(for screen: NSScreen, index: Int) -> String {
    var name = screen.localizedName.isEmpty ? "显示器 \(index + 1)" : screen.localizedName
    if screen === NSScreen.main {
      name += "（主）"
    }
    return name
  }
}
