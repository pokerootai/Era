import Foundation
import SwiftData

// Demo-Daten fuer Simulator-Screenshots (nur Simulator, nur wenn Bibliothek leer).
// Bildet die Spec-Beispiele ab: 530, Hurricane, Runaway, City in the Sky, Everybody.
enum DemoSeed {
    static func seedIfNeeded(store: EraStore) {
        #if targetEnvironment(simulator)
        guard ProcessInfo.processInfo.arguments.contains("--era-demo") else { return }
        guard ((try? store.allSongs().isEmpty) ?? true) else { return }

        store.ensureStatusTags()
        func tag(_ name: String) -> Tag { store.makeTag(named: name) }

        let vultures = tag("Vultures"), yandhi = tag("Yandhi"), mbdtf = tag("MBDTF"), donda = tag("Donda")
        let favorite = tag("Favorite")
        let released = tag("Released"), unreleased = tag("Unreleased"), leak = tag("Leak"), demo = tag("Demo")

        func song(_ title: String, _ artist: String, _ era: String, _ year: Int?, versions: [(String, Int?)], tags: [Tag], plays: Int) -> Song {
            let s = Song(title: title, artist: artist, album: era, era: era, year: year)
            s.playCount = plays
            if plays > 0 { s.lastPlayedAt = Date().addingTimeInterval(-3600 * Double(plays)) }
            for (i, v) in versions.enumerated() {
                let ver = SongVersion(name: v.0, fileName: "demo-\(s.id.uuidString)-\(i).m4a", pcmHash: "demo-\(s.id.uuidString)-\(i)", duration: Double(150 + i * 37), year: v.1)
                ver.sortIndex = i
                ver.song = s
                s.versions.append(ver)
                if i == 0 { s.primaryVersionID = ver.id }
            }
            s.tags = tags
            store.insertSong(s)
            return s
        }

        let s530 = song("530", "Ye", "Vultures", 2024, versions: [("OG", 2023), ("Vultures 2 Demo", 2024), ("Released", 2024)], tags: [vultures, unreleased], plays: 12)
        let hurricane = song("Hurricane", "Ye", "Donda", 2021, versions: [("2020 OG", 2020), ("2021 LP", 2021), ("DONDA Release", 2021), ("Demo", 2019)], tags: [donda, released, favorite], plays: 30)
        let runaway = song("Runaway", "Ye", "MBDTF", 2010, versions: [("Released", 2010)], tags: [mbdtf, released, favorite], plays: 44)
        let citySky = song("City in the Sky", "Ye", "Yandhi", 2018, versions: [("OG", 2018), ("Sunday Service", 2019)], tags: [yandhi, unreleased], plays: 9)
        let everybody = song("Everybody", "Ye ¥$", "Vultures", 2024, versions: [("V1", 2023), ("V2", 2024)], tags: [vultures, leak], plays: 17)
        let afterglow = song("Afterglow", "MALT3", "Proof", 2026, versions: [("OG", 2026)], tags: [released, favorite], plays: 5)

        let vPack = Pack(name: "Vultures", tagIDs: [vultures.id], confirmed: true)
        store.insertPack(vPack)
        store.insertPack(Pack(name: "Yandhi", tagIDs: [yandhi.id], confirmed: false))
        store.insertPack(Pack(name: "Donda Era", tagIDs: [donda.id], confirmed: false))
        store.insertPack(Pack(name: "Unreleased Ye", statusNames: ["Unreleased"], confirmed: false))

        let favs = Playlist(name: "Ye - Favorites")
        favs.filterTagIDs = []
        store.insertPlaylist(favs)
        store.appendEntry(song: runaway, version: runaway.primaryVersion, to: favs)
        store.appendEntry(song: citySky, version: citySky.primaryVersion, to: favs)
        store.appendEntry(song: everybody, version: everybody.sortedVersions.last, to: favs)
        store.appendEntry(song: s530, version: s530.primaryVersion, to: favs)
        store.appendEntry(song: hurricane, version: hurricane.sortedVersions.first(where: { $0.name == "DONDA Release" }), to: favs)
        store.save()
        #endif
    }
}
