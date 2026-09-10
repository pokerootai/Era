#if targetEnvironment(simulator)
import SwiftUI
import MusicKit

// MARK: - Demo-Modus (nur Simulator) fuer Screenshots & Design-Pruefung.
// Geraete-Builds enthalten diesen Code nicht - dort laeuft alles ueber MusicKit.

enum DemoMode: String {
    case home, nowplaying, search, library, album, auth, mini

    static func from(_ args: [String]) -> DemoMode? {
        for arg in args where arg.hasPrefix("--demo-") {
            return DemoMode(rawValue: String(arg.dropFirst("--demo-".count)))
        }
        return nil
    }
}

func mockArtwork(_ seed: String) -> (Int, Int) -> URL? {
    { w, h in URL(string: "https://picsum.photos/seed/\(seed)/\(w)/\(h)") }
}

enum DemoData {
    static let songs: [SongDisplayData] = [
        SongDisplayData(id: "d1", title: "Late Nights", artistName: "MALT3", artwork: mockArtwork("era-latenights")),
        SongDisplayData(id: "d2", title: "Midnight City", artistName: "M83", artwork: mockArtwork("era-m83")),
        SongDisplayData(id: "d3", title: "Blinding Lights", artistName: "The Weeknd", artwork: mockArtwork("era-weeknd")),
        SongDisplayData(id: "d4", title: "Starboy", artistName: "The Weeknd", artwork: mockArtwork("era-starboy")),
        SongDisplayData(id: "d5", title: "Nights", artistName: "Frank Ocean", artwork: mockArtwork("era-frank")),
        SongDisplayData(id: "d6", title: "Levitating", artistName: "Dua Lipa", artwork: mockArtwork("era-dua")),
        SongDisplayData(id: "d7", title: "Skeletons", artistName: "Travis Scott", artwork: mockArtwork("era-travis")),
        SongDisplayData(id: "d8", title: "After Hours", artistName: "The Weeknd", artwork: mockArtwork("era-afterhours")),
    ]

    static let albums: [SongDisplayData] = [
        SongDisplayData(id: "a1", title: "After Hours", artistName: "The Weeknd", artwork: mockArtwork("era-alb1")),
        SongDisplayData(id: "a2", title: "Blonde", artistName: "Frank Ocean", artwork: mockArtwork("era-alb2")),
        SongDisplayData(id: "a3", title: "Future Nostalgia", artistName: "Dua Lipa", artwork: mockArtwork("era-alb3")),
    ]

    static let artists = ["The Weeknd", "Frank Ocean", "Dua Lipa", "Travis Scott", "MALT3"]
}

@MainActor
final class DemoPlayer: PlayerControlling {
    @Published var playbackTime: TimeInterval = 71
    @Published var playing = true
    @Published var favorite = true
    @Published var shuffle = false
    @Published var repeatIdx = 0
    @Published var sleepTimerRemaining: TimeInterval? = 12 * 60
    @Published var lyrics: String? = "I've been on my own for long enough\nMaybe you can show me how to love, maybe\nI'm going through withdrawals\nYou don't even have to do too much\nYou can turn me on with just a touch, baby"
    @Published var isLoadingLyrics = false

    let duration: TimeInterval = 214

    var isPlaying: Bool { playing }
    var progress: Double { duration > 0 ? playbackTime / duration : 0 }
    var shuffleActive: Bool { shuffle }
    var repeatNone: Bool { repeatIdx == 0 }
    var repeatIcon: String { repeatIdx == 2 ? "repeat.1" : "repeat" }
    var isFavorite: Bool { favorite }
    var currentDisplay: SongDisplayData? { DemoData.songs[2] }
    var queueDisplays: [SongDisplayData] { DemoData.songs }
    var currentQueueID: String? { "d3" }
    var sleepTimerLabel: String {
        guard let r = sleepTimerRemaining else { return "Aus" }
        return String(format: "%d:%02d", Int(r) / 60, Int(r) % 60)
    }

    func togglePlayPause() async throws { playing.toggle() }
    func skipToNext() async throws { playbackTime = 0 }
    func skipToPrevious() async throws { playbackTime = 0 }
    func seek(to time: TimeInterval) { playbackTime = time }
    func toggleShuffle() { shuffle.toggle() }
    func toggleRepeat() { repeatIdx = (repeatIdx + 1) % 3 }
    func toggleFavorite() async { favorite.toggle() }
    func playFromQueueID(_ id: String) async {}
    func setSleepTimer(minutes: Int) { sleepTimerRemaining = TimeInterval(minutes * 60) }
    func cancelSleepTimer() { sleepTimerRemaining = nil }
}

struct DemoRootView: View {
    let mode: DemoMode
    @StateObject private var player = DemoPlayer()

    var body: some View {
        switch mode {
        case .home:
            DemoHomeView()
        case .nowplaying:
            NowPlayingView(player: player)
        case .search:
            DemoSearchView()
        case .library:
            DemoLibraryView()
        case .album:
            DemoAlbumView()
        case .auth:
            AuthorizationView(authStatus: .constant(.notDetermined))
        case .mini:
            ZStack(alignment: .bottom) {
                DemoHomeView()
                MiniPlayerView(player: player) {}
                    .padding(.bottom, 60)
            }
        }
    }
}

struct DemoHomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SongSection(title: "Top Charts 🏆", cards: DemoData.songs) { _ in }
                    SongSection(title: "Empfohlen für dich ✨", cards: Array(DemoData.songs.reversed())) { _ in }
                }
                .padding(.vertical)
            }
            .navigationTitle("Home")
        }
    }
}

struct DemoSearchView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Songs") {
                    ForEach(DemoData.songs.prefix(4)) { song in
                        SongRowView(song: song)
                    }
                }
                Section("Alben") {
                    ForEach(DemoData.albums) { album in
                        SongRowView(song: album, showsPlayIcon: false)
                    }
                }
                Section("Artists") {
                    ForEach(DemoData.artists, id: \.self) { artist in
                        Text(artist).padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Suche")
            .searchable(text: .constant("weeknd"), prompt: "Songs, Alben, Artists")
        }
    }
}

struct DemoLibraryView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Favoriten ❤️") {
                    ForEach(DemoData.songs.prefix(3)) { song in
                        SongRowView(song: song)
                    }
                }
                Section("Zuletzt gespielt") {
                    ForEach(DemoData.songs.suffix(4)) { song in
                        SongRowView(song: song)
                    }
                }
            }
            .navigationTitle("Mediathek")
        }
    }
}

struct DemoAlbumView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        AsyncImage(url: DemoData.albums[0].artworkURL(width: 200, height: 200)) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 16).fill(.secondary.opacity(0.2))
                        }
                        .frame(width: 200, height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(radius: 10)

                        Text(DemoData.albums[0].title).font(.title2.bold()).multilineTextAlignment(.center)
                        Text(DemoData.albums[0].artistName).foregroundStyle(.secondary)

                        Button { } label: {
                            Label("Album abspielen", systemImage: "play.fill")
                                .font(.headline).padding(.horizontal, 24).padding(.vertical, 10)
                                .background(.pink, in: Capsule()).foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section("Titel") {
                    ForEach(Array(DemoData.songs.prefix(6).enumerated()), id: \.element.id) { index, song in
                        HStack {
                            Text("\(index + 1)").foregroundStyle(.secondary).frame(width: 24)
                            SongRowView(song: song)
                        }
                    }
                }
            }
            .navigationTitle(DemoData.albums[0].title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
#endif
