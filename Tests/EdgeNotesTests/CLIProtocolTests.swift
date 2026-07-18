import EdgeNotesIPC
import Foundation
import XCTest

final class CLIProtocolTests: XCTestCase {
  func testRequestAndResponseRoundTrip() throws {
    let request = CLIRequest(
      id: UUID(),
      method: .notesCreate,
      parameters: CLIParameters(
        folder: "Inbox",
        title: "CLI note",
        body: "Body",
        color: "mint"
      )
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let decodedRequest = try decoder.decode(CLIRequest.self, from: encoder.encode(request))
    XCTAssertEqual(decodedRequest.version, EdgeNotesCLIProtocol.version)
    XCTAssertEqual(decodedRequest.id, request.id)
    XCTAssertEqual(decodedRequest.method, .notesCreate)
    XCTAssertEqual(decodedRequest.parameters.folder, "Inbox")
    XCTAssertEqual(decodedRequest.parameters.color, "mint")

    let note = CLINote(
      id: UUID(),
      folderID: UUID(),
      folderName: "Inbox",
      title: "CLI note",
      body: "Body",
      color: "mint",
      isPinned: false,
      isCollapsed: false,
      sortIndex: 0,
      createdAt: Date(timeIntervalSince1970: 123),
      updatedAt: Date(timeIntervalSince1970: 456)
    )
    let response = CLIResponse.success(id: request.id, result: CLIResult(note: note))
    let decodedResponse = try decoder.decode(CLIResponse.self, from: encoder.encode(response))
    XCTAssertEqual(decodedResponse, response)
  }

  func testUnixSocketClientAndServerExchangeOneMessage() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let socketPath = directory.appendingPathComponent("cli.sock").path
    defer { try? FileManager.default.removeItem(at: directory) }

    let server = EdgeNotesIPCServer(socketPath: socketPath) { request, completion in
      completion(.success(id: request.id, result: CLIResult(pong: true)))
    }
    try server.start()
    defer { server.stop() }

    let client = EdgeNotesIPCClient(socketPath: socketPath)
    for _ in 0..<50 {
      let request = CLIRequest(method: .ping)
      let response = try client.send(request)
      XCTAssertEqual(response.id, request.id)
      XCTAssertEqual(response.result?.pong, true)
    }

    let attributes = try FileManager.default.attributesOfItem(atPath: socketPath)
    let permissions = try XCTUnwrap(attributes[.posixPermissions] as? NSNumber)
    XCTAssertEqual(permissions.intValue & 0o777, 0o600)
  }
}
