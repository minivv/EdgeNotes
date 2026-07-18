import Combine
import EdgeNotesIPC
import Foundation

@MainActor
final class CLIRequestRouter {
  private let store: NotesStore
  private let openNoteHandler: (UUID) -> Void

  init(store: NotesStore, openNoteHandler: @escaping (UUID) -> Void = { _ in }) {
    self.store = store
    self.openNoteHandler = openNoteHandler
  }

  func handle(_ request: CLIRequest) -> CLIResponse {
    guard request.version == EdgeNotesCLIProtocol.version else {
      return .failure(
        id: request.id,
        code: "unsupported_version",
        message: "不支持 CLI 协议版本 \(request.version)，当前版本为 \(EdgeNotesCLIProtocol.version)"
      )
    }

    do {
      let result = try route(method: request.method, parameters: request.parameters)
      return .success(id: request.id, result: result)
    } catch let error as CLIProtocolError {
      return CLIResponse(id: request.id, error: error)
    } catch {
      return .failure(id: request.id, code: "internal_error", message: error.localizedDescription)
    }
  }

  private func route(method: CLIProtocolMethod, parameters: CLIParameters) throws -> CLIResult {
    switch method {
    case .ping:
      return CLIResult(pong: true)

    case .foldersList:
      return CLIResult(folders: store.sortedFolders.map(folderDTO))

    case .foldersCreate:
      let name = try requiredNonempty(parameters.title, label: "文件夹名称")
      let id = store.createFolder(name: name, selectCreatedFolder: false)
      guard let folder = store.folders.first(where: { $0.id == id }) else {
        throw failure("internal_error", "文件夹已创建，但无法读取创建结果")
      }
      return CLIResult(folder: folderDTO(folder))

    case .notesList:
      let folderID = try resolveFolder(parameters.folder)
      let query = parameters.query?.trimmingCharacters(in: .whitespacesAndNewlines)
      let limit = try validatedLimit(parameters.limit)
      var notes = store.notes.filter { note in
        if parameters.folder != nil, note.folderID != folderID { return false }
        guard let query, !query.isEmpty else { return true }
        return note.title.localizedCaseInsensitiveContains(query)
          || note.body.localizedCaseInsensitiveContains(query)
      }
      notes.sort(by: noteOrdering)
      if let limit { notes = Array(notes.prefix(limit)) }
      return CLIResult(notes: notes.map(noteDTO))

    case .notesGet:
      return CLIResult(note: noteDTO(try note(id: parameters.noteID)))

    case .notesCreate:
      let title = try requiredNonempty(parameters.title, label: "笔记标题")
      let folderID = try resolveFolder(parameters.folder)
      let color = try resolveColor(parameters.color ?? NoteColor.graphite.rawValue)
      let id = store.createNote(
        title: title,
        body: parameters.body ?? "",
        folderID: folderID,
        color: color
      )
      return CLIResult(note: noteDTO(try note(id: id)))

    case .notesAppend:
      let existing = try note(id: parameters.noteID)
      guard let text = parameters.text else {
        throw failure("invalid_parameter", "缺少要追加的文本")
      }
      let separator = existing.body.isEmpty || existing.body.hasSuffix("\n") ? "" : "\n"
      store.updateNote(existing.id, body: existing.body + separator + text)
      return CLIResult(note: noteDTO(try note(id: existing.id)))

    case .notesUpdate:
      let existing = try note(id: parameters.noteID)
      guard parameters.title != nil || parameters.body != nil else {
        throw failure("invalid_parameter", "至少需要提供 --title、--body、--body-file 或 --stdin 之一")
      }
      if let title = parameters.title, title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw failure("invalid_parameter", "笔记标题不能为空")
      }
      store.updateNote(existing.id, title: parameters.title, body: parameters.body)
      return CLIResult(note: noteDTO(try note(id: existing.id)))

    case .notesOpen:
      let existing = try note(id: parameters.noteID)
      openNoteHandler(existing.id)
      return CLIResult(note: noteDTO(existing), message: "已在 EdgeNotes 中打开笔记")

    case .tasksList:
      let existing = try note(id: parameters.noteID)
      return CLIResult(tasks: store.taskLines(for: existing).map(taskDTO))

    case .tasksToggle:
      let existing = try note(id: parameters.noteID)
      guard let lineIndex = parameters.lineIndex, lineIndex >= 0 else {
        throw failure("invalid_parameter", "行号必须是大于或等于 0 的整数")
      }
      guard let task = store.taskLines(for: existing).first(where: { $0.lineIndex == lineIndex }) else {
        throw failure("not_found", "第 \(lineIndex) 行不是 Markdown 待办")
      }
      store.toggleTask(noteID: existing.id, lineIndex: lineIndex)
      let updated = try note(id: existing.id)
      let updatedTask = store.taskLines(for: updated).first(where: { $0.lineIndex == lineIndex })
        ?? TaskLine(lineIndex: task.lineIndex, isDone: !task.isDone, title: task.title)
      return CLIResult(note: noteDTO(updated), task: taskDTO(updatedTask))
    }
  }

  private func note(id: UUID?) throws -> Note {
    guard let id else {
      throw failure("invalid_parameter", "缺少笔记 ID")
    }
    guard let note = store.notes.first(where: { $0.id == id }) else {
      throw failure("not_found", "找不到笔记：\(id.uuidString)")
    }
    return note
  }

  private func resolveFolder(_ selector: String?) throws -> UUID? {
    guard let selector else { return nil }
    let value = selector.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else {
      throw failure("invalid_parameter", "文件夹 ID 或名称不能为空")
    }

    if let id = UUID(uuidString: value) {
      guard store.folders.contains(where: { $0.id == id }) else {
        throw failure("not_found", "找不到文件夹：\(value)")
      }
      return id
    }

    let matches = store.folders.filter { $0.name.compare(value, options: .caseInsensitive) == .orderedSame }
    guard !matches.isEmpty else {
      throw failure("not_found", "找不到文件夹：\(value)")
    }
    guard matches.count == 1 else {
      throw failure("ambiguous_folder", "有多个同名文件夹，请改用文件夹 ID：\(value)")
    }
    return matches[0].id
  }

  private func resolveColor(_ value: String) throws -> NoteColor {
    guard let color = NoteColor(rawValue: value.lowercased()) else {
      let supported = NoteColor.allCases.map(\.rawValue).joined(separator: ", ")
      throw failure("invalid_color", "不支持颜色 \"\(value)\"；可用颜色：\(supported)")
    }
    return color
  }

  private func validatedLimit(_ value: Int?) throws -> Int? {
    guard let value else { return nil }
    guard value > 0 else {
      throw failure("invalid_parameter", "--limit 必须大于 0")
    }
    return value
  }

  private func requiredNonempty(_ value: String?, label: String) throws -> String {
    guard let value else {
      throw failure("invalid_parameter", "缺少\(label)")
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      throw failure("invalid_parameter", "\(label)不能为空")
    }
    return trimmed
  }

  private func noteOrdering(_ lhs: Note, _ rhs: Note) -> Bool {
    if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
    if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt > rhs.updatedAt }
    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
  }

  private func folderDTO(_ folder: NoteFolder) -> CLIFolder {
    CLIFolder(
      id: folder.id,
      name: folder.name,
      color: folder.color.rawValue,
      isPinned: folder.isPinned,
      sortIndex: folder.sortIndex,
      createdAt: folder.createdAt
    )
  }

  private func noteDTO(_ note: Note) -> CLINote {
    CLINote(
      id: note.id,
      folderID: note.folderID,
      folderName: note.folderID.flatMap { id in store.folders.first(where: { $0.id == id })?.name },
      title: note.title,
      body: note.body,
      color: note.color.rawValue,
      isPinned: note.isPinned,
      isCollapsed: note.isCollapsed,
      sortIndex: note.sortIndex,
      createdAt: note.createdAt,
      updatedAt: note.updatedAt
    )
  }

  private func taskDTO(_ task: TaskLine) -> CLITask {
    CLITask(lineIndex: task.lineIndex, isDone: task.isDone, title: task.title)
  }

  private func failure(_ code: String, _ message: String) -> CLIProtocolError {
    CLIProtocolError(code: code, message: message)
  }
}

