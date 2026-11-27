import Foundation

/// Supported languages for learning and translation.
struct LanguageOption: Identifiable, Hashable, Codable {
    let id: String          // ISO 639-1 code (e.g. "en", "ja")
    let name: String        // Display name in Vietnamese
    let nativeName: String  // Native name
    let speechLocale: String
    let supportsFreeDictionary: Bool

    static let all: [LanguageOption] = [
        LanguageOption(id: "en", name: "Tiếng Anh", nativeName: "English", speechLocale: "en-US", supportsFreeDictionary: true),
        LanguageOption(id: "ja", name: "Tiếng Nhật", nativeName: "日本語", speechLocale: "ja-JP", supportsFreeDictionary: false),
        LanguageOption(id: "ko", name: "Tiếng Hàn", nativeName: "한국어", speechLocale: "ko-KR", supportsFreeDictionary: false),
        LanguageOption(id: "zh", name: "Tiếng Trung", nativeName: "中文", speechLocale: "zh-CN", supportsFreeDictionary: false),
        LanguageOption(id: "fr", name: "Tiếng Pháp", nativeName: "Français", speechLocale: "fr-FR", supportsFreeDictionary: false),
        LanguageOption(id: "de", name: "Tiếng Đức", nativeName: "Deutsch", speechLocale: "de-DE", supportsFreeDictionary: false),
        LanguageOption(id: "es", name: "Tiếng Tây Ban Nha", nativeName: "Español", speechLocale: "es-ES", supportsFreeDictionary: false),
        LanguageOption(id: "vi", name: "Tiếng Việt", nativeName: "Tiếng Việt", speechLocale: "vi-VN", supportsFreeDictionary: false)
    ]

    static func find(_ code: String) -> LanguageOption {
        all.first { $0.id == code } ?? all[0]
    }
}

/// A saved vocabulary flashcard with simple spaced-repetition metadata.
struct Flashcard: Identifiable, Codable, Hashable {
    let id: UUID
    var word: String
    var phonetic: String?
    var translation: String
    var definition: String?
    var example: String?
    var languageCode: String
    var sourceTitle: String?
    var createdAt: Date
    var nextReviewAt: Date
    var intervalDays: Int
    var reviewCount: Int

    init(
        id: UUID = UUID(),
        word: String,
        phonetic: String? = nil,
        translation: String,
        definition: String? = nil,
        example: String? = nil,
        languageCode: String,
        sourceTitle: String? = nil,
        createdAt: Date = Date(),
        nextReviewAt: Date = Date(),
        intervalDays: Int = 0,
        reviewCount: Int = 0
    ) {
        self.id = id
        self.word = word
        self.phonetic = phonetic
        self.translation = translation
        self.definition = definition
        self.example = example
        self.languageCode = languageCode
        self.sourceTitle = sourceTitle
        self.createdAt = createdAt
        self.nextReviewAt = nextReviewAt
        self.intervalDays = intervalDays
        self.reviewCount = reviewCount
    }

    var isDue: Bool {
        nextReviewAt <= Date()
    }
}

/// Review quality rating for spaced repetition.
enum ReviewQuality: Int, CaseIterable {
    case forgot = 0
    case hard = 1
    case mastered = 2

    var title: String {
        switch self {
        case .forgot: return "Quên"
        case .hard: return "Nhớ tạm"
        case .mastered: return "Đã thuộc"
        }
    }
}

/// An article or passage fetched from Wikipedia, RSS, or any Web URL.
struct LearningArticle: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let summary: String
    let content: String
    let url: String?
    let sourceName: String
    let languageCode: String
    let imageURL: String?
    let fetchedAt: Date
}

/// External learning source configured by the user or preset.
struct WebSource: Identifiable, Codable, Hashable {
    enum SourceKind: String, Codable, CaseIterable {
        case wikipedia = "Wikipedia API"
        case rss = "RSS Feed"
        case webPage = "Trang Web"
    }

    let id: UUID
    var name: String
    var urlString: String
    var kind: SourceKind
    var languageCode: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        urlString: String,
        kind: SourceKind,
        languageCode: String,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.urlString = urlString
        self.kind = kind
        self.languageCode = languageCode
        self.isEnabled = isEnabled
    }
}

/// Combined result from Dictionary API + Translation API.
struct WordLookupResult: Identifiable {
    struct Meaning: Identifiable {
        let id = UUID()
        let partOfSpeech: String
        let definitions: [String]
        let examples: [String]
    }

    let id = UUID()
    let word: String
    let phonetic: String?
    let audioURL: String?
    let translation: String?
    let meanings: [Meaning]
}
