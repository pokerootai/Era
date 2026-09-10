import SwiftUI
import MusicKit

struct ArtistView: View {
    let artist: Artist
    @ObservedObject var player: MusicPlayerManager
    @State private var topSongs: [Song] = []
    @State private var albums: [Album] = []

    var body: some View {
        List {
            // Artwork Header
            Section {
                AsyncImage(url: artist.artwork?.url(width: 300, height: 300)) { image in
                    image.resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 220)
                        .clipped()
                } placeholder: {
                    Rectangle().fill(.secondary.opacity(0.2)).frame(height: 220)
                }
                .listRowInsets(.init())
            }

            if !topSongs.isEmpty {
                Section("Top Songs") {
                    ForEach(topSongs, id: \.id) { song in
                        SongRowView(song: song.displayData)
                            .onTapGesture {
                                Task { try? await player.playQueue(songs: topSongs, startingWith: song) }
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
        }
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.large)
        .task { await loadArtistContent() }
    }

    private func loadArtistContent() async {
        do {
            let detailed = try await artist.with([.topSongs, .albums])
            topSongs = Array((detailed.topSongs ?? []).prefix(10))
            albums   = Array(detailed.albums ?? [])
        } catch { print("Artist laden: \(error)") }
    }
}


