# 動画分割 (SplitClip)

みてねに2分を超える動画をアップロードするための、家族用のiPhoneアプリです。
長い動画を「2分以内」の複数の動画に分割して、写真アプリに保存します。

## できること

- 写真アプリから動画を1本選ぶ
- 1本あたりの最大の長さを設定する（初期値は **1分55秒**。30秒〜10分の範囲で5秒ずつ変更可）
- **均等に分割**する（例: 5分の動画 → 1分40秒 × 3本。最後の1本だけ数秒になることはありません）
- 分割した動画を写真アプリのアルバム **「分割動画」** に保存
- 元の動画の **撮影日時・撮影場所を引き継ぐ**
  - 2本目以降の撮影日時は「元の撮影日時 + 開始位置」にずらすので、みてね上でも順番どおりに並びます
- 画質は落ちません（再エンコードせずに切り出します。対応していない形式のときだけ最高画質で再エンコード）

使い方: アプリを開く → 「動画を選ぶ」 → 「分割して写真に保存」 → みてねアプリでアルバム「分割動画」から選んでアップロード。

## 必要なもの

- Mac と Xcode 16 以降
- iPhone（iOS 17 以降）
- Apple ID（配布方法によっては Apple Developer Program への加入）

## Macでのビルド手順

1. このリポジトリを Mac にクローンし、`SplitClip.xcodeproj` を Xcode で開く
2. 左のナビゲータで **SplitClip** プロジェクト → TARGETS の **SplitClip** → **Signing & Capabilities** を開く
3. **Team** に自分の Apple ID を選ぶ（未登録なら Xcode → Settings → Accounts で追加）
4. **Bundle Identifier** を自分だけのものに変える（例: `com.yourname.SplitClip`）。`com.example...` のままだと署名できません
5. iPhone をケーブルで Mac に接続し、Xcode 上部の実行先に iPhone を選んで ▶︎ (Run)
6. 初回のみ iPhone 側で設定が必要です
   - 設定 → プライバシーとセキュリティ → **デベロッパモード** をオン（再起動あり）
   - 設定 → 一般 → VPNとデバイス管理 → 自分の Apple ID を **信頼**

## 妻のiPhoneに入れる方法

App Store には公開せず、2台だけに入れる方法は次の3つです。

| 方法 | 費用 | 手間 | 有効期限 |
| --- | --- | --- | --- |
| A. 無料のApple IDでXcodeから直接インストール | 無料 | 妻のiPhoneもMacにつなぐ必要あり | **7日**（切れたら再インストール） |
| B. TestFlight（おすすめ） | Apple Developer Program 年額（米国99ドル相当） | 招待を送るだけ。妻はTestFlightアプリから入れる | ビルドごとに90日（アップロードし直せば延長） |
| C. Ad Hoc配布 | Apple Developer Program 年額 | 妻のiPhoneのUDIDを登録してipaを配る | 1年（証明書・プロファイルの期限） |

### A. 無料のApple ID（お試し向け）

上の「Macでのビルド手順」を、妻のiPhoneをMacにつないでもう一度行うだけです。
7日で起動できなくなるので、そのたびに Mac につないで ▶︎ し直します（写真に保存済みの動画は消えません）。

### B. TestFlight（長く使うならこれ）

1. [Apple Developer Program](https://developer.apple.com/programs/) に加入
2. [App Store Connect](https://appstoreconnect.apple.com/) で「マイApp」→「＋」→ 新規App を作成（Bundle ID は手順4で決めたもの。**公開はしません**）
3. Xcode で 実行先を「Any iOS Device」にして Product → **Archive** → Distribute App → **TestFlight Internal Only**（または App Store Connect）でアップロード
4. App Store Connect の「ユーザとアクセス」で妻の Apple ID を招待（役割は「Developer」など最小限でOK）
5. TestFlight タブの「内部テスト」グループに妻を追加
6. 妻のiPhoneに届いたメールから **TestFlight** アプリ経由でインストール

内部テストは Apple の審査なしで配布できます。App Store に一般公開されることもありません。

## 開発メモ

- `SplitClip/` … アプリ本体（SwiftUI）
  - `SegmentPlanner.swift` … どこで区切るかの計算（均等割り）
  - `VideoSplitter.swift` … AVFoundation での切り出し・撮影日時メタデータの書き換え
  - `PhotoLibrary.swift` … 写真ライブラリへの保存・アルバム作成
  - `SplitViewModel.swift` / `ContentView.swift` … 画面と状態管理
- `SplitClipTests/` … 分割位置の計算などの単体テスト
- `.github/workflows/ios.yml` … GitHub Actions（macOS）でビルドとテストを実行

プロジェクトは Xcode 16 の「フォルダ同期」形式なので、`SplitClip/` フォルダにファイルを追加すれば自動でビルド対象になります。
