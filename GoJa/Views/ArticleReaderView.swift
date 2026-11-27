import SwiftUI
import SafariServices

struct ArticleReaderView: View {
    @EnvironmentObject private var storage: StorageService
    let article: LearningArticle

    @State private var fullContent: String = ""
    @State private var translatedText: String?
    @State private var isTranslating = false
    @State private var isLoadingFullPage = false
    @State private var selectedWord: SelectedWordItem?
    @State private var showSafari = false

    struct SelectedWordItem: Identifiable {
        let id = UUID()
        let word: String
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(article.title)
                        .font(.title2.bold())

                    HStack {
                        Label(article.sourceName, systemImage: "globe")
                        Spacer()
                        Text(LanguageOption.find(article.languageCode).nativeName)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                HStack(spacing: 10) {
                    Button {
                        SpeechService.shared.speak(
                            text: fullContent,
                            languageCode: article.languageCode
                        )
                    } label: {
                        Label("Nghe", systemImage: "speaker.wave.2")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task { await translateArticle() }
                    } label: {
                        if isTranslating {
                            ProgressView()
                        } else {
                            Label("Dịch nhanh", systemImage: "translate")
                        }
                    }
                    .buttonStyle(.bordered)

                    if let urlString = article.url, URL(string: urlString) != nil {
                        Button {
                            showSafari = true
                        } label: {
                            Label("Web gốc", systemImage: "safari")
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if let translatedText {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Bản dịch (\(storage.nativeLanguage.name))")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Text(translatedText)
                            .font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }

                Divider()

                Text("Chạm vào bất kỳ từ nào bên dưới để tra nghĩa & lưu từ vựng:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(paragraphs, id: \.self) { paragraph in
                    InteractiveParagraphView(paragraph: paragraph) { word in
                        selectedWord = SelectedWordItem(word: word)
                    }
                }

                if isLoadingFullPage {
                    HStack {
                        ProgressView()
                        Text("Đang tải toàn bộ nội dung trang web...")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                } else if let urlString = article.url, fullContent.count < 350 {
                    Button("Tải thêm nội dung từ trang gốc") {
                        Task { await loadFullArticle(from: urlString) }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle("Đọc bài")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            fullContent = article.content
        }
        .sheet(item: $selectedWord) { item in
            WordLookupSheet(
                word: item.word,
                sourceLanguageCode: article.languageCode,
                sourceTitle: article.title
            )
        }
        .sheet(isPresented: $showSafari) {
            if let urlString = article.url, let url = URL(string: urlString) {
                SafariWebView(url: url)
            }
        }
    }

    private var paragraphs: [String] {
        fullContent
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func translateArticle() async {
        isTranslating = true
        defer { isTranslating = false }
        translatedText = try? await LanguageAPIService.shared.translateText(
            fullContent,
            from: article.languageCode,
            to: storage.nativeLanguageCode
        )
    }

    private func loadFullArticle(from urlString: String) async {
        isLoadingFullPage = true
        defer { isLoadingFullPage = false }
        if let loaded = try? await WebContentService.shared.fetchWebPageArticle(
            urlString: urlString,
            sourceName: article.sourceName,
            languageCode: article.languageCode
        ) {
            fullContent = loaded.content
        }
    }
}

/// Renders words in a flow layout so each word is individually tappable.
private struct InteractiveParagraphView: View {
    let paragraph: String
    let onTapWord: (String) -> Void

    private var tokens: [String] {
        paragraph.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    }

    var body: some View {
        FlowWordLayout(spacing: 5, lineSpacing: 6) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                Button {
                    let cleaned = token.trimmingCharacters(in: .punctuationCharacters)
                    if !cleaned.isEmpty {
                        onTapWord(cleaned)
                    }
                } label: {
                    Text(token)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// iOS 16 native Layout protocol for wrapping words naturally.
private struct FlowWordLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + lineSpacing
                lineHeight = 0
            }
            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(size)
            )
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// Modal sheet for quick word lookup & saving to flashcards while reading.
struct WordLookupSheet: View {
    @EnvironmentObject private var storage: StorageService
    @Environment(\.dismiss) private var dismiss

    let word: String
    let sourceLanguageCode: String
    let sourceTitle: String?

    @State private var result: WordLookupResult?
    @State private var isLoading = true
    @State private var isSaved = false

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Đang tra từ \"\(word)\"...")
                    }
                } else if let result {
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.word)
                                    .font(.title2.bold())
                                if let phonetic = result.phonetic {
                                    Text(phonetic)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                SpeechService.shared.speak(
                                    text: result.word,
                                    languageCode: sourceLanguageCode,
                                    audioURL: result.audioURL
                                )
                            } label: {
                                Image(systemName: "speaker.wave.2.circle.fill")
                                    .font(.title2)
                            }
                        }

                        if let translation = result.translation {
                            LabeledContent("Nghĩa (\(storage.nativeLanguage.name))", value: translation)
                        }
                    }

                    ForEach(result.meanings) { meaning in
                        Section(meaning.partOfSpeech.isEmpty ? "Định nghĩa" : meaning.partOfSpeech) {
                            ForEach(meaning.definitions.prefix(3), id: \.self) { def in
                                Text(def)
                            }
                            ForEach(meaning.examples.prefix(2), id: \.self) { ex in
                                Text("VD: \(ex)")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Section {
                        Button {
                            let card = Flashcard(
                                word: result.word,
                                phonetic: result.phonetic,
                                translation: result.translation ?? "(Chưa có bản dịch)",
                                definition: result.meanings.first?.definitions.first,
                                example: result.meanings.first?.examples.first,
                                languageCode: sourceLanguageCode,
                                sourceTitle: sourceTitle
                            )
                            storage.addOrUpdateFlashcard(card)
                            isSaved = true
                        } label: {
                            Label(
                                isSaved ? "Đã lưu vào Flashcard" : "Lưu vào Flashcard",
                                systemImage: isSaved ? "checkmark.circle.fill" : "plus.circle.fill"
                            )
                        }
                        .disabled(isSaved)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Tra từ nhanh")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { dismiss() }
                }
            }
            .task {
                result = try? await LanguageAPIService.shared.lookupWord(
                    word,
                    from: sourceLanguageCode,
                    to: storage.nativeLanguageCode
                )
                isLoading = false
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct SafariWebView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
