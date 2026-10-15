import Photos
import CoreLocation

enum PhotoLibraryError: LocalizedError {
    case accessDenied

    var errorDescription: String? {
        "写真へのアクセスが許可されていません。「設定」アプリ → 動画分割 → 写真 から「フルアクセス」を許可してください。"
    }
}

enum PhotoLibrary {
    static let albumTitle = "分割動画"

    struct NewVideo {
        let url: URL
        let creationDate: Date?
    }

    static func requestAccess() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    static func canAccess(_ status: PHAuthorizationStatus) -> Bool {
        status == .authorized || status == .limited
    }

    static func asset(localIdentifier: String?) -> PHAsset? {
        guard let localIdentifier else { return nil }
        return PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject
    }

    /// 動画を写真ライブラリに保存し、アルバム「分割動画」に入れる。
    /// 一時ファイルは写真ライブラリへ移動されるので、保存後は残らない。
    static func save(_ videos: [NewVideo], location: CLLocation?) async throws {
        let album = try? await findOrCreateAlbum()
        try await PHPhotoLibrary.shared().performChanges {
            var placeholders: [PHObjectPlaceholder] = []
            for video in videos {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                request.addResource(with: .video, fileURL: video.url, options: options)
                request.creationDate = video.creationDate
                request.location = location
                if let placeholder = request.placeholderForCreatedAsset {
                    placeholders.append(placeholder)
                }
            }
            if let album, let albumRequest = PHAssetCollectionChangeRequest(for: album) {
                albumRequest.addAssets(placeholders as NSArray)
            }
        }
    }

    private static func findOrCreateAlbum() async throws -> PHAssetCollection? {
        if let existing = fetchAlbum() { return existing }
        try await PHPhotoLibrary.shared().performChanges {
            _ = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumTitle)
        }
        return fetchAlbum()
    }

    private static func fetchAlbum() -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", albumTitle)
        return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options).firstObject
    }
}
