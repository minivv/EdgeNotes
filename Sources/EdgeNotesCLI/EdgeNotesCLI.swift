import ArgumentParser
import EdgeNotesIPC
import Foundation

@main
struct EdgeNotesCommand: ParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "edgenotes",
    abstract: "从终端读取和写入 EdgeNotes。",
    discussion: """
      edgenotes 通过本机 Socket 与 EdgeNotes 应用通信，所有写操作都由应用执行。
      如果使用应用包内附带的 CLI，而 EdgeNotes 尚未运行，CLI 会在后台自动启动它。

      示例：
        edgenotes folders list
        edgenotes notes search "发布计划"
        edgenotes notes create --title "灵感" --body "稍后继续整理"
        printf '%s' '- [ ] 检查发版' | edgenotes notes append NOTE_ID --stdin

      自动化脚本可加 --json 获取稳定的 JSON 输出。设置 EDGENOTES_SOCKET 可覆盖默认 Socket 路径。
      使用“edgenotes <命令> --help”查看每一级命令的完整说明。
      """,
    version: "0.2.0",
    subcommands: [Status.self, Folders.self, Notes.self, Tasks.self]
  )
}

extension EdgeNotesCommand {
  struct Status: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "检查 EdgeNotes 应用及 CLI 服务是否可用。"
    )

    @Flag(name: .long, help: "输出适合脚本处理的 JSON。")
    var json = false

    mutating func run() throws {
      let result = try CLIRuntime.request(.ping)
      if json {
        try CLIOutput.json(["available": result.pong == true])
      } else {
        print(result.pong == true ? "EdgeNotes 已连接" : "EdgeNotes 未响应")
      }
    }
  }

  struct Folders: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "列出和创建文件夹。",
      discussion: """
        文件夹具有稳定 UUID。其他命令的 --folder 同时接受 UUID 和不区分大小写的完整名称；
        自动化脚本建议使用 UUID。
        """,
      subcommands: [FolderList.self, FolderCreate.self]
    )
  }

  struct FolderList: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "list",
      abstract: "列出所有文件夹。"
    )

    @Flag(name: .long, help: "输出文件夹数组 JSON。")
    var json = false

    mutating func run() throws {
      let folders = try CLIRuntime.request(.foldersList).folders ?? []
      if json {
        try CLIOutput.json(folders)
      } else {
        CLIOutput.folders(folders)
      }
    }
  }

  struct FolderCreate: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "create",
      abstract: "创建一个文件夹。",
      discussion: "示例：edgenotes folders create \"工作记录\""
    )

    @Argument(help: "新文件夹的名称。名称冲突时，EdgeNotes 会自动添加序号。")
    var name: String

    @Flag(name: .long, help: "输出所创建文件夹的 JSON。")
    var json = false

    mutating func run() throws {
      let result = try CLIRuntime.request(.foldersCreate, parameters: CLIParameters(title: name))
      guard let folder = result.folder else { throw CLIUserError("EdgeNotes 没有返回创建结果") }
      if json {
        try CLIOutput.json(folder)
      } else {
        print("已创建文件夹：\(folder.name)  \(folder.id.uuidString)")
      }
    }
  }

  struct Notes: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "查找、读取、创建和编辑笔记。",
      discussion: """
        笔记 ID 是后续 get、append、update、open 和 tasks 命令使用的稳定 UUID。
        create 与 update 的正文可直接传入、从文件读取，或通过标准输入传入。

        示例：
          edgenotes notes list --folder Inbox --limit 20
          edgenotes notes get NOTE_ID
          edgenotes notes create --title "会议" --body-file meeting.md --folder Projects
          cat addition.md | edgenotes notes append NOTE_ID --stdin
        """,
      subcommands: [
        NoteList.self,
        NoteSearch.self,
        NoteGet.self,
        NoteCreate.self,
        NoteAppend.self,
        NoteUpdate.self,
        NoteOpen.self
      ]
    )
  }

  struct NoteList: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "list",
      abstract: "列出笔记，可按文件夹和文本筛选。"
    )

    @Option(name: .long, help: "文件夹 UUID 或完整名称；不提供时列出所有文件夹中的笔记。")
    var folder: String?

    @Option(name: .long, help: "在标题和正文中进行不区分大小写的搜索。")
    var query: String?

    @Option(name: .long, help: "最多返回多少条笔记，必须大于 0。")
    var limit: Int?

    @Flag(name: .long, help: "输出笔记数组 JSON。")
    var json = false

    mutating func run() throws {
      let result = try CLIRuntime.request(
        .notesList,
        parameters: CLIParameters(folder: folder, query: query, limit: limit)
      )
      let notes = result.notes ?? []
      if json {
        try CLIOutput.json(notes)
      } else {
        CLIOutput.notes(notes)
      }
    }
  }

  struct NoteSearch: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "search",
      abstract: "在笔记标题和正文中搜索。",
      discussion: "示例：edgenotes notes search \"API 设计\" --folder Projects --json"
    )

    @Argument(help: "要搜索的文本。")
    var query: String

    @Option(name: .long, help: "只搜索指定文件夹；接受 UUID 或完整名称。")
    var folder: String?

    @Option(name: .long, help: "最多返回多少条笔记，必须大于 0。")
    var limit: Int?

    @Flag(name: .long, help: "输出笔记数组 JSON。")
    var json = false

    mutating func run() throws {
      let result = try CLIRuntime.request(
        .notesList,
        parameters: CLIParameters(folder: folder, query: query, limit: limit)
      )
      let notes = result.notes ?? []
      if json {
        try CLIOutput.json(notes)
      } else {
        CLIOutput.notes(notes)
      }
    }
  }

  struct NoteGet: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "get",
      abstract: "读取一篇完整笔记。"
    )

    @Argument(help: "笔记 UUID。可从 notes list 或 notes search 获取。")
    var noteID: String

    @Flag(name: .long, help: "输出完整笔记 JSON。")
    var json = false

    mutating func run() throws {
      let result = try CLIRuntime.request(
        .notesGet,
        parameters: CLIParameters(noteID: try parseNoteID(noteID))
      )
      guard let note = result.note else { throw CLIUserError("EdgeNotes 没有返回笔记") }
      if json {
        try CLIOutput.json(note)
      } else {
        CLIOutput.note(note)
      }
    }
  }

  struct NoteCreate: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "create",
      abstract: "创建一篇笔记。",
      discussion: """
        --body、--body-file 和 --stdin 互斥；都不提供时创建空正文。
        未提供 --folder 时，笔记不归入任何文件夹。未提供 --color 时使用 graphite。

        示例：
          edgenotes notes create --title "想法" --body "先记下来"
          edgenotes notes create --title "清单" --stdin --folder Inbox < tasks.md
        """
    )

    @Option(name: .long, help: "笔记标题（必填）。")
    var title: String

    @OptionGroup
    var bodyInput: OptionalBodyInput

    @Option(name: .long, help: "文件夹 UUID 或完整名称。")
    var folder: String?

    @Option(name: .long, help: "笔记颜色：graphite、amber、mint、sky、rose 或 violet。")
    var color = "graphite"

    @Flag(name: .long, help: "输出所创建笔记的 JSON。")
    var json = false

    mutating func run() throws {
      let body = try bodyInput.read() ?? ""
      let result = try CLIRuntime.request(
        .notesCreate,
        parameters: CLIParameters(folder: folder, title: title, body: body, color: color)
      )
      guard let note = result.note else { throw CLIUserError("EdgeNotes 没有返回创建结果") }
      if json {
        try CLIOutput.json(note)
      } else {
        print("已创建笔记：\(note.title)  \(note.id.uuidString)")
      }
    }
  }

  struct NoteAppend: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "append",
      abstract: "在笔记正文末尾追加文本。",
      discussion: """
        --text 与 --stdin 必须二选一。若现有正文末尾没有换行，CLI 会先补一个换行。

        示例：
          edgenotes notes append NOTE_ID --text "- [ ] 新任务"
          printf '%s' "补充内容" | edgenotes notes append NOTE_ID --stdin
        """
    )

    @Argument(help: "要修改的笔记 UUID。")
    var noteID: String

    @Option(name: .long, help: "直接提供要追加的文本。")
    var text: String?

    @Flag(name: .long, help: "从标准输入读取要追加的文本。")
    var stdin = false

    @Flag(name: .long, help: "输出更新后笔记的 JSON。")
    var json = false

    mutating func run() throws {
      let count = (text == nil ? 0 : 1) + (stdin ? 1 : 0)
      guard count == 1 else { throw ValidationError("--text 与 --stdin 必须且只能提供一个") }
      let addition = try text ?? readStandardInput()
      let result = try CLIRuntime.request(
        .notesAppend,
        parameters: CLIParameters(noteID: try parseNoteID(noteID), text: addition)
      )
      guard let note = result.note else { throw CLIUserError("EdgeNotes 没有返回更新结果") }
      if json {
        try CLIOutput.json(note)
      } else {
        print("已追加到：\(note.title)  \(note.id.uuidString)")
      }
    }
  }

  struct NoteUpdate: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "update",
      abstract: "替换笔记标题和/或正文。",
      discussion: """
        正文参数 --body、--body-file 和 --stdin 互斥。只更新标题时不需要正文参数。
        append 用于保留现有正文并追加；update 的正文参数会替换完整正文。

        示例：
          edgenotes notes update NOTE_ID --title "新标题"
          edgenotes notes update NOTE_ID --body-file revised.md
        """
    )

    @Argument(help: "要修改的笔记 UUID。")
    var noteID: String

    @Option(name: .long, help: "新的笔记标题。")
    var title: String?

    @OptionGroup
    var bodyInput: OptionalBodyInput

    @Flag(name: .long, help: "输出更新后笔记的 JSON。")
    var json = false

    mutating func run() throws {
      let body = try bodyInput.read()
      guard title != nil || body != nil else {
        throw ValidationError("至少需要提供 --title、--body、--body-file 或 --stdin 之一")
      }
      let result = try CLIRuntime.request(
        .notesUpdate,
        parameters: CLIParameters(noteID: try parseNoteID(noteID), title: title, body: body)
      )
      guard let note = result.note else { throw CLIUserError("EdgeNotes 没有返回更新结果") }
      if json {
        try CLIOutput.json(note)
      } else {
        print("已更新：\(note.title)  \(note.id.uuidString)")
      }
    }
  }

  struct NoteOpen: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "open",
      abstract: "在 EdgeNotes 侧边栏中定位并打开笔记。"
    )

    @Argument(help: "要打开的笔记 UUID。")
    var noteID: String

    mutating func run() throws {
      let result = try CLIRuntime.request(
        .notesOpen,
        parameters: CLIParameters(noteID: try parseNoteID(noteID))
      )
      print(result.message ?? "已在 EdgeNotes 中打开笔记")
    }
  }

  struct Tasks: ParsableCommand {
    static let configuration = CommandConfiguration(
      abstract: "读取和切换笔记中的 Markdown 待办。",
      discussion: """
        EdgeNotes 识别“- [ ] 内容”、“- [x] 内容”和“- [X] 内容”。
        line-index 是从 0 开始的正文源文件行号，可由 tasks list 获得。
        """,
      subcommands: [TaskList.self, TaskToggle.self]
    )
  }

  struct TaskList: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "list",
      abstract: "列出一篇笔记中的所有 Markdown 待办。"
    )

    @Argument(help: "笔记 UUID。")
    var noteID: String

    @Flag(name: .long, help: "输出待办数组 JSON。")
    var json = false

    mutating func run() throws {
      let tasks = try CLIRuntime.request(
        .tasksList,
        parameters: CLIParameters(noteID: try parseNoteID(noteID))
      ).tasks ?? []
      if json {
        try CLIOutput.json(tasks)
      } else {
        CLIOutput.tasks(tasks)
      }
    }
  }

  struct TaskToggle: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "toggle",
      abstract: "切换指定 Markdown 源文件行上的待办状态。",
      discussion: "示例：edgenotes tasks toggle NOTE_ID 4"
    )

    @Argument(help: "笔记 UUID。")
    var noteID: String

    @Argument(help: "从 0 开始的正文源文件行号；使用 tasks list 查看。")
    var lineIndex: Int

    @Flag(name: .long, help: "输出更新后待办的 JSON。")
    var json = false

    mutating func run() throws {
      let result = try CLIRuntime.request(
        .tasksToggle,
        parameters: CLIParameters(noteID: try parseNoteID(noteID), lineIndex: lineIndex)
      )
      guard let task = result.task else { throw CLIUserError("EdgeNotes 没有返回待办更新结果") }
      if json {
        try CLIOutput.json(task)
      } else {
        print("\(task.isDone ? "[x]" : "[ ]") 第 \(task.lineIndex) 行  \(task.title)")
      }
    }
  }
}

