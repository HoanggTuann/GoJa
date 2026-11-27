import Foundation

/// Fetches learning articles from Wikipedia REST API, RSS/Atom feeds, and arbitrary Web URLs.
final class WebContentService {
    static let shared = WebContentService()
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchArticles(from source: WebSource) async throws -> [LearningArticle] {
        switch source.kind {
        case .wikipedia:
            let article = try await fetchWikipediaRandom(languageCode: source.languageCode, sourceName: source.name)
            return [article]
        case .rss:
            return try await fetchRSSArticles(
                urlString: source.urlString,
                sourceName: source.name,
                languageCode: source.languageCode
            )
        case .webPage:
            let article = try await fetchWebPageArticle(
                urlString: source.urlString,
                sourceName: source.name,
                languageCode: source.languageCode
            )
            return [article]
        }
    }

    func fetchWikipediaRandom(languageCode: String, sourceName: String = "Wikipedia") async throws -> LearningArticle {
        let urlString = "https://\(languageCode).wikipedia.org/api/rest_v1/page/random/summary"
        guard let url = URL(string: urlString) else { throw LanguageAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("GoJa-iOS/1.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        let dto = try JSONDecoder().decode(WikiSummaryDTO.self, from: data)

        return LearningArticle(
            id: "wiki-\(dto.pageid ?? Int.random(in: 1...999999))",
            title: dto.title,
            summary: dto.description ?? "",
            content: dto.extract,
            url: dto.content_urls?.mobile?.page ?? dto.content_urls?.desktop?.page,
            sourceName: sourceName,
            languageCode: languageCode,
            imageURL: dto.thumbnail?.source,
            fetchedAt: Date()
        )
    }

    func fetchRSSArticles(urlString: String, sourceName: String, languageCode: String) async throws -> [LearningArticle] {
        guard let url = URL(string: urlString) else { throw LanguageAPIError.invalidURL }
        let (data, _) = try await session.data(from: url)
        let parser = RSSFeedParser(sourceName: sourceName, languageCode: languageCode)
        return parser.parse(data: data)
    }

    func fetchWebPageArticle(urlString: String, sourceName: String? = nil, languageCode: String) async throws -> LearningArticle {
        var normalized = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.lowercased().hasPrefix("http") {
            normalized = "https://" + normalized
        }
        guard let url = URL(string: normalized) else { throw LanguageAPIError.invalidURL }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""

        let title = Self.extractTitle(from: html) ?? url.host ?? "Trang Web"
        let cleanText = Self.extractReadableText(from: html)
        let summary = String(cleanText.prefix(160))

        return LearningArticle(
            id: "web-\(normalized.hashValue)",
            title: title,
            summary: summary,
            content: cleanText.isEmpty ? "Không trích xuất được nội dung văn bản từ trang này." : cleanText,
            url: normalized,
            sourceName: sourceName ?? (url.host ?? "Web"),
            languageCode: languageCode,
            imageURL: nil,
            fetchedAt: Date()
        )
    }

    // MARK: - Lightweight HTML Reader Extractor

    private static func extractTitle(from html: String) -> String? {
        guard let range = html.range(of: "<title[^>]*>(.*?)</title>", options: [.regularExpression, .caseInsensitive]) else {
            return nil
        }
        let raw = String(html[range])
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        return decodeHTMLEntities(raw).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func extractReadableText(from html: String) -> String {
        var text = html
        let stripBlocks = ["<script[\\s\\S]*?</script>", "<style[\\s\\S]*?</style>", "<noscript[\\s\\S]*?</noscript>"]
        for pattern in stripBlocks {
            text = text.replacingOccurrences(of: pattern, with: " ", options: [.regularExpression, .caseInsensitive])
        }
        text = text.replacingOccurrences(of: "</(p|div|li|h1|h2|h3|h4|br)>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        text = decodeHTMLEntities(text)

        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces) }
            .filter { $0.count > 25 }

        return lines.prefix(60).joined(separator: "\n\n")
    }

    static func decodeHTMLEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}

// MARK: - DTO & RSS Parser

private struct WikiSummaryDTO: Decodable {
    struct Thumbnail: Decodable { let source: String? }
    struct ContentURLs: Decodable {
        struct PageURL: Decodable { let page: String? }
        let desktop: PageURL?
        let mobile: PageURL?
    }
    let pageid: Int?
    let title: String
    let description: String?
    let extract: String
    let thumbnail: Thumbnail?
    let content_urls: ContentURLs?
}

private final class RSSFeedParser: NSObject, XMLParserDelegate {
    private let sourceName: String
    private let languageCode: String
    private var articles: [LearningArticle] = []

    private var currentElement = ""
    private var inItem = false
    private var titleBuffer = ""
    private var summaryBuffer = ""
    private var linkBuffer = ""

    init(sourceName: String, languageCode: String) {
        self.sourceName = sourceName
        self.languageCode = languageCode
    }

    func parse(data: Data) -> [LearningArticle] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return Array(articles.prefix(20))
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName.lowercased()
        if currentElement == "item" || currentElement == "entry" {
            inItem = true
            titleBuffer = ""
            summaryBuffer = ""
            linkBuffer = ""
        } else if inItem && currentElement == "link", let href = attributeDict["href"], linkBuffer.isEmpty {
            linkBuffer = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch currentElement {
        case "title":
            titleBuffer += string
        case "description", "summary", "content:encoded", "content":
            summaryBuffer += string
        case "link":
            linkBuffer += string
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased()
        if name == "item" || name == "entry" {
            inItem = false
            let cleanTitle = WebContentService.decodeHTMLEntities(titleBuffer).trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanSummary = WebContentService.decodeHTMLEntities(
                summaryBuffer.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            ).replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
             .trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanLink = linkBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

            if !cleanTitle.isEmpty {
                articles.append(
                    LearningArticle(
                        id: "rss-\(cleanLink.isEmpty ? cleanTitle : cleanLink)",
                        title: cleanTitle,
                        summary: cleanSummary,
                        content: cleanSummary.isEmpty ? cleanTitle : cleanSummary,
                        url: cleanLink.isEmpty ? nil : cleanLink,
                        sourceName: sourceName,
                        languageCode: languageCode,
                        imageURL: nil,
                        fetchedAt: Date()
                    )
                )
            }
        }
    }
}
