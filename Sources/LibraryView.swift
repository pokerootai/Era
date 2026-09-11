import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject var store: LibraryStore
    @ObservedObject var player: PlayerEngine
    @State private var importer = false

    private var importableTypes: [UTType] {
        var types: [UTType] = [.audio, .mp3, .mpeg4Audio, .wav, .aiff, .appleProtectedMPEG4Audio]
        for raw in ["public.flac-audio", "org.xiph.flac", "com.apple.coreaudio-format", "public.aifc-audio"] {
            if let t = UTType(raw) { types.append(t) }
        }
        return types
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.songs.isEmpty { emptyState }
                else { songList }
            }
            .navigationTitle("Mediathek")
            .searchable(text: $store.searchText, prompt: "Titel, Künstler oder Album")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu { Picker("Sortierung", selection: $store.sort) { ForEach(LibrarySort.allCases) { Text($0.rawValue).tag($0) } } } label: { Image(systemName: "arrow.up.arrow.down") }
                    Button { importer = true } label: { Image(systemName: "square.and.arrow.down") }.symbolEffect(.bounce, value: store.songs.count)
                }
            }
            .fileImporter(isPresented: $importer, allowedContentTypes: importableTypes, allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    Task {
                        try? await Task.sleep(nanoseconds: 400_000_000)
                        await store.importFiles(urls)
                    }
                case .failure(let error):
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        store.importMessage = "Dateien konnten nicht geöffnet werden: \(error.localizedDescription)"
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if store.isImporting {
                    Label("Importiere …", systemImage: "square.and.arrow.down")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.bottom, 24)
                }
            }
            .alert("Era", isPresented: Binding(get: { store.importMessage != nil }, set: { if !$0 { store.importMessage = nil } })) { Button("OK") { store.importMessage = nil } } message: { Text(store.importMessage ?? "") }
        }
    }

    private var songList: some View {
        List {
            Section {
                HStack { Label("\(store.songs.count) Songs", systemImage: "music.note.list"); Spacer(); Text(formatDuration(store.totalDuration)).foregroundStyle(.secondary) }
                Button { if let first = store.filteredSongs.first { player.play(first, from: store.filteredSongs) } } label: { Label("Alle abspielen", systemImage: "play.fill") }
                    .foregroundStyle(EraTheme.accent)
            }
            Section(store.sort.rawValue) {
                ForEach(store.filteredSongs) { song in
                    SongRow(song: song, isCurrent: player.currentSong?.id == song.id)
                        .onTapGesture { player.play(song, from: store.filteredSongs) }
                        .swipeActions(edge: .leading) { Button { store.toggleFavorite(song.id) } label: { Label("Favorit", systemImage: song.isFavorite ? "heart.slash" : "heart.fill") }.tint(.pink) }
                        .swipeActions { Button(role: .destructive) { store.delete(song) } label: { Label("Löschen", systemImage: "trash") } }
                }
            }
        }.listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        ContentUnavailableView { Label("Deine Musik. Dein iPhone.", systemImage: "waveform.circle.fill") } description: { Text("Importiere MP3, M4A, WAV, FLAC und mehr aus der Dateien-App.") } actions: { Button { importer = true } label: { Label("Songs importieren", systemImage: "square.and.arrow.down") }.buttonStyle(.glassProminent) }
    }
    private func formatDuration(_ value: Double) -> String { let h = Int(value)/3600; let m=(Int(value)%3600)/60; return h > 0 ? "\(h) Std. \(m) Min." : "\(m) Min." }
}
