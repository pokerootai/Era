import SwiftUI

// Now Playing als Sheet (Apple-Music-Stil), kein eigener Tab (Spec 13.4).
struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var player: PlayerEngine
    @EnvironmentObject private var store: EraStore
    @State private var showQueue = false
    @State private var showTimer = false

    var body: some View {
        NavigationStack {
            Group {
                if let version = player.current, let song = version.song {
                    content(version, song)
                } else {
                    ContentUnavailableView("Nichts läuft", systemImage: "play.circle", description: Text("Wähle einen Song aus deiner Mediathek"))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.down") }
                }
            }
            .sheet(isPresented: $showQueue) { queueSheet }
            .sheet(isPresented: $showTimer) { timerSheet }
        }
    }

    private func content(_ version: SongVersion, _ song: Song) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Artwork(song: song, version: version, radius: 12)
                .frame(maxWidth: 300)
                .padding(.horizontal, 30)
                .scaleEffect(player.isPlaying ? 1 : 0.9)
                .animation(.spring(response: 0.45), value: player.isPlaying)
                .shadow(radius: 18, y: 8)

            VStack(spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(version.displayTitle).font(.title3.bold()).lineLimit(1)
                        Text(version.displayArtist).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button { song.isFavorite.toggle(); store.save() } label: {
                        Image(systemName: song.isFavorite ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundStyle(song.isFavorite ? .pink : .primary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    Menu {
                        ForEach(song.sortedVersions) { v in
                            Button {
                                let wasQueue = player.queue
                                player.play(v, from: wasQueue)
                            } label: {
                                Label(v.name, systemImage: v.id == version.id ? "checkmark" : "opticaldisc")
                            }
                            .disabled(v.id == version.id)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle").font(.title3)
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 22)

            VStack(spacing: 6) {
                Slider(value: Binding(get: { player.currentTime }, set: { player.seek($0) }), in: 0...max(1, player.duration))
                HStack {
                    Text(TimeFormatting.mmss(player.currentTime))
                    Spacer()
                    Text("-" + TimeFormatting.mmss(max(0, player.duration - player.currentTime)))
                }
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 30)
            .padding(.top, 8)

            HStack(spacing: 56) {
                Button { player.previous() } label: { Image(systemName: "backward.fill").font(.title) }
                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 40, weight: .bold))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 88, height: 88)
                        .eraGlassCircle()
                }
                Button { player.next() } label: { Image(systemName: "forward.fill").font(.title) }
            }
            .padding(.top, 18)

            HStack(spacing: 30) {
                control("shuffle", active: player.shuffle) { player.shuffle.toggle() }
                control(player.repeatMode == 2 ? "repeat.1" : "repeat", active: player.repeatMode > 0) { player.toggleRepeat() }
                AirPlayRouteButton().frame(width: 40, height: 40)
                control("list.bullet", active: false) { showQueue = true }
                control("moon.zzz.fill", active: player.sleepRemaining != nil) { showTimer = true }
            }
            .padding(.top, 24)
            Spacer(minLength: 0)
        }
    }

    private func control(_ icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(active ? Color.accentColor : .secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 40, height: 40)
        }
    }

    private var queueSheet: some View {
        NavigationStack {
            List(player.queue, id: \.id) { v in
                HStack {
                    if let song = v.song { SongRow(song: song, version: v, isCurrent: player.current?.id == v.id) }
                }
                .contentShape(Rectangle())
                .onTapGesture { player.play(v, from: player.queue) }
            }
            .navigationTitle("Als Nächstes")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { showQueue = false } } }
        }
    }

    private var timerSheet: some View {
        NavigationStack {
            List {
                if let r = player.sleepRemaining {
                    Section {
                        Text("Noch \(r / 60):\(String(format: "%02d", r % 60))").font(.title.bold())
                        Button("Timer stoppen", role: .destructive) { player.cancelSleep(); showTimer = false }
                    }
                }
                Section("Wiedergabe stoppen nach") {
                    ForEach([5, 10, 15, 30, 45, 60], id: \.self) { m in
                        Button("\(m) Minuten") { player.setSleep(minutes: m); showTimer = false }
                    }
                }
            }
            .navigationTitle("Sleep Timer")
        }
        .presentationDetents([.medium])
    }
}
