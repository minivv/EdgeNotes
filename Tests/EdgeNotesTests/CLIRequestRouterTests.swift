import EdgeNotesIPC
import Foundation
import XCTest
@testable import EdgeNotes

final class CLIRequestRouterTests: XCTestCase {
  @MainActor
  func testCreatesNoteInExplicitFolderWithoutChangingUISelection() throws {
    let fixture = makeFixture()
    defer { fixture.cleanup() }
    let store = fixture.store
    let router = CLIRequestRouter(store: store)
    let inbox = try XCTUnwrap(store.folders.first(where: { $0.name == "Inbox" }))
    let projects = try XCTUnwrap(store.folders.first(where: { $0.name == "Projects" }))
    store.selectedFolderID = inbox.id
    let selectedNoteID = store.selectedNoteID

    let response = router.handle(CLIRequest(
      method: .notesCreate,
      parameters: CLIParameters(
        folder: projects.name,
        title: "Created from CLI",
        body: "Hello",
        color: "violet"
      )
    ))

    XCTAssertNil(response.error)
    XCTAssertEqual(response.result?.note?.folderID, projects.id)
    XCTAssertEqual(response.result?.note?.color, "violet")
    XCTAssertEqual(store.selectedFolderID, inbox.id)
    XCTAssertEqual(store.selectedNoteID, selectedNoteID)
  }

  @MainActor
  func testCreateWithoutFolderCreatesAndReusesVisibleDefaultFolder() throws {
    let fixture = makeFixture()
    defer { fixture.cleanup() }
    let store = fixture.store
    let router = CLIRequestRouter(store: store)
    let firstResponse = router.handle(CLIRequest(
      method: .notesCreate,
      parameters: CLIParameters(title: "First CLI note", body: "Hello", color: "graphite")
    ))
    let secondResponse = router.handle(CLIRequest(
      method: .notesCreate,
      parameters: CLIParameters(title: "Second CLI note", body: "Hello", color: "graphite")
    ))

    let defaultFolders = store.folders.filter { $0.name == "新建文件夹" }
    let defaultFolder = try XCTUnwrap(defaultFolders.first)

    XCTAssertNil(firstResponse.error)
    XCTAssertNil(secondResponse.error)
    XCTAssertEqual(defaultFolders.count, 1)
    XCTAssertEqual(firstResponse.result?.note?.folderID, defaultFolder.id)
    XCTAssertEqual(secondResponse.result?.note?.folderID, defaultFolder.id)
    XCTAssertEqual(firstResponse.result?.note?.folderName, "新建文件夹")
    XCTAssertEqual(secondResponse.result?.note?.folderName, "新建文件夹")
  }

  @MainActor
  func testCreateWithMissingFolderNameCreatesFolder() throws {
    let fixture = makeFixture()
    defer { fixture.cleanup() }
    let store = fixture.store
    let router = CLIRequestRouter(store: store)

    let response = router.handle(CLIRequest(
      method: .notesCreate,
      parameters: CLIParameters(
        folder: "新文件夹",
        title: "Created with its folder",
        body: "Hello",
        color: "mint"
      )
    ))

    let folder = try XCTUnwrap(store.folders.first(where: { $0.name == "新文件夹" }))
    XCTAssertNil(response.error)
    XCTAssertEqual(response.result?.note?.folderID, folder.id)
    XCTAssertEqual(response.result?.note?.folderName, "新文件夹")
  }

  @MainActor
  func testSearchAppendUpdateAndToggleTask() throws {
    let fixture = makeFixture()
    defer { fixture.cleanup() }
    let store = fixture.store
    let router = CLIRequestRouter(store: store)
    let quickCapture = try XCTUnwrap(store.notes.first(where: { $0.title == "Quick Capture" }))

    let search = router.handle(CLIRequest(
      method: .notesList,
      parameters: CLIParameters(query: "side open bar", limit: 1)
    ))
    XCTAssertEqual(search.result?.notes?.map(\.id), [quickCapture.id])

    let append = router.handle(CLIRequest(
      method: .notesAppend,
      parameters: CLIParameters(noteID: quickCapture.id, text: "Appended")
    ))
    XCTAssertTrue(append.result?.note?.body.hasSuffix("\nAppended") == true)

    let update = router.handle(CLIRequest(
      method: .notesUpdate,
      parameters: CLIParameters(note: quickCapture.title, folder: "Projects", title: "Updated", color: "sky")
    ))
    XCTAssertEqual(update.result?.note?.title, "Updated")
    XCTAssertTrue(update.result?.note?.body.hasSuffix("\nAppended") == true)
    XCTAssertEqual(update.result?.note?.folderName, "Projects")
    XCTAssertEqual(update.result?.note?.color, "sky")

    let taskBefore = try XCTUnwrap(store.taskLines(for: try XCTUnwrap(store.notes.first(where: { $0.id == quickCapture.id }))).first)
    let toggle = router.handle(CLIRequest(
      method: .tasksToggle,
      parameters: CLIParameters(noteID: quickCapture.id, lineIndex: taskBefore.lineIndex)
    ))
    XCTAssertEqual(toggle.result?.task?.isDone, !taskBefore.isDone)
  }

  @MainActor
  func testDuplicateNoteTitlesRequireID() throws {
    let fixture = makeFixture()
    defer { fixture.cleanup() }
    let store = fixture.store
    let router = CLIRequestRouter(store: store)
    _ = store.createNote(title: "重复标题", body: "One", folderID: nil, color: .graphite)
    _ = store.createNote(title: "重复标题", body: "Two", folderID: nil, color: .graphite)

    let response = router.handle(CLIRequest(
      method: .notesGet,
      parameters: CLIParameters(note: "重复标题")
    ))

    XCTAssertEqual(response.error?.code, "ambiguous_note")
    XCTAssertTrue(response.error?.message.contains("笔记 ID") == true)
  }

  @MainActor
  func testReturnsUsefulValidationErrors() throws {
    let fixture = makeFixture()
    defer { fixture.cleanup() }
    let router = CLIRequestRouter(store: fixture.store)

    let invalidColor = router.handle(CLIRequest(
      method: .notesCreate,
      parameters: CLIParameters(title: "Bad color", color: "neon")
    ))
    XCTAssertEqual(invalidColor.error?.code, "invalid_color")
    XCTAssertTrue(invalidColor.error?.message.contains("graphite") == true)

    let missingFolder = router.handle(CLIRequest(
      method: .notesList,
      parameters: CLIParameters(folder: "Does Not Exist")
    ))
    XCTAssertEqual(missingFolder.error?.code, "not_found")

    let invalidLimit = router.handle(CLIRequest(
      method: .notesList,
      parameters: CLIParameters(limit: 0)
    ))
    XCTAssertEqual(invalidLimit.error?.code, "invalid_parameter")
  }

  @MainActor
  private func makeFixture() -> StoreFixture {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let storeURL = directory.appendingPathComponent("notes.json")
    return StoreFixture(store: NotesStore(storeURL: storeURL), directory: directory)
  }
}

private struct StoreFixture {
  let store: NotesStore
  let directory: URL

  func cleanup() {
    try? FileManager.default.removeItem(at: directory)
  }
}