struct OptionalBodyInput: ParsableArguments {
  @Option(name: .long, help: "直接提供完整正文。")
  var body: String?

  @Option(name: .long, help: "从 UTF-8 文件读取完整正文。")
  var bodyFile: String?

  @Flag(name: .long, help: "从标准输入读取完整正文。")
  var stdin = false

  func read() throws -> String? {
    let count = (body == nil ? 0 : 1) + (bodyFile == nil ? 0 : 1) + (stdin ? 1 : 0)
    guard count <= 1 else {
      throw ValidationError("--body、--body-file 与 --stdin 只能提供一个")
    }
    if let body { return body }
    if let bodyFile {
      let path = (bodyFile as NSString).expandingTildeInPath
      do {
        return try String(contentsOfFile: path, encoding: .utf8)
      } catch {
        throw CLIUserError("无法读取正文文件 \(path)：\(error.localizedDescription)")
      }
    }
    if stdin { return try readStandardInput() }
    return nil
  }
}

private enum CLIRuntime {
  static func request(
    _ method: CLIProtocolMethod,
    parameters: CLIParameters = CLIParameters()
  ) throws -> CLIResult {
    let request = CLIRequest(method: method, parameters: parameters)
    let client = EdgeNotesIPCClient()

    let response: CLIResponse
    do {
      response = try client.send(request)
    } catch let error as EdgeNotesSocketError where error.isServerUnavailable {
      guard try launchBundledAppIfAvailable() else {
        throw CLIUserError(
          "无法连接 EdgeNotes。请先启动应用；当前 Socket：\(client.socketPath)"
        )
      }
      response = try retry(request, with: client)
    } catch {
      throw CLIUserError(error.localizedDescription)
    }

    if let error = response.error {
      throw CLIUserError("\(error.message) [\(error.code)]")
    }
    guard let result = response.result else {
      throw CLIUserError("EdgeNotes 返回了空响应")
    }
    return result
  }

