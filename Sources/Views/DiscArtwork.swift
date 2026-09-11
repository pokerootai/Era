import SwiftUI
import UIKit

// Prozedurale CD im Yandhi-Look (Spec 8.1): nackte Disc, Regenbogen-Sheen,
// neutraler Hintergrund. Deterministisch aus der Song-ID: Neigung, Sheen und
// Reflexion variieren subtil pro Song. Kein Badge, keine Schrift, kein Noten-Symbol.
struct DiscArtwork: View {
    let songID: UUID
    var statusName: String?
    var radius: CGFloat = 10

    private var params: DiscParams { DiscParams(id: songID, status: statusName) }

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = side / 2
            let hole = side * 0.16

            // Neutraler Hintergrund
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(.systemGray5)))

            // Disc-Grundkoerper: silbernes Metall, radiale Abstufung
            let discRect = CGRect(x: center.x - outer, y: center.y - outer, width: side, height: side)
            let base = Gradient(colors: [
                Color(white: 0.86), Color(white: 0.72), Color(white: 0.80),
                Color(white: 0.62), Color(white: 0.78)
            ])
            context.fill(
                Circle().path(in: discRect),
                with: .radialGradient(base, center: center, startRadius: hole, endRadius: outer)
            )

            // Rillen
            var grooves = Path()
            var r = hole * 1.35
            while r < outer * 0.98 {
                grooves.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                r += max(1.2, side * 0.012)
            }
            context.stroke(grooves, with: .color(.black.opacity(0.08)), lineWidth: 0.6)

            // Regenbogen-Sheen: konischer Verlauf, deterministisch gedreht
            let sheen = Gradient(colors: [
                .red, .orange, .yellow, .green, .blue, .purple, .red
            ])
            var sheenContext = context
            sheenContext.opacity = params.sheenOpacity
            sheenContext.fill(
                Circle().path(in: discRect),
                with: .conicGradient(sheen, center: center, angle: .degrees(params.sheenAngle))
            )

            // Subtiler Status-Farbstich (optional, Spec 8.1)
            if let tint = params.statusTint {
                var tintContext = context
                tintContext.opacity = 0.10
                tintContext.fill(Circle().path(in: discRect), with: .color(tint))
            }

            // Licht-Reflexion: schmales weisses Segment, gedreht
            var reflection = Path()
            let reflRect = discRect.insetBy(dx: side * 0.06, dy: side * 0.06)
            reflection.addArc(center: center, radius: reflRect.width / 2,
                              startAngle: .degrees(params.reflectionAngle),
                              endAngle: .degrees(params.reflectionAngle + 42), clockwise: false)
            context.stroke(reflection, with: .color(.white.opacity(0.5)), lineWidth: side * 0.018)

            // Mittelloch
            let holeRect = CGRect(x: center.x - hole, y: center.y - hole, width: hole * 2, height: hole * 2)
            context.fill(Circle().path(in: holeRect), with: .color(Color(.systemGray5)))
            context.stroke(Circle().path(in: holeRect.insetBy(dx: -1, dy: -1)), with: .color(.black.opacity(0.15)), lineWidth: 1)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(.black.opacity(0.08), lineWidth: 0.5))
    }
}

struct DiscParams {
    let sheenAngle: Double
    let sheenOpacity: Double
    let reflectionAngle: Double
    let statusTint: Color?

    init(id: UUID, status: String?) {
        var bytes: [UInt8] = []
        withUnsafeBytes(of: id.uuid) { bytes.append(contentsOf: $0) }
        let b0 = Double(bytes.count > 0 ? bytes[0] : 0)
        let b1 = Double(bytes.count > 1 ? bytes[1] : 128)
        let b2 = Double(bytes.count > 2 ? bytes[2] : 64)
        sheenAngle = b0 / 255 * 360
        sheenOpacity = 0.16 + (b1 / 255) * 0.14
        reflectionAngle = b2 / 255 * 360
        switch status {
        case "Leak": statusTint = .red
        case "Unreleased": statusTint = .orange
        case "Demo", "Snippet": statusTint = .yellow
        case "Live": statusTint = .green
        case "Released": statusTint = .blue
        default: statusTint = nil
        }
    }
}

// Rasterisierung + Cache (Spec 8.1: pro Song gecacht, als 1024er PNG exportierbar)
enum DiscArtworkCache {
    static var cacheDir: URL {
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DiscArtwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @MainActor
    static func png(for songID: UUID, status: String?, size: CGFloat = 1024) -> UIImage {
        let file = cacheDir.appendingPathComponent("\(songID.uuidString)-\(status ?? "none")-\(Int(size)).png")
        if let data = try? Data(contentsOf: file), let image = UIImage(data: data) { return image }
        let renderer = ImageRenderer(content: DiscArtwork(songID: songID, statusName: status, radius: 0).frame(width: size, height: size))
        renderer.scale = 1
        let image = renderer.uiImage ?? UIImage()
        if let data = image.pngData() { try? data.write(to: file, options: .atomic) }
        return image
    }
}
