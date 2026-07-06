import Foundation

struct GistClient {
  struct UpsertResult {
    var gistID: String
    var htmlURL: URL?
  }

  func upsertBackup(
    token: String,
    gistID: String?,
    filename: String,
    content: String
  ) async throws -> UpsertResult {
    let trimmedGistID = gistID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let url: URL
    var requestBody = GistRequest(
      description: "EdgeNotes automatic backup",
      public: trimmedGistID.isEmpty ? false : nil,
      files: [filename: GistFile(content: content)]
    )

    if trimmedGistID.isEmpty {
      url = URL(string: "https://api.github.com/gists")!
    } else {
      url = URL(string: "https://api.github.com/gists/\(trimmedGistID)")!
      requestBody.description = nil
    }

    var request = URLRequest(url: url)
    request.httpMethod = trimmedGistID.isEmpty ? "POST" : "PATCH"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    request.httpBody = try JSONEncoder().encode(requestBody)

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw GistClientError.invalidResponse
    }

    guard (200..<300).contains(httpResponse.statusCode) else {
      let message = (try? JSONDecoder().decode(GitHubError.self, from: data).message)
        ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
      throw GistClientError.requestFailed(statusCode: httpResponse.statusCode, message: message)
    }

    let gist = try JSONDecoder().decode(GistResponse.self, from: data)
    return UpsertResult(gistID: gist.id, htmlURL: gist.htmlURL)
  }
}

enum GistClientError: LocalizedError {
  case invalidResponse
  case requestFailed(statusCode: Int, message: String)

  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      "GitHub returned an invalid response."
    case .requestFailed(let statusCode, let message):
      "GitHub request failed (\(statusCode)): \(message)"
    }
  }
}

private struct GistFile: Codable {
  var content: String
}

private struct GistRequest: Codable {
  var description: String?
  var `public`: Bool?
  var files: [String: GistFile]
}

private struct GistResponse: Decodable {
  var id: String
  var htmlURL: URL?

  enum CodingKeys: String, CodingKey {
    case id
    case htmlURL = "html_url"
  }
}

private struct GitHubError: Decodable {
  var message: String
}
