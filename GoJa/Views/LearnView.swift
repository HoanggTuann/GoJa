import SwiftUI
import UniformTypeIdentifiers

struct LearnView: View {
    @EnvironmentObject private var storage: StorageService
    @State private var activeLesson: LessonUnit?
    @State private var showJaPackImporter = false
    @State private var packImportNotice: String?

    private var curriculumLessons: [LessonUnit] {
        LessonCatalogService.lessons(
            for: storage.targetLanguageCode,
            customLessons: storage.customLessons
        )
    }

    private var flashcardPracticeLesson: LessonUnit? {
        LessonCatalogService.buildFlashcardPracticeLesson(
            from: storage.flashcards,
            languageCode: storage.targetLanguageCode
        )
    }

    private var samplePacks: [StorageService.BundledSamplePack] {
        storage.bundledSamplePacks()
    }

    var body: some View {
        NavigationStack {
            List {
                // Streak & Daily XP section (Duolingo-style foundation)
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 16) {
                            HStack(spacing: 6) {
                                Image(systemName: "flame.fill")
                                    .foregroundColor(storage.streakStats.currentStreak > 0 ? .orange : .secondary)
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(storage.streakStats.currentStreak) ngày")
                                        .font(.headline)
                                    Text("Chuỗi Streak")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Divider().frame(height: 32)

                            HStack(spacing: 6) {
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.yellow)
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(storage.streakStats.totalXP) XP")
                                        .font(.headline)
                                    Text("Kỷ lục: \(storage.streakStats.longestStreak) ngày")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Mục tiêu hôm nay: \(storage.streakStats.todayXP) / \(storage.streakStats.dailyXPGoal) XP")
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                if storage.streakStats.todayXP >= storage.streakStats.dailyXPGoal {
                                    Label("Đạt mục tiêu", systemImage: "checkmark.seal.fill")
                                        .font(.caption.bold())
                                        .foregroundColor(.green)
                                }
                            }
                            ProgressView(
                                value: Double(min(storage.streakStats.todayXP, storage.streakStats.dailyXPGoal)),
                                total: Double(max(1, storage.streakStats.dailyXPGoal))
                            )
                            .tint(.orange)
                        }

                        // 7-day Streak calendar row
                        HStack {
                            ForEach(storage.last7DaysActivity(), id: \.dateKey) { day in
                                VStack(spacing: 4) {
                                    Image(systemName: day.completed ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(day.completed ? .orange : Color(.tertiaryLabel))
                                        .font(.body)
                                    Text(day.label)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 6)
                } header: {
                    HStack {
                        Text("Tiến độ học tập")
                        Spacer()
                        Menu {
                            ForEach(LanguageOption.all.filter { $0.id != storage.nativeLanguageCode }) { lang in
                                Button {
                                    storage.targetLanguageCode = lang.id
                                } label: {
                                    Label("\(lang.flagEmoji) \(lang.name)", systemImage: lang.id == storage.targetLanguageCode ? "checkmark" : "")
                                }
                            }
                        } label: {
                            Text("\(storage.targetLanguage.flagEmoji) \(storage.targetLanguage.name)")
                                .font(.caption.bold())
                        }
                    }
                }

                if let practice = flashcardPracticeLesson {
                    Section("Luyện tập từ vựng của bạn") {
                        LessonRowView(
                            lesson: practice,
                            isCompleted: false,
                            accentColor: .purple
                        ) {
                            activeLesson = practice
                        }
                    }
                }

                Section("Lộ trình bài học (\(storage.targetLanguage.nativeName))") {
                    if curriculumLessons.isEmpty {
                        Text("Chưa có bài học cho ngôn ngữ này. Bạn có thể nhập thêm gói .japack bên dưới.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(curriculumLessons) { lesson in
                            let completed = storage.streakStats.completedLessonIDs.contains(lesson.id)
                            LessonRowView(
                                lesson: lesson,
                                isCompleted: completed,
                                accentColor: completed ? .green : .accentColor
                            ) {
                                activeLesson = lesson
                            }
                        }
                    }
                }

                Section {
                    ForEach(samplePacks) { sample in
                        let isImported = storage.importedPacks.contains(where: {
                            $0.name == sample.pack.name && $0.languageCode == sample.pack.targetLanguageCode
                        })
                        Button {
                            loadSamplePack(sample)
                        } label: {
                            HStack {
                                Text(LanguageOption.find(sample.pack.targetLanguageCode).flagEmoji)
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(sample.pack.name)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.primary)
                                    Text("\(sample.pack.items.count) từ (từ - nghĩa - cách đọc) • tự tạo lộ trình")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(isImported ? "Đã nạp" : "Nạp test")
                                    .font(.caption.bold())
                                    .foregroundColor(isImported ? .green : .accentColor)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        showJaPackImporter = true
                    } label: {
                        Label("Nhập tệp .japack của riêng bạn", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Gói JaPack (.japack)")
                } footer: {
                    Text("Nạp gói .japack (từ - nghĩa - cách đọc) sẽ tự động thêm Flashcard và cập nhật Lộ trình bài học ở trên.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Học tập")
            .fullScreenCover(item: $activeLesson) { lesson in
                LessonSessionView(lesson: lesson)
            }
            .fileImporter(
                isPresented: $showJaPackImporter,
                allowedContentTypes: [.jaPack, .json],
                allowsMultipleSelection: false
            ) { result in
                importJaPackFile(result)
            }
            .alert("Cập nhật từ JaPack", isPresented: Binding(
                get: { packImportNotice != nil },
                set: { if !$0 { packImportNotice = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(packImportNotice ?? "")
            }
        }
    }

    private func loadSamplePack(_ sample: StorageService.BundledSamplePack) {
        do {
            let data = try Data(contentsOf: sample.url)
            let result = try storage.importJaPack(from: data, switchToPackLanguage: true)
            packImportNotice = "Đã nạp \"\(result.packName)\" (\(LanguageOption.find(result.languageCode).name)): +\(result.addedFlashcards) từ mới và cập nhật \(result.addedLessons) bài học vào lộ trình."
        } catch {
            packImportNotice = "Không thể nạp gói mẫu: \(error.localizedDescription)"
        }
    }

    private func importJaPackFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let summary = try storage.importJaPack(from: data, switchToPackLanguage: true)
            packImportNotice = "Đã nhập \"\(summary.packName)\": +\(summary.addedFlashcards) từ mới, cập nhật \(summary.addedLessons) bài học cho \(LanguageOption.find(summary.languageCode).name)."
        } catch {
            packImportNotice = "Lỗi đọc tệp .japack: \(error.localizedDescription)"
        }
    }
}

private struct LessonRowView: View {
    let lesson: LessonUnit
    let isCompleted: Bool
    let accentColor: Color
    let onStart: () -> Void

    var body: some View {
        Button(action: onStart) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 46, height: 46)
                    Image(systemName: lesson.iconName)
                        .font(.title3)
                        .foregroundColor(accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        if lesson.unitNumber > 0 {
                            Text("Bài \(lesson.unitNumber)")
                                .font(.caption.bold())
                                .foregroundColor(accentColor)
                        }
                        Text("• \(lesson.exercises.count) câu")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("• +\(lesson.xpReward) XP")
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                    }

                    Text(lesson.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(lesson.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: isCompleted ? "checkmark.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(isCompleted ? .green : accentColor)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Duolingo-Style Lesson Session Runner

private struct LessonSessionView: View {
    @EnvironmentObject private var storage: StorageService
    @Environment(\.dismiss) private var dismiss

    let lesson: LessonUnit

    @State private var currentIndex = 0
    @State private var selectedOption: String?
    @State private var builtTokens: [IndexedToken] = []
    @State private var typedAnswer = ""
    @State private var hasChecked = false
    @State private var isCurrentCorrect = false
    @State private var correctCount = 0
    @State private var isFinished = false

    struct IndexedToken: Identifiable, Hashable {
        let id: Int
        let text: String
    }

    private var currentExercise: LessonExercise? {
        guard currentIndex < lesson.exercises.count else { return nil }
        return lesson.exercises[currentIndex]
    }

    private var availableTokens: [IndexedToken] {
        guard let ex = currentExercise else { return [] }
        return ex.options.enumerated().map { IndexedToken(id: $0.offset, text: $0.element) }
    }

    private var progress: Double {
        guard !lesson.exercises.isEmpty else { return 1 }
        return isFinished ? 1.0 : Double(currentIndex) / Double(lesson.exercises.count)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ProgressView(value: progress)
                    .tint(.green)
                    .padding(.horizontal)

                if isFinished {
                    completionView
                } else if let ex = currentExercise {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            Text(ex.kind.rawValue.uppercased())
                                .font(.caption.bold())
                                .foregroundColor(.secondary)

                            Text(ex.prompt)
                                .font(.title3.bold())

                            promptCard(for: ex)

                            exerciseInputView(for: ex)

                            if hasChecked {
                                feedbackBanner(for: ex)
                            }
                        }
                        .padding()
                    }

                    actionFooter(for: ex)
                }
            }
            .navigationTitle(lesson.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Thoát") {
                        SpeechService.shared.stop()
                        dismiss()
                    }
                }
            }
            .onAppear {
                autoPlayIfListening()
            }
            .onChange(of: currentIndex) { _ in
                autoPlayIfListening()
            }
        }
    }

    @ViewBuilder
    private func promptCard(for ex: LessonExercise) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if ex.kind != .listening || hasChecked {
                if ex.kind != .wordBuilder && ex.kind != .typeAnswer {
                    Text(ex.targetText)
                        .font(.title2.bold())
                    if let phonetic = ex.phonetic {
                        Text(phonetic)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("Nhấn nút bên dưới để nghe phát âm")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 10) {
                Button {
                    SpeechService.shared.speak(
                        text: ex.targetText,
                        languageCode: lesson.languageCode,
                        rate: storage.speechRate,
                        forceSynthesizer: true
                    )
                } label: {
                    Label("Nghe", systemImage: "speaker.wave.2.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    SpeechService.shared.speak(
                        text: ex.targetText,
                        languageCode: lesson.languageCode,
                        rate: max(SpeechService.minRate, storage.speechRate - 0.10),
                        forceSynthesizer: true
                    )
                } label: {
                    Label("Chậm", systemImage: "tortoise.fill")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func exerciseInputView(for ex: LessonExercise) -> some View {
        switch ex.kind {
        case .multipleChoice, .listening:
            VStack(spacing: 10) {
                ForEach(ex.options, id: \.self) { option in
                    let isSelected = selectedOption == option
                    Button {
                        guard !hasChecked else { return }
                        selectedOption = option
                    } label: {
                        HStack {
                            Text(option)
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

        case .wordBuilder:
            VStack(alignment: .leading, spacing: 14) {
                // Constructed answer area
                VStack(alignment: .leading, spacing: 8) {
                    Text("Câu bạn ghép:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if builtTokens.isEmpty {
                        Text("Chạm các từ bên dưới để ghép thành câu")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    } else {
                        FlowChipLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(builtTokens) { token in
                                Button(token.text) {
                                    guard !hasChecked else { return }
                                    builtTokens.removeAll { $0.id == token.id }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                // Word bank
                FlowChipLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(availableTokens) { token in
                        let isUsed = builtTokens.contains(where: { $0.id == token.id })
                        Button(token.text) {
                            guard !hasChecked, !isUsed else { return }
                            builtTokens.append(token)
                        }
                        .buttonStyle(.bordered)
                        .opacity(isUsed ? 0.35 : 1.0)
                        .disabled(isUsed || hasChecked)
                    }
                }
            }

        case .typeAnswer:
            VStack(alignment: .leading, spacing: 8) {
                TextField("Nhập đáp án của bạn...", text: $typedAnswer)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(hasChecked)

                if let phonetic = ex.phonetic {
                    Text("Gợi ý phát âm: \(phonetic)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func feedbackBanner(for ex: LessonExercise) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(
                isCurrentCorrect ? "Chính xác!" : "Chưa đúng rồi",
                systemImage: isCurrentCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"
            )
            .font(.headline)
            .foregroundColor(isCurrentCorrect ? .green : .red)

            if !isCurrentCorrect {
                Text("Đáp án đúng: \(ex.correctAnswer)")
                    .font(.subheadline.bold())
            }

            if let explanation = ex.explanation {
                Text(explanation)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            (isCurrentCorrect ? Color.green : Color.red).opacity(0.12),
            in: RoundedRectangle(cornerRadius: 12)
        )
    }

    private func actionFooter(for ex: LessonExercise) -> some View {
        VStack {
            if !hasChecked {
                Button("Kiểm tra") {
                    checkAnswer(for: ex)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(!canSubmit(for: ex))
            } else {
                Button(currentIndex + 1 < lesson.exercises.count ? "Tiếp tục" : "Hoàn thành bài học") {
                    advanceOrFinish()
                }
                .buttonStyle(.borderedProminent)
                .tint(isCurrentCorrect ? .green : .orange)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }

    private var completionView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "flame.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.orange)

            Text("Hoàn thành bài học!")
                .font(.title.bold())

            Text("Bạn trả lời đúng \(correctCount)/\(lesson.exercises.count) câu")
                .font(.headline)
                .foregroundColor(.secondary)

            HStack(spacing: 20) {
                VStack {
                    Text("+\(earnedXP) XP")
                        .font(.title2.bold())
                        .foregroundColor(.orange)
                    Text("Điểm kinh nghiệm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                VStack {
                    Text("\(storage.streakStats.currentStreak) ngày")
                        .font(.title2.bold())
                        .foregroundColor(.red)
                    Text("Chuỗi Streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }

            Spacer()

            Button("Quay lại lộ trình") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding()
        }
    }

    private var earnedXP: Int {
        guard !lesson.exercises.isEmpty else { return lesson.xpReward }
        let ratio = Double(correctCount) / Double(lesson.exercises.count)
        return max(5, Int(Double(lesson.xpReward) * max(0.5, ratio)))
    }

    private func canSubmit(for ex: LessonExercise) -> Bool {
        switch ex.kind {
        case .multipleChoice, .listening:
            return selectedOption != nil
        case .wordBuilder:
            return !builtTokens.isEmpty
        case .typeAnswer:
            return !typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func checkAnswer(for ex: LessonExercise) {
        let userAnswer: String
        switch ex.kind {
        case .multipleChoice, .listening:
            userAnswer = selectedOption ?? ""
        case .wordBuilder:
            let separator = (lesson.languageCode == "ja" || lesson.languageCode == "zh") ? "" : " "
            userAnswer = builtTokens.map(\.text).joined(separator: separator)
        case .typeAnswer:
            userAnswer = typedAnswer
        }

        let normalizedUser = normalizeAnswer(userAnswer)
        let normalizedTarget = normalizeAnswer(ex.correctAnswer)
        isCurrentCorrect = normalizedUser == normalizedTarget

        if isCurrentCorrect {
            correctCount += 1
        }
        hasChecked = true

        SpeechService.shared.speak(
            text: ex.targetText,
            languageCode: lesson.languageCode,
            rate: storage.speechRate,
            forceSynthesizer: true
        )
    }

    private func normalizeAnswer(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "[.!?,。？！]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func advanceOrFinish() {
        selectedOption = nil
        builtTokens = []
        typedAnswer = ""
        hasChecked = false
        isCurrentCorrect = false

        if currentIndex + 1 < lesson.exercises.count {
            currentIndex += 1
        } else {
            storage.recordStudyActivity(xp: earnedXP, completedLessonID: lesson.id)
            isFinished = true
        }
    }

    private func autoPlayIfListening() {
        guard let ex = currentExercise, ex.kind == .listening else { return }
        SpeechService.shared.speak(
            text: ex.targetText,
            languageCode: lesson.languageCode,
            rate: storage.speechRate,
            forceSynthesizer: true
        )
    }
}

private struct FlowChipLayout: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 320
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
