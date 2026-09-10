import SwiftUI
import MusicKit
import MediaPlayer
import AVKit

struct NowPlayingView<P: PlayerControlling>: View {
    @ObservedObject var player: P
    @State private var showLyrics = false
    @State private var showQueue = false
    @State private var showSleepTimer = false

    var body: some View {
        NavigationStack {
            ZStack {
                ArtworkBackground(song: player.currentDisplay)

                ScrollView {
                    VStack(spacing: 24) {
                        Spacer().frame(height: 16)

                        // Artwork (animiert groesser wenn playing)
                        ArtworkView(song: player.currentDisplay)
                            .scaleEffect(player.isPlaying ? 1.0 : 0.88)
                            .animation(.spring(response: 0.4), value: player.isPlaying)

                        // Song-Info + Favorit
                        ZStack {
                            SongInfoView(song: player.currentDisplay)
                                .frame(maxWidth: .infinity)
                            HStack {
                                Spacer()
                                Button {
                                    Task { await player.toggleFavorite() }
                                } label: {
                                    Image(systemName: player.isFavorite ? "heart.fill" : "heart")
                                        .font(.title2)
                                        .foregroundStyle(player.isFavorite ? Color.pink : Color.secondary)
                                }
                            }
                        }.padding(.horizontal, 28)

                        // Fortschrittsleiste
                        ProgressSection(player: player)
                            .padding(.horizontal, 28)

                        // Haupt-Controls - Liquid Glass
                        VStack(spacing: 20) {
                            HStack(spacing: 48) {
                                Button { player.toggleShuffle() } label: {
                                    Image(systemName: "shuffle").font(.title3)
                                        .foregroundStyle(player.shuffleActive ? Color.pink : Color.secondary)
                                }
                                Button { player.toggleRepeat() } label: {
                                    Image(systemName: player.repeatIcon).font(.title3)
                                        .foregroundStyle(player.repeatNone ? Color.secondary : Color.pink)
                                }
                            }

                            HStack(spacing: 40) {
                                Button { Task { try? await player.skipToPrevious() } } label: {
                                    Image(systemName: "backward.fill").font(.title)
                                }
                                Button { Task { try? await player.togglePlayPause() } } label: {
                                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 64))
                                }
                                Button { Task { try? await player.skipToNext() } } label: {
                                    Image(systemName: "forward.fill").font(.title)
                                }
                            }

                            // Lautstaerke
                            HStack(spacing: 10) {
                                Image(systemName: "speaker.fill").font(.caption).foregroundStyle(.secondary)
                                VolumeSliderView()
                                Image(systemName: "speaker.wave.3.fill").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 24).padding(.vertical, 20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .glassEffect(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .padding(.horizontal, 20)

                        // Extra Buttons
                        HStack(spacing: 32) {
                            // AirPlay
                            AirPlayButton()
                                .frame(width: 44, height: 44)

                            // Lyrics
                            Button { showLyrics.toggle() } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "quote.bubble.fill").font(.title2)
                                    Text("Lyrics").font(.caption2)
                                }
                            }
                            .foregroundStyle(showLyrics ? Color.pink : Color.secondary)

                            // Queue
                            Button { showQueue.toggle() } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "list.bullet").font(.title2)
                                    Text("Queue").font(.caption2)
                                }
                            }
                            .foregroundStyle(.secondary)

                            // Sleep Timer
                            Button { showSleepTimer.toggle() } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "moon.fill").font(.title2)
                                    Text(player.sleepTimerRemaining != nil ? player.sleepTimerLabel : "Timer")
                                        .font(.caption2)
                                }
                            }
                            .foregroundStyle(player.sleepTimerRemaining != nil ? Color.pink : Color.secondary)
                        }
                        .padding(.bottom, 20)

                        // Lyrics Panel
                        if showLyrics {
                            LyricsView(player: player)
                                .padding(.horizontal, 20)
                        }

                        Spacer().frame(height: 20)
                    }
                }
            }
            .navigationTitle("Läuft jetzt")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showQueue) { QueueView(player: player) }
            .sheet(isPresented: $showSleepTimer) { SleepTimerSheet(player: player) }
        }
    }
}

// MARK: - Progress

