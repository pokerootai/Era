import Foundation
import AVFoundation
import UniformTypeIdentifiers

private struct ImportOutcome: Sendable {
    let song: LocalSong?
    let name: String
    let error: String?
}

@MainActor
final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()
    @Published private(set) var songs: [LocalSong] = []
    @Published var importMessage: String?
    @Published var isImporting = false
    @Published var sort: LibrarySort = .recent
    @Published var searchText = ""

    static let supportedExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac"]

    private let fm = FileManager.default
    private var libraryURL: URL { fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("EraLibrary", isDirectory: true) }
    private var indexURL: URL { libraryURL.appendingPathComponent("library.json") }

    init() {
        try? fm.createDirectory(at: libraryURL, withIntermediateDirectories: true)
        load()
        #if targetEnvironment(simulator)
        let args = ProcessInfo.processInfo.arguments
        if songs.isEmpty && args.contains("--era-demo") { seedDemo() }
        if args.contains("--era-import-test") {
            let testDir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("ImportTest", isDirectory: true)
            if let files = try? fm.contentsOfDirectory(at: testDir, includingPropertiesForKeys: nil) {
                let sorted = files.sorted { $0.lastPathComponent < $1.lastPathComponent }
                Task { await importFiles(sorted) }
            }
        }
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

    var librarySizeText: String {
        let files = (try? fm.contentsOfDirectory(at: libraryURL, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        let total = files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        if total == 0 { return "0 KB" }
        return ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }

    func fileURL(for song: LocalSong) -> URL { libraryURL.appendingPathComponent(song.fileName) }

    func importFiles(_ urls: [URL]) async {
        isImporting = true
        let lib = libraryURL
        let supported = Self.supportedExtensions
        let outcomes: [ImportOutcome] = await Task.detached(priority: .userInitiated) { () -> [ImportOutcome] in
            var results: [ImportOutcome] = []
            for source in urls {
                let name = source.lastPathComponent
                let ext = source.pathExtension.lowercased()
                guard supported.contains(ext) else {
                    results.append(ImportOutcome(song: nil, name: name, error: "Format nicht unterstützt"))
                    continue
                }
                let access = source.startAccessingSecurityScopedResource()
                do {
                    // Data(contentsOf:) lädt auch nicht heruntergeladene iCloud-Dateien zuverlässig nach
                    let data = try Data(contentsOf: source)
                    if access { source.stopAccessingSecurityScopedResource() }
                    let id = UUID()
                    let destination = lib.appendingPathComponent("\(id.uuidString).\(ext)")
                    try data.write(to: destination, options: .atomic)
                    let asset = AVURLAsset(url: destination)
                    let duration = (try? await asset.load(.duration).seconds) ?? 0
                    let metadata = (try? await asset.load(.commonMetadata)) ?? []
                    let title = await Self.metadataValue(.commonIdentifierTitle, in: metadata) ?? source.deletingPathExtension().lastPathComponent
                    let artist = await Self.metadataValue(.commonIdentifierArtist, in: metadata) ?? "Unbekannter Künstler"
                    let album = await Self.metadataValue(.commonIdentifierAlbumName, in: metadata) ?? "Ohne Album"
                    results.append(ImportOutcome(song: LocalSong(id: id, title: title, artist: artist, album: album, fileName: destination.lastPathComponent, duration: duration.isFinite ? duration : 0, dateAdded: Date(), playCount: 0, isFavorite: false), name: name, error: nil))
                } catch {
                    if access { source.stopAccessingSecurityScopedResource() }
                    results.append(ImportOutcome(song: nil, name: name, error: error.localizedDescription))
                }
            }
            return results
        }.value

        let imported = outcomes.compactMap(\.song)
        for song in imported.reversed() { songs.insert(song, at: 0) }
        save()
        isImporting = false

        let failed = outcomes.filter { $0.error != nil }
        if imported.isEmpty && !failed.isEmpty {
            importMessage = failed.count == 1
                ? "\(failed[0].name): \(failed[0].error ?? "Fehler")"
                : "\(failed.count) Dateien konnten nicht importiert werden: \(failed[0].error ?? "")"
        } else if failed.isEmpty {
            importMessage = imported.count == 1 ? "1 Song importiert" : "\(imported.count) Songs importiert"
        } else {
            importMessage = "\(imported.count) importiert, \(failed.count) übersprungen (\(failed[0].error ?? ""))"
        }
    }

    private nonisolated static func metadataValue(_ identifier: AVMetadataIdentifier, in items: [AVMetadataItem]) async -> String? {
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
