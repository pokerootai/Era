import SwiftUI

struct HomeView: View {
    @ObservedObject var store: LibraryStore
    @ObservedObject var player: PlayerEngine
    @Binding var selectedTab: Int

    var body: some View {
        NavigationStack {
            Group {
                if store.songs.isEmpty {
                    ContentUnavailableView {
                        Label("Noch keine Musik", systemImage: "music.note")
                    } description: {
                        Text("Importiere Songs aus der Dateien-App und baue deine Bibliothek auf.")
                    } actions: {
                        Button { selectedTab = 1 } label: { Label("Songs importieren", systemImage: "square.and.arrow.down") }
                            .buttonStyle(.glassProminent)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            if !store.recentlyPlayed.isEmpty { shelf("Dein Sound", songs: Array(store.recentlyPlayed.prefix(8)), icon: "waveform") }
                            if !store.favorites.isEmpty { shelf("Favoriten", songs: store.favorites, icon: "heart.fill") }
                            shelf("Zuletzt hinzugefügt", songs: Array(store.songs.prefix(10)), icon: "clock.fill")
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Era")
            .background(Color(.systemGroupedBackground))
        }
    }

    private func shelf(_ title: String, songs: [LocalSong], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.title2.bold()).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(songs) { song in
                        VStack(alignment: .leading, spacing: 7) {
                            Artwork(song: song).frame(width: 150, height: 150)
                            Text(song.title).font(.subheadline.bold()).lineLimit(1)
                            Text(song.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        .frame(width: 150, alignment: .leading)
                        .onTapGesture { player.play(song, from: songs) }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
