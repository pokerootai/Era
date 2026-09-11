import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var player: PlayerEngine
    @ObservedObject var store: LibraryStore
    @State private var showQueue = false
    @State private var showTimer = false
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [EraTheme.accent.opacity(0.28), EraTheme.blue.opacity(0.12), Color(.systemBackground)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                if let song = player.currentSong { content(song) } else { ContentUnavailableView("Nichts läuft", systemImage: "play.circle", description: Text("Wähle einen Song aus deiner Mediathek")) }
            }.navigationTitle("Läuft jetzt").navigationBarTitleDisplayMode(.inline).sheet(isPresented: $showQueue) { queueSheet }.sheet(isPresented: $showTimer) { timerSheet }
        }
    }
    private func content(_ song: LocalSong) -> some View {
        ScrollView { VStack(spacing: 24) {
            Artwork(song: song, radius: 28).frame(maxWidth: 355).aspectRatio(1, contentMode: .fit).padding(.horizontal, 26).padding(.top, 8).scaleEffect(player.isPlaying ? 1 : 0.91).animation(.spring(response: 0.45), value: player.isPlaying)
            HStack { VStack(alignment: .leading, spacing: 5) { Text(song.title).font(.title2.bold()).lineLimit(1); Text(song.subtitle).foregroundStyle(.secondary) }; Spacer(); Button { store.toggleFavorite(song.id) } label: { Image(systemName: song.isFavorite ? "heart.fill" : "heart").font(.title2).foregroundStyle(song.isFavorite ? .pink : .primary).contentTransition(.symbolEffect(.replace)) } }.padding(.horizontal, 28)
            VStack(spacing: 7) { Slider(value: Binding(get:{player.currentTime},set:{player.seek($0)}), in: 0...max(1,player.duration)).tint(.primary); HStack { Text(time(player.currentTime)); Spacer(); Text("-"+time(max(0,player.duration-player.currentTime))) }.font(.caption.monospacedDigit()).foregroundStyle(.secondary) }.padding(.horizontal, 28)
            HStack(spacing: 46) { Button { player.previous() } label:{Image(systemName:"backward.fill").font(.title)}; Button { player.toggle() } label:{Image(systemName:player.isPlaying ? "pause.circle.fill":"play.circle.fill").font(.system(size:72)).contentTransition(.symbolEffect(.replace))}; Button { player.next() } label:{Image(systemName:"forward.fill").font(.title)} }
            HStack(spacing: 30) { control("shuffle", active: player.shuffle) { player.shuffle.toggle() }; control(player.repeatMode == 2 ? "repeat.1":"repeat", active: player.repeatMode > 0) { player.toggleRepeat() }; AirPlayRouteButton().frame(width:44,height:44); control("list.bullet", active:false) { showQueue=true }; control("moon.fill", active:player.sleepRemaining != nil) { showTimer=true } }.padding(.vertical, 13).padding(.horizontal, 22).background(.ultraThinMaterial, in: Capsule())
        }.padding(.bottom, 30) }
    }
    private func control(_ icon:String, active:Bool, action:@escaping()->Void)->some View { Button(action:action){Image(systemName:icon).font(.title3).foregroundStyle(active ? EraTheme.accent : .primary).contentTransition(.symbolEffect(.replace))} }
    private func time(_ d:Double)->String { String(format:"%d:%02d",Int(d)/60,Int(d)%60) }
    private var queueSheet: some View { NavigationStack { List(player.queue) { s in SongRow(song:s,isCurrent:player.currentSong?.id==s.id).onTapGesture{player.play(s,from:player.queue)} }.navigationTitle("Als Nächstes").toolbar{ToolbarItem(placement:.topBarTrailing){Button("Fertig"){showQueue=false}}} } }
    private var timerSheet: some View { NavigationStack { List { if let r=player.sleepRemaining { Section { Text("Noch \(r/60):\(String(format:"%02d",r%60))").font(.title.bold()); Button("Timer stoppen",role:.destructive){player.cancelSleep();showTimer=false} } }; Section("Wiedergabe stoppen nach") { ForEach([5,10,15,30,45,60],id:\.self){m in Button("\(m) Minuten"){player.setSleep(minutes:m);showTimer=false} } } }.navigationTitle("Sleep Timer") } }
}
