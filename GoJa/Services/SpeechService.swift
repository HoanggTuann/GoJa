import Foundation
import AVFoundation

/// Plays pronunciation audio from Dictionary API URLs or iOS AVSpeechSynthesizer with configurable learner speed.
@MainActor
final class SpeechService: ObservableObject {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    private var player: AVPlayer?

    /// Default learner-friendly rate (AVSpeechUtteranceDefaultSpeechRate is 0.5, which is fast for beginners).
    static let defaultRate: Double = 0.40
    static let minRate: Double = 0.25
    static let maxRate: Double = 0.60

    func speak(
        text: String,
        languageCode: String,
        audioURL: String? = nil,
        rate: Double? = nil,
        forceSynthesizer: Bool = false
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if !forceSynthesizer, let urlString = audioURL, let url = URL(string: urlString) {
            player = AVPlayer(url: url)
            player?.play()
            return
        }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let effectiveRate = Float(min(max(rate ?? Self.defaultRate, Self.minRate), Self.maxRate))
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: LanguageOption.find(languageCode).speechLocale)
        utterance.rate = effectiveRate
        utterance.pitchMultiplier = 1.0
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        player?.pause()
    }

    static func description(for rate: Double) -> String {
        switch rate {
        case ..<0.33:
            return "Rất chậm (Dễ nghe từng âm)"
        case 0.33..<0.44:
            return "Chậm (Khuyên dùng cho người học)"
        case 0.44..<0.52:
            return "Vừa phải"
        default:
            return "Nhanh (Gần tốc độ bản ngữ)"
        }
    }
}
