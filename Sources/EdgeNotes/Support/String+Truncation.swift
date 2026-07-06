import Foundation

extension String {
  func menuTitle(maxLength: Int = 30) -> String {
    let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > maxLength else {
      return trimmed.isEmpty ? "Untitled Note" : trimmed
    }
    let end = trimmed.index(trimmed.startIndex, offsetBy: maxLength - 1)
    return String(trimmed[..<end]) + "…"
  }
}
