import SwiftUI
import Observation
import WidgetKit

/// App state: the chosen place and its weather/air conditions.
@MainActor
@Observable
final class AppModel {
    private(set) var place: Place = AppSettings.place
    private(set) var conditions: Conditions?
    private(set) var loading = false
    private(set) var failed = false

    init() {
        conditions = Conditions.cached(for: place)
    }

    func refresh(force: Bool = false) async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        let target = place
        let result = await Conditions.load(for: target, force: force)
        guard target == place else { return }   // the place changed while loading
        conditions = result
        // Failed = nothing to show, or only an old cached reading.
        failed = result.map { Date.now.timeIntervalSince($0.fetched) > 25 * 60 } ?? true
        WidgetCenter.shared.reloadAllTimelines()
    }

    func select(_ newPlace: Place) {
        guard newPlace != place else { return }
        AppSettings.place = newPlace
        place = newPlace
        conditions = Conditions.cached(for: newPlace)
        WidgetCenter.shared.reloadAllTimelines()
        Task { await refresh(force: true) }
    }
}
