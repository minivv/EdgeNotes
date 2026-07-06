import Foundation

enum AppPreferences {
  enum Key {
    static let didCompleteOnboarding = "app.didCompleteOnboarding"
    static let themeName = "appearance.themeName"
    static let noteStyle = "appearance.noteStyle"
    static let markdownMarksHidden = "text.markdownMarksHidden"
    static let menuBarIconMode = "edgePanel.menuBarIconMode"
    static let menuBarIconVisible = "edgePanel.menuBarIconVisible"
    static let displaySpeed = "edgePanel.displaySpeed"
    static let hotEdgeEnabled = "edgePanel.hotEdgeEnabled"
    static let hideOnOutsideClick = "edgePanel.hideOnOutsideClick"
    static let hideOnEmptyClick = "edgePanel.hideOnEmptyClick"
    static let panelPinned = "edgePanel.panelPinned"
    static let sidePanelRoute = "edgePanel.route"
    static let selectedFolderID = "edgePanel.selectedFolderID"
    static let defaultNoteColor = "notes.defaultColor"
    static let newNoteLocation = "notes.newNoteLocation"
    static let showVerticalScrollbars = "notes.showVerticalScrollbars"
    static let newFolderLocation = "folders.newFolderLocation"
    static let folderOpenMode = "folders.openMode"
  }

  static var didCompleteOnboarding: Bool {
    get { UserDefaults.standard.bool(forKey: Key.didCompleteOnboarding) }
    set { UserDefaults.standard.set(newValue, forKey: Key.didCompleteOnboarding) }
  }

  static var defaultNoteColor: NoteColor {
    let rawValue = UserDefaults.standard.string(forKey: Key.defaultNoteColor) ?? NoteColor.amber.rawValue
    return NoteColor(rawValue: rawValue) ?? .amber
  }

  static var newNoteLocation: String {
    UserDefaults.standard.string(forKey: Key.newNoteLocation) ?? "currentOrTop"
  }

  static var newFolderLocation: String {
    UserDefaults.standard.string(forKey: Key.newFolderLocation) ?? "bottom"
  }

  static var folderOpenMode: String {
    UserDefaults.standard.string(forKey: Key.folderOpenMode) ?? "single"
  }
}
