import Foundation
import Combine

/// Local persistence for flashcards, custom web/API sources, and user preferences.
@MainActor
final class StorageService: ObservableObject {
    @Published var flashcards: [Flashcard] = []
    @Published var sources: [WebSource] = []

    @Published var targetLanguageCode: String {
        didSet { UserDefaults.standard.set(targetLanguageCode, forKey: Keys.targetLanguage) }
    }

    @Published var nativeLanguageCode: String {
        didSet { UserDefaults.standard.set(nativeLanguageCode, forKey: Keys.nativeLanguage) }
    }

    @Published var dailyGoal: Int {
        didSet { UserDefaults.standard.set(dailyGoal, forKey: Keys.dailyGoal) }
    }

    @Published var todayReviewedCount: Int {
        didSet {
            UserDefaults.standard.set(todayReviewedCount, forKey: Keys.todayReviewed)
            UserDefaults.standard.set(Date(), forKey: Keys.lastReviewDate)
        }
    }

    private enum Keys {
        static let targetLanguage = "goja.targetLanguage"
        static let nativeLanguage = "goja.nativeLanguage"
        static let dailyGoal = "goja.dailyGoal"
        static let todayReviewed = "goja.todayReviewed"
        static let lastReviewDate = "goja.lastReviewDate"
    }

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var flashcardsURL: URL { documentsURL.appendingPathComponent("flashcards.json") }
    private var sourcesURL: URL { documentsURL.appendingPathComponent("sources.json") }

    init() {
        self.targetLanguageCode = UserDefaults.standard.string(forKey: Keys.targetLanguage) ?? "en"
        self.nativeLanguageCode = UserDefaults.standard.string(forKey: Keys.nativeLanguage) ?? "vi"
        let savedGoal = UserDefaults.standard.integer(forKey: Keys.dailyGoal)
        self.dailyGoal = savedGoal > 0 ? savedGoal : 15

        if let lastDate = UserDefaults.standard.object(forKey: Keys.lastReviewDate) as? Date,
           Calendar.current.isDateInToday(lastDate) {
            self.todayReviewedCount = UserDefaults.standard.integer(forKey: Keys.todayReviewed)
        } else {
            self.todayReviewedCount = 0
        }

        loadFlashcards()
        loadSources()
    }

    var targetLanguage: LanguageOption { LanguageOption.find(targetLanguageCode) }
    var nativeLanguage: LanguageOption { LanguageOption.find(nativeLanguageCode) }

    var dueFlashcards: [Flashcard] {
        flashcards.filter { $0.isDue }.sorted { $0.nextReviewAt < $1.nextReviewAt }
    }

    // MARK: - Flashcards

    func addOrUpdateFlashcard(_ card: Flashcard) {
        if let idx = flashcards.firstIndex(where: {
            $0.word.caseInsensitiveCompare(card.word) == .orderedSame &&
            $0.languageCode == card.languageCode
        }) {
            flashcards[idx].translation = card.translation
            flashcards[idx].phonetic = card.phonetic ?? flashcards[idx].phonetic
            flashcards[idx].definition = card.definition ?? flashcards[idx].definition
            flashcards[idx].example = card.example ?? flashcards[idx].example
        } else {
            flashcards.insert(card, at: 0)
        }
        saveFlashcards()
    }

    func deleteFlashcards(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            flashcards.remove(at: index)
        }
        saveFlashcards()
    }

    func markReviewed(cardID: UUID, quality: ReviewQuality) {
        guard let idx = flashcards.firstIndex(where: { $0.id == cardID }) else { return }
        var card = flashcards[idx]
        card.reviewCount += 1

        switch quality {
        case .forgot:
            card.intervalDays = 0
            card.nextReviewAt = Calendar.current.date(byAdding: .minute, value: 10, to: Date()) ?? Date()
        case .hard:
            card.intervalDays = max(1, card.intervalDays == 0 ? 1 : card.intervalDays)
            card.nextReviewAt = Calendar.current.date(byAdding: .day, value: card.intervalDays, to: Date()) ?? Date()
        case .mastered:
            card.intervalDays = card.intervalDays == 0 ? 2 : min(30, card.intervalDays * 2)
            card.nextReviewAt = Calendar.current.date(byAdding: .day, value: card.intervalDays, to: Date()) ?? Date()
        }

        flashcards[idx] = card
        todayReviewedCount += 1
        saveFlashcards()
    }

    // MARK: - Sources

    func addSource(_ source: WebSource) {
        sources.append(source)
        saveSources()
    }

    func toggleSource(id: UUID) {
        guard let idx = sources.firstIndex(where: { $0.id == id }) else { return }
        sources[idx].isEnabled.toggle()
        saveSources()
    }

    func deleteSources(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            sources.remove(at: index)
        }
        saveSources()
    }

    // MARK: - Disk I/O

    private func loadFlashcards() {
        guard let data = try? Data(contentsOf: flashcardsURL),
              let decoded = try? JSONDecoder().decode([Flashcard].self, from: data) else {
            flashcards = []
            return
        }
        flashcards = decoded
    }

    private func saveFlashcards() {
        guard let data = try? JSONEncoder().encode(flashcards) else { return }
        try? data.write(to: flashcardsURL, options: .atomic)
    }

    private func loadSources() {
        if let data = try? Data(contentsOf: sourcesURL),
           let decoded = try? JSONDecoder().decode([WebSource].self, from: data),
           !decoded.isEmpty {
            sources = decoded
            return
        }

        sources = Self.defaultSources
        saveSources()
    }

    private func saveSources() {
        guard let data = try? JSONEncoder().encode(sources) else { return }
        try? data.write(to: sourcesURL, options: .atomic)
    }

    static let defaultSources: [WebSource] = [
        WebSource(
            name: "Wikipedia Ngẫu Nhiên",
            urlString: "https://en.wikipedia.org/api/rest_v1/page/random/summary",
            kind: .wikipedia,
            languageCode: "en"
        ),
        WebSource(
            name: "BBC Learning / News RSS",
            urlString: "https://feeds.bbci.co.uk/news/world/rss.xml",
            kind: .rss,
            languageCode: "en"
        ),
        WebSource(
            name: "NHK World English RSS",
            urlString: "https://www3.nhk.or.jp/rss/news/cat0.xml",
            kind: .rss,
            languageCode: "ja"
        ),
        WebSource(
            name: "VOA Learning English RSS",
            urlString: "https://learningenglish.voanews.com/api/z-pq$em_qq",
            kind: .rss,
            languageCode: "en"
        )
    ]
}
