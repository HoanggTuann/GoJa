import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Custom GoJa pack format (.japack), backed by JSON structure.
    static let jaPack = UTType(exportedAs: "com.hoanggtuann.goja.japack", conformingTo: .json)
}

/// Simple extensible vocabulary entry inside a `.japack` file: từ - nghĩa - cách đọc.
/// Supports Vietnamese keys (`tu`, `nghia`, `cachDoc`), English keys (`word`, `meaning`, `reading`),
/// and optional fields (`unit`, `example`, `note`) so users can append more attributes later.
struct JaPackEntry: Codable, Hashable, Identifiable {
    var id: String { "\(tu)|\(nghia)|\(cachDoc)" }

    var tu: String
    var nghia: String
    var cachDoc: String
    var bai: String?
    var viDu: String?
    var ghiChu: String?

    init(
        tu: String,
        nghia: String,
        cachDoc: String = "",
        bai: String? = nil,
        viDu: String? = nil,
        ghiChu: String? = nil
    ) {
        self.tu = tu
        self.nghia = nghia
        self.cachDoc = cachDoc
        self.bai = bai
        self.viDu = viDu
        self.ghiChu = ghiChu
    }

    private enum CodingKeys: String, CodingKey {
        case tu, nghia, cachDoc, bai, viDu, ghiChu
        case tuAccent = "từ"
        case nghiaAccent = "nghĩa"
        case cachDocSnake = "cach_doc"
        case cachDocAccent = "cách đọc"
        case word, term, meaning, translation, reading, phonetic, pronunciation
        case unit, topic, lesson, example, note
    }

    init(from decoder: Decoder) throws {
        // Support shorthand string: "từ - nghĩa - cách đọc" or "từ | nghĩa | cách đọc"
        if let single = try? decoder.singleValueContainer(),
           let line = try? single.decode(String.self) {
            let separator: Character = line.contains("|") ? "|" : "-"
            let parts = line.split(separator: separator, maxSplits: 2).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            self.tu = parts.indices.contains(0) ? parts[0] : ""
            self.nghia = parts.indices.contains(1) ? parts[1] : ""
            self.cachDoc = parts.indices.contains(2) ? parts[2] : ""
            self.bai = nil
            self.viDu = nil
            self.ghiChu = nil
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.tu = (try? Self.decodeFirstString(in: container, keys: [.tu, .tuAccent, .word, .term])) ?? ""
        self.nghia = (try? Self.decodeFirstString(in: container, keys: [.nghia, .nghiaAccent, .meaning, .translation])) ?? ""
        self.cachDoc = (try? Self.decodeFirstString(in: container, keys: [.cachDoc, .cachDocSnake, .cachDocAccent, .reading, .phonetic, .pronunciation])) ?? ""
        self.bai = try? Self.decodeFirstString(in: container, keys: [.bai, .unit, .topic, .lesson])
        self.viDu = try? Self.decodeFirstString(in: container, keys: [.viDu, .example])
        self.ghiChu = try? Self.decodeFirstString(in: container, keys: [.ghiChu, .note])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tu, forKey: .tu)
        try container.encode(nghia, forKey: .nghia)
        try container.encode(cachDoc, forKey: .cachDoc)
        try container.encodeIfPresent(bai, forKey: .bai)
        try container.encodeIfPresent(viDu, forKey: .viDu)
        try container.encodeIfPresent(ghiChu, forKey: .ghiChu)
    }

    private static func decodeFirstString(
        in container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) throws -> String? {
        for key in keys {
            if let value = try container.decodeIfPresent(String.self, forKey: key),
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }
}

/// Portable GoJa learning pack stored with the `.japack` extension (JSON payload).
struct GoJaPack: Codable, Identifiable {
    var format: String
    var version: Int
    var id: UUID
    var name: String
    var summary: String
    var author: String
    var targetLanguageCode: String
    var nativeLanguageCode: String
    var createdAt: Date
    /// Sequential `từ - nghĩa - cách đọc` entries that auto-generate flashcards & learning units.
    var items: [JaPackEntry]
    var flashcards: [Flashcard]
    var sources: [WebSource]
    var lessons: [LessonUnit]

    init(
        id: UUID = UUID(),
        name: String,
        summary: String = "Gói dữ liệu học ngoại ngữ GoJa (.japack)",
        author: String = "GoJa User",
        targetLanguageCode: String,
        nativeLanguageCode: String = "vi",
        createdAt: Date = Date(),
        items: [JaPackEntry] = [],
        flashcards: [Flashcard] = [],
        sources: [WebSource] = [],
        lessons: [LessonUnit] = []
    ) {
        self.format = "JaPack"
        self.version = 1
        self.id = id
        self.name = name
        self.summary = summary
        self.author = author
        self.targetLanguageCode = targetLanguageCode
        self.nativeLanguageCode = nativeLanguageCode
        self.createdAt = createdAt
        self.items = items
        self.flashcards = flashcards
        self.sources = sources
        self.lessons = lessons
    }

