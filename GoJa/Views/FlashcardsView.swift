import SwiftUI
import UniformTypeIdentifiers

struct FlashcardsView: View {
    @EnvironmentObject private var storage: StorageService
    @State private var showReviewSession = false
    @State private var showAddSheet = false
    @State private var showImporter = false
    @State private var exportDocument: JaPackDocument?
    @State private var showExporter = false
    @State private var statusAlertMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Tiến độ hôm nay") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Đã ôn: \(storage.todayReviewedCount) / \(storage.dailyGoal) từ")
                                .font(.subheadline.bold())
                            Spacer()
                            Text("Cần ôn: \(storage.dueFlashcards.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        ProgressView(
                            value: Double(min(storage.todayReviewedCount, storage.dailyGoal)),
                            total: Double(max(1, storage.dailyGoal))
                        )
                    }
                    .padding(.vertical, 4)

                    Button {
                        showReviewSession = true
                    } label: {
                        Label("Bắt đầu ôn tập (\(storage.dueFlashcards.count) thẻ)", systemImage: "play.fill")
                    }
                    .disabled(storage.dueFlashcards.isEmpty)
                }

                Section("Từ vựng đã lưu (\(storage.flashcards.count))") {
                    if storage.flashcards.isEmpty {
                        Text("Chưa có từ vựng nào. Hãy tra từ, chạm vào từ khi đọc báo hoặc nhập gói .japack.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(storage.flashcards) { card in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 6) {
                                        Text(LanguageOption.find(card.languageCode).flagEmoji)
                                        Text(card.word)
                                            .font(.headline)
                                        if let phonetic = card.phonetic {
                                            Text(phonetic)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Text(card.translation)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button {
                                    SpeechService.shared.speak(
                                        text: card.word,
                                        languageCode: card.languageCode,
                                        rate: storage.speechRate,
                                        forceSynthesizer: true
                                    )
                                } label: {
                                    Image(systemName: "speaker.wave.2")
                                }
                                .buttonStyle(.borderless)
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete(perform: storage.deleteFlashcards)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Ôn tập")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Menu {
                        Button {
                            exportDocument = JaPackDocument(pack: storage.buildExportPack(name: "GoJa Flashcards"))
                            showExporter = true
                        } label: {
                            Label("Xuất gói .japack", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            showImporter = true
                        } label: {
                            Label("Nhập gói .japack", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "doc.zipper")
                    }

                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showReviewSession) {
                FlashcardReviewSheet()
            }
            .sheet(isPresented: $showAddSheet) {
                AddFlashcardSheet()
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: .jaPack,
                defaultFilename: "GoJa-Vocabulary.japack"
            ) { result in
                switch result {
                case .success:
                    statusAlertMessage = "Đã xuất gói từ vựng .japack thành công."
                case .failure(let error):
                    statusAlertMessage = "Không thể xuất tệp: \(error.localizedDescription)"
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.jaPack, .json],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .alert("JaPack", isPresented: Binding(
                get: { statusAlertMessage != nil },
                set: { if !$0 { statusAlertMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(statusAlertMessage ?? "")
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            let data = try Data(contentsOf: url)
            let summary = try storage.importJaPack(from: data)
            statusAlertMessage = "Đã nhập \"\(summary.packName)\": +\(summary.addedFlashcards) từ vựng, +\(summary.addedSources) nguồn, +\(summary.addedLessons) bài học."
        } catch {
            statusAlertMessage = "Lỗi đọc tệp .japack: \(error.localizedDescription)"
        }
    }
}

private struct FlashcardReviewSheet: View {
    @EnvironmentObject private var storage: StorageService
    @Environment(\.dismiss) private var dismiss

    @State private var showAnswer = false

    private var currentCard: Flashcard? {
        storage.dueFlashcards.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let card = currentCard {
                    Spacer()

                    VStack(spacing: 12) {
                        Text(card.word)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)

                        if let phonetic = card.phonetic {
                            Text(phonetic)
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }

                        HStack(spacing: 10) {
                            Button {
                                SpeechService.shared.speak(
                                    text: card.word,
                                    languageCode: card.languageCode,
                                    rate: storage.speechRate,
                                    forceSynthesizer: true
                                )
                            } label: {
                                Label("Phát âm", systemImage: "speaker.wave.2.fill")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                SpeechService.shared.speak(
                                    text: card.word,
                                    languageCode: card.languageCode,
                                    rate: max(SpeechService.minRate, storage.speechRate - 0.10),
                                    forceSynthesizer: true
                                )
                            } label: {
                                Label("Chậm", systemImage: "tortoise.fill")
                            }
                            .buttonStyle(.bordered)
                        }

                        if showAnswer {
                            Divider().padding(.vertical, 8)

                            Text(card.translation)
                                .font(.title2)
                                .foregroundColor(.accentColor)

                            if let def = card.definition {
                                Text(def)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    Spacer()

                    if !showAnswer {
                        Button("Hiện đáp án") {
                            showAnswer = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else {
                        HStack(spacing: 12) {
                            ForEach(ReviewQuality.allCases, id: \.rawValue) { quality in
                                Button(quality.title) {
                                    storage.markReviewed(cardID: card.id, quality: quality)
                                    showAnswer = false
                                }
                                .buttonStyle(.bordered)
                                .tint(quality == .forgot ? .red : (quality == .hard ? .orange : .green))
                            }
                        }
                    }
                } else {
                    ContentUnavailableFallbackView()
                }
            }
            .padding(.bottom, 24)
            .navigationTitle("Ôn tập Flashcard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}

private struct ContentUnavailableFallbackView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("Hoàn thành!")
                .font(.title2.bold())
            Text("Bạn đã ôn hết tất cả thẻ đến hạn.")
                .foregroundColor(.secondary)
        }
    }
}

private struct AddFlashcardSheet: View {
    @EnvironmentObject private var storage: StorageService
    @Environment(\.dismiss) private var dismiss

    @State private var word = ""
    @State private var translation = ""
    @State private var example = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Từ vựng", text: $word)
                    .textInputAutocapitalization(.never)
                TextField("Nghĩa", text: $translation)
                TextField("Ví dụ (không bắt buộc)", text: $example)
            }
            .navigationTitle("Thêm từ vựng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        let card = Flashcard(
                            word: word.trimmingCharacters(in: .whitespacesAndNewlines),
                            translation: translation.trimmingCharacters(in: .whitespacesAndNewlines),
                            example: example.isEmpty ? nil : example,
                            languageCode: storage.targetLanguageCode
                        )
                        storage.addOrUpdateFlashcard(card)
                        dismiss()
                    }
                    .disabled(word.trimmingCharacters(in: .whitespaces).isEmpty || translation.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
