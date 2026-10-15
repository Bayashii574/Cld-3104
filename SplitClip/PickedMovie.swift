import CoreTransferable
import UniformTypeIdentifiers

/// PhotosPicker で選んだ動画をアプリの一時フォルダにコピーして受け取る。
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let dir = TempFiles.importDirectory
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let dest = dir.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
            try FileManager.default.copyItem(at: received.file, to: dest)
            return Self(url: dest)
        }
    }
}

enum TempFiles {
    static let importDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("Imported", isDirectory: true)
    static let outputRoot = FileManager.default.temporaryDirectory
        .appendingPathComponent("Output", isDirectory: true)

    static func makeOutputDirectory() throws -> URL {
        let dir = outputRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 前回の起動で残ったファイルを掃除する（動画は大きいので溜めない）
    static func removeAll() {
        try? FileManager.default.removeItem(at: importDirectory)
        try? FileManager.default.removeItem(at: outputRoot)
    }
}
