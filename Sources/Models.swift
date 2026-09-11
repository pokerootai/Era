import Foundation
import SwiftUI

struct LocalSong: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var artist: String
    var album: String
    var fileName: String
    var duration: Double
    var dateAdded: Date
    var playCount: Int
    var isFavorite: Bool

    var subtitle: String { artist.isEmpty ? "Unbekannter Künstler" : artist }
    var durationText: String { String(format: "%d:%02d", Int(duration) / 60, Int(duration) % 60) }
}

enum LibrarySort: String, CaseIterable, Identifiable {
    case recent = "Neueste", title = "Titel", artist = "Künstler", played = "Meistgespielt"
    var id: String { rawValue }
}

enum MusicSource: String, CaseIterable, Identifiable {
    case local = "Auf diesem iPhone"
    case appleMusic = "Apple Music"
    var id: String { rawValue }
    var available: Bool { self == .local }
}

struct EraTheme {
    static let accent = Color(red: 0.69, green: 0.39, blue: 1)
    static let blue = Color(red: 0.18, green: 0.70, blue: 1)
    static let gradient = LinearGradient(colors: [accent, blue], startPoint: .topLeading, endPoint: .bottomTrailing)
}
