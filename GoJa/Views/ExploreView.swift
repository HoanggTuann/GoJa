import SwiftUI

struct ExploreView: View {
    @EnvironmentObject private var storage: StorageService

    @State private var articles: [LearningArticle] = []
    @State private var customURL: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedArticle: LearningArticle?

    var body: some View {
        NavigationStack {
            List {
                Section("Mở trang web bất kỳ để học") {
                    HStack {
                        TextField("Nhập URL (vd: bbc.com/news)", text: $customURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Button("Đọc") {
                            Task { await openCustomURL() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(customURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    }
                }

                Section {
                    Button {
                        Task { await loadWikipediaRandom() }
                    } label: {
                        Label("Tải bài Wikipedia ngẫu nhiên (\(storage.targetLanguage.nativeName))", systemImage: "sparkles")
                    }
                    .disabled(isLoading)

                    Button {
                        Task { await refreshAllSources() }
                    } label: {
                        Label("Cập nhật bài từ các nguồn RSS / Web", systemImage: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }

                Section("Bài đọc (\(articles.count))") {
                    if articles.isEmpty && !isLoading {
                        Text("Chưa có bài viết nào. Nhấn cập nhật hoặc tải bài Wikipedia ngẫu nhiên.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(articles) { article in
                            NavigationLink(destination: ArticleReaderView(article: article)) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(article.title)
                                        .font(.headline)
                                        .lineLimit(2)

                                    if !article.summary.isEmpty {
                                        Text(article.summary)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }

                                    HStack {
                                        Text(article.sourceName)
                                        Text("•")
                                        Text(LanguageOption.find(article.languageCode).nativeName)
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Đọc & Nguồn")
            .overlay {
                if isLoading {
                    ProgressView("Đang tải nội dung...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationDestination(item: $selectedArticle) { article in
                ArticleReaderView(article: article)
            }
            .task {
                if articles.isEmpty {
                    await refreshAllSources()
                }
            }
        }
    }

    private func loadWikipediaRandom() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let article = try await WebContentService.shared.fetchWikipediaRandom(
                languageCode: storage.targetLanguageCode
            )
            articles.insert(article, at: 0)
        } catch {
            errorMessage = "Không thể tải Wikipedia: \(error.localizedDescription)"
        }
    }

    private func openCustomURL() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let article = try await WebContentService.shared.fetchWebPageArticle(
                urlString: customURL,
                languageCode: storage.targetLanguageCode
            )
            articles.insert(article, at: 0)
            selectedArticle = article
        } catch {
            errorMessage = "Không thể mở trang web: \(error.localizedDescription)"
        }
    }

    private func refreshAllSources() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let enabledSources = storage.sources.filter { $0.isEnabled }
        var loaded: [LearningArticle] = []

        for source in enabledSources {
            if let items = try? await WebContentService.shared.fetchArticles(from: source) {
                loaded.append(contentsOf: items)
            }
        }

        if loaded.isEmpty {
            errorMessage = "Không tải được bài viết từ các nguồn đã bật. Kiểm tra kết nối mạng."
        } else {
            articles = loaded
        }
    }
}
