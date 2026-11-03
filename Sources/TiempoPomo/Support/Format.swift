import Foundation

enum Format {
    /// 24:59, or 1:04:59 past the hour.
    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%02d:%02d", m, sec)
    }

    /// 95 → "1h 35m".
    static func minutes(_ total: Int) -> String {
        let h = total / 60, m = total % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}
