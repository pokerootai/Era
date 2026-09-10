import SwiftUI
import MusicKit

struct LibraryView: View {
    @ObservedObject var player: MusicPlayerManager
    @State private var recentlyPlayed: [Song] = []
    @State private var favorites: [Song] = []

    var body: some View {
        NavigationStack {
            List {
                if !favorites.isEmpty {
                    Section("Favoriten ❤️") {
                        ForEach(favorites, id: \.id) { song in
                            SongRowView(song: song.displayData)
                                .onTapGesture {
                                    Task { try? await player.playQueue(songs: favorites, startingWith: song) }
                                }
                        }
                    }
                }

                if !recentlyPlayed.isEmpty {
                    Section("Zuletzt gespielt") {
                        ForEach(recentlyPlayed, id: \.id) { song in
                            SongRowView(song: song.displayData)
                                .onTapGesture {
                                    Task { try? await player.playQueue(songs: recentlyPlayed, startingWith: song) }
                                }
                        }
                    }
                }

                if recentlyPlayed.isEmpty && favorites.isEmpty {
                    ContentUnavailableView("Mediathek leer", systemImage: "music.note",
                                          description: Text("Spiele Songs um sie hier zu sehen"))
                }
            }
            .navigationTitle("Mediathek")
            .task { await loadLibrary() }
        }
    }

    private func loadLibrary() async {
        async let recentTask: () = loadRecent()
        async let favTask: () = loadFavorites()
        await recentTask; await favTask
    }

    private func loadRecent() async {
        do {
            let res = try await MusicRecentlyPlayedRequest<Song>().response()
            recentlyPlayed = Array(res.items.prefix(20))
        } catch {}
    }

    private func loadFavorites() async {
        do {
            var req = MusicLibraryRequest<Song>()
            req.filter(matching: \.isFavorite, equalTo: true)
            req.limit = 50
            let res = try await req.response()
            favorites = Array(res.items)
        } catch {}
    }
}


