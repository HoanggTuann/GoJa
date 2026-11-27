import SwiftUI

struct DictionaryView: View {
    @EnvironmentObject private var storage: StorageService

    @State private var query = ""
    @State private var result: WordLookupResult?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var savedWord: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Tra từ & Dịch câu") {
                    HStack {
                        TextField("Nhập từ hoặc câu (\(storage.targetLanguage.nativeName))...", text: $query)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.search)
                            .onSubmit {
                                Task { await performLookup() }
                            }

                        Button("Tra") {
                            Task { await performLookup() }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    }

                    HStack {
                        Text("Ngôn ngữ:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(storage.targetLanguage.name) → \(storage.nativeLanguage.name)")
                            .font(.subheadline)
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
                    Section("Kết quả") {
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
                                    languageCode: storage.targetLanguageCode,
                                    audioURL: result.audioURL
                                )
                            } label: {
                                Image(systemName: "speaker.wave.2.circle.fill")
                                    .font(.title2)
                            }
                        }

                        if let translation = result.translation {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Bản dịch")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(translation)
                                    .font(.body)
                            }
                        }

                        Button {
                            let card = Flashcard(
                                word: result.word,
                                phonetic: result.phonetic,
                                translation: result.translation ?? "",
                                definition: result.meanings.first?.definitions.first,
                                example: result.meanings.first?.examples.first,
                                languageCode: storage.targetLanguageCode
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
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Tra từ & Dịch")
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
        defer { isLoading = false }

        do {
            result = try await LanguageAPIService.shared.lookupWord(
                query,
                from: storage.targetLanguageCode,
                to: storage.nativeLanguageCode
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
