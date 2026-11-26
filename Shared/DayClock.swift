import Foundation

enum DayClock {
    /// Fraction of the current calendar day that has elapsed, 0...1.
    static func fraction(at date: Date, calendar: Calendar = .current) -> Double {
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        let fraction = date.timeIntervalSince(start) / end.timeIntervalSince(start)
        return min(max(fraction, 0), 1)
    }
}
