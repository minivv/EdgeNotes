import Foundation

struct TaskLine: Identifiable, Hashable {
  var id: Int { lineIndex }
  var lineIndex: Int
  var isDone: Bool
  var title: String
}
