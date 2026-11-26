import SwiftUI

/// A Bangla month calendar (Bangladesh revised calendar). Each day shows its
/// Bangla date with the Gregorian date underneath; holidays, the Friday–Saturday
/// weekend, and full/new moons are marked. Tap a day for its details.
struct BanglaCalendarView: View {
    @State private var month: Int
    @State private var year: Int
    @State private var selected: Date

    private let calendar = Calendar.current
    private let today: Date

    init(date: Date = .now) {
        let b = BanglaDate(date)
        _month = State(initialValue: b.month)
        _year = State(initialValue: b.year)
        let start = Calendar.current.startOfDay(for: date)
        _selected = State(initialValue: start)
        today = start
    }

    private static let weekdayInitials = ["র", "সো", "ম", "বু", "বৃ", "শু", "শ"]   // Sunday first
    private static let red = Color(red: 1.0, green: 0.4, blue: 0.42)
    private static let gold = Color(red: 1.0, green: 0.82, blue: 0.3)
    private static let silver = Color(red: 0.78, green: 0.82, blue: 1.0)

    var body: some View {
        let first = BanglaDate.firstDay(month: month, year: year, calendar: calendar)
        let length = BanglaDate.monthLengths(year: year)[month]
        let days = (0..<length).map { calendar.date(byAdding: .day, value: $0, to: first)! }
        let leadingBlanks = calendar.component(.weekday, from: first) - 1
        let seasonColor = Color(rgb: Bangla.Season.allCases[month / 2].rgb)
        let moons = moonDays(from: first, count: length)

        ScrollView {
            VStack(spacing: 6) {
                header(first: first, last: days.last ?? first, color: seasonColor)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 2) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(Self.weekdayInitials[i])
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(i >= 5 ? Self.red : .secondary)
                    }
                    ForEach(0..<leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 24) }
                    ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                        cell(banglaDay: index + 1, date: day, moon: moons[calendar.startOfDay(for: day)], accent: seasonColor)
                    }
                }

                detail(for: selected)
                    .padding(.top, 4)
            }
        }
        .navigationTitle("বাংলা ক্যালেন্ডার")
    }

    // MARK: Header

    private func header(first: Date, last: Date, color: Color) -> some View {
        HStack(spacing: 4) {
            Button { shift(-1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color(white: 0.11)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("আগের মাস")

            VStack(spacing: 0) {
                Text("\(Bangla.months[month]) \(Bangla.digits(year))")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(gregorianSpan(first, last))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)

            Button { shift(1) } label: {
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color(white: 0.11)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("পরের মাস")
        }
    }

    /// "নভেম্বর–ডিসেম্বর ২০২৬" or "ডিসেম্বর ২০২৬ – জানুয়ারি ২০২৭"
    private func gregorianSpan(_ first: Date, _ last: Date) -> String {
        let a = calendar.dateComponents([.month, .year], from: first)
        let b = calendar.dateComponents([.month, .year], from: last)
        let m1 = Bangla.gregorianMonths[a.month! - 1], m2 = Bangla.gregorianMonths[b.month! - 1]
        if a.year == b.year { return "\(m1)–\(m2) \(Bangla.digits(a.year!))" }
        return "\(m1) \(Bangla.digits(a.year!)) – \(m2) \(Bangla.digits(b.year!))"
    }

    private func shift(_ delta: Int) {
        let next = BanglaDate.shifted(month: month, year: year, by: delta)
        month = next.month
        year = next.year
        let first = BanglaDate.firstDay(month: month, year: year, calendar: calendar)
        let length = BanglaDate.monthLengths(year: year)[month]
        let last = calendar.date(byAdding: .day, value: length - 1, to: first)!
        // Keep today selected when it's in view, otherwise the 1st.
        selected = (first...last).contains(today) ? today : first
    }

    // MARK: Day cell

    private enum Moon { case full, new }

    private func cell(banglaDay: Int, date: Date, moon: Moon?, accent: Color) -> some View {
        let isToday = calendar.isDate(date, inSameDayAs: today)
        let isSelected = calendar.isDate(date, inSameDayAs: selected)
        let weekday = calendar.component(.weekday, from: date)          // 6 = Fri, 7 = Sat
        let holiday = Holidays.on(date, calendar: calendar).first { $0.kind == .holiday }
        let isWeekend = weekday == 6 || weekday == 7
        let numberColor: Color = isToday ? .black : (holiday != nil || isWeekend ? Self.red : .white)

        // Bangla numeral only (English date shows in the bar below); markers as dots underneath.
        return Button { selected = calendar.startOfDay(for: date) } label: {
            VStack(spacing: 1) {
                Text(Bangla.digits(banglaDay))
                    .font(.system(size: 13, weight: holiday != nil || isToday ? .bold : .medium))
                    .foregroundStyle(numberColor)
                    .frame(width: 21, height: 19)
                    .background {
                        Capsule().fill(isToday ? accent : (holiday != nil ? Self.red.opacity(0.22) : Color.clear))
                    }
                    .overlay {
                        if isSelected && !isToday { Capsule().stroke(accent, lineWidth: 1.2) }
                    }
                HStack(spacing: 1.5) {
                    if let moon {
                        Circle()
                            .strokeBorder(moon == .full ? Self.gold : Self.silver, lineWidth: 0.8)
                            .background(Circle().fill(moon == .full ? Self.gold : .clear))
                            .frame(width: 3.5, height: 3.5)
                    }
                    if holiday != nil {
                        Circle().fill(Self.red).frame(width: 3.5, height: 3.5)
                    }
                }
                .frame(height: 3.5)
            }
            .frame(maxWidth: .infinity, minHeight: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Bangla.digits(banglaDay)) \(Bangla.months[month])\(holiday.map { ", \($0.name)" } ?? "")")
    }

    /// Days in the month on which a full or new moon happens.
    private func moonDays(from first: Date, count: Int) -> [Date: Moon] {
        guard let end = calendar.date(byAdding: .day, value: count, to: first),
              let probeStart = calendar.date(byAdding: .hour, value: -1, to: first) else { return [:] }
        var result: [Date: Moon] = [:]
        for (target, kind) in [(MoonPhase.Target.full, Moon.full), (.new, .new)] {
            var cursor = probeStart
            while let instant = MoonPhase.next(target, after: cursor), instant < end {
                result[calendar.startOfDay(for: instant)] = kind
                cursor = instant.addingTimeInterval(20 * 86400)
            }
        }
        return result
    }

    // MARK: Selected day

    private func detail(for date: Date) -> some View {
        let b = BanglaDate(date)
        let seasonColor = Color(rgb: b.season.rgb)
        // Tithi at sunrise (about 6 AM), as Bangla almanacs give it.
        let moon = MoonPhase(calendar.date(byAdding: .hour, value: 6, to: calendar.startOfDay(for: date)) ?? date)
        let holidays = Holidays.on(date, calendar: calendar)

        // Compact bar: big Bangla day, then weekday · English date, then tithi.
        // Holidays and the season follow underneath.
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                Text(Bangla.digits(b.day))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(seasonColor)
                VStack(alignment: .leading, spacing: 0) {
                    Text((calendar.isDate(date, inSameDayAs: today) ? "আজ · " : "")
                         + "\(Bangla.weekday(date, short: true)) · \(Bangla.gregorianDate(date))")
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text("\(moon.paksha) \(moon.tithiName)")
                        .font(.system(size: 10))
                        .foregroundStyle(moon.isWaxing ? Self.gold : Self.silver)
                }
                Spacer(minLength: 0)
            }
            ForEach(holidays) { holiday in
                Label(holiday.name + (holiday.moonDependent ? " (চাঁদ দেখা সাপেক্ষে)" : ""), systemImage: holiday.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(rgb: holiday.rgb))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Label("\(b.monthName) \(Bangla.digits(b.year)) · \(b.season.name)কাল", systemImage: b.season.symbol)
                .font(.system(size: 10))
                .foregroundStyle(seasonColor.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(white: 0.11)))
    }
}

#Preview { NavigationStack { BanglaCalendarView() } }
