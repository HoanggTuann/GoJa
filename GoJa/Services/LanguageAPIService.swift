import Foundation

enum LanguageAPIError: LocalizedError {
    case invalidURL
    case networkError(String)
    case emptyQuery

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Địa chỉ API không hợp lệ."
        case .networkError(let message):
            return "Lỗi kết nối: \(message)"
        case .emptyQuery:
            return "Vui lòng nhập từ hoặc câu cần tra."
        }
    }
}

/// Integrates Free Dictionary API and MyMemory Translation API (no API key required).
final class LanguageAPIService {
    static let shared = LanguageAPIService()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func lookupWord(_ rawWord: String, from sourceLang: String, to targetLang: String) async throws -> WordLookupResult {
        let word = rawWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty else { throw LanguageAPIError.emptyQuery }

        async let translationTask = try? translateText(word, from: sourceLang, to: targetLang)
        async let dictionaryTask = try? fetchDictionaryEntry(word: word, lang: sourceLang)

        let translation = await translationTask
        let dictEntry = await dictionaryTask

        return WordLookupResult(
            word: dictEntry?.word ?? word,
            phonetic: dictEntry?.phonetic,
            audioURL: dictEntry?.audioURL,
            translation: translation,
            meanings: dictEntry?.meanings ?? []
        )
    }

    func translateText(_ text: String, from sourceLang: String, to targetLang: String) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LanguageAPIError.emptyQuery }
        if sourceLang == targetLang { return trimmed }

        var components = URLComponents(string: "https://api.mymemory.translated.net/get")
        components?.queryItems = [
            URLQueryItem(name: "q", value: String(trimmed.prefix(480))),
            URLQueryItem(name: "langpair", value: "\(sourceLang)|\(targetLang)")
        ]
        guard let url = components?.url else { throw LanguageAPIError.invalidURL }

        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode(MyMemoryResponse.self, from: data)
        return decoded.responseData.translatedText
    }

    // MARK: - Free Dictionary API

    private struct DictEntry {
        let word: String
        let phonetic: String?
        let audioURL: String?
        let meanings: [WordLookupResult.Meaning]
    }

    private func fetchDictionaryEntry(word: String, lang: String) async throws -> DictEntry? {
        guard LanguageOption.find(lang).supportsFreeDictionary else { return nil }
        guard let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.dictionaryapi.dev/api/v2/entries/\(lang)/\(encoded)") else {
            return nil
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            return nil
        }

        let entries = try JSONDecoder().decode([FreeDictEntryDTO].self, from: data)
        guard let first = entries.first else { return nil }

        let phonetic = first.phonetic ?? first.phonetics?.compactMap(\.text).first(where: { !$0.isEmpty })
        let audioURL = first.phonetics?.compactMap(\.audio).first(where: { !$0.isEmpty })

        let meanings: [WordLookupResult.Meaning] = (first.meanings ?? []).map { m in
            WordLookupResult.Meaning(
                partOfSpeech: m.partOfSpeech ?? "",
                definitions: m.definitions?.compactMap(\.definition) ?? [],
                examples: m.definitions?.compactMap(\.example) ?? []
            )
        }

        return DictEntry(word: first.word, phonetic: phonetic, audioURL: audioURL, meanings: meanings)
    }
}

// MARK: - DTOs

private struct MyMemoryResponse: Decodable {
    struct ResponseData: Decodable {
        let translatedText: String
    }
    let responseData: ResponseData
}

private struct FreeDictEntryDTO: Decodable {
    struct PhoneticDTO: Decodable {
        let text: String?
        let audio: String?
    }
    struct MeaningDTO: Decodable {
        struct DefinitionDTO: Decodable {
            let definition: String?
            let example: String?
        }
        let partOfSpeech: String?
        let definitions: [DefinitionDTO]?
    }
    let word: String
    let phonetic: String?
    let phonetics: [PhoneticDTO]?
    let meanings: [MeaningDTO]?
}
