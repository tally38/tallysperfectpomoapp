import AppKit

class SoundManager {
    static let availableSounds = [
        "Glass", "Blow", "Bottle", "Frog", "Funk",
        "Hero", "Morse", "Ping", "Pop", "Purr",
        "Sosumi", "Submarine", "Tink"
    ]

    func playCompletionSound() {
        let soundName = UserDefaults.standard.string(forKey: "alertSound") ?? "Glass"
        NSSound(named: NSSound.Name(soundName))?.play()
    }

    func playPreview(soundName: String) {
        NSSound(named: NSSound.Name(soundName))?.play()
    }
}
