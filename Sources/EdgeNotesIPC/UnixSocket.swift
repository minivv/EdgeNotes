import Darwin
import Foundation

public struct EdgeNotesSocketError: Error, LocalizedError, Sendable {
  public let operation: String
  public let code: Int32
  public let detail: String?

  public init(operation: String, code: Int32 = errno, detail: String? = nil) {
    self.operation = operation
    self.code = code
    self.detail = detail
  }

  public var errorDescription: String? {
    let reason = detail ?? String(cString: strerror(code))
    return "\(operation)失败：\(reason)"
  }

  public var isServerUnavailable: Bool {
    code == ENOENT || code == ECONNREFUSED || code == ECONNRESET
  }
}

public final class EdgeNotesIPCClient {
  public let socketPath: String

  public init(socketPath: String = EdgeNotesSocketPath.current()) {
    self.socketPath = socketPath
  }

  public func send(_ request: CLIRequest) throws -> CLIResponse {
    let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
    guard descriptor >= 0 else {
      throw EdgeNotesSocketError(operation: "创建本地连接")
    }
    defer { close(descriptor) }

    configureSocket(descriptor)
    try withUnixSocketAddress(path: socketPath) { address, length in
      guard Darwin.connect(descriptor, address, length) == 0 else {
        throw EdgeNotesSocketError(operation: "连接 EdgeNotes")
      }
    }

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    var payload = try encoder.encode(request)
    payload.append(0x0A)
    try writeAll(payload, to: descriptor)
    guard shutdown(descriptor, SHUT_WR) == 0 else {
      throw EdgeNotesSocketError(operation: "结束请求写入")
    }

    let responseData = try readAll(from: descriptor)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let response = try decoder.decode(CLIResponse.self, from: responseData)
    guard response.id == request.id else {
      throw EdgeNotesSocketError(
        operation: "读取 EdgeNotes 响应",
        code: EPROTO,
        detail: "响应 ID 与请求不匹配"
      )
    }
    return response
  }
}

public final class EdgeNotesIPCServer: @unchecked Sendable {
  public typealias Handler = @Sendable (CLIRequest, @escaping @Sendable (CLIResponse) -> Void) -> Void

  public let socketPath: String
  private let handler: Handler
  private let queue = DispatchQueue(label: "com.edgenotes.cli.listener", qos: .userInitiated)
  private let connectionQueue = DispatchQueue(
    label: "com.edgenotes.cli.connections",
    qos: .userInitiated,
    attributes: .concurrent
  )
  private var listener: Int32 = -1
  private var source: DispatchSourceRead?
  private let stateLock = NSLock()

  public init(socketPath: String = EdgeNotesSocketPath.current(), handler: @escaping Handler) {
    self.socketPath = socketPath
    self.handler = handler
  }

  deinit {
    stop()
  }

  public func start() throws {
    stateLock.lock()
    defer { stateLock.unlock() }
    guard listener < 0 else { return }

    let parent = URL(fileURLWithPath: socketPath).deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: parent,
      withIntermediateDirectories: true,
      attributes: [.posixPermissions: 0o700]
    )

    let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
    guard descriptor >= 0 else {
      throw EdgeNotesSocketError(operation: "创建 CLI 服务")
    }

    do {
      configureSocket(descriptor)
      _ = unlink(socketPath)
      try withUnixSocketAddress(path: socketPath) { address, length in
        guard Darwin.bind(descriptor, address, length) == 0 else {
          throw EdgeNotesSocketError(operation: "绑定 CLI Socket")
        }
      }
      guard chmod(socketPath, 0o600) == 0 else {
        throw EdgeNotesSocketError(operation: "限制 CLI Socket 权限")
      }
      guard listen(descriptor, 16) == 0 else {
        throw EdgeNotesSocketError(operation: "监听 CLI Socket")
      }
      let flags = fcntl(descriptor, F_GETFL)
      guard flags >= 0, fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) == 0 else {
        throw EdgeNotesSocketError(operation: "配置 CLI Socket")
      }
    } catch {
      close(descriptor)
      _ = unlink(socketPath)
      throw error
    }

    listener = descriptor
    let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
    source.setEventHandler { [weak self] in
      self?.acceptConnections()
    }
    source.setCancelHandler {
      close(descriptor)
    }
    self.source = source
    source.resume()
  }

  public func stop() {
    stateLock.lock()
    let activeSource = source
    let hadListener = listener >= 0
    source = nil
    listener = -1
    stateLock.unlock()

    activeSource?.cancel()
    if hadListener {
      _ = unlink(socketPath)
    }
  }

  private func acceptConnections() {
    while true {
      let client = accept(listener, nil, nil)
      if client < 0 {
        if errno == EINTR { continue }
        return
      }
      guard setBlocking(client) else {
        close(client)
        continue
      }
      configureSocket(client)
      connectionQueue.async { [weak self] in
        self?.handleConnection(client)
      }
    }
  }

  private func handleConnection(_ descriptor: Int32) {
    do {
      let requestData = try readAll(from: descriptor)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let request = try decoder.decode(CLIRequest.self, from: requestData)
      let responseQueue = connectionQueue
      handler(request) { response in
        responseQueue.async {
          do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            var responseData = try encoder.encode(response)
            responseData.append(0x0A)
            try writeAll(responseData, to: descriptor)
          } catch {
            // The client may have exited before the app completed the command.
          }
          close(descriptor)
        }
      }
    } catch {
      let response = CLIResponse.failure(
        id: UUID(),
        code: "invalid_request",
        message: "无法解析 CLI 请求：\(error.localizedDescription)"
      )
      if let data = try? JSONEncoder().encode(response) {
        try? writeAll(data, to: descriptor)
      }
      close(descriptor)
    }
  }
}

