import SwiftUI
import MusicKit

// Anzeige-Daten fuer Songs/Alben - entkoppelt die Views von MusicKit-Typen,
// damit dieselben Views im Simulator mit Demo-Daten gerendert werden koennen.
struct SongDisplayData: Identifiable {
    let id: String
    let title: String
    let artistName: String
    let artwork: (Int, Int) -> URL?

    func artworkURL(width: Int, height: Int) -> URL? { artwork(width, height) }
}

extension Song {
    var displayData: SongDisplayData {
        SongDisplayData(id: id.rawValue, title: title, artistName: artistName) { w, h in
            self.artwork?.url(width: w, height: h)
        }
    }
}

extension Album {
    var displayData: SongDisplayData {
        SongDisplayData(id: id.rawValue, title: title, artistName: artistName) { w, h in
            self.artwork?.url(width: w, height: h)
        }
    }
}

// Abstraktion des Players, damit NowPlaying & Co. auch mit Demo-Daten laufen.
@MainActor
protocol PlayerControlling: ObservableObject {
    var playbackTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var progress: Double { get }
    var isPlaying: Bool { get }
    var shuffleActive: Bool { get }
    var repeatNone: Bool { get }
    var repeatIcon: String { get }
    var isFavorite: Bool { get }
    var currentDisplay: SongDisplayData? { get }
    var queueDisplays: [SongDisplayData] { get }
    var currentQueueID: String? { get }
    var lyrics: String? { get }
    var isLoadingLyrics: Bool { get }
    var sleepTimerRemaining: TimeInterval? { get }
    var sleepTimerLabel: String { get }

    func togglePlayPause() async throws
    func skipToNext() async throws
    func skipToPrevious() async throws
    func seek(to time: TimeInterval)
    func toggleShuffle()
    func toggleRepeat()
    func toggleFavorite() async
    func playFromQueueID(_ id: String) async
    func setSleepTimer(minutes: Int)
    func cancelSleepTimer()
}

extension MusicPlayerManager: PlayerControlling {
    var shuffleActive: Bool { shuffleMode != .off }
    var repeatNone: Bool { repeatMode == .none }
    var currentDisplay: SongDisplayData? { currentSong?.displayData }
    var queueDisplays: [SongDisplayData] { queue.map { $0.displayData } }
    var currentQueueID: String? { currentSong?.id.rawValue }

    func playFromQueueID(_ id: String) async {
        if let song = queue.first(where: { $0.id.rawValue == id }) {
            try? await playFromQueue(song: song)
        }
    }
}
