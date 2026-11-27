import Foundation
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Custom GoJa pack format (.japack), backed by JSON structure.
    static let jaPack = UTType(exportedAs: "com.hoanggtuann.goja.japack", conformingTo: .json)
}

/// Portable GoJa learning pack stored with the `.japack` extension (JSON payload).
struct GoJaPack: Codable, Identifiable {
    let format: String
    let version: Int
    let id: UUID
    var name: String
    var summary: String
    var author: String
    var targetLanguageCode: String
    var nativeLanguageCode: String
    var createdAt: Date
    var flashcards: [Flashcard]
    var sources: [WebSource]
    var lessons: [LessonUnit]

    init(
        id: UUID = UUID(),
        name: String,
        summary: String = "Gói dữ liệu học ngoại ngữ GoJa (.japack)",
        author: String = "GoJa User",
        targetLanguageCode: String,
        nativeLanguageCode: String,
        createdAt: Date = Date(),
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
        self.flashcards = flashcards
        self.sources = sources
        self.lessons = lessons
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
            // Fallback for packs encoded with default JSON date strategy
            return try JSONDecoder().decode(GoJaPack.self, from: data)
        }
    }
}

struct JaPackImportResult {
    let packName: String
    let addedFlashcards: Int
    let addedSources: Int
    let addedLessons: Int
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
