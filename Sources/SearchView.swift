import SwiftUI
import MusicKit
import Combine

struct SearchView: View {
    @ObservedObject var player: MusicPlayerManager
    @State private var searchText = ""
    @State private var songs: [Song] = []
    @State private var albums: [Album] = []
    @State private var artists: [Artist] = []
    @State private var isLoading = false
    @State private var debounceTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if !songs.isEmpty {
                    Section("Songs") {
                        ForEach(songs, id: \.id) { song in
                            SongRowView(song: song.displayData)
                                .onTapGesture {
                                    Task { try? await player.playQueue(songs: songs, startingWith: song) }
                                }
                        }
                    }
                }

                if !albums.isEmpty {
                    Section("Alben") {
                        ForEach(albums, id: \.id) { album in
                            NavigationLink(destination: AlbumDetailView(album: album, player: player)) {
                                SongRowView(song: album.displayData, showsPlayIcon: false)
                            }
                        }
                    }
                }

                if !artists.isEmpty {
                    Section("Artists") {
                        ForEach(artists, id: \.id) { artist in
                            NavigationLink(destination: ArtistView(artist: artist, player: player)) {
                                Text(artist.name).padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if isLoading { ProgressView() }
                if songs.isEmpty && albums.isEmpty && artists.isEmpty && !searchText.isEmpty && !isLoading {
                    ContentUnavailableView.search(text: searchText)
                }
                if searchText.isEmpty {
                    ContentUnavailableView("Suchen", systemImage: "magnifyingglass",
                                          description: Text("Songs, Alben oder Artists eingeben"))
                }
            }
            .navigationTitle("Suche")
            .searchable(text: $searchText, prompt: "Songs, Alben, Artists")
            .onChange(of: searchText) { _, new in
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    await search(query: new)
                }
            }
        }
    }

    private func search(query: String) async {
        guard !query.isEmpty else { songs = []; albums = []; artists = []; return }
        isLoading = true
        defer { isLoading = false }
        do {
            var req = MusicCatalogSearchRequest(term: query, types: [Song.self, Album.self, Artist.self])
            req.limit = 10
            let res = try await req.response()
            songs   = Array(res.songs)
            albums  = Array(res.albums)
            artists = Array(res.artists)
        } catch { print("Suche: \(error)") }
    }
}


​
