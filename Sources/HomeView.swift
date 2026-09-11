import SwiftUI

struct HomeView: View {
    @ObservedObject var store: LibraryStore
    @ObservedObject var player: PlayerEngine
    @Binding var selectedTab: Int
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    hero
                    if !store.favorites.isEmpty { shelf("Favoriten", songs: store.favorites, icon: "heart.fill") }
                    if !store.recentlyPlayed.isEmpty { shelf("Dein Sound", songs: Array(store.recentlyPlayed.prefix(8)), icon: "waveform") }
                    sourceCard
                }.padding(.vertical)
            }.navigationTitle("Era").background(Color(.systemGroupedBackground))
        }
    }
    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 30, style: .continuous).fill(LinearGradient(colors: [.black, EraTheme.accent.opacity(0.85), EraTheme.blue], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(height: 225)
            Image(systemName: "waveform.path.ecg.rectangle.fill").font(.system(size: 120)).foregroundStyle(.white.opacity(0.10)).offset(x: 190, y: -25).symbolEffect(.variableColor.iterative, isActive: player.isPlaying)
            VStack(alignment: .leading, spacing: 8) { Text("100 % OFFLINE").font(.caption.bold()).tracking(2).foregroundStyle(.white.opacity(0.7)); Text("Deine Musik.\nOhne Limits.").font(.system(size: 35, weight: .black, design: .rounded)); Text("\(store.songs.count) Songs direkt auf diesem iPhone").font(.subheadline).foregroundStyle(.white.opacity(0.75)); Button { selectedTab = 1 } label: { Label(store.songs.isEmpty ? "Musik importieren" : "Mediathek öffnen", systemImage: "arrow.down.doc.fill") }.buttonStyle(.borderedProminent).tint(.white).foregroundStyle(.black).padding(.top, 5) }.padding(24).foregroundStyle(.white)
        }.padding(.horizontal)
    }
    private func shelf(_ title: String, songs: [LocalSong], icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) { Label(title, systemImage: icon).font(.title2.bold()).padding(.horizontal); ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 15) { ForEach(songs) { song in VStack(alignment: .leading, spacing: 7) { Artwork(song: song).frame(width: 150, height: 150); Text(song.title).font(.subheadline.bold()).lineLimit(1); Text(song.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1) }.frame(width:150, alignment:.leading).onTapGesture { player.play(song, from: songs) } } }.padding(.horizontal) } }
    }
    private var sourceCard: some View { VStack(alignment: .leading, spacing: 13) { Label("Bereit für später", systemImage: "apple.logo").font(.headline); Text("Apple Music ist als nächste Quelle vorgesehen. Deine lokale Bibliothek und der Player bleiben davon unabhängig.").font(.subheadline).foregroundStyle(.secondary); HStack { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green); Text("Lokale Musik aktiv"); Spacer(); Text("Apple Music").foregroundStyle(.tertiary); Image(systemName: "lock.fill").foregroundStyle(.tertiary) } }.padding(18).background(.background, in: RoundedRectangle(cornerRadius: 22)).padding(.horizontal) }
}