  private static func retry(_ request: CLIRequest, with client: EdgeNotesIPCClient) throws -> CLIResponse {
    var latestError: Error?
    for _ in 0..<30 {
      usleep(100_000)
      do {
        return try client.send(request)
      } catch {
        latestError = error
      }
    }
    throw CLIUserError(
      "EdgeNotes 已启动，但 CLI 服务未就绪：\(latestError?.localizedDescription ?? "未知错误")"
    )
  }

  private static func launchBundledAppIfAvailable() throws -> Bool {
    let executableURL = Bundle.main.executableURL
      ?? URL(fileURLWithPath: CommandLine.arguments[0])
    let executable = executableURL.resolvingSymlinksInPath().path
    guard let appRange = executable.range(of: ".app/Contents/", options: .backwards) else {
      return false
    }
    let appPath = String(executable[...appRange.lowerBound]) + ".app"
    guard FileManager.default.fileExists(atPath: appPath) else { return false }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    process.arguments = ["-g", appPath]
    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      throw CLIUserError("无法启动 EdgeNotes：\(error.localizedDescription)")
    }
    guard process.terminationStatus == 0 else {
      throw CLIUserError("open 无法启动 EdgeNotes（退出码 \(process.terminationStatus)）")
    }
    return true
  }
}

private enum CLIOutput {
  static func json<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    do {
      let data = try encoder.encode(value)
      guard let string = String(data: data, encoding: .utf8) else {
        throw CLIUserError("无法生成 UTF-8 JSON")
      }
      print(string)
    } catch let error as CLIUserError {
      throw error
    } catch {
      throw CLIUserError("无法生成 JSON：\(error.localizedDescription)")
    }
  }

  static func folders(_ folders: [CLIFolder]) {
    guard !folders.isEmpty else {
      print("没有文件夹")
      return
    }
    for folder in folders {
      let pin = folder.isPinned ? "置顶" : ""
      print("\(folder.id.uuidString)\t\(folder.name)\t\(folder.color)\t\(pin)")
    }
  }

  static func notes(_ notes: [CLINote]) {
    guard !notes.isEmpty else {
      print("没有匹配的笔记")
      return
    }
    for note in notes {
      let folder = note.folderName ?? "未归档"
      let pin = note.isPinned ? "置顶" : ""
      print("\(note.id.uuidString)\t\(note.title)\t\(folder)\t\(note.color)\t\(pin)")
    }
  }

  static func note(_ note: CLINote) {
    print(note.title)
    print("ID: \(note.id.uuidString)")
    print("文件夹: \(note.folderName ?? "未归档")")
    print("颜色: \(note.color)")
    print("更新时间: \(ISO8601DateFormatter().string(from: note.updatedAt))")
    print("")
    print(note.body)
  }

  static func tasks(_ tasks: [CLITask]) {
    guard !tasks.isEmpty else {
      print("这篇笔记没有 Markdown 待办")
      return
    }
    for task in tasks {
      print("\(task.lineIndex)\t\(task.isDone ? "[x]" : "[ ]")\t\(task.title)")
    }
  }
}

private struct CLIUserError: Error, CustomStringConvertible, LocalizedError {
  let description: String

  init(_ description: String) {
    self.description = description
  }

  var errorDescription: String? { description }
}

private func parseNoteID(_ value: String) throws -> UUID {
  guard let id = UUID(uuidString: value) else {
    throw ValidationError("笔记 ID 必须是有效 UUID：\(value)")
  }
  return id
}

private func readStandardInput() throws -> String {
  let data = FileHandle.standardInput.readDataToEndOfFile()
  guard let value = String(data: data, encoding: .utf8) else {
    throw CLIUserError("标准输入不是有效的 UTF-8 文本")
  }
  return value
}
