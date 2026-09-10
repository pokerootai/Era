import SwiftUI

struct MiniPlayerView<P: PlayerControlling>: View {
    @ObservedObject var player: P
    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: player.currentDisplay?.artworkURL(width: 44, height: 44)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 6).fill(.secondary.opacity(0.2))
            }
            .frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(player.currentDisplay?.title ?? "").font(.subheadline.weight(.medium)).lineLimit(1)
                Text(player.currentDisplay?.artistName ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()

            Button { Task { try? await player.togglePlayPause() } } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.title3)
            }
            Button { Task { try? await player.skipToNext() } } label: {
                Image(systemName: "forward.fill").font(.title3)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
        .onTapGesture { onTap() }
    }
}
