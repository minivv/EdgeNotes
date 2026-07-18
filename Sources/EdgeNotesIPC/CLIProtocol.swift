import Foundation

public enum EdgeNotesCLIProtocol {
  public static let version = 1
  public static let maximumMessageSize = 1_048_576
}

public enum CLIProtocolMethod: String, Codable, Sendable {
  case ping
  case foldersList = "folders.list"
  case foldersCreate = "folders.create"
  case notesList = "notes.list"
  case notesGet = "notes.get"
  case notesCreate = "notes.create"
  case notesAppend = "notes.append"
  case notesUpdate = "notes.update"
  case notesOpen = "notes.open"
  case tasksList = "tasks.list"
  case tasksToggle = "tasks.toggle"
}

public struct CLIRequest: Codable, Sendable {
  public var version: Int
  public var id: UUID
  public var method: CLIProtocolMethod
  public var parameters: CLIParameters

  public init(
    version: Int = EdgeNotesCLIProtocol.version,
    id: UUID = UUID(),
    method: CLIProtocolMethod,
    parameters: CLIParameters = CLIParameters()
  ) {
    self.version = version
    self.id = id
    self.method = method
    self.parameters = parameters
  }
}

public struct CLIParameters: Codable, Sendable {
  public var noteID: UUID?
  public var folder: String?
  public var title: String?
  public var body: String?
  public var text: String?
  public var query: String?
  public var color: String?
  public var lineIndex: Int?
  public var limit: Int?

  public init(
    noteID: UUID? = nil,
    folder: String? = nil,
    title: String? = nil,
    body: String? = nil,
    text: String? = nil,
    query: String? = nil,
    color: String? = nil,
    lineIndex: Int? = nil,
    limit: Int? = nil
  ) {
    self.noteID = noteID
    self.folder = folder
    self.title = title
    self.body = body
    self.text = text
    self.query = query
    self.color = color
    self.lineIndex = lineIndex
    self.limit = limit
  }
}

public struct CLIFolder: Codable, Sendable, Equatable {
  public var id: UUID
  public var name: String
  public var color: String
  public var isPinned: Bool
  public var sortIndex: Int
  public var createdAt: Date

  public init(
    id: UUID,
    name: String,
    color: String,
    isPinned: Bool,
    sortIndex: Int,
    createdAt: Date
  ) {
    self.id = id
    self.name = name
    self.color = color
    self.isPinned = isPinned
    self.sortIndex = sortIndex
    self.createdAt = createdAt
  }
}

public struct CLINote: Codable, Sendable, Equatable {
  public var id: UUID
  public var folderID: UUID?
  public var folderName: String?
  public var title: String
  public var body: String
  public var color: String
  public var isPinned: Bool
  public var isCollapsed: Bool
  public var sortIndex: Int
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: UUID,
    folderID: UUID?,
    folderName: String?,
    title: String,
    body: String,
    color: String,
    isPinned: Bool,
    isCollapsed: Bool,
    sortIndex: Int,
    createdAt: Date,
    updatedAt: Date
  ) {
    self.id = id
    self.folderID = folderID
    self.folderName = folderName
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

public struct CLITask: Codable, Sendable, Equatable {
  public var lineIndex: Int
  public var isDone: Bool
  public var title: String

  public init(lineIndex: Int, isDone: Bool, title: String) {
    self.lineIndex = lineIndex
    self.isDone = isDone
    self.title = title
  }
}

public struct CLIResult: Codable, Sendable, Equatable {
  public var pong: Bool?
  public var folders: [CLIFolder]?
  public var folder: CLIFolder?
  public var notes: [CLINote]?
  public var note: CLINote?
  public var tasks: [CLITask]?
  public var task: CLITask?
  public var message: String?

  public init(
    pong: Bool? = nil,
    folders: [CLIFolder]? = nil,
    folder: CLIFolder? = nil,
    notes: [CLINote]? = nil,
    note: CLINote? = nil,
    tasks: [CLITask]? = nil,
    task: CLITask? = nil,
    message: String? = nil
  ) {
    self.pong = pong
    self.folders = folders
    self.folder = folder
    self.notes = notes
    self.note = note
    self.tasks = tasks
    self.task = task
    self.message = message
  }
}

public struct CLIProtocolError: Codable, Error, LocalizedError, Sendable, Equatable {
  public var code: String
  public var message: String

  public init(code: String, message: String) {
    self.code = code
    self.message = message
  }

  public var errorDescription: String? { message }
}

public struct CLIResponse: Codable, Sendable, Equatable {
  public var version: Int
  public var id: UUID
  public var result: CLIResult?
  public var error: CLIProtocolError?

  public init(
    version: Int = EdgeNotesCLIProtocol.version,
    id: UUID,
    result: CLIResult? = nil,
    error: CLIProtocolError? = nil
  ) {
    self.version = version
    self.id = id
    self.result = result
    self.error = error
  }

  public static func success(id: UUID, result: CLIResult) -> CLIResponse {
    CLIResponse(id: id, result: result)
  }

  public static func failure(id: UUID, code: String, message: String) -> CLIResponse {
    CLIResponse(id: id, error: CLIProtocolError(code: code, message: message))
  }
}

public enum EdgeNotesSocketPath {
  public static let environmentKey = "EDGENOTES_SOCKET"

  public static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
    if let override = environment[environmentKey], !override.isEmpty {
      return (override as NSString).expandingTildeInPath
    }

    let support = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first ?? FileManager.default.temporaryDirectory
    return support
      .appendingPathComponent("EdgeNotes", isDirectory: true)
      .appendingPathComponent("edgenotes-v1.sock")
      .path
  }
}
