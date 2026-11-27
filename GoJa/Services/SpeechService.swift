import Foundation
import AVFoundation

/// Plays pronunciation audio from Dictionary API URLs or falls back to iOS AVSpeechSynthesizer.
@MainActor
final class SpeechService: ObservableObject {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVPlayer?

    func speak(text: String, languageCode: String, audioURL: String? = nil) {
        if let urlString = audioURL, let url = URL(string: urlString) {
            player = AVPlayer(url: url)
            player?.play()
            return
        }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: LanguageOption.find(languageCode).speechLocale)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        synthesizer.speak(utterance)
    }
}
