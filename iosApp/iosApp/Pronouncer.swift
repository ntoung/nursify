import AVFoundation

/// Speaks a concept name aloud via on-device speech synthesis - the "tap to
/// hear" pronunciation control on the concept detail page. Kept as a shared
/// instance so the synthesizer isn't deallocated mid-utterance (a common cause
/// of speech silently not playing).
final class Pronouncer {
    static let shared = Pronouncer()

    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        // Cancel anything in flight so rapid taps don't queue up behind each other.
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        // Slightly slower than default so multi-syllable drug names are clearer.
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        synthesizer.speak(utterance)
    }
}
