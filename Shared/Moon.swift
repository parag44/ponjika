import Foundation

/// Moon phase from Meeus' low-precision lunar terms (good to a few hours),
/// plus the Bengali tithi (lunar day: each 12° of sun–moon elongation).
struct MoonPhase {
    /// Sun–moon elongation in degrees, 0..<360. 0 = new moon, 180 = full moon.
    let elongation: Double

    init(_ date: Date) {
        let julianDay = date.timeIntervalSince1970 / 86400 + 2440587.5
        let t = (julianDay - 2451545.0) / 36525
        func norm(_ x: Double) -> Double { let r = x.truncatingRemainder(dividingBy: 360); return r < 0 ? r + 360 : r }
        let rad = Double.pi / 180
        let d = norm(297.8501921 + 445267.1114034 * t) * rad       // mean elongation
        let m = norm(357.5291092 + 35999.0502909 * t) * rad        // sun's mean anomaly
        let mp = norm(134.9633964 + 477198.8675055 * t) * rad      // moon's mean anomaly
        let correction = 6.289 * sin(mp) - 2.100 * sin(m) + 1.274 * sin(2 * d - mp)
                       + 0.658 * sin(2 * d) + 0.214 * sin(2 * mp) + 0.110 * sin(d)
        elongation = norm(d / rad + correction)
    }

    /// Fraction of the disc that is lit, 0...1.
    var illumination: Double { (1 - cos(elongation * .pi / 180)) / 2 }
    var isWaxing: Bool { elongation < 180 }

    /// 1...30. 1–15 শুক্লপক্ষ (15 = পূর্ণিমা), 16–30 কৃষ্ণপক্ষ (30 = অমাবস্যা).
    var tithi: Int { min(30, Int(elongation / 12) + 1) }

    static let tithiNames = ["প্রতিপদ", "দ্বিতীয়া", "তৃতীয়া", "চতুর্থী", "পঞ্চমী", "ষষ্ঠী", "সপ্তমী",
                             "অষ্টমী", "নবমী", "দশমী", "একাদশী", "দ্বাদশী", "ত্রয়োদশী", "চতুর্দশী"]

    /// "ষষ্ঠী", "পূর্ণিমা", "অমাবস্যা"
    var tithiName: String {
        switch tithi {
        case 15: "পূর্ণিমা"
        case 30: "অমাবস্যা"
        default: Self.tithiNames[(tithi - 1) % 15]
        }
    }

    /// "শুক্লপক্ষ" (waxing fortnight) or "কৃষ্ণপক্ষ" (waning fortnight)
    var paksha: String { isWaxing ? "শুক্লপক্ষ" : "কৃষ্ণপক্ষ" }

    /// Whole days until the next full moon (0 = within the next day).
    var daysToFull: Int {
        let degrees = isWaxing ? 180 - elongation : 540 - elongation
        return Int(degrees / 12.19)   // mean daily elongation
    }

    /// Whole days until the next new moon.
    var daysToNew: Int { Int((360 - elongation) / 12.19) }

    /// The next moment the moon reaches full (elongation 180°) or new (360°/0°), found by
    /// stepping forward an hour at a time — accurate to within an hour.
    static func next(_ target: Target, after date: Date) -> Date? {
        var previous = MoonPhase(date).elongation
        for hour in 1...(31 * 24) {
            let probe = date.addingTimeInterval(Double(hour) * 3600)
            let current = MoonPhase(probe).elongation
            switch target {
            case .full where previous < 180 && current >= 180: return probe
            case .new where current < previous: return probe   // wrapped past 360°
            default: break
            }
            previous = current
        }
        return nil
    }

    enum Target { case full, new }
}
