import Foundation

struct Note: Identifiable, Codable, Hashable {
  var id: UUID
  var folderID: UUID?
  var title: String
  var body: String
  var color: NoteColor
  var isPinned: Bool
  var isCollapsed: Bool
  var sortIndex: Int
  var createdAt: Date
  var updatedAt: Date

  init(
    id: UUID = UUID(),
    folderID: UUID?,
    title: String,
    body: String,
    color: NoteColor = .graphite,
    isPinned: Bool = false,
    isCollapsed: Bool = false,
    sortIndex: Int,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.folderID = folderID
    self.title = title
    self.body = body
    self.color = color
    self.isPinned = isPinned
    self.isCollapsed = isCollapsed
    self.sortIndex = sortIndex
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}