@MainActor
final class EdgeNotesCLIService: ObservableObject {
  @Published private(set) var isInstalled: Bool
  @Published private(set) var statusMessage = ""

  private let server: EdgeNotesIPCServer

  static var installationURL: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".local/bin", isDirectory: true)
      .appendingPathComponent("edgenotes")
  }

  init(store: NotesStore, panelCoordinator: EdgePanelCoordinator) {
    let router = CLIRequestRouter(store: store) { [weak store, weak panelCoordinator] noteID in
      guard let note = store?.notes.first(where: { $0.id == noteID }) else { return }
      store?.selectedFolderID = note.folderID
      store?.selectedNoteID = note.id
      panelCoordinator?.route = .notes
      panelCoordinator?.showPanel(activate: true)
    }
    server = EdgeNotesIPCServer { request, completion in
      Task { @MainActor in
        completion(router.handle(request))
      }
    }
    isInstalled = Self.hasCurrentInstallation()
    statusMessage = isInstalled ? "命令行工具已安装" : "命令行工具尚未安装"
  }

  func startIfInstalled() {
    guard isInstalled else { return }
    _ = startServer()
  }

  func install() {
    do {
      let source = try Self.bundledExecutableURL()
      let destination = Self.installationURL
      let directory = destination.deletingLastPathComponent()
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o755]
      )

      if let existingTarget = try? FileManager.default.destinationOfSymbolicLink(atPath: destination.path) {
        guard existingTarget.contains(".app/Contents/SharedSupport/bin/edgenotes") else {
          throw CLIInstallError.message("\(destination.path) 已指向其他程序；请先手动处理该链接")
        }
        try FileManager.default.removeItem(at: destination)
      } else if FileManager.default.fileExists(atPath: destination.path) {
        throw CLIInstallError.message("\(destination.path) 已存在且不是符号链接；为避免覆盖文件，安装已停止")
      }

      try FileManager.default.createSymbolicLink(at: destination, withDestinationURL: source)
      isInstalled = true
      if startServer() {
        statusMessage = "安装完成。在终端运行 edgenotes --help 开始使用。"
      }
    } catch {
      refreshInstallationState()
      statusMessage = "安装失败：\(error.localizedDescription)"
    }
  }

  func uninstall() {
    do {
      let destination = Self.installationURL
      if (try? FileManager.default.destinationOfSymbolicLink(atPath: destination.path)) != nil {
        try FileManager.default.removeItem(at: destination)
      } else if FileManager.default.fileExists(atPath: destination.path) {
        throw CLIInstallError.message("\(destination.path) 不是符号链接，EdgeNotes 不会删除它")
      }
      server.stop()
      isInstalled = false
      statusMessage = "命令行工具已卸载，CLI 服务已关闭。"
    } catch {
      refreshInstallationState()
      statusMessage = "卸载失败：\(error.localizedDescription)"
    }
  }

  func refreshInstallationState() {
    isInstalled = Self.hasCurrentInstallation()
  }

  @discardableResult
  private func startServer() -> Bool {
    do {
      try server.start()
      return true
    } catch {
      statusMessage = "CLI 服务启动失败：\(error.localizedDescription)"
      NSLog("EdgeNotes CLI service could not start: %@", error.localizedDescription)
      return false
    }
  }

  private static func bundledExecutableURL() throws -> URL {
    let bundleURL = Bundle.main.bundleURL
    guard bundleURL.pathExtension == "app" else {
      throw CLIInstallError.message("请先构建并打开 EdgeNotes.app，再安装命令行工具")
    }
    let executable = bundleURL.appendingPathComponent("Contents/SharedSupport/bin/edgenotes")
    guard FileManager.default.isExecutableFile(atPath: executable.path) else {
      throw CLIInstallError.message("应用包中缺少 edgenotes，请重新安装 EdgeNotes")
    }
    return executable
  }

  private static func hasCurrentInstallation() -> Bool {
    let destination = installationURL
    guard let target = try? FileManager.default.destinationOfSymbolicLink(atPath: destination.path),
          let bundled = try? bundledExecutableURL()
    else { return false }

    let resolvedTarget: URL
    if target.hasPrefix("/") {
      resolvedTarget = URL(fileURLWithPath: target)
    } else {
      resolvedTarget = destination.deletingLastPathComponent().appendingPathComponent(target)
    }
    return resolvedTarget.resolvingSymlinksInPath().standardizedFileURL
      == bundled.resolvingSymlinksInPath().standardizedFileURL
  }
}

private enum CLIInstallError: LocalizedError {
  case message(String)

  var errorDescription: String? {
    switch self {
    case .message(let message): message
    }
  }
}
