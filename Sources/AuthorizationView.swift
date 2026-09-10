import SwiftUI
import MusicKit

struct AuthorizationView: View {
    @Binding var authStatus: MusicAuthorization.Status

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 80)).foregroundStyle(.pink)
            Text("Musik-Zugriff").font(.largeTitle.bold())
            Text("Diese App benötigt Zugriff auf Apple Music, um Songs zu suchen und abzuspielen.")
                .foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.horizontal, 32)
            Button {
                Task { authStatus = await MusicAuthorization.request() }
            } label: {
                Label("Zugriff erlauben", systemImage: "checkmark.circle.fill")
                    .font(.headline).padding(.horizontal, 32).padding(.vertical, 14)
                    .background(.pink, in: Capsule()).foregroundStyle(.white)
            }
            if authStatus == .denied {
                Text("Zugriff verweigert — bitte in den Einstellungen aktivieren.")
                    .font(.caption).foregroundStyle(.red)
                Button("Einstellungen öffnen") {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }.font(.caption)
            }
            Spacer()
        }
    }
}


