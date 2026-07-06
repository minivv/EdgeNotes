import Foundation

struct BackupPayload: Codable {
  var schemaVersion: Int
  var exportedAt: Date
  var folders: [NoteFolder]
  var notes: [Note]
}
