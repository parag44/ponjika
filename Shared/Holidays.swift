import Foundation

/// Bangladesh government holidays and notable days.
///
/// Years with a published government list use it exactly (`official`). Other
/// years use the fixed-date holidays plus Islamic holidays calculated from the
/// Umm al-Qura calendar + 1 day, which matches all of Bangladesh's official
/// 2027 dates; those are flagged as depending on moon sighting. Lunar Hindu
/// and Buddhist holidays only appear for years with an official list.
struct Holiday: Identifiable {
    enum Kind { case holiday, observance }

    let name: String
    let short: String          // fits a small complication
    let start: Date
    let end: Date              // same as start for one-day holidays
    let symbol: String
    let rgb: (Double, Double, Double)
    let kind: Kind
    let moonDependent: Bool

    var id: String { "\(name)-\(start.timeIntervalSince1970)" }
    var isMultiDay: Bool { end > start }

    /// Whole days from `date`'s day to the start (0 = today, also while the holiday is running).
    func daysAway(from date: Date, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: date)
        if today >= start && today <= end { return 0 }
        return calendar.dateComponents([.day], from: today, to: start).day ?? 0
    }

    /// "১০ মার্চ" or "৮–১২ মার্চ" / "৩১ মার্চ – ২ এপ্রিল"
    func dateText(calendar: Calendar = .current) -> String {
        let s = calendar.dateComponents([.day, .month], from: start)
        let e = calendar.dateComponents([.day, .month], from: end)
        let startMonth = Bangla.gregorianMonths[s.month! - 1]
        guard isMultiDay else { return "\(Bangla.digits(s.day!)) \(startMonth)" }
        if s.month == e.month { return "\(Bangla.digits(s.day!))–\(Bangla.digits(e.day!)) \(startMonth)" }
        return "\(Bangla.digits(s.day!)) \(startMonth) – \(Bangla.digits(e.day!)) \(Bangla.gregorianMonths[e.month! - 1])"
    }
}

enum Holidays {
    // Colours
    private static let red = (1.0, 0.33, 0.38), green = (0.2, 0.82, 0.55), gold = (1.0, 0.8, 0.25)
    private static let white = (0.95, 0.95, 0.95), teal = (0.35, 0.85, 0.85), violet = (0.7, 0.5, 1.0)
    private static let orange = (1.0, 0.6, 0.2), sky = (0.45, 0.75, 1.0)

    /// Upcoming holidays and observances within `days` days, soonest first.
    static func upcoming(from date: Date = .now, within days: Int = 370, calendar: Calendar = .current) -> [Holiday] {
        let today = calendar.startOfDay(for: date)
        guard let horizon = calendar.date(byAdding: .day, value: days, to: today) else { return [] }
        let year = calendar.component(.year, from: today)
        return [year, year + 1]
            .flatMap { list(for: $0, calendar: calendar) }
            .filter { $0.end >= today && $0.start <= horizon }
            .sorted { $0.start < $1.start }
    }

    /// The next holiday or observance (including one happening today).
    static func next(from date: Date = .now, calendar: Calendar = .current) -> Holiday? {
        upcoming(from: date, within: 400, calendar: calendar).first
    }

    // MARK: Building a year's list

    static func list(for year: Int, calendar: Calendar = .current) -> [Holiday] {
        func day(_ m: Int, _ d: Int) -> Date { calendar.date(from: DateComponents(year: year, month: m, day: d))! }
        func make(_ name: String, _ short: String, _ start: Date, _ end: Date? = nil, _ symbol: String,
                  _ rgb: (Double, Double, Double), kind: Holiday.Kind = .holiday, moon: Bool = false) -> Holiday {
            Holiday(name: name, short: short, start: start, end: end ?? start, symbol: symbol, rgb: rgb, kind: kind, moonDependent: moon)
        }

        // Fixed Gregorian dates, every year.
        var items: [Holiday] = [
            make("পহেলা ফাল্গুন", "ফাল্গুন", day(2, 14), nil, "camera.macro", gold, kind: .observance),
            make("শহীদ দিবস ও আন্তর্জাতিক মাতৃভাষা দিবস", "একুশে", day(2, 21), nil, "text.book.closed.fill", white),
            make("স্বাধীনতা ও জাতীয় দিবস", "স্বাধীনতা", day(3, 26), nil, "flag.fill", green),
            make("পহেলা বৈশাখ (বাংলা নববর্ষ)", "বৈশাখ", day(4, 14), nil, "sun.max.fill", red),
            make("মে দিবস", "মে দিবস", day(5, 1), nil, "hammer.fill", orange),
            make("জুলাই গণঅভ্যুত্থান দিবস", "জুলাই", day(8, 5), nil, "person.3.fill", red),
            make("জাতীয় বিপ্লব ও সংহতি দিবস", "৭ নভেম্বর", day(11, 7), nil, "flag.fill", green),
            make("বিজয় দিবস", "বিজয়", day(12, 16), nil, "flag.fill", red),
            make("বড়দিন", "বড়দিন", day(12, 25), nil, "star.fill", sky),
        ]

        if let official = official[year] {
            items += official.map { o in
                make(o.name, o.short, day(o.start.0, o.start.1),
                     o.end.map { day($0.0, $0.1) }, o.symbol, o.rgb, moon: o.moon)
            }
        } else {
            items += islamic(for: year, calendar: calendar).map { name, short, start, end, symbol, rgb in
                make(name, short, start, end, symbol, rgb, moon: true)
            }
        }
        return items
    }

