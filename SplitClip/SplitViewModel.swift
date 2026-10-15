import SwiftUI
import PhotosUI
import AVFoundation
import CoreLocation

struct SourceVideo {
    let url: URL
    let duration: CMTime
    let thumbnail: UIImage?
    let creationDate: Date?
    let location: CLLocation?
}

@MainActor
@Observable
final class SplitViewModel {
    enum Phase: Equatable {
        case empty
        case loading
        case ready
        case exporting(index: Int, total: Int, progress: Double)
        case saving
        case done(count: Int)
        case failed(String)
    }

    private(set) var phase: Phase = .empty
    private(set) var source: SourceVideo?
    private var splitTask: Task<Void, Never>?

    var isBusy: Bool {
        switch phase {
        case .loading, .exporting, .saving: return true
        default: return false
        }
    }

    func plan(maxSeconds: Int) -> [CMTimeRange] {
        guard let source else { return [] }
        return SegmentPlanner.plan(duration: source.duration,
                                   maxLength: CMTime(value: CMTimeValue(maxSeconds), timescale: 1))
    }

    // MARK: - 読み込み

    func load(item: PhotosPickerItem) async {
        phase = .loading
        if let old = source?.url { try? FileManager.default.removeItem(at: old) }
        source = nil

        do {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                throw VideoSplitterError.exportFailed
            }
            let asset = AVURLAsset(url: movie.url)
            let duration = try await asset.load(.duration)
            let thumbnail = try? await Self.thumbnail(for: asset)

            // 撮影日時と位置情報は写真ライブラリの元データから取るのが一番正確
            var creationDate: Date?
            var location: CLLocation?
            if PhotoLibrary.canAccess(await PhotoLibrary.requestAccess()),
               let original = PhotoLibrary.asset(localIdentifier: item.itemIdentifier) {
                creationDate = original.creationDate
                location = original.location
            }
            if creationDate == nil, let meta = try? await asset.load(.creationDate) {
                creationDate = try? await meta.load(.dateValue)
            }

            source = SourceVideo(url: movie.url, duration: duration, thumbnail: thumbnail,
                                 creationDate: creationDate, location: location)
            phase = .ready
        } catch {
            phase = .failed("動画を読み込めませんでした。\n\(error.localizedDescription)")
        }
    }

    private static func thumbnail(for asset: AVAsset) async throws -> UIImage {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 800, height: 800)
        let (image, _) = try await generator.image(at: CMTime(value: 1, timescale: 2))
        return UIImage(cgImage: image)
    }

    // MARK: - 分割

    func split(maxSeconds: Int) {
        guard let source, !isBusy else { return }
        let ranges = plan(maxSeconds: maxSeconds)
        guard !ranges.isEmpty else { return }
        splitTask = Task { await runSplit(source: source, ranges: ranges) }
    }

    func cancel() {
        splitTask?.cancel()
    }

    func reset() {
        phase = source == nil ? .empty : .ready
    }

    private func runSplit(source: SourceVideo, ranges: [CMTimeRange]) async {
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = false }

        // 他のアプリに切り替えても少しの間は書き出しを続けられるようにする
        var backgroundTask = UIBackgroundTaskIdentifier.invalid
        func endBackgroundTask() {
            guard backgroundTask != .invalid else { return }
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            // 期限切れ時はメインスレッドで呼ばれる
            MainActor.assumeIsolated {
                self?.cancel()
                endBackgroundTask()
            }
        }
        defer { endBackgroundTask() }

        var outputDirectory: URL?
        defer { if let outputDirectory { try? FileManager.default.removeItem(at: outputDirectory) } }

        do {
            guard PhotoLibrary.canAccess(await PhotoLibrary.requestAccess()) else {
                throw PhotoLibraryError.accessDenied
            }
            let directory = try TempFiles.makeOutputDirectory()
            outputDirectory = directory

            let asset = AVURLAsset(url: source.url)
            let baseMetadata = (try? await asset.load(.metadata)) ?? []
            var outputs: [PhotoLibrary.NewVideo] = []
            let total = ranges.count

            for (index, range) in ranges.enumerated() {
                phase = .exporting(index: index, total: total, progress: 0)
                let date = source.creationDate?.addingTimeInterval(range.start.seconds)
                let url = directory.appendingPathComponent(String(format: "part%02d.mov", index + 1))
                let metadata = MetadataEditor.replacingCreationDate(in: baseMetadata, with: date)

                try await VideoSplitter.export(asset: asset, range: range, to: url, metadata: metadata) { value in
                    Task { @MainActor [weak self] in
                        self?.updateProgress(index: index, total: total, progress: value)
                    }
                }
                outputs.append(.init(url: url, creationDate: date))
            }

            try Task.checkCancellation()
            phase = .saving
            try await PhotoLibrary.save(outputs, location: source.location)
            phase = .done(count: outputs.count)
        } catch is CancellationError {
            phase = .ready
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func updateProgress(index: Int, total: Int, progress: Double) {
        // 遅れて届いた古い進捗で次の区間の表示を上書きしない
        guard case .exporting(let current, _, _) = phase, current == index else { return }
        phase = .exporting(index: index, total: total, progress: progress)
    }
}
