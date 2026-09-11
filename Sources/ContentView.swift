import SwiftUI

struct ContentView: View {
    @StateObject private var store = LibraryStore.shared
    @StateObject private var player = PlayerEngine.shared
    @State private var tab: Int = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--era-library") { return 1 }
        if args.contains("--era-player") { return 2 }
        if args.contains("--era-settings") { return 3 }
        return 0
    }()

    var body: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                HomeView(store: store, player: player, selectedTab: $tab)
            }
            Tab("Mediathek", systemImage: "music.note.list", value: 1) {
                LibraryView(store: store, player: player)
            }
            Tab("Player", systemImage: "play.circle.fill", value: 2) {
                NowPlayingView(player: player, store: store)
            }
            Tab("Einstellungen", systemImage: "gearshape.fill", value: 3) {
                SettingsView(store: store)
            }
        }
        .tint(EraTheme.accent)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: player.currentSong != nil && tab != 2) {
            MiniPlayer(player: player) { tab = 2 }
        }
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("--era-player"), player.currentSong == nil, let first = store.songs.first {
                player.play(first, from: store.songs)
            }
        }
    }
}
