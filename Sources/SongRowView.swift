import SwiftUI

struct SongRowView: View {
    let song: SongDisplayData
    var showsPlayIcon: Bool = true

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: song.artworkURL(width: 50, height: 50)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 6).fill(.secondary.opacity(0.2))
            }
            .frame(width: 50, height: 50).clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title).font(.body).lineLimit(1)
                Text(song.artistName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if showsPlayIcon {
                Image(systemName: "play.fill").foregroundStyle(.secondary).font(.caption)
            }
        }.padding(.vertical, 4)
    }
}
