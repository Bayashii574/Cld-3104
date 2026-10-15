import SwiftUI
import PhotosUI

struct ContentView: View {
    @State private var model = SplitViewModel()
    @State private var pickerItem: PhotosPickerItem?
    @AppStorage("maxSegmentSeconds") private var maxSeconds = 115
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    preview
                    lengthSetting
                    actionArea
                }
                .padding()
            }
            .navigationTitle("動画分割")
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            pickerItem = nil
            Task { await model.load(item: item) }
        }
    }

    // MARK: - 選んだ動画

    @ViewBuilder
    private var preview: some View {
        VStack(spacing: 12) {
            if let source = model.source {
                Group {
                    if let thumbnail = source.thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .scaledToFit()
                    } else {
                        placeholder(systemImage: "film")
                    }
                }
                .frame(maxHeight: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(spacing: 4) {
                    Text("長さ: \(TimeFormat.japanese(seconds: source.duration.seconds))")
                        .font(.headline)
                    if let date = source.creationDate {
                        Text("撮影日時: \(date.formatted(date: .long, time: .shortened))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if model.phase == .loading {
                placeholder(systemImage: nil)
                    .overlay { ProgressView("読み込み中…") }
            } else {
                placeholder(systemImage: "video.badge.plus")
            }

            PhotosPicker(selection: $pickerItem, matching: .videos, photoLibrary: .shared()) {
                Label(model.source == nil ? "動画を選ぶ" : "別の動画を選ぶ",
                      systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(model.isBusy)
        }
    }

    private func placeholder(systemImage: String?) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.secondarySystemBackground))
            .frame(height: 200)
            .overlay {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                }
            }
    }

    // MARK: - 設定

    private var lengthSetting: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper(value: $maxSeconds, in: 30...600, step: 5) {
                Text("1本の最大の長さ: **\(TimeFormat.japanese(seconds: Double(maxSeconds)))**")
            }
            .disabled(model.isBusy)
            Text("アップロード先の上限（2分）より少し短めにしておくと安心です。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - 実行と状態表示

    @ViewBuilder
    private var actionArea: some View {
        let ranges = model.plan(maxSeconds: maxSeconds)

        switch model.phase {
        case .empty, .loading:
            EmptyView()

        case .ready:
            if ranges.count <= 1 {
                Label("この動画は分割しなくても上限内です。", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    Text("\(ranges.count)本に分割します（1本あたり約\(TimeFormat.japanese(seconds: ranges[0].duration.seconds))）")
                        .multilineTextAlignment(.center)
                    Button {
                        model.split(maxSeconds: maxSeconds)
                    } label: {
                        Label("分割して写真に保存", systemImage: "scissors")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }

        case let .exporting(index, total, progress):
            VStack(spacing: 12) {
                ProgressView(value: (Double(index) + progress) / Double(total)) {
                    Text("書き出し中… \(index + 1) / \(total) 本目")
                }
                Text("終わるまでアプリを開いたままにしてください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("中止", role: .cancel) { model.cancel() }
            }

        case .saving:
            ProgressView("写真に保存中…")

        case let .done(count):
            VStack(spacing: 12) {
                Label("\(count)本の動画を保存しました", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text("「写真」アプリのアルバム「\(PhotoLibrary.albumTitle)」に入っています。みてねアプリからアップロードしてください。")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                Button("写真アプリを開く") {
                    if let url = URL(string: "photos-redirect://") { openURL(url) }
                }
                .buttonStyle(.bordered)
                Button("もう一度設定を変えて分割する") { model.reset() }
                    .font(.footnote)
            }

        case let .failed(message):
            VStack(spacing: 12) {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Button("戻る") { model.reset() }
            }
        }
    }
}

#Preview {
    ContentView()
}
