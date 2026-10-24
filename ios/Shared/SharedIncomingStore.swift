import Foundation

enum IncomingImportError: LocalizedError {
    case groupUnavailable
    case invalidPayload
    var errorDescription: String? {
        switch self {
        case .groupUnavailable: return "尚未配置易取件共享容器。请使用启用了 App Groups 的签名版本后再分享。"
        case .invalidPayload: return "无法读取这份分享内容，请重新选择文字或一张图片。"
        }
    }
}

enum SharedIncomingStore {
    static let groupIdentifier = "group.io.github.oneperson9804.easypickup"

    private static func directory() throws -> URL {
        let files = FileManager.default
        guard let group = files.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) else { throw IncomingImportError.groupUnavailable }
        let directory = group.appendingPathComponent("IncomingImports", isDirectory: true)
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func save(text: String?, image: URL?) throws {
        let directory = try directory()
        let name = "\(Int64(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString)"
        var manifest: [String: String] = [:]
        var imageDestination: URL?
        if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { manifest["text"] = text }
        if let image {
            let suffix = image.pathExtension.isEmpty ? "jpg" : image.pathExtension
            let destination = directory.appendingPathComponent("\(name).\(suffix)")
            try FileManager.default.copyItem(at: image, to: destination)
            imageDestination = destination
            manifest["imageFile"] = destination.lastPathComponent
        }
        guard !manifest.isEmpty else { throw IncomingImportError.invalidPayload }
        do {
            let data = try JSONSerialization.data(withJSONObject: manifest)
            try data.write(to: directory.appendingPathComponent("\(name).json"), options: .atomic)
        } catch {
            if let imageDestination { try? FileManager.default.removeItem(at: imageDestination) }
            throw error
        }
    }

    /// Peeks at one share draft; the original remains until Dart durably saves and acknowledges it.
    static func consume() throws -> [String: String]? {
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) != nil else { return nil }
        let directory = try directory()
        let files = FileManager.default
        let manifests = try files.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard let manifest = manifests.first else { return nil }
        guard let input = try JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as? [String: String] else { throw IncomingImportError.invalidPayload }
        var output: [String: String] = ["draftId": manifest.deletingPathExtension().lastPathComponent]
        if let text = input["text"] { output["text"] = text }
        if let imageFile = input["imageFile"] {
            // The manifest contains a filename, never an arbitrary path supplied by another app.
            guard imageFile == URL(fileURLWithPath: imageFile).lastPathComponent, !imageFile.contains("..") else { throw IncomingImportError.invalidPayload }
            let source = directory.appendingPathComponent(imageFile)
            guard files.fileExists(atPath: source.path) else { throw IncomingImportError.invalidPayload }
            output["imagePath"] = source.path
        }
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
        guard let input = try JSONSerialization.jsonObject(with: Data(contentsOf: acknowledged)) as? [String: String] else { throw IncomingImportError.invalidPayload }
        if let filename = input["imageFile"] {
            guard filename == URL(fileURLWithPath: filename).lastPathComponent, !filename.contains("..") else { throw IncomingImportError.invalidPayload }
            let image = directory.appendingPathComponent(filename)
            if files.fileExists(atPath: image.path) { try files.removeItem(at: image) }
        }
        try files.removeItem(at: acknowledged)
    }
}