struct ProgressSection<P: PlayerControlling>: View {
    @ObservedObject var player: P
    var body: some View {
        VStack(spacing: 6) {
            Slider(value: Binding(
                get: { player.progress },
                set: { player.seek(to: $0 * player.duration) }
            )).tint(.primary)
            HStack {
                Text(formatTime(player.playbackTime))
                Spacer()
                Text("-" + formatTime(max(0, player.duration - player.playbackTime)))
            }.font(.caption).foregroundStyle(.secondary)
        }
    }
    private func formatTime(_ t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// MARK: - Lyrics

struct LyricsView<P: PlayerControlling>: View {
    @ObservedObject var player: P
    var body: some View {
        Group {
            if player.isLoadingLyrics {
                ProgressView().frame(maxWidth: .infinity)
            } else if let lyrics = player.lyrics {
                Text(lyrics)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .glassEffect(in: RoundedRectangle(cornerRadius: 20))
            } else {
                Text("Keine Lyrics verfügbar")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Queue

struct QueueView<P: PlayerControlling>: View {
    @ObservedObject var player: P
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            List {
                ForEach(player.queueDisplays) { song in
                    SongRowView(song: song)
                        .opacity(song.id == player.currentQueueID ? 1 : 0.6)
                        .onTapGesture {
                            Task {
                                await player.playFromQueueID(song.id)
                                dismiss()
                            }
                        }
                }
            }
            .navigationTitle("Warteschlange")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button("Fertig") { dismiss() }
            }}
        }
    }
}

// MARK: - Sleep Timer Sheet

struct SleepTimerSheet<P: PlayerControlling>: View {
    @ObservedObject var player: P
    @Environment(\.dismiss) var dismiss
    let options = [5, 10, 15, 30, 45, 60, 90]

    var body: some View {
        NavigationStack {
            List {
                if player.sleepTimerRemaining != nil {
                    Section {
                        HStack {
                            Text("Verbleibend:").foregroundStyle(.secondary)
                            Spacer()
                            Text(player.sleepTimerLabel).bold().foregroundStyle(.pink)
                        }
                        Button("Timer abbrechen", role: .destructive) {
                            player.cancelSleepTimer(); dismiss()
                        }
                    }
                }

                Section("Timer setzen") {
                    ForEach(options, id: \.self) { minutes in
                        Button("\(minutes) Minuten") {
                            player.setSleepTimer(minutes: minutes)
                            dismiss()
                        }.foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Sleep Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button("Fertig") { dismiss() }
            }}
        }
    }
}

// MARK: - AirPlay Button

struct AirPlayButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = .secondaryLabel
        return view
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

// MARK: - Shared Subviews

struct ArtworkBackground: View {
    let song: SongDisplayData?
    var body: some View {
        Group {
            if let url = song?.artworkURL(width: 600, height: 600) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill().ignoresSafeArea().blur(radius: 60).opacity(0.6)
                } placeholder: { Color(.systemBackground).ignoresSafeArea() }
            } else { Color(.systemBackground).ignoresSafeArea() }
        }
    }
}

struct ArtworkView: View {
    let song: SongDisplayData?
    var body: some View {
        Group {
            if let url = song?.artworkURL(width: 300, height: 300) {
                AsyncImage(url: url) { image in image.resizable().scaledToFit() }
                placeholder: { RoundedRectangle(cornerRadius: 20).fill(.secondary.opacity(0.2)) }
            } else {
                RoundedRectangle(cornerRadius: 20).fill(.secondary.opacity(0.15))
                    .overlay { Image(systemName: "music.note").font(.system(size: 60)).foregroundStyle(.secondary) }
            }
        }
        .frame(width: 280, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
    }
}

struct SongInfoView: View {
    let song: SongDisplayData?
    var body: some View {
        VStack(spacing: 6) {
            Text(song?.title ?? "Kein Song").font(.title2.bold()).lineLimit(1)
            Text(song?.artistName ?? "–").font(.body).foregroundStyle(.secondary).lineLimit(1)
        }.multilineTextAlignment(.center)
    }
}

struct VolumeSliderView: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let v = MPVolumeView(); v.showsRouteButton = false; return v
    }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
