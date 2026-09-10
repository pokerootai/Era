import SwiftUI
import MusicKit

struct AlbumDetailView: View {
    let album: Album
    @ObservedObject var player: MusicPlayerManager
    @State private var tracks: [Song] = []

    var body: some View {
        List {
            // Header
            Section {
                VStack(spacing: 12) {
                    AsyncImage(url: album.artwork?.url(width: 200, height: 200)) { image in
                        image.resizable().scaledToFit()
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 16).fill(.secondary.opacity(0.2))
                    }
                    .frame(width: 200, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 10)

                    Text(album.title).font(.title2.bold()).multilineTextAlignment(.center)
                    Text(album.artistName).foregroundStyle(.secondary)

                    Button {
                        Task {
                            if let first = tracks.first {
                                try? await player.playQueue(songs: tracks, startingWith: first)
                            }
                        }
                    } label: {
                        Label("Album abspielen", systemImage: "play.fill")
                            .font(.headline).padding(.horizontal, 24).padding(.vertical, 10)
                            .background(.pink, in: Capsule()).foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            // Tracks
            Section("Titel") {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, song in
                    HStack {
                        Text("\(index + 1)").foregroundStyle(.secondary).frame(width: 24)
                        SongRowView(song: song.displayData)
                    }
                    .onTapGesture {
                        Task { try? await player.playQueue(songs: tracks, startingWith: song) }
                    }
                }
            }
        }
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            do {
                let detailed = try await album.with([.tracks])
                tracks = Array(detailed.tracks ?? [])
            } catch { print("Album-Tracks laden: \(error)") }
        }
    }
}


