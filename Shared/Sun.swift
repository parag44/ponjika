import Foundation

/// Sunrise and sunset from NOAA's solar equations (accurate to about a minute).
/// Uses the standard -0.833° altitude, which allows for refraction and the sun's disc.
enum Sun {
    /// Dhaka (Zero Point area) and its time zone.
    static let dhaka = (latitude: 23.7104, longitude: 90.4074, timeZone: TimeZone(identifier: "Asia/Dhaka")!)

    struct Day {
        let sunrise: Date
        let sunset: Date
        var daylight: TimeInterval { sunset.timeIntervalSince(sunrise) }
    }

    /// Sunrise and sunset for the calendar day containing `date` at the location.
    static func day(for date: Date,
                    latitude: Double = dhaka.latitude,
                    longitude: Double = dhaka.longitude,
                    timeZone: TimeZone = dhaka.timeZone) -> Day? {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = timeZone
        let parts = local.dateComponents([.year, .month, .day], from: date)

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        guard let utcMidnight = utc.date(from: parts),
              let dayOfYear = utc.ordinality(of: .day, in: .year, for: utcMidnight) else { return nil }

        let rad = Double.pi / 180
        let γ = 2 * Double.pi / 365 * Double(dayOfYear - 1)   // fractional year at noon-ish
        let eqTime = 229.18 * (0.000075 + 0.001868 * cos(γ) - 0.032077 * sin(γ)
                               - 0.014615 * cos(2 * γ) - 0.040849 * sin(2 * γ))
        let decl = 0.006918 - 0.399912 * cos(γ) + 0.070257 * sin(γ) - 0.006758 * cos(2 * γ)
                 + 0.000907 * sin(2 * γ) - 0.002697 * cos(3 * γ) + 0.00148 * sin(3 * γ)

        let lat = latitude * rad
        let cosHA = cos(90.833 * rad) / (cos(lat) * cos(decl)) - tan(lat) * tan(decl)
        guard (-1...1).contains(cosHA) else { return nil }   // polar day or night
        let haDegrees = acos(cosHA) / rad

        let riseMinutes = 720 - 4 * (longitude + haDegrees) - eqTime
        let setMinutes = 720 - 4 * (longitude - haDegrees) - eqTime
        return Day(sunrise: utcMidnight.addingTimeInterval(riseMinutes * 60),
                   sunset: utcMidnight.addingTimeInterval(setMinutes * 60))
    }

    enum Event { case sunrise, sunset }

    /// Sunrise and sunset for `date`'s day at `place`.
    static func day(for date: Date, at place: Place) -> Day? {
        day(for: date, latitude: place.latitude, longitude: place.longitude, timeZone: place.timeZone)
    }

    /// The next sunrise or sunset strictly after `date` at `place`.
    static func next(after date: Date, at place: Place) -> (event: Event, at: Date)? {
        for offset in 0...2 {
            guard let probe = Calendar.current.date(byAdding: .day, value: offset, to: date),
                  let day = day(for: probe, at: place) else { continue }
            if day.sunrise > date { return (.sunrise, day.sunrise) }
            if day.sunset > date { return (.sunset, day.sunset) }
        }
        return nil
    }
}

extension Bangla {
    /// "৬:২২" in 12-hour time, using the watch's time zone.
    static func clock(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let hour12 = (parts.hour! + 11) % 12 + 1
        return digits(String(format: "%d:%02d", hour12, parts.minute!))
    }

    /// "১০ ঘ ৪৯ মি"
    static func duration(_ interval: TimeInterval) -> String {
        let minutes = Int((interval / 60).rounded())
        return "\(digits(minutes / 60)) ঘ \(digits(minutes % 60)) মি"
    }
}
