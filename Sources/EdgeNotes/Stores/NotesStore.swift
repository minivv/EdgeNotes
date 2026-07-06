import Combine
import Foundation
import SwiftUI

@MainActor
final class NotesStore: ObservableObject {
  @Published private(set) var folders: [NoteFolder] = []
  @Published private(set) var notes: [Note] = []
  @Published var selectedFolderID: UUID? {
    didSet {
      persistSelectedFolder()
      selectFirstVisibleNoteIfNeeded()
    }
  }
  @Published var selectedNoteID: UUID?
  @Published var searchText = "" {
    didSet { selectFirstVisibleNoteIfNeeded() }
  }
  @Published private(set) var lastPersistenceError: String?

  private let storeURL: URL

  init(storeURL: URL = NotesStore.defaultStoreURL()) {
    self.storeURL = storeURL
    load()
  }

  var dataDirectoryURL: URL {
    storeURL.deletingLastPathComponent()
  }

  var sortedFolders: [NoteFolder] {
    folders.sorted {
      if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
      if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
      return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
  }

  var selectedFolderName: String {
    guard let selectedFolderID,
          let folder = folders.first(where: { $0.id == selectedFolderID })
    else {
      return "All Notes"
    }

    return folder.name
  }

  var selectedNote: Note? {
    guard let selectedNoteID else { return nil }
    return notes.first(where: { $0.id == selectedNoteID })
  }

  func visibleNotes() -> [Note] {
    visibleNotes(includeSearch: true)
  }

  @discardableResult
  func createFolder(name: String = "新建文件夹") -> UUID {
    var folder = NoteFolder(
      name: uniqueFolderName(base: name),
      color: .sky,
      sortIndex: nextFolderSortIndex()
    )
    if AppPreferences.newFolderLocation == "top" {
      for index in folders.indices {
        folders[index].sortIndex += 1
      }
      folder.sortIndex = 0
    }
    folders.append(folder)
    selectedFolderID = folder.id
    save()
    return folder.id
  }

  func renameFolder(_ id: UUID, name: String) {
    guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
    folders[index].name = name.isEmpty ? "Untitled Folder" : name
    save()
  }

  func deleteFolder(_ id: UUID) {
    folders.removeAll { $0.id == id }
    for index in notes.indices where notes[index].folderID == id {
      notes[index].folderID = nil
      notes[index].updatedAt = Date()
    }
    if selectedFolderID == id {
      selectedFolderID = nil
    }
    save()
  }

  func toggleFolderPinned(_ id: UUID) {
    guard let index = folders.firstIndex(where: { $0.id == id }) else { return }
    folders[index].isPinned.toggle()
    save()
  }

  func moveFolders(from offsets: IndexSet, to destination: Int) {
    var ordered = sortedFolders
    ordered.move(fromOffsets: offsets, toOffset: destination)
    for (sortIndex, folder) in ordered.enumerated() {
      guard let originalIndex = folders.firstIndex(where: { $0.id == folder.id }) else { continue }
      folders[originalIndex].sortIndex = sortIndex
    }
    save()
  }

  func moveFolder(sourceID: UUID, before targetID: UUID) {
    guard sourceID != targetID else { return }
    var ordered = sortedFolders
    guard let sourceIndex = ordered.firstIndex(where: { $0.id == sourceID }),
          let targetIndex = ordered.firstIndex(where: { $0.id == targetID })
    else { return }

    let folder = ordered.remove(at: sourceIndex)
    let insertionIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
    ordered.insert(folder, at: max(0, insertionIndex))

    for (sortIndex, folder) in ordered.enumerated() {
      guard let originalIndex = folders.firstIndex(where: { $0.id == folder.id }) else { continue }
      folders[originalIndex].sortIndex = sortIndex
    }
    save()
  }

  @discardableResult
  func createNote(title: String = "新建笔记", body: String = "") -> UUID {
    let folderID = selectedFolderID
    var sortIndex = sortIndexForNewNote(in: folderID)
    if AppPreferences.newNoteLocation != "bottom" {
      for index in notes.indices where notes[index].folderID == folderID && notes[index].sortIndex >= sortIndex {
        notes[index].sortIndex += 1
      }
    } else {
      sortIndex = nextNoteSortIndex(in: folderID)
    }

    let note = Note(
      folderID: folderID,
      title: title,
      body: body,
      color: AppPreferences.defaultNoteColor,
      sortIndex: sortIndex
    )
    notes.append(note)
    selectedNoteID = note.id
    save()
    return note.id
  }

  func duplicateNote(_ id: UUID) {
    guard let note = notes.first(where: { $0.id == id }) else { return }
    var copy = note
    copy.id = UUID()
    copy.title = "\(note.title) Copy"
    copy.sortIndex = nextNoteSortIndex(in: note.folderID)
    copy.createdAt = Date()
    copy.updatedAt = Date()
    notes.append(copy)
    selectedNoteID = copy.id
    save()
  }

  func deleteNote(_ id: UUID) {
    notes.removeAll { $0.id == id }
    if selectedNoteID == id {
      selectedNoteID = visibleNotes().first?.id
    }
    save()
  }

  func updateNote(_ id: UUID, title: String? = nil, body: String? = nil) {
    guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
    if let title {
      notes[index].title = title
    }
    if let body {
      notes[index].body = body
    }
    notes[index].updatedAt = Date()
    save()
  }

  func setNoteColor(_ id: UUID, color: NoteColor) {
    guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
    notes[index].color = color
    notes[index].updatedAt = Date()
    save()
  }

  func toggleNotePinned(_ id: UUID) {
    guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
    notes[index].isPinned.toggle()
    notes[index].updatedAt = Date()
    save()
  }

  func toggleNoteCollapsed(_ id: UUID) {
    guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
    notes[index].isCollapsed.toggle()
    notes[index].updatedAt = Date()
    save()
  }

  func setVisibleNotesCollapsed(_ collapsed: Bool) {
    let visibleIDs = Set(visibleNotes().map(\.id))
    guard !visibleIDs.isEmpty else { return }
    for index in notes.indices where visibleIDs.contains(notes[index].id) {
      notes[index].isCollapsed = collapsed
      notes[index].updatedAt = Date()
    }
    save()
  }

  func moveSelectedNote(to folderID: UUID?) {
    guard let selectedNoteID,
          let index = notes.firstIndex(where: { $0.id == selectedNoteID })
    else { return }

    notes[index].folderID = folderID
    notes[index].sortIndex = nextNoteSortIndex(in: folderID)
    notes[index].updatedAt = Date()
    selectedFolderID = folderID
    save()
  }

  func moveVisibleNotes(from offsets: IndexSet, to destination: Int) {
    guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    var ordered = visibleNotes(includeSearch: false)
    ordered.move(fromOffsets: offsets, toOffset: destination)
    for (sortIndex, note) in ordered.enumerated() {
      guard let originalIndex = notes.firstIndex(where: { $0.id == note.id }) else { continue }
      notes[originalIndex].sortIndex = sortIndex
    }
    save()
  }

  func moveNote(sourceID: UUID, before targetID: UUID) {
    guard searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          sourceID != targetID
    else { return }

    var ordered = visibleNotes(includeSearch: false)
    guard let sourceIndex = ordered.firstIndex(where: { $0.id == sourceID }),
          let targetIndex = ordered.firstIndex(where: { $0.id == targetID })
    else { return }

    let note = ordered.remove(at: sourceIndex)
    let insertionIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
    ordered.insert(note, at: max(0, insertionIndex))

    for (sortIndex, note) in ordered.enumerated() {
      guard let originalIndex = notes.firstIndex(where: { $0.id == note.id }) else { continue }
      notes[originalIndex].sortIndex = sortIndex
    }
    save()
  }

  func taskLines(for note: Note) -> [TaskLine] {
    note.body.components(separatedBy: .newlines).enumerated().compactMap { index, line in
      guard let parsed = parseTaskLine(line) else { return nil }
      return TaskLine(lineIndex: index, isDone: parsed.isDone, title: parsed.title)
    }
  }

  func toggleTask(noteID: UUID, lineIndex: Int) {
    guard let noteIndex = notes.firstIndex(where: { $0.id == noteID }) else { return }
    var lines = notes[noteIndex].body.components(separatedBy: .newlines)
    guard lines.indices.contains(lineIndex),
          let parsed = parseTaskLine(lines[lineIndex])
    else { return }

    let line = lines[lineIndex]
    let indentation = String(line.prefix { $0 == " " || $0 == "\t" })
    let marker = parsed.isDone ? "- [ ] " : "- [x] "
    lines[lineIndex] = indentation + marker + parsed.title
    notes[noteIndex].body = lines.joined(separator: "\n")
    notes[noteIndex].updatedAt = Date()
    save()
  }

  func backupPayload() -> BackupPayload {
    BackupPayload(
      schemaVersion: 1,
      exportedAt: Date(),
      folders: sortedFolders,
      notes: notes.sorted {
        if $0.folderID != $1.folderID { return String(describing: $0.folderID) < String(describing: $1.folderID) }
        if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
        return $0.sortIndex < $1.sortIndex
      }
    )
  }

  func exportBackupData() throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601
    return try encoder.encode(backupPayload())
  }

