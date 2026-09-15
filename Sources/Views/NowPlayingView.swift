import SwiftUI

// Now Playing als Sheet (Apple-Music-Stil), kein eigener Tab (Spec 13.4).
struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var player: PlayerEngine
    @EnvironmentObject private var store: EraStore
    @State private var showQueue = false
    @State private var showTimer = false

    init() {
        if ProcessInfo.processInfo.arguments.contains("--era-queue") {
            _showQueue = State(initialValue: true)
        }
    }

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
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: song.isFavorite)
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

            HStack(spacing: 24) {
                Button { player.previous() } label: { Image(systemName: "backward.fill").font(.title2) }
                Button { player.skipBackward() } label: { Image(systemName: "gobackward.15").font(.title3) }
                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 36, weight: .bold))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 80, height: 80)
                        .eraGlassCircle()
                }
                .sensoryFeedback(.selection, trigger: player.isPlaying)
                Button { player.skipForward() } label: { Image(systemName: "goforward.15").font(.title3) }
                Button { player.next() } label: { Image(systemName: "forward.fill").font(.title2) }
            }
            .padding(.top, 16)

            HStack(spacing: 24) {
                control("shuffle", active: player.shuffle) { player.shuffle.toggle() }
                control(player.repeatMode == 2 ? "repeat.1" : "repeat", active: player.repeatMode > 0) { player.toggleRepeat() }
                Menu {
                    ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { r in
                        Button {
                            player.setRate(Float(r))
                        } label: {
                            let label = r == 1.0 ? "Normal" : "\(String(format: "%g", r))x"
                            if Float(r) == player.rate {
                                Label(label, systemImage: "checkmark")
                            } else {
                                Text(label)
                            }
                        }
                    }
                } label: {
                    Text(player.rate == 1.0 ? "1x" : "\(String(format: "%g", player.rate))x")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(player.rate == 1.0 ? .secondary : Color.accentColor)
                        .frame(width: 40, height: 40)
                }
                AirPlayRouteButton().frame(width: 40, height: 40)
                control("list.bullet", active: false) { showQueue = true }
                control("moon.zzz.fill", active: player.sleepRemaining != nil) { showTimer = true }
            }
            .padding(.top, 20)

            VolumeSlider()
                .frame(height: 28)
                .padding(.horizontal, 30)
                .padding(.top, 14)
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

    // "Als Naechstes" mit nativem Bearbeiten: Verschieben, Entfernen, Leeren.
    private var queueSheet: some View {
        NavigationStack {
            List {
                ForEach(player.queue, id: \.id) { v in
                    HStack {
                        if let song = v.song { SongRow(song: song, version: v, isCurrent: player.current?.id == v.id) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { player.play(v, from: player.queue) }
                }
                .onMove { player.moveInQueue(from: $0, to: $1) }
                .onDelete { player.removeFromQueue(at: $0) }
            }
            .navigationTitle("Als Nächstes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { showQueue = false } }
                ToolbarItem(placement: .bottomBar) {
                    if player.queue.count > 1 {
                        Button("Queue leeren", role: .destructive) { player.clearQueue() }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
