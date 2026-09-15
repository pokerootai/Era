import SwiftUI
import AVKit
import MediaPlayer
import UIKit

// Artwork: eingebettetes Cover der Version, sonst generierte Disc (Spec 8.1).
struct Artwork: View {
    let song: Song?
    var version: SongVersion?
    var radius: CGFloat = 10

    var body: some View {
        let v = version ?? song?.primaryVersion
        if let file = v?.artworkFile,
           let data = try? Data(contentsOf: LibraryFiles.artworkURL(file)),
           let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        } else if let song {
            DiscArtwork(songID: song.id, statusName: song.statusTags.first?.name, radius: radius)
        } else {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(Color(.secondarySystemFill))
        }
    }
}

struct SongRow: View {
    let song: Song
    let version: SongVersion?
    var isCurrent: Bool = false

    var body: some View {
        let v = version ?? song.primaryVersion
        HStack(spacing: 12) {
            Artwork(song: song, version: v, radius: 8).frame(width: 50, height: 50)
            VStack(alignment: .leading, spacing: 2) {
                Text((v?.displayTitle.isEmpty == false ? v?.displayTitle : nil) ?? song.title)
                    .font(.body).lineLimit(1)
                HStack(spacing: 4) {
                    if let v, song.versions.count > 1 {
                        Text(v.name)
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color(.tertiarySystemFill), in: .capsule)
                    }
                    Text(song.displayArtist)
                    if !song.album.isEmpty { Text("· \(song.album)") }
                }
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if isCurrent {
                Image(systemName: "waveform")
                    .foregroundStyle(.tint)
                    .symbolEffect(.variableColor.iterative, isActive: true)
            } else {
                Text(v?.durationText ?? "").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }
}

struct MiniPlayer: View {
    @EnvironmentObject private var player: PlayerEngine
    let open: () -> Void

    var body: some View {
        if let version = player.current, let song = version.song {
            HStack(spacing: 10) {
                Artwork(song: song, version: version, radius: 7).frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(version.displayTitle).font(.subheadline).lineLimit(1)
                    Text(version.displayArtist).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 40, height: 40).contentShape(Rectangle())
                }
                Button { player.next() } label: {
                    Image(systemName: "forward.fill")
                        .font(.body)
                        .frame(width: 36, height: 40).contentShape(Rectangle())
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .eraGlassRect(18)
            .contentShape(Rectangle())
            .onTapGesture(perform: open)
        }
    }
}

struct AirPlayRouteButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = .secondaryLabel
        return view
    }
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {}
}

// Nativer Lautstaerke-Slider (MediaPlayer.MPVolumeView, wie in Apple Music).
struct VolumeSlider: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let view = MPVolumeView()
        view.showsRouteButton = false
        return view
    }
    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}

// Natives iOS-Share-Sheet fuer Audiodateien (UIActivityViewController).
struct ShareItem: Identifiable {
    let url: URL
    var id: URL { url }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
