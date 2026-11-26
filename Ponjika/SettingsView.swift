import SwiftUI

/// The সেটিংস page: current location and app info.
struct SettingsPage: View {
    let model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Label("সেটিংস", systemImage: "gearshape.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.gray)

                NavigationLink {
                    PlacePicker(model: model)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill").foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 0) {
                            Text("অবস্থান").font(.system(size: 11)).foregroundStyle(.secondary)
                            Text(model.place.name).font(.system(size: 16, weight: .semibold))
                            Text(model.place.country).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }

                Text("সূর্যোদয়-সূর্যাস্ত, আবহাওয়া, বায়ুর মান ও সতর্কতা এই অবস্থান অনুযায়ী দেখানো হয়।")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Divider().padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text("তথ্যসূত্র").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    Text("আবহাওয়া ও বায়ুর মান: Open-Meteo").font(.system(size: 11))
                    Text("ছুটির তালিকা: বাংলাদেশ সরকার").font(.system(size: 11))
                    Text("বাংলা তারিখ: সংশোধিত বঙ্গাব্দ").font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Choose a city: search worldwide, or pick from Bangladesh and abroad lists.
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
                TextField("শহর খুঁজুন (ইংরেজিতে)", text: $query)
                    .onSubmit { Task { await search() } }
                if searching {
                    ProgressView()
                } else if searchFailed {
                    Text("খুঁজে পাওয়া যায়নি").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                ForEach(results) { place in row(place) }
            }

            Section("বাংলাদেশ") {
                ForEach(Place.bangladesh) { place in row(place) }
            }
            Section("প্রবাসে") {
                ForEach(Place.abroad) { place in row(place) }
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
                VStack(alignment: .leading, spacing: 0) {
                    Text(place.name).font(.system(size: 15, weight: .semibold))
                    Text(place.country).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                if place.id == model.place.id {
                    Image(systemName: "checkmark").foregroundStyle(.blue)
                }
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
