import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: LibraryStore

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "3.0"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Bibliothek") {
                    LabeledContent("Speicherort", value: "Lokal auf diesem iPhone")
                    LabeledContent("Songs", value: "\(store.songs.count)")
                    LabeledContent("Speicherbedarf", value: store.librarySizeText)
                }
                Section("Wiedergabe") {
                    Label("Hintergrundwiedergabe", systemImage: "play.rectangle.on.rectangle")
                    Label("AirPlay & Bluetooth", systemImage: "airplayaudio")
                    Label("Sleep Timer", systemImage: "moon.fill")
                    Label("Lockscreen-Steuerung", systemImage: "lock.display")
                }
                Section("Datenschutz") {
                    Label("Musik verlässt dein iPhone nicht", systemImage: "lock.fill")
                    Label("Kein Tracking, keine Analyse", systemImage: "hand.raised.fill")
                }
                Section("Era") {
                    LabeledContent("Version", value: appVersion)
                }
            }
            .navigationTitle("Einstellungen")
        }
    }
}
