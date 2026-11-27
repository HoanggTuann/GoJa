import SwiftUI
import UIKit

struct DictionaryView: View {
    @EnvironmentObject private var storage: StorageService

    @State private var query = ""
    @State private var sourceLangCode = ""
    @State private var targetLangCode = ""
    @State private var result: WordLookupResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var savedWord: String?
    @State private var copiedNotice = false

    private var activeSourceCode: String {
        sourceLangCode.isEmpty ? storage.targetLanguageCode : sourceLangCode
    }

    private var activeTargetCode: String {
        targetLangCode.isEmpty ? storage.nativeLanguageCode : targetLangCode
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Ngôn ngữ tra từ & dịch") {
                    HStack(spacing: 8) {
                        Picker("Từ", selection: Binding(
                            get: { activeSourceCode },
                            set: { sourceLangCode = $0 }
                        )) {
                            ForEach(LanguageOption.all) { lang in
                                Text("\(lang.flagEmoji) \(lang.name)").tag(lang.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)

                        Spacer()

                        Button {
                            let oldSource = activeSourceCode
                            let oldTarget = activeTargetCode
                            sourceLangCode = oldTarget
                            targetLangCode = oldSource
                            if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Task { await performLookup() }
                            }
                        } label: {
                            Image(systemName: "arrow.left.arrow.right.circle.fill")
                                .font(.title3)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Đổi chiều ngôn ngữ")

                        Spacer()

                        Picker("Sang", selection: Binding(
                            get: { activeTargetCode },
                            set: { targetLangCode = $0 }
                        )) {
                            ForEach(LanguageOption.all) { lang in
                                Text("\(lang.flagEmoji) \(lang.name)").tag(lang.id)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }

                Section("Nhập từ hoặc đoạn văn") {
                    TextField(
                        "Nhập từ hoặc câu (\(LanguageOption.find(activeSourceCode).nativeName))...",
                        text: $query,
                        axis: .vertical
                    )
                    .lineLimit(1...5)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await performLookup() }
                    }

                    HStack {
                        Button("Dán") {
                            if let paste = UIPasteboard.general.string {
                                query = paste
                            }
                        }
                        .buttonStyle(.bordered)

                        if !query.isEmpty {
                            Button("Xóa") {
                                query = ""
                                result = nil
                                errorMessage = nil
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()

                        Button {
                            Task { await performLookup() }
                        } label: {
                            Label("Tra & Dịch", systemImage: "magnifyingglass")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }

                if let result {
                    Section("Kết quả (\(LanguageOption.find(result.sourceLanguageCode).flagEmoji) → \(LanguageOption.find(result.targetLanguageCode).flagEmoji))") {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.word)
                                    .font(.title3.bold())
                                if let phonetic = result.phonetic {
                                    Text(phonetic)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            HStack(spacing: 12) {
                                Button {
                                    SpeechService.shared.speak(
                                        text: result.word,
                                        languageCode: result.sourceLanguageCode,
                                        audioURL: result.audioURL,
                                        rate: storage.speechRate
                                    )
                                } label: {
                                    Image(systemName: "speaker.wave.2.circle.fill")
                                        .font(.title2)
                                }
                                .buttonStyle(.borderless)

                                Button {
                                    SpeechService.shared.speak(
                                        text: result.word,
                                        languageCode: result.sourceLanguageCode,
                                        rate: max(SpeechService.minRate, storage.speechRate - 0.10),
                                        forceSynthesizer: true
                                    )
                                } label: {
                                    Image(systemName: "tortoise.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.orange)
                                }
                                .buttonStyle(.borderless)
                            }
                        }

                        if let translation = result.translation {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Bản dịch (\(LanguageOption.find(result.targetLanguageCode).name))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button {
                                        UIPasteboard.general.string = translation
                                        copiedNotice = true
                                    } label: {
                                        Label(copiedNotice ? "Đã chép" : "Sao chép", systemImage: "doc.on.doc")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                Text(translation)
                                    .font(.body)
                                    .textSelection(.enabled)
                            }
                        }

                        Button {
                            let card = Flashcard(
                                word: result.word,
                                phonetic: result.phonetic,
                                translation: result.translation ?? result.meanings.first?.definitions.first ?? "",
                                definition: result.meanings.first?.definitions.first,
                                example: result.meanings.first?.examples.first,
                                languageCode: result.sourceLanguageCode
                            )
                            storage.addOrUpdateFlashcard(card)
                            savedWord = result.word
                        } label: {
                            Label(
                                savedWord == result.word ? "Đã lưu vào Flashcard" : "Lưu vào Flashcard",
                                systemImage: savedWord == result.word ? "checkmark.circle.fill" : "plus.circle"
                            )
                        }
                    }

                    ForEach(result.meanings) { meaning in
                        Section(meaning.partOfSpeech.isEmpty ? "Từ điển" : meaning.partOfSpeech) {
                            ForEach(meaning.definitions, id: \.self) { def in
                                Text(def)
                            }
                            ForEach(meaning.examples, id: \.self) { ex in
                                Text("Ví dụ: \(ex)")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if !storage.lookupHistory.isEmpty {
                    Section {
                        ForEach(storage.lookupHistory) { item in
                            Button {
                                query = item.query
                                sourceLangCode = item.sourceLanguageCode
                                targetLangCode = item.targetLanguageCode
                                Task { await performLookup() }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.query)
                                            .font(.subheadline.bold())
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Text(item.translation)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text("\(LanguageOption.find(item.sourceLanguageCode).flagEmoji)→\(LanguageOption.find(item.targetLanguageCode).flagEmoji)")
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        HStack {
                            Text("Tra cứu gần đây")
                            Spacer()
                            Button("Xóa") {
                                storage.clearLookupHistory()
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Tra từ & Dịch")
            .onAppear {
                if sourceLangCode.isEmpty { sourceLangCode = storage.targetLanguageCode }
                if targetLangCode.isEmpty { targetLangCode = storage.nativeLanguageCode }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func performLookup() async {
        isLoading = true
        errorMessage = nil
        savedWord = nil
        copiedNotice = false
        defer { isLoading = false }

        do {
            let lookup = try await LanguageAPIService.shared.lookupWord(
                query,
                from: activeSourceCode,
                to: activeTargetCode
            )
            result = lookup
            if let translation = lookup.translation {
                storage.recordLookupHistory(
                    query: lookup.word,
                    translation: translation,
                    sourceLang: activeSourceCode,
                    targetLang: activeTargetCode
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
