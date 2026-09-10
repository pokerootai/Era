import SwiftUI
import MusicKit
import MediaPlayer
import Combine

@MainActor
class MusicPlayerManager: ObservableObject {
    static let shared = MusicPlayerManager()
    private let player = ApplicationMusicPlayer.shared

    // Playback State
    @Published var playbackState: MusicPlayer.PlaybackStatus = .stopped
    @Published var playbackTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    // Controls
    @Published var shuffleMode: MusicPlayer.ShuffleMode = .off
    @Published var repeatMode: MusicPlayer.RepeatMode = .none
    @Published var isFavorite: Bool = false

    // Queue
    @Published var queue: [Song] = []

    // Lyrics
    @Published var lyrics: String? = nil
    @Published var isLoadingLyrics = false

    // Sleep Timer
    @Published var sleepTimerRemaining: TimeInterval? = nil
    private var sleepTimer: Timer?

    private var stateObserver: Task<Void, Never>?
    private var timer: Timer?

    init() {
        stateObserver = Task {
            for await state in player.state.playbackStatus {
                self.playbackState = state
                if state == .playing { self.startTimer() }
                else { self.stopTimer() }
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

    // MARK: - Favoriten

    func toggleFavorite() async {
        guard let song = currentSong else { return }
        do {
            if isFavorite { try await MusicLibrary.shared.unfavorite(song) }
            else           { try await MusicLibrary.shared.favorite(song) }
            isFavorite.toggle()
        } catch { print("Favorit-Fehler: \(error)") }
    }

    private func checkFavorite(for song: Song) async {
        do {
            var req = MusicLibraryRequest<Song>()
            req.filter(matching: \.id, equalTo: song.id)
            let res = try await req.response()
            isFavorite = res.items.first?.isFavorite ?? false
        } catch { isFavorite = false }
    }

    // MARK: - Lyrics

    func loadLyrics(for song: Song) async {
        lyrics = nil
        isLoadingLyrics = true
        defer { isLoadingLyrics = false }
        do {
            // MusicKit liefert Lyrics über detailliertes Song-Objekt
            let detailedSong = try await song.with([.lyrics])
            lyrics = detailedSong.lyrics
        } catch { lyrics = nil }
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

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.playbackTime = self?.player.playbackTime ?? 0
            }
        }
    }

    private func stopTimer() { timer?.invalidate(); timer = nil }

    private func updateDuration(for song: Song) { duration = song.duration ?? 0 }

    var currentSong: Song? { player.queue.currentEntry?.item as? Song }
    var isPlaying: Bool { playbackState == .playing }
    var progress: Double { duration > 0 ? playbackTime / duration : 0 }
    var repeatIcon: String { repeatMode == .one ? "repeat.1" : "repeat" }
}

​
