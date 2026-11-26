import WidgetKit
import SwiftUI

// MARK: - Timeline

struct DayEntry: TimelineEntry {
    let date: Date
}

/// Static provider: one entry every 15 minutes for the next 12 hours,
/// aligned to the quarter hour.
struct DayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        completion(DayEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        let calendar = Calendar.current
        let now = Date.now
        let minute = calendar.component(.minute, from: now)
        let start = calendar.date(bySettingHour: calendar.component(.hour, from: now),
                                  minute: minute - minute % 15, second: 0, of: now) ?? now
        var entries = [DayEntry(date: now)]
        for step in 1...48 {
            if let date = calendar.date(byAdding: .minute, value: step * 15, to: start) {
                entries.append(DayEntry(date: date))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Bundle

@main
struct PonjikaWidgets: WidgetBundle {
    var body: some Widget {
        BanglaDateWidget()
        BanglaSeasonWidget()
        BanglaDayWidget()
        BanglaCountdownWidget()
        SunWidget()
        MoonWidget()
        WeatherWidget()
    }
}