  private func visibleNotes(includeSearch: Bool) -> [Note] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    return notes
      .filter { note in
        if let selectedFolderID, note.folderID != selectedFolderID {
          return false
        }
        guard includeSearch, !query.isEmpty else {
          return true
        }
        return note.title.localizedCaseInsensitiveContains(query)
          || note.body.localizedCaseInsensitiveContains(query)
      }
      .sorted {
        if $0.isPinned != $1.isPinned { return $0.isPinned && !$1.isPinned }
        if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
        return $0.updatedAt > $1.updatedAt
      }
  }

  private func load() {
    do {
      guard FileManager.default.fileExists(atPath: storeURL.path) else {
        seed()
        save()
        return
      }

      let data = try Data(contentsOf: storeURL)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let database = try decoder.decode(NotesDatabase.self, from: data)
      folders = database.folders
      notes = database.notes
      restoreSelectedFolder()
      selectedNoteID = visibleNotes().first?.id
      lastPersistenceError = nil
    } catch {
      lastPersistenceError = error.localizedDescription
      seed()
    }
  }

  private func save() {
    do {
      try FileManager.default.createDirectory(
        at: storeURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      encoder.dateEncodingStrategy = .iso8601
      let data = try encoder.encode(NotesDatabase(folders: folders, notes: notes))
      try data.write(to: storeURL, options: [.atomic])
      lastPersistenceError = nil
    } catch {
      lastPersistenceError = error.localizedDescription
    }
  }

  private func seed() {
    let inbox = NoteFolder(name: "Inbox", color: .sky, isPinned: true, sortIndex: 0)
    let projects = NoteFolder(name: "Projects", color: .violet, sortIndex: 1)
    folders = [inbox, projects]
    notes = [
      Note(
        folderID: inbox.id,
        title: "Quick Capture",
        body: """
        Drop thoughts here while you work.

        - [ ] Try the side Open Bar
        - [x] Pin this note
        - [ ] Change the note color
        """,
        color: .amber,
        isPinned: true,
        sortIndex: 0
      ),
      Note(
        folderID: projects.id,
        title: "Markdown Preview",
        body: """
        # EdgeNotes

        A compact side notebook with **Markdown**, tasks, folders, search, pins, colors, and scheduled Gist backups.
        """,
        color: .mint,
        sortIndex: 0
      )
    ]
    selectedFolderID = nil
    selectedNoteID = notes.first?.id
  }

  private func selectFirstVisibleNoteIfNeeded() {
    let visible = visibleNotes()
    guard !visible.contains(where: { $0.id == selectedNoteID }) else { return }
    selectedNoteID = visible.first?.id
  }

  private func restoreSelectedFolder() {
    guard let uuidString = UserDefaults.standard.string(forKey: AppPreferences.Key.selectedFolderID),
          let folderID = UUID(uuidString: uuidString),
          folders.contains(where: { $0.id == folderID })
    else {
      selectedFolderID = nil
      return
    }

    selectedFolderID = folderID
  }

  private func persistSelectedFolder() {
    if let selectedFolderID {
      UserDefaults.standard.set(selectedFolderID.uuidString, forKey: AppPreferences.Key.selectedFolderID)
    } else {
      UserDefaults.standard.removeObject(forKey: AppPreferences.Key.selectedFolderID)
    }
  }

  private func nextFolderSortIndex() -> Int {
    (folders.map(\.sortIndex).max() ?? -1) + 1
  }

  private func nextNoteSortIndex(in folderID: UUID?) -> Int {
    let scoped = notes.filter { $0.folderID == folderID }
    return (scoped.map(\.sortIndex).max() ?? -1) + 1
  }

  private func sortIndexForNewNote(in folderID: UUID?) -> Int {
    guard AppPreferences.newNoteLocation != "bottom" else {
      return nextNoteSortIndex(in: folderID)
    }

    if let selectedNoteID,
       let selected = notes.first(where: { $0.id == selectedNoteID && $0.folderID == folderID }) {
      return selected.sortIndex
    }

    return notes
      .filter { $0.folderID == folderID }
      .map(\.sortIndex)
      .min() ?? 0
  }

  private func uniqueFolderName(base: String) -> String {
    let names = Set(folders.map(\.name))
    guard names.contains(base) else { return base }
    var index = 2
    while names.contains("\(base) \(index)") {
      index += 1
    }
    return "\(base) \(index)"
  }

  private func parseTaskLine(_ line: String) -> (isDone: Bool, title: String)? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    let openPrefix = "- [ ] "
    let donePrefix = "- [x] "
    let donePrefixUpper = "- [X] "

    if trimmed.hasPrefix(openPrefix) {
      return (false, String(trimmed.dropFirst(openPrefix.count)))
    }
    if trimmed.hasPrefix(donePrefix) {
      return (true, String(trimmed.dropFirst(donePrefix.count)))
    }
    if trimmed.hasPrefix(donePrefixUpper) {
      return (true, String(trimmed.dropFirst(donePrefixUpper.count)))
    }
    return nil
  }

  nonisolated static func defaultStoreURL() -> URL {
    let support = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first ?? FileManager.default.temporaryDirectory

    return support
      .appendingPathComponent("EdgeNotes", isDirectory: true)
      .appendingPathComponent("notes.json")
  }
}

private struct NotesDatabase: Codable {
  var schemaVersion: Int
  var folders: [NoteFolder]
  var notes: [Note]

  init(schemaVersion: Int = 1, folders: [NoteFolder], notes: [Note]) {
    self.schemaVersion = schemaVersion
    self.folders = folders
    self.notes = notes
  }
}
