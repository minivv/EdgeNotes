import Foundation
import XCTest
@testable import EdgeNotes

final class NotesStoreFileMonitoringTests: XCTestCase {
  @MainActor
  func testReloadsAtomicAndInPlaceExternalChanges() async throws {
    let directoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storeURL = directoryURL.appendingPathComponent("notes.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let store = NotesStore(storeURL: storeURL)

    try rewriteFirstNoteTitle("Atomic external edit", at: storeURL, options: [.atomic])
    let didLoadAtomicEdit = await waitUntil {
      store.notes.first?.title == "Atomic external edit"
    }
    XCTAssertTrue(didLoadAtomicEdit)

    try rewriteFirstNoteTitle("In-place external edit", at: storeURL, options: [])
    let didLoadInPlaceEdit = await waitUntil {
      store.notes.first?.title == "In-place external edit"
    }
    XCTAssertTrue(didLoadInPlaceEdit)
  }

  private func rewriteFirstNoteTitle(
    _ title: String,
    at url: URL,
    options: Data.WritingOptions
  ) throws {
    let data = try Data(contentsOf: url)
    guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          var notes = root["notes"] as? [[String: Any]],
          !notes.isEmpty
    else {
      XCTFail("The seeded notes database has an unexpected shape")
      return
    }

    notes[0]["title"] = title
    root["notes"] = notes
    let updatedData = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    try updatedData.write(to: url, options: options)
  }

  @MainActor
  private func waitUntil(
    timeout: Duration = .seconds(2),
    condition: () -> Bool
  ) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)

    while clock.now < deadline {
      if condition() { return true }
      try? await Task.sleep(for: .milliseconds(20))
    }

    return condition()
  }
}
