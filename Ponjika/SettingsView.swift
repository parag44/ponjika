import SwiftUI

/// The সেটিংস page: current location and data sources.
struct SettingsPage: View {
    let model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                PageTitle(text: "সেটিংস", color: Palette.secondary)

                NavigationLink {
                    PlacePicker(model: model)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill").foregroundStyle(Palette.blue)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("অবস্থান").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                            Text(model.place.name).font(.system(size: 16, weight: .bold))
                            Text(model.place.country).font(.system(size: 10)).foregroundStyle(Palette.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    }
                    .padding(.horizontal, 11).padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.card))
                }
                .buttonStyle(.plain)

                Text("সূর্যোদয়-সূর্যাস্ত, আবহাওয়া, বায়ুর মান ও সতর্কতা এই অবস্থান অনুযায়ী দেখানো হয়।")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 4)

                VStack(alignment: .leading, spacing: 3) {
                    Text("তথ্যসূত্র").font(.system(size: 10, weight: .semibold))
                    Text("আবহাওয়া ও বায়ুর মান: Open-Meteo")
                    Text("ছুটির তালিকা: বাংলাদেশ সরকার")
                    Text("বাংলা তারিখ: সংশোধিত বঙ্গাব্দ")
                }
                .font(.system(size: 10))
                .foregroundStyle(Palette.secondary)
                .padding(.horizontal, 4)
                .padding(.top, 6)
            }
        }
    }
}

/// Choose a city: search first (the watch keyboard offers dictation and
/// scribble), the current city pinned, then Bangladesh and abroad lists.
struct PlacePicker: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Place] = []
    @State private var searching = false
    @State private var searchFailed = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Palette.secondary)
                    TextField("শহর খুঁজুন", text: $query)
                        .onSubmit { Task { await search() } }
                }
                if searching {
                    ProgressView()
                } else if searchFailed {
                    Text("খুঁজে পাওয়া যায়নি").font(.system(size: 12)).foregroundStyle(Palette.secondary)
                }
                ForEach(results) { place in row(place) }
            } footer: {
                Text("ইংরেজিতে লিখুন বা বলুন, যেমন Sylhet").font(.system(size: 10))
            }

            Section {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill").foregroundStyle(Palette.blue)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(model.place.name).font(.system(size: 15, weight: .bold))
                        Text("বর্তমান অবস্থান").font(.system(size: 10)).foregroundStyle(Palette.blue.opacity(0.8))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark").foregroundStyle(Palette.blue)
                }
                .listRowBackground(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.blue.opacity(0.18)))
            }

            Section("বাংলাদেশ") {
                ForEach(Place.bangladesh.filter { $0.id != model.place.id }) { place in row(place) }
            }
            Section("প্রবাসে") {
                ForEach(Place.abroad.filter { $0.id != model.place.id }) { place in row(place) }
            }
        }
        .navigationTitle("অবস্থান")
    }

    private func row(_ place: Place) -> some View {
        Button {
            model.select(place)
            dismiss()
        } label: {
            HStack {
                Text(place.name).font(.system(size: 15, weight: .semibold))
                Spacer(minLength: 4)
                Text(place.country).font(.system(size: 10)).foregroundStyle(Palette.secondary).lineLimit(1)
            }
        }
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { return }
        searching = true
        defer { searching = false }
        let found = (try? await Place.search(text)) ?? []
        results = found
        searchFailed = found.isEmpty
    }
}