    private enum CodingKeys: String, CodingKey {
        case format, version, id, name, summary, author
        case targetLanguageCode, language, lang
        case nativeLanguageCode, nativeLanguage
        case createdAt, items, entries, data, flashcards, sources, lessons
    }

    init(from decoder: Decoder) throws {
        // Allow bare JSON array of `từ - nghĩa - cách đọc` entries at top level
        if let arrayContainer = try? decoder.singleValueContainer(),
           let rawEntries = try? arrayContainer.decode([JaPackEntry].self) {
            self.format = "JaPack"
            self.version = 1
            self.id = UUID()
            self.name = "Gói từ vựng JaPack"
            self.summary = "Nhập từ danh sách JSON (\(rawEntries.count) mục)"
            self.author = "GoJa User"
            self.targetLanguageCode = "en"
            self.nativeLanguageCode = "vi"
            self.createdAt = Date()
            self.items = rawEntries.filter { !$0.tu.isEmpty && !$0.nghia.isEmpty }
            self.flashcards = []
            self.sources = []
            self.lessons = []
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.format = (try? container.decodeIfPresent(String.self, forKey: .format)) ?? "JaPack"
        self.version = (try? container.decodeIfPresent(Int.self, forKey: .version)) ?? 1
        self.id = (try? container.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        self.name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? "Gói học GoJa"
        self.summary = (try? container.decodeIfPresent(String.self, forKey: .summary)) ?? ""
        self.author = (try? container.decodeIfPresent(String.self, forKey: .author)) ?? "GoJa"
        self.targetLanguageCode =
            (try? container.decodeIfPresent(String.self, forKey: .targetLanguageCode))
            ?? (try? container.decodeIfPresent(String.self, forKey: .language))
            ?? (try? container.decodeIfPresent(String.self, forKey: .lang))
            ?? "en"
        self.nativeLanguageCode =
            (try? container.decodeIfPresent(String.self, forKey: .nativeLanguageCode))
            ?? (try? container.decodeIfPresent(String.self, forKey: .nativeLanguage))
            ?? "vi"
        self.createdAt = (try? container.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()

        let decodedItems =
            (try? container.decodeIfPresent([JaPackEntry].self, forKey: .items))
            ?? (try? container.decodeIfPresent([JaPackEntry].self, forKey: .entries))
            ?? (try? container.decodeIfPresent([JaPackEntry].self, forKey: .data))
            ?? []
        self.items = decodedItems.filter { !$0.tu.isEmpty && !$0.nghia.isEmpty }

        self.flashcards = (try? container.decodeIfPresent([Flashcard].self, forKey: .flashcards)) ?? []
        self.sources = (try? container.decodeIfPresent([WebSource].self, forKey: .sources)) ?? []
        self.lessons = (try? container.decodeIfPresent([LessonUnit].self, forKey: .lessons)) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(format, forKey: .format)
        try container.encode(version, forKey: .version)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(summary, forKey: .summary)
        try container.encode(author, forKey: .author)
        try container.encode(targetLanguageCode, forKey: .targetLanguageCode)
        try container.encode(nativeLanguageCode, forKey: .nativeLanguageCode)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(items, forKey: .items)
        try container.encode(flashcards, forKey: .flashcards)
        try container.encode(sources, forKey: .sources)
        try container.encode(lessons, forKey: .lessons)
    }

    static func encode(_ pack: GoJaPack) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(pack)
    }

    static func decode(from data: Data) throws -> GoJaPack {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(GoJaPack.self, from: data)
        } catch {
            return try JSONDecoder().decode(GoJaPack.self, from: data)
        }
    }
}

struct JaPackImportResult {
    let packName: String
    let languageCode: String
    let addedFlashcards: Int
    let addedSources: Int
    let addedLessons: Int
}

/// Metadata summary of an imported `.japack` pack stored locally so users can inspect or switch to it.
struct ImportedPackRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var summary: String
    var languageCode: String
    var itemCount: Int
    var generatedLessonCount: Int
    var importedAt: Date
}

/// FileDocument wrapper enabling `.fileExporter` / `.fileImporter` for `.japack` files.
struct JaPackDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.jaPack, .json] }
    static var writableContentTypes: [UTType] { [.jaPack] }

    var pack: GoJaPack

    init(pack: GoJaPack) {
        self.pack = pack
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.pack = try GoJaPack.decode(from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try GoJaPack.encode(pack)
        return FileWrapper(regularFileWithContents: data)
    }
}
