import SwiftUI
import MusicKit
import MediaPlayer
import Combine

@MainActor
class MusicPlayerManager: ObservableObject {
    static let shared = MusicPlayerManager()
    private let player = ApplicationMusicPlayer.shared

    // Playback State
    @Published var playbackState: MusicKit.MusicPlayer.PlaybackStatus = .stopped
    @Published var playbackTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    // Controls
    @Published var shuffleMode: MusicKit.MusicPlayer.ShuffleMode = .off
    @Published var repeatMode: MusicKit.MusicPlayer.RepeatMode = .none
    @Published var isFavorite: Bool = false

    // Queue
    @Published var queue: [Song] = []

    // Favoriten (lokal persistiert - MusicKit bietet keine Favoriten-API)
    @Published private(set) var favoriteSongs: [Song] = []
    private let favoritesKey = "era.favorites.v1"

    // Lyrics
    @Published var lyrics: String? = nil
    @Published var isLoadingLyrics = false

    // Sleep Timer
    @Published var sleepTimerRemaining: TimeInterval? = nil
    private var sleepTimer: Timer?

    private var timer: Timer?

    init() {
        loadFavorites()
        // Status & Zeit per Polling beobachten (MusicKit hat kein AsyncSequence-API dafuer)
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let status = self.player.state.playbackStatus
                if status != self.playbackState { self.playbackState = status }
                if status == .playing {
                    self.playbackTime = self.player.playbackTime
                    if let current = self.currentSong {
                        if self.duration == 0 { self.updateDuration(for: current) }
                    }
                }
            }
        }
    }

    // MARK: - Playback

    func playQueue(songs: [Song], startingWith song: Song) async throws {
        queue = songs
        player.queue = ApplicationMusicPlayer.Queue(for: songs, startingAt: song)
        try await player.play()
        updateDuration(for: song)
        await checkFavorite(for: song)
        await loadLyrics(for: song)
    }

    func togglePlayPause() async throws {
        if playbackState == .playing { player.pause() }
        else { try await player.play() }
    }

    func skipToNext() async throws {
        try await player.skipToNextEntry()
        await onSongChanged()
    }

    func skipToPrevious() async throws {
        try await player.skipToPreviousEntry()
        await onSongChanged()
    }

    func seek(to time: TimeInterval) {
        player.playbackTime = time
        playbackTime = time
    }

    func playFromQueue(song: Song) async throws {
        if let idx = queue.firstIndex(where: { $0.id == song.id }) {
            try await playQueue(songs: queue, startingWith: queue[idx])
        }
    }

    private func onSongChanged() async {
        guard let song = currentSong else { return }
        updateDuration(for: song)
        await checkFavorite(for: song)
        await loadLyrics(for: song)
    }

    // MARK: - Shuffle & Repeat

    func toggleShuffle() {
        shuffleMode = shuffleMode == .off ? .songs : .off
        player.state.shuffleMode = shuffleMode
    }

    func toggleRepeat() {
        switch repeatMode {
        case .none: repeatMode = .all
        case .all:  repeatMode = .one
        default:    repeatMode = .none
        }
        player.state.repeatMode = repeatMode
    }

    // MARK: - Favoriten (lokal)

    func toggleFavorite() async {
        guard let song = currentSong else { return }
        if let idx = favoriteSongs.firstIndex(where: { $0.id == song.id }) {
            favoriteSongs.remove(at: idx)
            isFavorite = false
        } else {
            favoriteSongs.insert(song, at: 0)
            isFavorite = true
        }
        saveFavorites()
    }

    private func checkFavorite(for song: Song) async {
        isFavorite = favoriteSongs.contains { $0.id == song.id }
    }

    private func loadFavorites() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let songs = try? JSONDecoder().decode([Song].self, from: data) {
            favoriteSongs = songs
        }
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favoriteSongs) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }

    // MARK: - Lyrics (Apple-Music-API via MusicDataRequest, TTML -> Text)

    func loadLyrics(for song: Song) async {
        lyrics = nil
        guard song.hasLyrics else { return }
        isLoadingLyrics = true
        defer { isLoadingLyrics = false }
        do {
            let storefront = try await currentStorefront()
            let url = URL(string: "https://api.music.apple.com/v1/catalog/\(storefront)/songs/\(song.id.rawValue)/lyrics")!
            let request = MusicDataRequest(urlRequest: URLRequest(url: url))
            let response = try await request.response()
            if let ttml = Self.decodeTTML(from: response.data) {
                lyrics = Self.plainText(fromTTML: ttml)
            }
        } catch {
            lyrics = nil
        }
    }

    private func currentStorefront() async throws -> String {
        struct StorefrontResponse: Decodable {
            struct Item: Decodable { let id: String }
            let data: [Item]
        }
        let request = MusicDataRequest(urlRequest: URLRequest(url: URL(string: "https://api.music.apple.com/v1/me/storefront")!))
        let response = try await request.response()
        let decoded = try JSONDecoder().decode(StorefrontResponse.self, from: response.data)
        return decoded.data.first?.id ?? "de"
    }

    private static func decodeTTML(from data: Data) -> String? {
        struct LyricsResponse: Decodable {
            struct Item: Decodable {
                struct Attributes: Decodable { let ttml: String? }
                let attributes: Attributes?
            }
            let data: [Item]
        }
        return try? JSONDecoder().decode(LyricsResponse.self, from: data).data.first?.attributes?.ttml
    }

    private static func plainText(fromTTML ttml: String) -> String {
        var lines: [String] = []
        for part in ttml.components(separatedBy: "<p ").dropFirst() {
            var text = part
            if let end = text.range(of: "</p>") { text = String(text[..<end.lowerBound]) }
            text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            text = text.replacingOccurrences(of: "&amp;", with: "&")
                       .replacingOccurrences(of: "&lt;", with: "<")
                       .replacingOccurrences(of: "&gt;", with: ">")
                       .replacingOccurrences(of: "&quot;", with: "\"")
                       .replacingOccurrences(of: "&apos;", with: "'")
                       .replacingOccurrences(of: "&#39;", with: "'")
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { lines.append(text) }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Sleep Timer

    func setSleepTimer(minutes: Int) {
        cancelSleepTimer()
        let seconds = TimeInterval(minutes * 60)
        sleepTimerRemaining = seconds
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let remaining = self.sleepTimerRemaining, remaining > 0 {
                    self.sleepTimerRemaining = remaining - 1
                } else {
                    self.player.pause()
                    self.cancelSleepTimer()
                }
            }
        }
    }

    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerRemaining = nil
    }

    var sleepTimerLabel: String {
        guard let r = sleepTimerRemaining else { return "Aus" }
        let m = Int(r) / 60
        let s = Int(r) % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Helpers

    private func updateDuration(for song: Song) { duration = song.duration ?? 0 }

    var currentSong: Song? { player.queue.currentEntry?.item as? Song }
    var isPlaying: Bool { playbackState == .playing }
    var progress: Double { duration > 0 ? playbackTime / duration : 0 }
    var repeatIcon: String { repeatMode == .one ? "repeat.1" : "repeat" }
}