    // MARK: Official lists

    private struct Entry {
        let name: String, short: String
        let start: (Int, Int), end: (Int, Int)?
        let symbol: String, rgb: (Double, Double, Double)
        let moon: Bool
    }

    /// Government holiday lists (lunar and moving holidays only; fixed dates are added above).
    /// 2027: cabinet-approved list of 2 November 2026 (29 holidays), as reported by Prothom Alo.
    private static let official: [Int: [Entry]] = [
        2027: [
            Entry(name: "শবে বরাত", short: "শবে বরাত", start: (1, 24), end: nil, symbol: "moon.stars.fill", rgb: teal, moon: true),
            Entry(name: "জুমাতুল বিদা", short: "জুমাতুল বিদা", start: (3, 5), end: nil, symbol: "building.columns.fill", rgb: teal, moon: true),
            Entry(name: "শবে কদর", short: "শবে কদর", start: (3, 7), end: nil, symbol: "moon.stars.fill", rgb: teal, moon: true),
            Entry(name: "ঈদুল ফিতর", short: "ঈদ", start: (3, 8), end: (3, 12), symbol: "moon.stars.fill", rgb: green, moon: true),
            Entry(name: "চৈত্র সংক্রান্তি (পার্বত্য তিন জেলা)", short: "সংক্রান্তি", start: (4, 13), end: nil, symbol: "leaf.fill", rgb: orange, moon: false),
            Entry(name: "ঈদুল আজহা", short: "ঈদ", start: (5, 15), end: (5, 20), symbol: "moon.stars.fill", rgb: green, moon: true),
            Entry(name: "বুদ্ধ পূর্ণিমা", short: "বুদ্ধ পূর্ণিমা", start: (5, 20), end: nil, symbol: "circle.fill", rgb: gold, moon: false),
            Entry(name: "আশুরা", short: "আশুরা", start: (6, 16), end: nil, symbol: "moon.fill", rgb: teal, moon: true),
            Entry(name: "ঈদে মিলাদুন্নবী (সা.)", short: "মিলাদুন্নবী", start: (8, 15), end: nil, symbol: "moon.stars.fill", rgb: teal, moon: true),
            Entry(name: "জন্মাষ্টমী", short: "জন্মাষ্টমী", start: (8, 25), end: nil, symbol: "sparkles", rgb: violet, moon: false),
            Entry(name: "দুর্গাপূজা (নবমী ও বিজয়া দশমী)", short: "দুর্গাপূজা", start: (10, 9), end: (10, 10), symbol: "sparkles", rgb: orange, moon: false),
        ],
    ]

    // MARK: Calculated Islamic holidays

    /// Umm al-Qura + 1 day, which matches Bangladesh's moon-sighting dates (checked against 2027).
    private static func islamic(for year: Int, calendar: Calendar)
        -> [(String, String, Date, Date?, String, (Double, Double, Double))] {
        var hijri = Calendar(identifier: .islamicUmmAlQura)
        hijri.timeZone = calendar.timeZone
        guard let jan1 = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) else { return [] }
        let hijriYear = hijri.component(.year, from: jan1)

        func date(_ month: Int, _ day: Int, plus extra: Int = 0) -> Date? {
            for y in [hijriYear, hijriYear + 1] {
                guard let d = hijri.date(from: DateComponents(year: y, month: month, day: day)),
                      let bd = calendar.date(byAdding: .day, value: 1 + extra, to: calendar.startOfDay(for: d)),
                      calendar.component(.year, from: bd) == year else { continue }
                return bd
            }
            return nil
        }

        var result: [(String, String, Date, Date?, String, (Double, Double, Double))] = []
        if let d = date(8, 15) { result.append(("শবে বরাত", "শবে বরাত", d, nil, "moon.stars.fill", teal)) }
        if let d = date(9, 27) { result.append(("শবে কদর", "শবে কদর", d, nil, "moon.stars.fill", teal)) }
        if let s = date(10, 1, plus: -2), let e = date(10, 1, plus: 2) {
            result.append(("ঈদুল ফিতর", "ঈদ", s, e, "moon.stars.fill", green))
        }
        if let s = date(12, 10, plus: -2), let e = date(12, 10, plus: 3) {
            result.append(("ঈদুল আজহা", "ঈদ", s, e, "moon.stars.fill", green))
        }
        if let d = date(1, 10) { result.append(("আশুরা", "আশুরা", d, nil, "moon.fill", teal)) }
        if let d = date(3, 12) { result.append(("ঈদে মিলাদুন্নবী (সা.)", "মিলাদুন্নবী", d, nil, "moon.stars.fill", teal)) }
        return result
    }
}
