import SwiftUI

struct ContentView: View {
    @StateObject private var store = LibraryStore.shared
    @StateObject private var player = PlayerEngine.shared
    @State private var tab = ProcessInfo.processInfo.arguments.contains("--era-library") ? 1 : (ProcessInfo.processInfo.arguments.contains("--era-player") ? 2 : 0)
    var body: some View {
        ZStack(alignment:.bottom) {
            TabView(selection:$tab) {
                HomeView(store:store,player:player,selectedTab:$tab).tabItem{Label("Home",systemImage:"house.fill")}.tag(0)
                LibraryView(store:store,player:player).tabItem{Label("Mediathek",systemImage:"music.note.list")}.tag(1)
                NowPlayingView(player:player,store:store).tabItem{Label("Player",systemImage:"play.circle.fill")}.tag(2)
                SettingsView().tabItem{Label("Mehr",systemImage:"ellipsis.circle.fill")}.tag(3)
            }.tint(EraTheme.accent)
            if player.currentSong != nil && tab != 2 { MiniPlayer(player:player){tab=2}.padding(.bottom,50) }
        }
    }
}
