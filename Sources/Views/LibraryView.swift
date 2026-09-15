import SwiftUI
import SwiftData
import UniformTypeIdentifiers

enum LibrarySection: String, CaseIterable, Identifiable {
    case songs = "Songs", artists = "Artists", albums = "Alben", playlists = "Playlists", versions = "Versionen"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .songs: return "music.note"
        case .artists: return "person.fill"
        case .albums: return "square.stack"
        case .playlists: return "music.note.list"
        case .versions: return "opticaldisc"
        }
    }
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case recent = "Zuletzt hinzugefügt", title = "Titel", artist = "Künstler"
    var id: String { rawValue }
}

struct LibraryView: View {
    @Binding var showNowPlaying: Bool
    @EnvironmentObject private var store: EraStore
    @EnvironmentObject private var player: PlayerEngine
    @EnvironmentObject private var importer: ImportManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Song.dateAdded, order: .reverse) private var songs: [Song]
    @Query private var playlists: [Playlist]

    @State private var section: LibrarySection = .songs
    @State private var sort: LibrarySort = .recent
    @State private var showImporter = false
    @State private var showFolderImporter = false
    @State private var showSettings = false
    @State private var newPlaylistName = ""
    @State private var showNewPlaylist = false
    @State private var demoSongSheet = false

    init(showNowPlaying: Binding<Bool>) {
        _showNowPlaying = showNowPlaying
        let args = ProcessInfo.processInfo.arguments
        if args.contains("--era-settings") { _showSettings = State(initialValue: true) }
        if args.contains("--era-picker-test") { _showImporter = State(initialValue: true) }
        if args.contains("--era-playlists") { _section = State(initialValue: .playlists) }
        if args.contains("--era-song") { _demoSongSheet = State(initialValue: true) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if songs.isEmpty { emptyState } else { content }
            }
            .navigationTitle("Mediathek")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showImporter = true } label: { Label("Dateien importieren", systemImage: "doc") }
                        Button { showFolderImporter = true } label: { Label("Ordner importieren", systemImage: "folder") }
                        Divider()
                        Button { importer.showMassImport = true } label: { Label("Massenimport", systemImage: "square.and.arrow.down.on.square") }
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sortierung", selection: $sort) {
                            ForEach(LibrarySort.allCases) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $demoSongSheet) {
                if let song = songs.max(by: { $0.versions.count < $1.versions.count }) {
                    SongDetailView(song: song, showNowPlaying: $showNowPlaying)
                }
            }
            .sheet(isPresented: $showImporter) {
                DocumentPicker(contentTypes: ImportManager.importableTypes) { urls in
                    showImporter = false
                    guard !urls.isEmpty else { noFilesNotice(); return }
                    Task { await importer.importFiles(urls, into: store) }
                } onCancel: { showImporter = false }
            }
            .sheet(isPresented: $showFolderImporter) {
                DocumentPicker(contentTypes: [.folder]) { urls in
                    showFolderImporter = false
                    guard !urls.isEmpty else { noFilesNotice(); return }
                    Task { await importer.stage(urls, existing: songs) }
                } onCancel: { showFolderImporter = false }
            }
            .sheet(isPresented: $importer.showMassImport) {
                MassImportView()
            }
            .alert("Era", isPresented: Binding(get: { importer.message != nil }, set: { if !$0 { importer.message = nil } })) {
                Button("OK") { importer.message = nil }
            } message: {
                Text(importer.message ?? "")
            }
            .overlay(alignment: .bottom) {
                if importer.isImporting {
                    Label("Importiere …", systemImage: "square.and.arrow.down")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .eraGlassCapsule()
                        .padding(.bottom, 70)
                }
            }
        }
    }

    private func noFilesNotice() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            importer.message = "Keine Dateien übernommen. Liegen die Songs lokal auf dem iPhone vor (nicht nur in iCloud)?"
        }
    }

    private var content: some View {
        List {
            Section {
                Picker("Bereich", selection: $section) {
                    ForEach(LibrarySection.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            switch section {
            case .songs: songsSection
            case .artists: artistsSection
            case .albums: albumsSection
            case .playlists: playlistsSection
            case .versions: versionsSection
            }
        }
        .listStyle(.insetGrouped)
    }

    private var sortedSongs: [Song] {
        switch sort {
        case .recent: return songs
        case .title: return songs.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .artist: return songs.sorted {
            let a = $0.displayArtist.localizedStandardCompare($1.displayArtist)
            return a == .orderedSame ? $0.title.localizedStandardCompare($1.title) == .orderedAscending : a == .orderedAscending
        }
        }
    }

    private var songsSection: some View {
        Section {
            Button {
                let versions = sortedSongs.compactMap(\.primaryVersion)
                if let first = versions.first { player.play(first, from: versions) }
            } label: {
                Label("Alle abspielen (\(sortedSongs.count))", systemImage: "play.fill")
            }
            ForEach(sortedSongs) { song in
                NavigationLink {
                    SongDetailView(song: song, showNowPlaying: $showNowPlaying)
                } label: {
                    SongRow(song: song, version: nil, isCurrent: player.current?.song?.id == song.id)
                }
                .swipeActions(edge: .leading) {
                    Button { song.isFavorite.toggle(); store.save() } label: {
                        Label("Favorit", systemImage: song.isFavorite ? "heart.slash" : "heart.fill")
                    }.tint(.pink)
                }
                .swipeActions {
                    Button(role: .destructive) { store.deleteSong(song) } label: { Label("Löschen", systemImage: "trash") }
                }
                .contextMenu { SongContextMenu(song: song, showNowPlaying: $showNowPlaying) }
            }
        }
    }

    private var artistsSection: some View {
        let grouped = Dictionary(grouping: songs) { $0.displayArtist }
        let names = grouped.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return Section {
            ForEach(names, id: \.self) { name in
                NavigationLink {
                    SongListView(title: name, songs: grouped[name] ?? [], showNowPlaying: $showNowPlaying)
                } label: {
                    Label("\(name) (\(grouped[name]?.count ?? 0))", systemImage: "person.fill")
                }
            }
        }
    }

    private var albumsSection: some View {
        let grouped = Dictionary(grouping: songs) { $0.album.isEmpty ? "Unbekanntes Album" : $0.album }
        let names = grouped.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return Section {
            ForEach(names, id: \.self) { name in
                NavigationLink {
                    SongListView(title: name, songs: grouped[name] ?? [], showNowPlaying: $showNowPlaying)
                } label: {
                    Label("\(name) (\(grouped[name]?.count ?? 0))", systemImage: "square.stack")
                }
            }
        }
    }

    private var playlistsSection: some View {
        Section {
            ForEach(playlists) { playlist in
                NavigationLink {
                    PlaylistDetailView(playlist: playlist, showNowPlaying: $showNowPlaying)
                } label: {
                    Label("\(playlist.name) (\(playlist.entries.count))", systemImage: "music.note.list")
                }
            }
            Button { showNewPlaylist = true } label: { Label("Neue Playlist", systemImage: "plus") }
        }
        .alert("Neue Playlist", isPresented: $showNewPlaylist) {
            TextField("Name", text: $newPlaylistName)
            Button("Erstellen") {
                let name = newPlaylistName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { store.insertPlaylist(Playlist(name: name)) }
                newPlaylistName = ""
            }
            Button("Abbrechen", role: .cancel) { newPlaylistName = "" }
        }
    }

    private var versionsSection: some View {
        Section {
            ForEach(songs) { song in
                ForEach(song.sortedVersions) { version in
                    HStack(spacing: 12) {
                        Artwork(song: song, version: version, radius: 7).frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title).font(.body).lineLimit(1)
                            HStack(spacing: 4) {
                                Text(version.name)
                                if let year = version.year { Text(verbatim: "· \(year)") }
                            }
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text(version.durationText).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { player.play(version, from: song.sortedVersions) }
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Deine Musik. Dein iPhone.", systemImage: "waveform.circle.fill")
        } description: {
            Text("Importiere MP3, M4A, WAV, FLAC und mehr aus der Dateien-App.")
        } actions: {
            Button { showImporter = true } label: { Label("Songs importieren", systemImage: "square.and.arrow.down") }
                .eraProminentButton()
        }
    }
}

// Schlichtes Listen-Ziel fuer Artists/Alben
struct SongListView: View {
    let title: String
    let songs: [Song]
    @Binding var showNowPlaying: Bool
    @EnvironmentObject private var player: PlayerEngine

    var body: some View {
        List(songs) { song in
            NavigationLink {
                SongDetailView(song: song, showNowPlaying: $showNowPlaying)
            } label: {
                SongRow(song: song, version: nil, isCurrent: player.current?.song?.id == song.id)
            }
            .contextMenu { SongContextMenu(song: song, showNowPlaying: $showNowPlaying) }
        }
        .navigationTitle(title)
    }
}
