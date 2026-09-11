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
        .modifier(BottomAccessoryModifier(enabled: player.currentSong != nil && tab != 2, player: player, open: { tab = 2 }))
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("--era-player"), player.currentSong == nil, let first = store.songs.first {
                player.play(first, from: store.songs)
            }
        }
    }
}

// Mini-Player als native Bottom-Accessory-Leiste (iOS 26.1+), darunter als Glass-Overlay
private struct BottomAccessoryModifier: ViewModifier {
    let enabled: Bool
    let player: PlayerEngine
    let open: () -> Void

    func body(content: Content) -> some View {
        if #available(iOS 26.1, *) {
            content.tabViewBottomAccessory(isEnabled: enabled) {
                MiniPlayer(player: player, open: open)
            }
        } else {
            content.overlay(alignment: .bottom) {
                if enabled {
                    MiniPlayer(player: player, open: open)
                        .padding(.vertical, 4)
                        .glassEffect(.regular, in: .rect(cornerRadius: 24))
                        .padding(.horizontal, 12)
                        .padding(.bottom, 58)
                }
            }
        }
    }
}
