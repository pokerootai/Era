import Foundation
import AVFoundation
import CryptoKit

// SHA-256 ueber dekodierte PCM-Frames (nicht die Datei), Dauer als zweites Kriterium (Spec 13.3).
// AVAudioFile dekodiert mp3/m4a/wav/aif/caf/flac einheitlich nach PCM.
enum AudioHasher {
    struct Result { let hash: String; let duration: Double }

    static func hash(url: URL) -> Result? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let format = file.processingFormat
        let duration = Double(file.length) / max(1, format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 131_072) else { return nil }
        var hasher = SHA256()
        do {
            while true {
                try file.read(into: buffer)
                if buffer.frameLength == 0 { break }
                let bytes = Int(buffer.frameLength) * MemoryLayout<Float>.size
                if let channels = buffer.floatChannelData {
                    for ch in 0..<Int(format.channelCount) {
                        hasher.update(bufferPointer: UnsafeRawBufferPointer(start: channels[ch], count: bytes))
                    }
                } else if let int16 = buffer.int16ChannelData {
                    let wide = Int(buffer.frameLength) * MemoryLayout<Int16>.size
                    for ch in 0..<Int(format.channelCount) {
                        hasher.update(bufferPointer: UnsafeRawBufferPointer(start: int16[ch], count: wide))
                    }
                } else if let audioList = buffer.audioBufferList {
                    let list = UnsafeMutableAudioBufferListPointer(audioList)
                    for ab in list {
                        hasher.update(bufferPointer: UnsafeRawBufferPointer(start: ab.mData, count: Int(ab.mDataByteSize)))
                    }
                }
            }
        } catch { return nil }
        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return Result(hash: digest, duration: duration)
    }
}
