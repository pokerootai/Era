import SwiftUI
import SwiftData

// Apple-Stil: App-Icon + Versionsnummer, gruppierte Liste, nur Offline-Relevantes.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var songs: [Song]
    @Query private var versions: [SongVersion]

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "27.0.0"
    }
    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image(uiImage: appIcon)
                            .resizable()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Era").font(.title3.weight(.semibold))
                            Text("Version \(appVersion) (\(buildNumber))").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Bibliothek") {
                    LabeledContent("Speicherort", value: "Lokal auf diesem iPhone")
                    LabeledContent("Songs", value: "\(songs.count)")
                    LabeledContent("Versionen", value: "\(versions.count)")
                    LabeledContent("Speicherbedarf", value: LibraryFiles.librarySizeText())
                }
                Section("Wiedergabe") {
                    Label("Hintergrundwiedergabe", systemImage: "play.rectangle.on.rectangle")
                    Label("AirPlay & Bluetooth", systemImage: "airplayaudio")
                    Label("Sleep Timer", systemImage: "moon.zzz.fill")
                    Label("Lockscreen-Steuerung", systemImage: "lock.display")
                }
                Section("Datenschutz") {
                    Label("Musik verlässt dein iPhone nicht", systemImage: "lock.fill")
                    Label("Kein Tracking, keine Analyse", systemImage: "hand.raised.fill")
                    Label("Komplett offline", systemImage: "wifi.slash")
                }
            }
            .navigationTitle("Einstellungen")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }

    private var appIcon: UIImage {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let name = files.last, let image = UIImage(named: name) {
            return image
        }
        return UIImage(named: "AppIcon") ?? UIImage()
    }
}
