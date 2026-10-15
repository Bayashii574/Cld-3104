import AVFoundation

enum VideoSplitterError: LocalizedError {
    case cannotCreateSession
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .cannotCreateSession: return "この動画は書き出しに対応していません。"
        case .exportFailed: return "動画の書き出しに失敗しました。"
        }
    }
}

enum VideoSplitter {
    /// 1区間を書き出す。
    ///
    /// まず再エンコードなし（パススルー）で試し、画質劣化なし・高速で切り出す。
    /// 失敗した場合のみ最高画質で再エンコードする。
    static func export(
        asset: AVAsset,
        range: CMTimeRange,
        to url: URL,
        metadata: [AVMetadataItem],
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        var lastError: Error = VideoSplitterError.exportFailed
        for preset in [AVAssetExportPresetPassthrough, AVAssetExportPresetHighestQuality] {
            try Task.checkCancellation()
            try? FileManager.default.removeItem(at: url)
            do {
                try await run(asset: asset, preset: preset, range: range, to: url,
                              metadata: metadata, progress: progress)
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }
        throw lastError
    }

    private static func run(
        asset: AVAsset,
        preset: String,
        range: CMTimeRange,
        to url: URL,
        metadata: [AVMetadataItem],
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw VideoSplitterError.cannotCreateSession
        }
        session.outputURL = url
        session.outputFileType = .mov
        session.timeRange = range
        session.metadata = metadata
        session.shouldOptimizeForNetworkUse = true

        let poller = Task {
            while !Task.isCancelled {
                progress(Double(session.progress))
                try? await Task.sleep(for: .milliseconds(200))
            }
        }
        defer { poller.cancel() }

        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                session.exportAsynchronously {
                    continuation.resume()
                }
            }
        } onCancel: {
            session.cancelExport()
        }

        switch session.status {
        case .completed:
            progress(1)
        case .cancelled:
            throw CancellationError()
        default:
            throw session.error ?? VideoSplitterError.exportFailed
        }
    }
}

enum MetadataEditor {
    /// 分割後の各動画の撮影日時を「元の撮影日時 + 区間の開始位置」にずらす。
    /// これでアップロード先でも撮影順どおりに並ぶ。
    static func replacingCreationDate(in items: [AVMetadataItem], with date: Date?) -> [AVMetadataItem] {
        guard let date else { return items }
        let filtered = items.filter {
            $0.identifier != .quickTimeMetadataCreationDate
                && $0.identifier != .commonIdentifierCreationDate
        }
        let item = AVMutableMetadataItem()
        item.identifier = .quickTimeMetadataCreationDate
        item.dataType = kCMMetadataBaseDataType_UTF8 as String
        item.value = iso8601String(from: date) as NSString
        return filtered + [item]
    }

    static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
