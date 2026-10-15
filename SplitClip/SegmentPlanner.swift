import CoreMedia

/// 動画をどこで区切るかを決める。
///
/// 「最大長 → 最大長 → 端数」ではなく、全体を同じ長さに均等割りする。
/// 例: 5分の動画を最大1分55秒で分割すると 1分40秒 × 3本 になる。
enum SegmentPlanner {
    private static let timescale: CMTimeScale = 600

    static func plan(duration: CMTime, maxLength: CMTime) -> [CMTimeRange] {
        guard duration.isNumeric, maxLength.isNumeric,
              duration > .zero, maxLength > .zero else { return [] }

        let total = duration.convertScale(timescale, method: .roundTowardZero).value
        let limit = maxLength.convertScale(timescale, method: .roundTowardZero).value
        guard total > 0, limit > 0 else { return [] }

        let count = (total + limit - 1) / limit
        return (0..<count).map { i in
            let start = CMTime(value: total * i / count, timescale: timescale)
            // 最後の区間は元の長さの端まで含める（timescale変換で切り捨てた分を落とさない）
            let end = i == count - 1
                ? duration
                : CMTime(value: total * (i + 1) / count, timescale: timescale)
            return CMTimeRange(start: start, end: end)
        }
    }
}
