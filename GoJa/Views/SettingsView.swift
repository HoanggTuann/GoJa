import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var storage: StorageService
    @State private var showAddSource = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Ngôn ngữ học") {
                    Picker("Ngôn ngữ đang học", selection: $storage.targetLanguageCode) {
                        ForEach(LanguageOption.all) { lang in
                            Text("\(lang.name) (\(lang.nativeName))").tag(lang.id)
                        }
                    }

                    Picker("Ngôn ngữ mẹ đẻ", selection: $storage.nativeLanguageCode) {
                        ForEach(LanguageOption.all) { lang in
                            Text("\(lang.name) (\(lang.nativeName))").tag(lang.id)
                        }
                    }

                    Stepper("Mục tiêu mỗi ngày: \(storage.dailyGoal) từ", value: $storage.dailyGoal, in: 5...100, step: 5)
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
