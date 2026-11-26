import Foundation

/// Bangla (Bengali) calendar and text helpers, following Bangladesh's revised
/// calendar (2019): Pohela Boishakh is 14 April, the first six months have 31
/// days, Falgun has 30 days in Gregorian leap years (29 otherwise), and the
/// rest have 30. That puts 1 Poush on 16 December and 8 Falgun on 21 February.
struct BanglaDate: Equatable {
    let day: Int     // 1...31
    let month: Int   // 0 = Boishakh ... 11 = Chaitra
    let year: Int    // Bangabda, e.g. 1433

    init(day: Int, month: Int, year: Int) {
        self.day = day; self.month = month; self.year = year
    }

    init(_ date: Date, calendar: Calendar = .current) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let parts = gregorian.dateComponents([.year, .month, .day], from: date)
        let gYear = parts.year!, gMonth = parts.month!, gDay = parts.day!

        // Bangla year starts on 14 April.
        let startsThisYear = (gMonth, gDay) >= (4, 14)
        let newYearGregorianYear = startsThisYear ? gYear : gYear - 1
        let newYear = gregorian.date(from: DateComponents(year: newYearGregorianYear, month: 4, day: 14))!
        let today = gregorian.date(from: DateComponents(year: gYear, month: gMonth, day: gDay))!
        var offset = gregorian.dateComponents([.day], from: newYear, to: today).day!

        let lengths = Self.monthLengths(year: newYearGregorianYear - 593)
        var month = 0
        while month < 11 && offset >= lengths[month] {
            offset -= lengths[month]
            month += 1
        }
        self.init(day: offset + 1, month: month, year: newYearGregorianYear - 593)
    }

    var monthName: String { Bangla.months[month] }
    var season: Bangla.Season { Bangla.Season.allCases[month / 2] }

    /// Day counts for each month of Bangla `year`. Falgun falls in Feb–Mar of
    /// Gregorian year `year + 594`, and has 30 days when that year is a leap year.
    static func monthLengths(year: Int) -> [Int] {
        let falgunYear = year + 594
        let isLeap = (falgunYear % 4 == 0 && falgunYear % 100 != 0) || falgunYear % 400 == 0
        return [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, isLeap ? 30 : 29, 30]
    }

    /// The Gregorian date of the 1st of a Bangla month (midnight in `calendar`'s time zone).
    static func firstDay(month: Int, year: Int, calendar: Calendar = .current) -> Date {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let newYear = gregorian.date(from: DateComponents(year: year + 593, month: 4, day: 14))!
        let offset = monthLengths(year: year).prefix(month).reduce(0, +)
        return gregorian.date(byAdding: .day, value: offset, to: newYear)!
    }

    /// The (month, year) before or after this one, wrapping across years.
    static func shifted(month: Int, year: Int, by delta: Int) -> (month: Int, year: Int) {
        let total = year * 12 + month + delta
        return (((total % 12) + 12) % 12, Int((Double(total) / 12).rounded(.down)))
    }
}

enum Bangla {
    static let months = ["বৈশাখ", "জ্যৈষ্ঠ", "আষাঢ়", "শ্রাবণ", "ভাদ্র", "আশ্বিন",
                         "কার্তিক", "অগ্রহায়ণ", "পৌষ", "মাঘ", "ফাল্গুন", "চৈত্র"]

    /// Sunday first, matching Calendar's weekday numbering (1 = Sunday).
    static let weekdays = ["রবিবার", "সোমবার", "মঙ্গলবার", "বুধবার", "বৃহস্পতিবার", "শুক্রবার", "শনিবার"]
    static let weekdaysShort = ["রবি", "সোম", "মঙ্গল", "বুধ", "বৃহঃ", "শুক্র", "শনি"]

    static let gregorianMonths = ["জানুয়ারি", "ফেব্রুয়ারি", "মার্চ", "এপ্রিল", "মে", "জুন",
                                  "জুলাই", "আগস্ট", "সেপ্টেম্বর", "অক্টোবর", "নভেম্বর", "ডিসেম্বর"]

    enum Season: CaseIterable {
        case grishmo, borsha, shorot, hemonto, sheet, boshonto

        var name: String {
            switch self {
            case .grishmo: "গ্রীষ্ম"
            case .borsha: "বর্ষা"
            case .shorot: "শরৎ"
            case .hemonto: "হেমন্ত"
            case .sheet: "শীত"
            case .boshonto: "বসন্ত"
            }
        }

        /// Season colour (RGB): summer orange, monsoon blue, autumn sky,
        /// late-autumn harvest gold, winter ice, spring pink.
        var rgb: (Double, Double, Double) {
            switch self {
            case .grishmo: (1.0, 0.55, 0.15)
            case .borsha: (0.3, 0.6, 1.0)
            case .shorot: (0.45, 0.85, 1.0)
            case .hemonto: (1.0, 0.8, 0.2)
            case .sheet: (0.75, 0.9, 1.0)
            case .boshonto: (1.0, 0.45, 0.7)
            }
        }

        var symbol: String {
            switch self {
            case .grishmo: "sun.max.fill"
            case .borsha: "cloud.rain.fill"
            case .shorot: "cloud.sun.fill"
            case .hemonto: "leaf.fill"
            case .sheet: "snowflake"
            case .boshonto: "camera.macro"
            }
        }
    }

    /// "1433" -> "১৪৩৩"
    static func digits(_ value: Int) -> String {
        digits(String(value))
    }

    static func digits(_ text: String) -> String {
        let bengali: [Character] = ["০", "১", "২", "৩", "৪", "৫", "৬", "৭", "৮", "৯"]
        return String(text.map { c in c.wholeNumberValue.map { bengali[$0] } ?? c })
    }

    static func weekday(_ date: Date, short: Bool = false, calendar: Calendar = .current) -> String {
        let index = calendar.component(.weekday, from: date) - 1
        return short ? weekdaysShort[index] : weekdays[index]
    }

    /// "২৬ নভেম্বর"
    static func gregorianDate(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.day, .month], from: date)
        return "\(digits(parts.day!)) \(gregorianMonths[parts.month! - 1])"
    }
}
