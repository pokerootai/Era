import SwiftUI
import AVKit

struct Artwork: View {
    let song: LocalSong?
    var radius: CGFloat = 16
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous).fill(EraTheme.gradient)
            Circle().stroke(.white.opacity(0.22), lineWidth: 2).padding(20)
            Circle().fill(.black.opacity(0.72)).padding(32)
            Image(systemName: "waveform").font(.system(size: 29, weight: .bold)).foregroundStyle(.white)
        }.shadow(color: EraTheme.accent.opacity(0.25), radius: 20, y: 10)
    }
}

struct SongRow: View {
    let song: LocalSong
    let isCurrent: Bool
    var body: some View {
        HStack(spacing: 13) {
            Artwork(song: song, radius: 10).frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 3) {
                Text(song.title).font(.body.weight(.semibold)).lineLimit(1)
                Text("\(song.subtitle) · \(song.album)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if isCurrent { Image(systemName: "waveform").foregroundStyle(EraTheme.accent).symbolEffect(.variableColor.iterative, isActive: true) }
            else { Text(song.durationText).font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
        }.contentShape(Rectangle())
    }
}

struct MiniPlayer: View {
    @ObservedObject var player: PlayerEngine
    let open: () -> Void
    var body: some View {
        if let song = player.currentSong {
            HStack(spacing: 12) {
                Artwork(song: song, radius: 8).frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(song.title).font(.subheadline.bold()).lineLimit(1)
                    Text(song.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace)).font(.title3)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                Button { player.next() } label: {
                    Image(systemName: "forward.fill").font(.title3)
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
            .onTapGesture(perform: open)
        }
    }
}

struct AirPlayRouteButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView { let v = AVRoutePickerView(); v.tintColor = .secondaryLabel; return v }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}
