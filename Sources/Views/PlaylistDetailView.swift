import SwiftUI
import SwiftData

// Playlist mit Song+Version-Referenz, kombinierbaren Tag-Filtern und
// Versions-Auswahl pro Eintrag (Spec 5 + 6).
struct PlaylistDetailView: View {
    let playlist: Playlist
    @Binding var showNowPlaying: Bool
    @EnvironmentObject private var player: PlayerEngine
    @EnvironmentObject private var store: EraStore
    @Query private var songs: [Song]
    @Query private var tags: [Tag]
    @State private var showAddSongs = false

    private var filteredEntries: [PlaylistEntry] {
        let active = playlist.filterTagIDs
        guard !active.isEmpty else { return playlist.sortedEntries }
        return playlist.sortedEntries.filter { entry in
            guard let song = entry.song else { return false }
            // Kombinierbar: UND ueber alle aktiven Filter (Spec 6)
            return active.allSatisfy { id in song.tags.contains { $0.id == id } }
        }
    }

    private var usedTags: [Tag] {
        let ids = Set(playlist.sortedEntries.compactMap { $0.song }.flatMap { $0.tags.map(\.id) })
        return tags.filter { ids.contains($0.id) }.sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            if !usedTags.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterChip(nil, label: "Alle")
                            ForEach(usedTags) { tag in filterChip(tag.id, label: tag.name) }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }

            Section {
                ForEach(filteredEntries) { entry in
                    if let song = entry.song {
                        PlaylistEntryRow(playlist: playlist, entry: entry, song: song)
                    }
                }
                .onDelete { offsets in
                    for index in offsets { store.removeEntry(filteredEntries[index], from: playlist) }
                }
                .onMove { source, destination in
                    var entries = playlist.sortedEntries
                    entries.move(fromOffsets: source, toOffset: destination)
                    for (i, entry) in entries.enumerated() { entry.position = i }
                    store.save()
                }
            }

            Section {
                Button { showAddSongs = true } label: { Label("Songs hinzufügen", systemImage: "plus") }
            }
        }
        .navigationTitle(playlist.name)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { EditButton() } }
        .sheet(isPresented: $showAddSongs) { AddToPlaylistSheet(playlist: playlist) }
    }

    private func filterChip(_ tagID: UUID?, label: String) -> some View {
        let isActive = tagID == nil ? playlist.filterTagIDs.isEmpty : playlist.filterTagIDs.contains(tagID!)
        return Button {
            if let tagID {
                if playlist.filterTagIDs.contains(tagID) {
                    playlist.filterTagIDs.removeAll { $0 == tagID }
                } else {
                    playlist.filterTagIDs.append(tagID)
                }
                store.save()
            } else {
                playlist.filterTagIDs = []
                store.save()
            }
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isActive ? Color.accentColor : Color(.tertiarySystemFill), in: .capsule)
                .foregroundStyle(isActive ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct PlaylistEntryRow: View {
    let playlist: Playlist
    let entry: PlaylistEntry
    let song: Song
    @EnvironmentObject private var player: PlayerEngine
    @EnvironmentObject private var store: EraStore
    @State private var showDrawer = false

    private var version: SongVersion? { entry.resolvedVersion }

    var body: some View {
        HStack {
            SongRow(song: song, version: version, isCurrent: player.current?.id == version?.id)
                .onTapGesture {
                    if let v = version {
                        let queue = playlist.sortedEntries.compactMap { $0.resolvedVersion }
                        player.play(v, from: queue)
                    }
                }
            Menu {
                Button {
                    if let v = version { player.playNext(v) }
                } label: { Label("Als Nächstes abspielen", systemImage: "text.line.first.and.arrowtriangle.forward") }

                // Versionen verschachtelt (Spec 5): vorhandene Versionen,
                // in dieser Playlist vorhandene deaktiviert mit Grund im Label.
                Menu {
                    Button { showDrawer = true } label: { Label("Hinzufügen", systemImage: "plus") }
                    Divider()
                    ForEach(song.sortedVersions.prefix(6)) { v in
                        let inPlaylist = playlist.entries.contains { $0.versionID == v.id }
                        let isThis = entry.versionID == v.id || (entry.versionID == nil && v.id == song.primaryVersion?.id)
                        if inPlaylist && !isThis {
                            Label("\(v.name) – schon in dieser Playlist", systemImage: "checkmark.circle")
                                .disabled(true)
                        } else {
                            Button {
                                entry.versionID = v.id
                                store.save()
                            } label: {
                                Label(v.name, systemImage: isThis ? "checkmark" : "opticaldisc")
                            }
                            .disabled(isThis)
                        }
                    }
                    if song.versions.count > 6 {
                        NavigationLink("Alle anzeigen") {
                            List(song.sortedVersions) { v in
                                Button(v.name) { entry.versionID = v.id; store.save() }
                            }
                            .navigationTitle("Versionen")
                        }
                    }
                } label: { Label("Versionen", systemImage: "square.stack") }

                Divider()
                Button(role: .destructive) {
                    store.removeEntry(entry, from: playlist)
                } label: { Label("Entfernen", systemImage: "minus.circle") }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
        }
        .sheet(isPresented: $showDrawer) { VersionDrawer(song: song) }
    }
}

struct AddToPlaylistSheet: View {
    let playlist: Playlist
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: EraStore
    @Query(sort: \Song.title) private var songs: [Song]
    @State private var search = ""

    private var filtered: [Song] {
        search.isEmpty ? songs : songs.filter {
            $0.title.localizedCaseInsensitiveContains(search) || $0.artist.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { song in
                Button {
                    // Aus der Library landet die primaere Version in der Playlist (Spec 5)
                    store.appendEntry(song: song, version: song.primaryVersion, to: playlist)
                } label: {
                    HStack {
                        SongRow(song: song, version: nil)
                        Spacer()
                        Image(systemName: "plus.circle").foregroundStyle(Color.accentColor)
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $search, prompt: "Song suchen")
            .navigationTitle("Hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Fertig") { dismiss() } } }
        }
    }
}
