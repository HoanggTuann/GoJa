import Foundation
import Combine

/// Local persistence for flashcards, custom web/API sources, JaPack format (.japack), speech rate, and Duolingo-style streak/XP.
@MainActor
final class StorageService: ObservableObject {
    @Published var flashcards: [Flashcard] = []
    @Published var sources: [WebSource] = []
    @Published var customLessons: [LessonUnit] = []
    @Published var importedPacks: [ImportedPackRecord] = []
    @Published var lookupHistory: [DictionaryHistoryItem] = []
    @Published var streakStats: StreakStats = StreakStats()

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

    @Published var speechRate: Double {
        didSet { UserDefaults.standard.set(speechRate, forKey: Keys.speechRate) }
    }

    @Published var showLanguageSuggestions: Bool {
        didSet { UserDefaults.standard.set(showLanguageSuggestions, forKey: Keys.showLanguageSuggestions) }
    }

    private enum Keys {
        static let targetLanguage = "goja.targetLanguage"
        static let nativeLanguage = "goja.nativeLanguage"
        static let dailyGoal = "goja.dailyGoal"
        static let todayReviewed = "goja.todayReviewed"
        static let lastReviewDate = "goja.lastReviewDate"
        static let speechRate = "goja.speechRate"
        static let showLanguageSuggestions = "goja.showLanguageSuggestions"
    }

    private var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var libraryJaPackURL: URL { documentsURL.appendingPathComponent("GoJaLibrary.japack") }
    private var legacyFlashcardsURL: URL { documentsURL.appendingPathComponent("flashcards.json") }
    private var legacySourcesURL: URL { documentsURL.appendingPathComponent("sources.json") }
    private var streakURL: URL { documentsURL.appendingPathComponent("streak_stats.json") }
    private var historyURL: URL { documentsURL.appendingPathComponent("lookup_history.json") }
    private var packsIndexURL: URL { documentsURL.appendingPathComponent("imported_packs.json") }

    init() {
        self.targetLanguageCode = UserDefaults.standard.string(forKey: Keys.targetLanguage) ?? "en"
        self.nativeLanguageCode = UserDefaults.standard.string(forKey: Keys.nativeLanguage) ?? "vi"

        let savedGoal = UserDefaults.standard.integer(forKey: Keys.dailyGoal)
        self.dailyGoal = savedGoal > 0 ? savedGoal : 15

        let savedRate = UserDefaults.standard.double(forKey: Keys.speechRate)
        self.speechRate = savedRate > 0 ? savedRate : SpeechService.defaultRate

        if UserDefaults.standard.object(forKey: Keys.showLanguageSuggestions) == nil {
            self.showLanguageSuggestions = true
        } else {
            self.showLanguageSuggestions = UserDefaults.standard.bool(forKey: Keys.showLanguageSuggestions)
        }

        if let lastDate = UserDefaults.standard.object(forKey: Keys.lastReviewDate) as? Date,
           Calendar.current.isDateInToday(lastDate) {
            self.todayReviewedCount = UserDefaults.standard.integer(forKey: Keys.todayReviewed)
        } else {
            self.todayReviewedCount = 0
        }

        loadLibrary()
        loadStreakStats()
        loadHistory()
        loadImportedPacksIndex()
    }

    var targetLanguage: LanguageOption { LanguageOption.find(targetLanguageCode) }
    var nativeLanguage: LanguageOption { LanguageOption.find(nativeLanguageCode) }

    var dueFlashcards: [Flashcard] {
        flashcards.filter { $0.isDue }.sorted { $0.nextReviewAt < $1.nextReviewAt }
    }

    // MARK: - Language Suggestions

    func applySuggestedLanguage(_ code: String) {
        targetLanguageCode = code
        let wikiURL = "https://\(code).wikipedia.org/api/rest_v1/page/random/summary"
        if !sources.contains(where: { $0.kind == .wikipedia && $0.languageCode == code }) {
            let lang = LanguageOption.find(code)
            sources.insert(
                WebSource(
                    name: "Wikipedia \(lang.nativeName)",
                    urlString: wikiURL,
                    kind: .wikipedia,
                    languageCode: code
                ),
                at: 0
            )
            saveLibrary()
        }
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
        saveLibrary()
    }

