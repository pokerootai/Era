import SwiftUI
import SwiftData

// Suche: eigene Bibliothek (Spec 13.4) - Songs, Artists, Alben, Versionen, Tags.
struct SearchView: View {
    @Binding var showNowPlaying: Bool
    @EnvironmentObject private var player: PlayerEngine
    @Query private var songs: [Song]
    @State private var query = ""

    private var results: [Song] {
        guard !query.isEmpty else { return [] }
        return songs.filter { song in
            song.title.localizedCaseInsensitiveContains(query)
            || song.displayArtist.localizedCaseInsensitiveContains(query)
            || song.album.localizedCaseInsensitiveContains(query)
            || song.era.localizedCaseInsensitiveContains(query)
            || song.tags.contains { $0.name.localizedCaseInsensitiveContains(query) }
            || song.versions.contains { $0.name.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if query.isEmpty {
                    ContentUnavailableView("Bibliothek durchsuchen", systemImage: "magnifyingglass", description: Text("Songs, Artists, Alben, Versionen und Tags."))
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(results) { song in
                        NavigationLink {
                            SongDetailView(song: song, showNowPlaying: $showNowPlaying)
                        } label: {
                            SongRow(song: song, version: nil, isCurrent: player.current?.song?.id == song.id)
                        }
                        .contextMenu { SongContextMenu(song: song, showNowPlaying: $showNowPlaying) }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Suche")
            .searchable(text: $query, prompt: "Titel, Künstler, Album, Tag")
        }
    }
}
