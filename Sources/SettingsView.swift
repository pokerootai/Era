import SwiftUI

struct SettingsView: View {
    @State private var source: MusicSource = .local
    var body: some View { NavigationStack { Form { Section("Musikquellen") { ForEach(MusicSource.allCases) { item in HStack { Image(systemName:item == .local ? "iphone":"apple.logo").frame(width:28); VStack(alignment:.leading){Text(item.rawValue);Text(item.available ? "Aktiv · komplett offline":"Später verfügbar").font(.caption).foregroundStyle(.secondary)};Spacer();Image(systemName:item.available ? "checkmark.circle.fill":"lock.fill").foregroundStyle(item.available ? .green:.secondary) } } }; Section("Offline") { Label("Songs bleiben in Era gespeichert",systemImage:"internaldrive.fill");Label("Keine Analyse, kein Tracking",systemImage:"hand.raised.fill");Label("Hintergrundwiedergabe & AirPlay",systemImage:"airplayaudio") }; Section("Era") { LabeledContent("Version","2.0");LabeledContent("Bibliothek","Lokal") } }.navigationTitle("Einstellungen") } }
}
