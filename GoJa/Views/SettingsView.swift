import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var storage: StorageService

    @State private var showAddSource = false
    @State private var showJaPackImporter = false
    @State private var showJaPackExporter = false
    @State private var exportDocument: JaPackDocument?
    @State private var jaPackURLString = ""
    @State private var isImportingFromURL = false
    @State private var jaPackNotice: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Ngôn ngữ & Đề xuất học tập") {
                    Picker("Ngôn ngữ đang học", selection: $storage.targetLanguageCode) {
                        ForEach(LanguageOption.all) { lang in
                            Text("\(lang.flagEmoji) \(lang.name) (\(lang.nativeName))").tag(lang.id)
                        }
                    }

                    Picker("Ngôn ngữ chính (mẹ đẻ)", selection: $storage.nativeLanguageCode) {
                        ForEach(LanguageOption.all) { lang in
                            Text("\(lang.flagEmoji) \(lang.name) (\(lang.nativeName))").tag(lang.id)
                        }
                    }

                    Toggle("Hiển thị đề xuất ngôn ngữ học", isOn: $storage.showLanguageSuggestions)

                    if storage.showLanguageSuggestions {
                        ForEach(LanguageOption.recommendedLearningLanguages) { lang in
                            Button {
                                storage.applySuggestedLanguage(lang.id)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Text(lang.flagEmoji)
                                        .font(.title3)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(lang.name)
                                                .font(.subheadline.bold())
                                                .foregroundColor(.primary)
                                            Text("• \(lang.recommendationTag)")
                                                .font(.caption.bold())
                                                .foregroundColor(.accentColor)
                                        }
                                        Text(lang.recommendedReason)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if storage.targetLanguageCode == lang.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Tốc độ phát âm")
                            Spacer()
                            Text(String(format: "%.2f", storage.speechRate))
                                .font(.subheadline.monospacedDigit())
                                .foregroundColor(.secondary)
                        }

                        Slider(
                            value: $storage.speechRate,
                            in: SpeechService.minRate...SpeechService.maxRate,
                            step: 0.02
                        )

                        Text(SpeechService.description(for: storage.speechRate))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                    Button {
                        SpeechService.shared.speak(
                            text: samplePhrase(for: storage.targetLanguageCode),
                            languageCode: storage.targetLanguageCode,
                            rate: storage.speechRate,
                            forceSynthesizer: true
                        )
                    } label: {
                        Label("Nghe thử giọng đọc hiện tại", systemImage: "speaker.wave.2.fill")
                    }

                    Button("Khôi phục tốc độ khuyên dùng (0.40)") {
                        storage.speechRate = SpeechService.defaultRate
                    }
                } header: {
                    Text("Phát âm & Tốc độ nói")
                } footer: {
                    Text("Giảm tốc độ giúp nghe rõ âm tiết hơn khi mới học ngoại ngữ.")
                }

                Section {
                    Stepper("Mục tiêu Flashcard/ngày: \(storage.dailyGoal) từ", value: $storage.dailyGoal, in: 5...100, step: 5)
                    Stepper("Mục tiêu XP/ngày: \(storage.streakStats.dailyXPGoal) XP", value: $storage.streakStats.dailyXPGoal, in: 10...200, step: 10)
                    LabeledContent("Chuỗi Streak hiện tại", value: "\(storage.streakStats.currentStreak) ngày")
                } header: {
                    Text("Mục tiêu & Streak")
                }

                Section {
                    Button {
                        exportDocument = JaPackDocument(pack: storage.buildExportPack(name: "GoJa-\(storage.targetLanguageCode)"))
                        showJaPackExporter = true
                    } label: {
                        Label("Xuất toàn bộ dữ liệu (.japack)", systemImage: "square.and.arrow.up")
                    }

                    if let shareURL = try? storage.writeTempJaPackFile(pack: storage.buildExportPack(name: "GoJa-\(storage.targetLanguageCode)")) {
                        ShareLink(item: shareURL) {
                            Label("Chia sẻ tệp .japack", systemImage: "paperplane")
                        }
                    }

                    Button {
                        showJaPackImporter = true
                    } label: {
                        Label("Nhập từ tệp .japack / .json", systemImage: "square.and.arrow.down")
                    }

                    HStack {
                        TextField("Nhập gói .japack từ URL...", text: $jaPackURLString)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button {
                            Task { await importFromURL() }
                        } label: {
                            if isImportingFromURL {
                                ProgressView()
                            } else {
                                Text("Tải")
                            }
                        }
                        .disabled(jaPackURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isImportingFromURL)
                    }
                } header: {
                    Text("Định dạng JaPack (.japack)")
                } footer: {
                    Text("JaPack là định dạng JSON đổi đuôi sang .japack dùng để lưu, chia sẻ và nhập nhanh từ vựng, nguồn đọc & bài học.")
                }

                Section("Nguồn web & API học tập") {
                    ForEach(storage.sources) { source in
                        Toggle(isOn: Binding(
                            get: { source.isEnabled },
                            set: { _ in storage.toggleSource(id: source.id) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.name)
                                    .font(.body)
                                Text("\(source.kind.rawValue) • \(source.urlString)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .onDelete(perform: storage.deleteSources)

                    Button {
                        showAddSource = true
                    } label: {
                        Label("Thêm nguồn RSS / Web mới", systemImage: "plus.circle")
                    }
                }

                Section("API tích hợp sẵn") {
                    LabeledContent("Từ điển", value: "Free Dictionary API")
                    LabeledContent("Dịch thuật", value: "MyMemory API")
                    LabeledContent("Bài đọc", value: "Wikipedia REST + RSS + Web")
                }

                Section("Thông tin") {
                    LabeledContent("Ứng dụng", value: "GoJa")
                    LabeledContent("Hỗ trợ từ", value: "iOS 16.0+")
                }
            }
            .navigationTitle("Cài đặt")
            .sheet(isPresented: $showAddSource) {
                AddSourceSheet()
            }
            .fileExporter(
                isPresented: $showJaPackExporter,
                document: exportDocument,
                contentType: .jaPack,
                defaultFilename: "GoJa-Pack.japack"
            ) { result in
                switch result {
                case .success:
                    jaPackNotice = "Đã xuất tệp .japack thành công."
                case .failure(let error):
                    jaPackNotice = "Lỗi xuất tệp: \(error.localizedDescription)"
                }
            }
            .fileImporter(
                isPresented: $showJaPackImporter,
                allowedContentTypes: [.jaPack, .json],
                allowsMultipleSelection: false
            ) { result in
                importFromFile(result)
            }
            .alert("JaPack", isPresented: Binding(
                get: { jaPackNotice != nil },
                set: { if !$0 { jaPackNotice = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(jaPackNotice ?? "")
            }
        }
    }

    private func samplePhrase(for code: String) -> String {
        switch code {
        case "ja": return "おはようございます。今日も楽しく勉強しましょう。"
        case "ko": return "안녕하세요. 오늘도 즐겁게 공부해요."
        case "zh": return "你好，今天我们一起学习外语吧。"
        case "fr": return "Bonjour, pratiquons ensemble aujourd'hui."
        case "de": return "Guten Tag, lernen wir heute zusammen."
        case "es": return "Buenos días, aprendamos juntos hoy."
        case "vi": return "Xin chào, hãy cùng luyện tập ngoại ngữ hôm nay."
        default: return "Hello! Let us practice speaking clearly and steadily."
        }
    }

    private func importFromFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let summary = try storage.importJaPack(from: data)
            jaPackNotice = "Đã nhập gói \"\(summary.packName)\": +\(summary.addedFlashcards) từ vựng, +\(summary.addedSources) nguồn, +\(summary.addedLessons) bài học."
        } catch {
            jaPackNotice = "Không thể nhập tệp .japack: \(error.localizedDescription)"
        }
    }

    private func importFromURL() async {
        isImportingFromURL = true
        defer { isImportingFromURL = false }
        do {
            let summary = try await storage.importJaPack(fromURL: jaPackURLString)
            jaPackURLString = ""
            jaPackNotice = "Đã tải gói \"\(summary.packName)\": +\(summary.addedFlashcards) từ vựng, +\(summary.addedSources) nguồn, +\(summary.addedLessons) bài học."
        } catch {
            jaPackNotice = "Lỗi tải gói .japack: \(error.localizedDescription)"
        }
    }
}

private struct AddSourceSheet: View {
    @EnvironmentObject private var storage: StorageService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var urlString = ""
    @State private var kind: WebSource.SourceKind = .rss
    @State private var languageCode = "en"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Tên nguồn (vd: NHK Easy)", text: $name)
                TextField("URL RSS hoặc trang web", text: $urlString)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Picker("Loại nguồn", selection: $kind) {
                    ForEach(WebSource.SourceKind.allCases, id: \.self) { item in
                        Text(item.rawValue).tag(item)
                    }
                }

                Picker("Ngôn ngữ", selection: $languageCode) {
                    ForEach(LanguageOption.all) { lang in
                        Text(lang.name).tag(lang.id)
                    }
                }
            }
            .navigationTitle("Thêm nguồn học")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Thêm") {
                        let source = WebSource(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            urlString: urlString.trimmingCharacters(in: .whitespacesAndNewlines),
                            kind: kind,
                            languageCode: languageCode
                        )
                        storage.addSource(source)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || urlString.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
