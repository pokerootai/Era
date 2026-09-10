import SwiftUI
import MusicKit

struct HomeView: View {
    @ObservedObject var player: MusicPlayerManager
    @State private var charts: [Song] = []
    @State private var recommendations: [Song] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else {
                        SongSection(title: "Top Charts 🏆", cards: charts.map(\.displayData)) { data in
                            if let song = charts.first(where: { $0.id.rawValue == data.id }) {
                                Task { try? await player.playQueue(songs: charts, startingWith: song) }
                            }
                        }
                        SongSection(title: "Empfohlen für dich ✨", cards: recommendations.map(\.displayData)) { data in
                            if let song = recommendations.first(where: { $0.id.rawValue == data.id }) {
                                Task { try? await player.playQueue(songs: recommendations, startingWith: song) }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Home")
            .task { await loadContent() }
        }
    }

    private func loadContent() async {
        isLoading = true
        async let chartsTask = loadCharts()
        async let recsTask = loadRecommendations()
        charts = await chartsTask
        recommendations = await recsTask
        isLoading = false
    }

    private func loadCharts() async -> [Song] {
        do {
            let request = MusicCatalogChartsRequest(kinds: [.mostPlayed], types: [Song.self])
            let response = try await request.response()
            return Array((response.songCharts.first?.items ?? []).prefix(15))
        } catch { return [] }
    }

    private func loadRecommendations() async -> [Song] {
        do {
            let request = MusicPersonalRecommendationsRequest()
            let response = try await request.response()
            let albums = response.recommendations.flatMap { $0.items.compactMap { $0 as? Album } }.prefix(5)
            var songs: [Song] = []
            for album in albums {
                let detailed = try? await album.with([.tracks])
                if let tracks = detailed?.tracks {
                    songs += tracks.prefix(3).compactMap { track -> Song? in
                        if case .song(let song) = track { return song }
                        return nil
                    }
                }
            }
            return songs
        } catch { return [] }
    }
}

struct SongSection: View {
    let title: String
    let cards: [SongDisplayData]
    var onSelect: (SongDisplayData) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title2.bold()).padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(cards) { card in
                        AlbumCardView(song: card)
                            .onTapGesture { onSelect(card) }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct AlbumCardView: View {
    let song: SongDisplayData
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: song.artworkURL(width: 160, height: 160)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 12).fill(.secondary.opacity(0.2))
            }
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(song.title).font(.caption.weight(.medium)).lineLimit(1).frame(width: 160, alignment: .leading)
            Text(song.artistName).font(.caption2).foregroundStyle(.secondary).lineLimit(1).frame(width: 160, alignment: .leading)
        }
    }
}