    func deleteFlashcards(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            flashcards.remove(at: index)
        }
        saveLibrary()
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
        recordStudyActivity(xp: quality == .mastered ? 5 : 3)
        saveLibrary()
    }

    // MARK: - Sources

    func addSource(_ source: WebSource) {
        sources.append(source)
        saveLibrary()
    }

    func toggleSource(id: UUID) {
        guard let idx = sources.firstIndex(where: { $0.id == id }) else { return }
        sources[idx].isEnabled.toggle()
        saveLibrary()
    }

    func deleteSources(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            sources.remove(at: index)
        }
        saveLibrary()
    }

    // MARK: - Lookup History

    func recordLookupHistory(query: String, translation: String, sourceLang: String, targetLang: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !translation.isEmpty else { return }

        lookupHistory.removeAll {
            $0.query.caseInsensitiveCompare(trimmed) == .orderedSame &&
            $0.sourceLanguageCode == sourceLang &&
            $0.targetLanguageCode == targetLang
        }
        lookupHistory.insert(
            DictionaryHistoryItem(
                query: trimmed,
                translation: translation,
                sourceLanguageCode: sourceLang,
                targetLanguageCode: targetLang
            ),
            at: 0
        )
        if lookupHistory.count > 20 {
            lookupHistory = Array(lookupHistory.prefix(20))
        }
        saveHistory()
    }

    func clearLookupHistory() {
        lookupHistory = []
        saveHistory()
    }

    // MARK: - Streak & Duolingo-style XP

    func recordStudyActivity(xp: Int, completedLessonID: String? = nil) {
        let todayKey = Self.dayKey(for: Date())
        let yesterdayDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        let yesterdayKey = Self.dayKey(for: yesterdayDate)

        if let lastStudyKey = streakStats.studyDays.last, lastStudyKey != todayKey {
            streakStats.todayXP = 0
        }

        streakStats.todayXP += xp
        streakStats.totalXP += xp

        if !streakStats.studyDays.contains(todayKey) {
            if streakStats.studyDays.contains(yesterdayKey) {
                streakStats.currentStreak += 1
            } else {
                streakStats.currentStreak = 1
            }
            streakStats.studyDays.append(todayKey)
            streakStats.longestStreak = max(streakStats.longestStreak, streakStats.currentStreak)
        }

        if let completedLessonID, !streakStats.completedLessonIDs.contains(completedLessonID) {
            streakStats.completedLessonIDs.append(completedLessonID)
        }

        saveStreakStats()
    }

    func last7DaysActivity() -> [(label: String, dateKey: String, completed: Bool)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "EEEEE"

        return (-6...0).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: Date()) else { return nil }
            let key = Self.dayKey(for: date)
            let label = offset == 0 ? "Nay" : formatter.string(from: date).uppercased()
            return (label: label, dateKey: key, completed: streakStats.studyDays.contains(key))
        }
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - JaPack (.japack) Bundled Samples, Export & Import

    struct BundledSamplePack: Identifiable {
        let id: String
        let url: URL
        let pack: GoJaPack
    }

    func bundledSamplePacks() -> [BundledSamplePack] {
        let urls = Bundle.main.urls(forResourcesWithExtension: "japack", subdirectory: nil) ?? []
        return urls.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let pack = try? GoJaPack.decode(from: data) else { return nil }
            return BundledSamplePack(id: url.lastPathComponent, url: url, pack: pack)
        }
        .sorted { $0.pack.name < $1.pack.name }
    }

    func buildExportPack(name: String = "GoJa Pack") -> GoJaPack {
        let exportedItems = flashcards.map { card in
            JaPackEntry(
                tu: card.word,
                nghia: card.translation,
                cachDoc: card.phonetic ?? "",
                bai: card.sourceTitle,
                viDu: card.example
            )
        }

        return GoJaPack(
            name: name,
            summary: "Xuất từ GoJa (\(flashcards.count) từ vựng, \(sources.count) nguồn, \(customLessons.count) bài học)",
            targetLanguageCode: targetLanguageCode,
            nativeLanguageCode: nativeLanguageCode,
            items: exportedItems,
            flashcards: flashcards,
            sources: sources,
            lessons: customLessons
        )
    }

    func writeTempJaPackFile(pack: GoJaPack) throws -> URL {
        let safeName = pack.name
            .replacingOccurrences(of: "[^a-zA-Z0-9_-]", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let fileName = (safeName.isEmpty ? "GoJa-Pack" : safeName) + ".japack"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        let data = try GoJaPack.encode(pack)
        try data.write(to: url, options: .atomic)
        return url
    }

    @discardableResult
    func importJaPack(from data: Data, switchToPackLanguage: Bool = true) throws -> JaPackImportResult {
        let pack = try GoJaPack.decode(from: data)

        var addedCards = 0

        // 1. Import sequential `từ - nghĩa - cách đọc` entries into flashcards
        for entry in pack.items {
            let card = Flashcard(
                word: entry.tu,
                phonetic: entry.cachDoc.isEmpty ? nil : entry.cachDoc,
                translation: entry.nghia,
                example: entry.viDu,
                languageCode: pack.targetLanguageCode,
                sourceTitle: entry.bai ?? pack.name
            )
            if let idx = flashcards.firstIndex(where: {
                $0.word.caseInsensitiveCompare(card.word) == .orderedSame &&
                $0.languageCode == card.languageCode
            }) {
                flashcards[idx].translation = card.translation
                if let phonetic = card.phonetic { flashcards[idx].phonetic = phonetic }
                if let example = card.example { flashcards[idx].example = example }
            } else {
                flashcards.insert(card, at: 0)
                addedCards += 1
            }
        }

        // 2. Also import explicit Flashcards if included
        for card in pack.flashcards {
            if !flashcards.contains(where: {
                $0.word.caseInsensitiveCompare(card.word) == .orderedSame &&
                $0.languageCode == card.languageCode
            }) {
                flashcards.insert(card, at: 0)
                addedCards += 1
            }
        }

        // 3. Import Web/RSS sources
        var addedSources = 0
        for source in pack.sources {
            if !sources.contains(where: { $0.urlString == source.urlString }) {
                sources.append(source)
                addedSources += 1
            }
        }

        // 4. Generate/Update Learning Path units directly from pack.items + explicit pack.lessons
        let generatedFromItems = LessonCatalogService.buildLessons(from: pack)
        let combinedPackLessons = generatedFromItems + pack.lessons.filter { explicit in
            !generatedFromItems.contains(where: { $0.id == explicit.id })
        }

        var addedLessons = 0
        for lesson in combinedPackLessons {
            if let existingIdx = customLessons.firstIndex(where: { $0.id == lesson.id }) {
                customLessons[existingIdx] = lesson
            } else {
                customLessons.append(lesson)
                addedLessons += 1
            }
        }

        // 5. Record imported pack metadata
        let record = ImportedPackRecord(
            id: pack.id,
            name: pack.name,
            summary: pack.summary,
            languageCode: pack.targetLanguageCode,
            itemCount: pack.items.count + pack.flashcards.count,
            generatedLessonCount: combinedPackLessons.count,
            importedAt: Date()
        )
        importedPacks.removeAll { $0.name == record.name && $0.languageCode == record.languageCode }
        importedPacks.insert(record, at: 0)
        saveImportedPacksIndex()

        if switchToPackLanguage {
            applySuggestedLanguage(pack.targetLanguageCode)
        }

        saveLibrary()
        return JaPackImportResult(
            packName: pack.name,
            languageCode: pack.targetLanguageCode,
            addedFlashcards: addedCards,
            addedSources: addedSources,
            addedLessons: addedLessons > 0 ? addedLessons : combinedPackLessons.count
        )
    }

    func importJaPack(fromURL urlString: String) async throws -> JaPackImportResult {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw LanguageAPIError.invalidURL
        }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try importJaPack(from: data)
    }

    // MARK: - Disk I/O (Library stored in .japack format)

    private func loadLibrary() {
        if let data = try? Data(contentsOf: libraryJaPackURL),
           let pack = try? GoJaPack.decode(from: data) {
            flashcards = pack.flashcards
            sources = pack.sources.isEmpty ? Self.defaultSources : pack.sources
            customLessons = pack.lessons
            return
        }

        if let fData = try? Data(contentsOf: legacyFlashcardsURL),
           let decoded = try? JSONDecoder().decode([Flashcard].self, from: fData) {
            flashcards = decoded
        }

        if let sData = try? Data(contentsOf: legacySourcesURL),
           let decoded = try? JSONDecoder().decode([WebSource].self, from: sData),
           !decoded.isEmpty {
            sources = decoded
        } else {
            sources = Self.defaultSources
        }

        saveLibrary()
    }

    private func saveLibrary() {
        let pack = buildExportPack(name: "GoJa Local Library")
        guard let data = try? GoJaPack.encode(pack) else { return }
        try? data.write(to: libraryJaPackURL, options: .atomic)
    }

    private func loadStreakStats() {
        guard let data = try? Data(contentsOf: streakURL),
              let decoded = try? JSONDecoder().decode(StreakStats.self, from: data) else {
            streakStats = StreakStats()
            return
        }
        streakStats = decoded
        if let lastStudyKey = streakStats.studyDays.last, lastStudyKey != Self.dayKey(for: Date()) {
            streakStats.todayXP = 0
        }
    }

    private func saveStreakStats() {
        guard let data = try? JSONEncoder().encode(streakStats) else { return }
        try? data.write(to: streakURL, options: .atomic)
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyURL),
              let decoded = try? JSONDecoder().decode([DictionaryHistoryItem].self, from: data) else {
            lookupHistory = []
            return
        }
        lookupHistory = decoded
    }

    private func saveHistory() {
        guard let data = try? JSONEncoder().encode(lookupHistory) else { return }
        try? data.write(to: historyURL, options: .atomic)
    }

    private func loadImportedPacksIndex() {
        guard let data = try? Data(contentsOf: packsIndexURL),
              let decoded = try? JSONDecoder().decode([ImportedPackRecord].self, from: data) else {
            importedPacks = []
            return
        }
        importedPacks = decoded
    }

    private func saveImportedPacksIndex() {
        guard let data = try? JSONEncoder().encode(importedPacks) else { return }
        try? data.write(to: packsIndexURL, options: .atomic)
    }

    static let defaultSources: [WebSource] = [
        WebSource(
            name: "Wikipedia Ngẫu Nhiên",
            urlString: "https://en.wikipedia.org/api/rest_v1/page/random/summary",
            kind: .wikipedia,
            languageCode: "en"
        ),
        WebSource(
            name: "BBC World RSS",
            urlString: "https://feeds.bbci.co.uk/news/world/rss.xml",
            kind: .rss,
            languageCode: "en"
        ),
        WebSource(
            name: "NHK World RSS",
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
