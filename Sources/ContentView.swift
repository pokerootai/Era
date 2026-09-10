import SwiftUI
import MusicKit

struct ContentView: View {
    @StateObject private var player = MusicPlayerManager()
    @State private var authStatus: MusicAuthorization.Status = .notDetermined
    @State private var selectedTab: Tab = .home

    enum Tab { case home, search, library, nowPlaying }

    var body: some View {
        #if targetEnvironment(simulator)
        if let demoMode = DemoMode.from(ProcessInfo.processInfo.arguments) {
            DemoRootView(mode: demoMode)
        } else {
            mainContent
        }
        #else
        mainContent
        #endif
    }

    private var mainContent: some View {
        Group {
            if authStatus == .authorized {
                ZStack(alignment: .bottom) {
                    TabView(selection: $selectedTab) {
                        HomeView(player: player)
                            .tabItem { Label("Home", systemImage: "house.fill") }
                            .tag(Tab.home)

                        SearchView(player: player)
                            .tabItem { Label("Suche", systemImage: "magnifyingglass") }
                            .tag(Tab.search)

                        LibraryView(player: player)
                            .tabItem { Label("Mediathek", systemImage: "music.note.list") }
                            .tag(Tab.library)

                        NowPlayingView(player: player)
                            .tabItem { Label("Läuft", systemImage: "music.note") }
                            .tag(Tab.nowPlaying)
                    }

                    if player.currentSong != nil && selectedTab != .nowPlaying {
                        MiniPlayerView(player: player) { selectedTab = .nowPlaying }
                            .padding(.bottom, 60)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(), value: player.currentSong != nil)
                    }
                }
            } else {
                AuthorizationView(authStatus: $authStatus)
            }
        }
        .task { authStatus = await MusicAuthorization.request() }
    }
}
