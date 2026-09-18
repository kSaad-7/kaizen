import AppKit

enum SoundPlayer {
    private static let names = ["session-complete"]
    private static let extensions = ["aiff", "caf", "wav"]

    static func playCompletionIfPresent() {
        for name in names {
            for ext in extensions {
                if let url = Bundle.main.url(forResource: name, withExtension: ext),
                   let sound = NSSound(contentsOf: url, byReference: true) {
                    sound.play()
                    return
                }
            }
        }
    }
}
