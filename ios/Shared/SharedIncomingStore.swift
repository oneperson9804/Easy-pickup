import Foundation

enum IncomingImportError: LocalizedError {
    case groupUnavailable
    case invalidPayload
    var errorDescription: String? {
        switch self {
        case .groupUnavailable: return "尚未配置易取件共享容器。请使用启用了 App Groups 的签名版本后再分享。"
        case .invalidPayload: return "无法读取这份分享内容，请重新选择文字或图片。"
        }
    }
}

enum SharedIncomingStore {
    static let groupIdentifier = "group.io.github.oneperson9804.easypickup"

    private struct Manifest: Codable {
        var text: String?
        var imageFile: String?
        var imageFiles: [String]?

        var images: [String] {
            var result = imageFiles ?? []
            if let imageFile, !result.contains(imageFile) { result.append(imageFile) }
            return result
        }
    }

    private static func directory() throws -> URL {
        let files = FileManager.default
        guard let group = files.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) else { throw IncomingImportError.groupUnavailable }
        let directory = group.appendingPathComponent("IncomingImports", isDirectory: true)
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func save(text: String?, images: [URL]) throws {
        let directory = try directory()
        let files = FileManager.default
        let name = "\(Int64(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString)"
        var manifest = Manifest()
        let notice = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let notice, !notice.isEmpty { manifest.text = notice }
        guard manifest.text != nil || !images.isEmpty else { throw IncomingImportError.invalidPayload }
        var destinations: [URL] = []
        do {
            for (index, image) in images.enumerated() {
                let suffix = image.pathExtension.isEmpty ? "jpg" : image.pathExtension
                let destination = directory.appendingPathComponent("\(name)-\(index).\(suffix)")
                destinations.append(destination)
                try files.copyItem(at: image, to: destination)
            }
            if destinations.count == 1 { manifest.imageFile = destinations[0].lastPathComponent }
            else if !destinations.isEmpty { manifest.imageFiles = destinations.map { $0.lastPathComponent } }
            let data = try JSONEncoder().encode(manifest)
            // A reader can discover this draft only after every image has been copied.
            try data.write(to: directory.appendingPathComponent("\(name).json"), options: .atomic)
        } catch {
            for destination in destinations where files.fileExists(atPath: destination.path) {
                try? files.removeItem(at: destination)
            }
            throw error
        }
    }

    /// Peeks at one share draft; the original remains until Dart durably saves and acknowledges it.
    static func consume() throws -> [String: Any]? {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) != nil else { return nil }
        let directory = try directory()
        let files = FileManager.default
        let manifests = try files.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard let manifest = manifests.first else { return nil }
        let input = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifest))
        var output: [String: Any] = ["draftId": manifest.deletingPathExtension().lastPathComponent]
        if let text = input.text, !text.isEmpty { output["text"] = text }
        let paths = try input.images.map { filename -> String in
            let source = try imageURL(filename: filename, directory: directory)
            guard files.fileExists(atPath: source.path) else { throw IncomingImportError.invalidPayload }
            return source.path
        }
        if paths.count == 1 { output["imagePath"] = paths[0] }
        else if !paths.isEmpty { output["imagePaths"] = paths }
        guard output.count > 1 else { throw IncomingImportError.invalidPayload }
        return output
    }

    static func acknowledge(id: String) throws {
        guard id.range(of: "^[A-Za-z0-9-]{1,100}$", options: .regularExpression) != nil else { throw IncomingImportError.invalidPayload }
        let files = FileManager.default
        let directory = try directory()
        let manifest = directory.appendingPathComponent("\(id).json")
        let acknowledged = directory.appendingPathComponent("\(id).ack")
        if files.fileExists(atPath: manifest.path) { try files.moveItem(at: manifest, to: acknowledged) }
        guard files.fileExists(atPath: acknowledged.path) else { return }
        let input = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: acknowledged))
        for filename in input.images {
            let image = try imageURL(filename: filename, directory: directory)
            if files.fileExists(atPath: image.path) { try files.removeItem(at: image) }
        }
        try files.removeItem(at: acknowledged)
    }

    private static func imageURL(filename: String, directory: URL) throws -> URL {
        // Manifests store local filenames, never paths supplied by another app.
        guard !filename.isEmpty,
              filename == URL(fileURLWithPath: filename).lastPathComponent,
              !filename.contains("..") else { throw IncomingImportError.invalidPayload }
        return directory.appendingPathComponent(filename)
    }
}
