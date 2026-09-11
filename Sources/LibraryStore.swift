import Foundation
import AVFoundation
import UniformTypeIdentifiers

@MainActor
final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()
    @Published private(set) var songs: [LocalSong] = []
    @Published var importMessage: String?
    @Published var sort: LibrarySort = .recent
    @Published var searchText = ""

    private let fm = FileManager.default
    private var libraryURL: URL { fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("EraLibrary", isDirectory: true) }
    private var indexURL: URL { libraryURL.appendingPathComponent("library.json") }

    init() {
        try? fm.createDirectory(at: libraryURL, withIntermediateDirectories: true)
        load()
        #if targetEnvironment(simulator)
        if songs.isEmpty && ProcessInfo.processInfo.arguments.contains("--era-demo") { seedDemo() }
        #endif
    }

    var filteredSongs: [LocalSong] {
        let filtered = searchText.isEmpty ? songs : songs.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) || $0.artist.localizedCaseInsensitiveContains(searchText) || $0.album.localizedCaseInsensitiveContains(searchText)
        }
        switch sort {
        case .recent: return filtered.sorted { $0.dateAdded > $1.dateAdded }
        case .title: return filtered.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .artist: return filtered.sorted { $0.artist.localizedStandardCompare($1.artist) == .orderedAscending }
        case .played: return filtered.sorted { $0.playCount > $1.playCount }
        }
    }

    var favorites: [LocalSong] { songs.filter(\.isFavorite) }
    var recentlyPlayed: [LocalSong] { songs.filter { $0.playCount > 0 }.sorted { $0.playCount > $1.playCount } }
    var totalDuration: Double { songs.reduce(0) { $0 + $1.duration } }

    func fileURL(for song: LocalSong) -> URL { libraryURL.appendingPathComponent(song.fileName) }

    func importFiles(_ urls: [URL]) async {
        var imported = 0
        for source in urls {
            let access = source.startAccessingSecurityScopedResource()
            defer { if access { source.stopAccessingSecurityScopedResource() } }
            do {
                let ext = source.pathExtension.lowercased()
                guard ["mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac"].contains(ext) else { continue }
                let id = UUID()
                let destination = libraryURL.appendingPathComponent("\(id.uuidString).\(ext)")
                try fm.copyItem(at: source, to: destination)
                let asset = AVURLAsset(url: destination)
                let duration = (try? await asset.load(.duration).seconds) ?? 0
                let metadata = (try? await asset.load(.commonMetadata)) ?? []
                let title = await metadataValue(.commonIdentifierTitle, in: metadata) ?? source.deletingPathExtension().lastPathComponent
                let artist = await metadataValue(.commonIdentifierArtist, in: metadata) ?? "Unbekannter Künstler"
                let album = await metadataValue(.commonIdentifierAlbumName, in: metadata) ?? "Ohne Album"
                songs.insert(LocalSong(id: id, title: title, artist: artist, album: album, fileName: destination.lastPathComponent, duration: duration.isFinite ? duration : 0, dateAdded: Date(), playCount: 0, isFavorite: false), at: 0)
                imported += 1
            } catch { importMessage = "Ein Song konnte nicht importiert werden." }
        }
        save()
        importMessage = imported == 1 ? "1 Song importiert" : "\(imported) Songs importiert"
    }

    private func metadataValue(_ identifier: AVMetadataIdentifier, in items: [AVMetadataItem]) async -> String? {
        guard let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier).first else { return nil }
        return try? await item.load(.stringValue)
    }

    func toggleFavorite(_ id: UUID) {
        guard let i = songs.firstIndex(where: { $0.id == id }) else { return }
        songs[i].isFavorite.toggle(); save()
    }

    func markPlayed(_ id: UUID) {
        guard let i = songs.firstIndex(where: { $0.id == id }) else { return }
        songs[i].playCount += 1; save()
    }

    func delete(_ song: LocalSong) {
        try? fm.removeItem(at: fileURL(for: song)); songs.removeAll { $0.id == song.id }; save()
    }

    private func load() { if let d = try? Data(contentsOf: indexURL), let decoded = try? JSONDecoder().decode([LocalSong].self, from: d) { songs = decoded } }
    private func save() { if let d = try? JSONEncoder().encode(songs) { try? d.write(to: indexURL, options: .atomic) } }

    private func seedDemo() {
        let names = [("Afterglow", "MALT3", "Proof"), ("Neon Hearts", "MALT3", "Proof"), ("Late Shift", "MALT3", "Night Drive"), ("Blue Hour", "MALT3", "Night Drive"), ("No Signal", "MALT3", "Offline")]
        songs = names.enumerated().map { i, v in LocalSong(id: UUID(), title: v.0, artist: v.1, album: v.2, fileName: "demo-\(i).m4a", duration: Double(178 + i * 21), dateAdded: Date().addingTimeInterval(Double(-i * 7200)), playCount: max(0, 8-i*2), isFavorite: i < 2) }
    }
}
