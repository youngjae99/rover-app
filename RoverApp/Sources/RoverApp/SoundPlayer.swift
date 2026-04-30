import Foundation
import AVFoundation

@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    private var players: [String: AVAudioPlayer] = [:]
    var enabled: Bool = true

    func play(_ name: String, volume: Float = 0.6) {
        guard enabled else { return }
        if players[name] == nil {
            guard let url = AnimationCatalog.shared.soundURL(named: name) else {
                NSLog("⚠️ Rover: sound not found '\(name)'")
                return
            }
            guard let player = try? AVAudioPlayer(contentsOf: url) else { return }
            player.prepareToPlay()
            players[name] = player
        }
        guard let player = players[name] else { return }
        player.volume = volume
        player.currentTime = 0
        player.play()
    }
}
