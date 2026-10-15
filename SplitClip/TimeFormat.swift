import Foundation

enum TimeFormat {
    /// 例: 115 → "1分55秒", 60 → "1分", 45 → "45秒"
    static func japanese(seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let m = total / 60
        let s = total % 60
        switch (m, s) {
        case (0, _): return "\(s)秒"
        case (_, 0): return "\(m)分"
        default: return "\(m)分\(s)秒"
        }
    }
}
