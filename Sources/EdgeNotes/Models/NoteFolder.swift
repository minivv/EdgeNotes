import Foundation

struct NoteFolder: Identifiable, Codable, Hashable {
  var id: UUID
  var name: String
  var color: NoteColor
  var isPinned: Bool
  var sortIndex: Int
  var createdAt: Date

  init(
    id: UUID = UUID(),
    name: String,
    color: NoteColor = .graphite,
    isPinned: Bool = false,
    sortIndex: Int,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.name = name
    self.color = color
    self.isPinned = isPinned
    self.sortIndex = sortIndex
    self.createdAt = createdAt
  }
}
