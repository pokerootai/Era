import Foundation
import AVFoundation
import MediaPlayer

@MainActor
final class PlayerEngine: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = PlayerEngine()
    @Published var queue: [LocalSong] = []
    @Published var currentSong: LocalSong?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var shuffle = false
    @Published var repeatMode = 0
    @Published var sleepRemaining: Int?

    private var audio: AVAudioPlayer?
    private var ticker: Timer?
    private var sleepTimer: Timer?

    override init() {
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowAirPlay, .allowBluetoothA2DP])
        try? AVAudioSession.sharedInstance().setActive(true)
        setupRemoteCommands()
    }

    func play(_ song: LocalSong, from songs: [LocalSong]) {
        queue = songs
        currentSong = song
        let url = LibraryStore.shared.fileURL(for: song)
        #if targetEnvironment(simulator)
        if !FileManager.default.fileExists(atPath: url.path) { duration = song.duration; currentTime = 31; isPlaying = true; startTicker(); updateNowPlaying(); return }
        #endif
        do {
            audio = try AVAudioPlayer(contentsOf: url); audio?.delegate = self; audio?.prepareToPlay(); audio?.play()
            duration = audio?.duration ?? song.duration; currentTime = 0; isPlaying = true
            LibraryStore.shared.markPlayed(song.id); startTicker(); updateNowPlaying()
        } catch { isPlaying = false }
    }

    func toggle() {
        guard currentSong != nil else { if let first = LibraryStore.shared.songs.first { play(first, from: LibraryStore.shared.songs) }; return }
        if isPlaying { audio?.pause() } else { audio?.play() }
        isPlaying.toggle(); updateNowPlaying()
    }

    func seek(_ value: Double) { currentTime = value; audio?.currentTime = value; updateNowPlaying() }
    func next() { move(1) }
    func previous() { if currentTime > 4 { seek(0) } else { move(-1) } }
    private func move(_ offset: Int) {
        guard !queue.isEmpty, let currentSong, let i = queue.firstIndex(where: { $0.id == currentSong.id }) else { return }
        if repeatMode == 2 { play(currentSong, from: queue); return }
        let nextIndex = shuffle ? Int.random(in: queue.indices) : (i + offset + queue.count) % queue.count
        play(queue[nextIndex], from: queue)
    }
    func toggleRepeat() { repeatMode = (repeatMode + 1) % 3 }

    func setSleep(minutes: Int) {
        sleepTimer?.invalidate(); sleepRemaining = minutes * 60
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in
            guard let self else { return }
            if let r = self.sleepRemaining, r > 1 { self.sleepRemaining = r - 1 } else { self.audio?.pause(); self.isPlaying = false; self.sleepRemaining = nil; self.sleepTimer?.invalidate() }
        }}
    }
    func cancelSleep() { sleepTimer?.invalidate(); sleepRemaining = nil }

    private func startTicker() {
        ticker?.invalidate(); ticker = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in Task { @MainActor in
            guard let self else { return }; if let a = self.audio { self.currentTime = a.currentTime; self.isPlaying = a.isPlaying }; self.updateNowPlaying()
        }}
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { Task { @MainActor in self.next() } }

    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        c.playCommand.addTarget { [weak self] _ in Task { @MainActor in if self?.isPlaying == false { self?.toggle() } }; return .success }
        c.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in if self?.isPlaying == true { self?.toggle() } }; return .success }
        c.nextTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.next() }; return .success }
        c.previousTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.previous() }; return .success }
    }
    private func updateNowPlaying() {
        guard let s = currentSong else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle:s.title, MPMediaItemPropertyArtist:s.artist, MPMediaItemPropertyPlaybackDuration:duration, MPNowPlayingInfoPropertyElapsedPlaybackTime:currentTime, MPNowPlayingInfoPropertyPlaybackRate:isPlaying ? 1 : 0]
    }
}