private func configureSocket(_ descriptor: Int32) {
  var enabled: Int32 = 1
  _ = setsockopt(
    descriptor,
    SOL_SOCKET,
    SO_NOSIGPIPE,
    &enabled,
    socklen_t(MemoryLayout<Int32>.size)
  )

  var timeout = timeval(tv_sec: 5, tv_usec: 0)
  _ = setsockopt(
    descriptor,
    SOL_SOCKET,
    SO_RCVTIMEO,
    &timeout,
    socklen_t(MemoryLayout<timeval>.size)
  )
  _ = setsockopt(
    descriptor,
    SOL_SOCKET,
    SO_SNDTIMEO,
    &timeout,
    socklen_t(MemoryLayout<timeval>.size)
  )
}

private func setBlocking(_ descriptor: Int32) -> Bool {
  let flags = fcntl(descriptor, F_GETFL)
  guard flags >= 0 else { return false }
  return fcntl(descriptor, F_SETFL, flags & ~O_NONBLOCK) == 0
}

private func withUnixSocketAddress<T>(
  path: String,
  _ body: (UnsafePointer<sockaddr>, socklen_t) throws -> T
) throws -> T {
  let pathBytes = Array(path.utf8)
  var address = sockaddr_un()
  let capacity = MemoryLayout.size(ofValue: address.sun_path)
  guard pathBytes.count < capacity else {
    throw EdgeNotesSocketError(
      operation: "使用 CLI Socket 路径",
      code: ENAMETOOLONG,
      detail: "路径过长：\(path)"
    )
  }

  address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
  address.sun_family = sa_family_t(AF_UNIX)
  withUnsafeMutableBytes(of: &address.sun_path) { buffer in
    buffer.copyBytes(from: pathBytes)
    buffer[pathBytes.count] = 0
  }

  return try withUnsafePointer(to: &address) { pointer in
    try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
      try body($0, socklen_t(MemoryLayout<sockaddr_un>.size))
    }
  }
}

private func writeAll(_ data: Data, to descriptor: Int32) throws {
  try data.withUnsafeBytes { rawBuffer in
    guard let baseAddress = rawBuffer.baseAddress else { return }
    var written = 0
    while written < rawBuffer.count {
      let result = Darwin.write(descriptor, baseAddress.advanced(by: written), rawBuffer.count - written)
      if result < 0 {
        if errno == EINTR { continue }
        throw EdgeNotesSocketError(operation: "写入 CLI Socket")
      }
      guard result > 0 else {
        throw EdgeNotesSocketError(operation: "写入 CLI Socket", code: EPIPE)
      }
      written += result
    }
  }
}

private func readAll(from descriptor: Int32) throws -> Data {
  var data = Data()
  var buffer = [UInt8](repeating: 0, count: 16_384)

  while true {
    let count = Darwin.read(descriptor, &buffer, buffer.count)
    if count < 0 {
      if errno == EINTR { continue }
      throw EdgeNotesSocketError(operation: "读取 CLI Socket")
    }
    if count == 0 { break }
    guard data.count + count <= EdgeNotesCLIProtocol.maximumMessageSize else {
      throw EdgeNotesSocketError(
        operation: "读取 CLI Socket",
        code: EMSGSIZE,
        detail: "请求或响应超过 1 MiB 限制"
      )
    }
    data.append(buffer, count: count)
    if buffer.prefix(count).contains(0x0A) { break }
  }

  guard !data.isEmpty else {
    throw EdgeNotesSocketError(operation: "读取 CLI Socket", code: ECONNRESET, detail: "连接未返回数据")
  }
  return data
}
