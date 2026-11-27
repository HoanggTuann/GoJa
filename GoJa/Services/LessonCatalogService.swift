import Foundation

/// Provides built-in Duolingo-style guided lessons and generates dynamic practice lessons from saved flashcards.
enum LessonCatalogService {
    static func lessons(for languageCode: String, customLessons: [LessonUnit] = []) -> [LessonUnit] {
        let builtIn = builtInLessons.filter { $0.languageCode == languageCode }
        let imported = customLessons.filter { $0.languageCode == languageCode }
        return (builtIn + imported).sorted { $0.unitNumber < $1.unitNumber }
    }

    static func buildFlashcardPracticeLesson(from flashcards: [Flashcard], languageCode: String) -> LessonUnit? {
        let pool = flashcards.filter { $0.languageCode == languageCode && !$0.translation.isEmpty }
        guard pool.count >= 2 else { return nil }

        let selected = Array(pool.shuffled().prefix(5))
        var exercises: [LessonExercise] = []

        for (index, card) in selected.enumerated() {
            let distractors = pool
                .filter { $0.id != card.id }
                .map(\.translation)
                .shuffled()
            let options = ([card.translation] + Array(distractors.prefix(3))).shuffled()

            let kind: LessonExercise.ExerciseKind = (index % 2 == 0) ? .multipleChoice : .listening
            exercises.append(
                LessonExercise(
                    id: "fc-ex-\(card.id.uuidString)",
                    kind: kind,
                    prompt: kind == .listening ? "Nghe phát âm và chọn nghĩa đúng" : "Từ \"\(card.word)\" có nghĩa là gì?",
                    targetText: card.word,
                    phonetic: card.phonetic,
                    correctAnswer: card.translation,
                    options: options,
                    explanation: card.example
                )
            )
        }

        return LessonUnit(
            id: "practice-flashcards-\(languageCode)",
            languageCode: languageCode,
            unitNumber: 0,
            title: "Ôn tập từ vựng cá nhân",
            subtitle: "Luyện \(selected.count) từ bạn đã lưu từ web & từ điển",
            iconName: "star.circle.fill",
            xpReward: 20,
            exercises: exercises
        )
    }

    // MARK: - Built-in Curriculum

    static let builtInLessons: [LessonUnit] = [
        // English
        LessonUnit(
            id: "en-u1",
            languageCode: "en",
            unitNumber: 1,
            title: "Chào hỏi & Giao tiếp đầu tiên",
            subtitle: "Làm quen từ vựng và mẫu câu chào hỏi hằng ngày",
            iconName: "hand.wave.fill",
            xpReward: 15,
            exercises: [
                LessonExercise(
                    id: "en-u1-1",
                    kind: .multipleChoice,
                    prompt: "Chọn nghĩa đúng của từ sau",
                    targetText: "Good morning",
                    phonetic: "/ɡʊd ˈmɔːrnɪŋ/",
                    correctAnswer: "Chào buổi sáng",
                    options: ["Chào buổi sáng", "Chúc ngủ ngon", "Cảm ơn nhiều", "Hẹn gặp lại"],
                    explanation: "Dùng khi gặp ai đó vào buổi sáng (trước 12 giờ trưa)."
                ),
                LessonExercise(
                    id: "en-u1-2",
                    kind: .listening,
                    prompt: "Nghe và chọn cụm từ bạn nghe được",
                    targetText: "How are you?",
                    phonetic: "/haʊ ɑːr juː/",
                    correctAnswer: "Bạn khỏe không?",
                    options: ["Bạn khỏe không?", "Bạn tên là gì?", "Bạn đi đâu vậy?", "Xin lỗi nhé"],
                    explanation: "Câu hỏi thăm sức khỏe phổ biến nhất trong tiếng Anh."
                ),
                LessonExercise(
                    id: "en-u1-3",
                    kind: .wordBuilder,
                    prompt: "Ghép câu: \"Rất vui được gặp bạn\"",
                    targetText: "Nice to meet you",
                    phonetic: "/naɪs tuː miːt juː/",
                    correctAnswer: "Nice to meet you",
                    options: ["meet", "Nice", "you", "to", "see"],
                    explanation: "Cấu trúc lịch sự khi mới làm quen."
                ),
                LessonExercise(
                    id: "en-u1-4",
                    kind: .typeAnswer,
                    prompt: "Gõ lại bằng tiếng Anh: \"Cảm ơn\"",
                    targetText: "Thank you",
                    phonetic: "/θæŋk juː/",
                    correctAnswer: "Thank you",
                    options: [],
                    explanation: "Bạn cũng có thể nói ngắn gọn là \"Thanks\"."
                )
            ]
        ),
        LessonUnit(
            id: "en-u2",
            languageCode: "en",
            unitNumber: 2,
            title: "Đời sống & Đọc tin tức",
            subtitle: "Từ vựng thông dụng khi đọc báo và du lịch",
            iconName: "newspaper.fill",
            xpReward: 20,
            exercises: [
                LessonExercise(
                    id: "en-u2-1",
                    kind: .multipleChoice,
                    prompt: "Chọn nghĩa đúng của từ sau",
                    targetText: "Knowledge",
                    phonetic: "/ˈnɒlɪdʒ/",
                    correctAnswer: "Kiến thức",
                    options: ["Kiến thức", "Thời tiết", "Kinh nghiệm", "Lịch trình"],
                    explanation: "Danh từ không đếm được, chữ 'k' ở đầu là âm câm."
                ),
                LessonExercise(
                    id: "en-u2-2",
                    kind: .listening,
                    prompt: "Nghe và chọn nghĩa phù hợp",
                    targetText: "Where is the station?",
                    phonetic: "/weər ɪz ðə ˈsteɪʃən/",
                    correctAnswer: "Nhà ga ở đâu?",
                    options: ["Nhà ga ở đâu?", "Mấy giờ tàu chạy?", "Sân bay rất xa", "Tôi muốn mua vé"],
                    explanation: "\"Station\" dùng cho ga tàu điện hoặc ga xe lửa."
                ),
                LessonExercise(
                    id: "en-u2-3",
                    kind: .wordBuilder,
                    prompt: "Ghép câu: \"Tôi đang học tiếng Anh\"",
                    targetText: "I am learning English",
                    phonetic: nil,
                    correctAnswer: "I am learning English",
                    options: ["learning", "English", "I", "am", "read"],
                    explanation: "Thì hiện tại tiếp diễn diễn tả việc đang diễn ra."
                )
            ]
        ),

        // Japanese
        LessonUnit(
            id: "ja-u1",
            languageCode: "ja",
            unitNumber: 1,
            title: "Chào hỏi tiếng Nhật cơ bản",
            subtitle: "Những câu giao tiếp thiết yếu hằng ngày",
            iconName: "sun.max.fill",
            xpReward: 15,
            exercises: [
                LessonExercise(
                    id: "ja-u1-1",
                    kind: .multipleChoice,
                    prompt: "Chọn nghĩa đúng của cụm từ",
                    targetText: "おはようございます",
                    phonetic: "Ohayō gozaimasu",
                    correctAnswer: "Chào buổi sáng (lịch sự)",
                    options: ["Chào buổi sáng (lịch sự)", "Chào buổi tối", "Xin lỗi", "Tạm biệt"],
                    explanation: "Dùng dạng lịch sự với người lớn tuổi hoặc đồng nghiệp."
                ),
                LessonExercise(
                    id: "ja-u1-2",
                    kind: .listening,
                    prompt: "Nghe phát âm và chọn nghĩa đúng",
                    targetText: "ありがとうございます",
                    phonetic: "Arigatō gozaimasu",
                    correctAnswer: "Cảm ơn rất nhiều",
                    options: ["Cảm ơn rất nhiều", "Không có gì", "Tôi không hiểu", "Rất hân hạnh"],
                    explanation: "Cách nói cảm ơn lịch sự thông dụng nhất."
                ),
                LessonExercise(
                    id: "ja-u1-3",
                    kind: .wordBuilder,
                    prompt: "Ghép câu: \"Xin lỗi (khi nhờ hoặc gọi ai đó)\"",
                    targetText: "すみません",
                    phonetic: "Sumimasen",
                    correctAnswer: "すみません",
                    options: ["すみ", "ません", "はい", "いいえ"],
                    explanation: "Rất hữu ích khi đi nhà hàng hoặc hỏi đường ở Nhật."
                ),
                LessonExercise(
                    id: "ja-u1-4",
                    kind: .multipleChoice,
                    prompt: "Từ nào mang nghĩa \"Nước uống\"?",
                    targetText: "みず",
                    phonetic: "Mizu (水)",
                    correctAnswer: "Nước",
                    options: ["Nước", "Cơm", "Trà xanh", "Cà phê"],
                    explanation: "Chữ Hán là 水 (Thủy)."
                )
            ]
        ),
        LessonUnit(
            id: "ja-u2",
            languageCode: "ja",
            unitNumber: 2,
            title: "Đi ăn & Mua sắm",
            subtitle: "Mẫu câu gọi món và hỏi giá",
            iconName: "cup.and.saucer.fill",
            xpReward: 20,
            exercises: [
                LessonExercise(
                    id: "ja-u2-1",
                    kind: .listening,
                    prompt: "Nghe và chọn nghĩa đúng",
                    targetText: "これはいくらですか",
                    phonetic: "Kore wa ikura desu ka",
                    correctAnswer: "Cái này giá bao nhiêu?",
                    options: ["Cái này giá bao nhiêu?", "Cái này là gì?", "Cho tôi xem cái kia", "Ngon quá!"],
                    explanation: "\"いくら (ikura)\" dùng để hỏi giá tiền."
                ),
                LessonExercise(
                    id: "ja-u2-2",
                    kind: .multipleChoice,
                    prompt: "Chọn nghĩa đúng",
                    targetText: "おいしいです",
                    phonetic: "Oishii desu",
                    correctAnswer: "Ngon quá",
                    options: ["Ngon quá", "Cay quá", "Đắt quá", "Gần đây"],
                    explanation: "Khen đồ ăn ngon khi dùng bữa."
                )
            ]
        ),

        // Korean
        LessonUnit(
            id: "ko-u1",
            languageCode: "ko",
            unitNumber: 1,
            title: "Làm quen tiếng Hàn",
            subtitle: "Chào hỏi và cảm ơn cơ bản",
            iconName: "sparkles",
            xpReward: 15,
            exercises: [
                LessonExercise(
                    id: "ko-u1-1",
                    kind: .multipleChoice,
                    prompt: "Chọn nghĩa đúng của câu",
                    targetText: "안녕하세요",
                    phonetic: "Annyeonghaseyo",
                    correctAnswer: "Xin chào",
                    options: ["Xin chào", "Tạm biệt", "Xin lỗi", "Cảm ơn"],
                    explanation: "Câu chào lịch sự dùng được ở mọi thời điểm trong ngày."
                ),
                LessonExercise(
                    id: "ko-u1-2",
                    kind: .listening,
                    prompt: "Nghe và chọn đáp án đúng",
                    targetText: "감사합니다",
                    phonetic: "Gamsahamnida",
                    correctAnswer: "Xin cảm ơn",
                    options: ["Xin cảm ơn", "Rất vui được gặp", "Không sao đâu", "Hẹn gặp lại"],
                    explanation: "Cách cảm ơn trang trọng và phổ biến nhất."
                ),
                LessonExercise(
                    id: "ko-u1-3",
                    kind: .multipleChoice,
                    prompt: "Từ này có nghĩa là gì?",
                    targetText: "사랑해요",
                    phonetic: "Saranghaeyo",
                    correctAnswer: "Tôi yêu bạn",
                    options: ["Tôi yêu bạn", "Tôi đói rồi", "Bạn khỏe không", "Đi thôi"],
                    explanation: "Câu nói yêu thương quen thuộc trong tiếng Hàn."
                )
            ]
        ),

        // Chinese
        LessonUnit(
            id: "zh-u1",
            languageCode: "zh",
            unitNumber: 1,
            title: "Tiếng Trung cơ bản",
            subtitle: "Giao tiếp chào hỏi kèm Pinyin",
            iconName: "character.bubble.fill",
            xpReward: 15,
            exercises: [
                LessonExercise(
                    id: "zh-u1-1",
                    kind: .multipleChoice,
                    prompt: "Chọn nghĩa đúng của từ sau",
                    targetText: "你好",
                    phonetic: "Nǐ hǎo",
                    correctAnswer: "Xin chào",
                    options: ["Xin chào", "Tạm biệt", "Cảm ơn", "Không có gì"],
                    explanation: "Câu chào cơ bản nhất trong tiếng Trung."
                ),
                LessonExercise(
                    id: "zh-u1-2",
                    kind: .listening,
                    prompt: "Nghe và chọn nghĩa đúng",
                    targetText: "谢谢",
                    phonetic: "Xièxie",
                    correctAnswer: "Cảm ơn",
                    options: ["Cảm ơn", "Xin lỗi", "Tạm biệt", "Chào buổi sáng"],
                    explanation: "Dùng để cảm ơn trong mọi tình huống."
                ),
                LessonExercise(
                    id: "zh-u1-3",
                    kind: .multipleChoice,
                    prompt: "Câu này có nghĩa là gì?",
                    targetText: "多少钱",
                    phonetic: "Duōshao qián",
                    correctAnswer: "Bao nhiêu tiền?",
                    options: ["Bao nhiêu tiền?", "Mấy giờ rồi?", "Ở đâu vậy?", "Tên bạn là gì?"],
                    explanation: "Dùng khi mua sắm và trả giá."
                )
            ]
        ),

        // French
        LessonUnit(
            id: "fr-u1",
            languageCode: "fr",
            unitNumber: 1,
            title: "Giao tiếp tiếng Pháp",
            subtitle: "Từ vựng làm quen cơ bản",
            iconName: "globe.europe.africa.fill",
            xpReward: 15,
            exercises: [
                LessonExercise(
                    id: "fr-u1-1",
                    kind: .multipleChoice,
                    prompt: "Chọn nghĩa đúng",
                    targetText: "Bonjour",
                    phonetic: "/bɔ̃.ʒuʁ/",
                    correctAnswer: "Xin chào / Chào buổi sáng",
                    options: ["Xin chào / Chào buổi sáng", "Chúc ngủ ngon", "Cảm ơn", "Xin lỗi"],
                    explanation: "Câu chào lịch sự phổ biến vào ban ngày."
                ),
                LessonExercise(
                    id: "fr-u1-2",
                    kind: .listening,
                    prompt: "Nghe và chọn nghĩa đúng",
                    targetText: "Merci beaucoup",
                    phonetic: "/mɛʁ.si bo.ku/",
                    correctAnswer: "Cảm ơn rất nhiều",
                    options: ["Cảm ơn rất nhiều", "Không có gì", "Tạm biệt", "Làm ơn"],
                    explanation: "\"Beaucoup\" nghĩa là rất nhiều."
                )
            ]
        ),

        // German
        LessonUnit(
            id: "de-u1",
            languageCode: "de",
            unitNumber: 1,
            title: "Tiếng Đức nhập môn",
            subtitle: "Chào hỏi và cảm ơn",
            iconName: "book.closed.fill",
            xpReward: 15,
            exercises: [
                LessonExercise(
                    id: "de-u1-1",
                    kind: .multipleChoice,
                    prompt: "Chọn nghĩa đúng",
                    targetText: "Guten Tag",
                    phonetic: "/ˈɡuːtn̩ taːk/",
                    correctAnswer: "Xin chào (ban ngày)",
                    options: ["Xin chào (ban ngày)", "Chúc ngủ ngon", "Cảm ơn", "Tạm biệt"],
                    explanation: "Cách chào lịch sự thông dụng ở Đức."
                ),
                LessonExercise(
                    id: "de-u1-2",
                    kind: .listening,
                    prompt: "Nghe và chọn nghĩa đúng",
                    targetText: "Danke schön",
                    phonetic: "/ˈdaŋkə ʃøːn/",
                    correctAnswer: "Cảm ơn nhiều",
                    options: ["Cảm ơn nhiều", "Xin lỗi", "Tôi tên là...", "Khỏe không?"],
                    explanation: "Thể hiện sự cảm ơn lịch sự."
                )
            ]
        ),

        // Spanish
        LessonUnit(
            id: "es-u1",
            languageCode: "es",
            unitNumber: 1,
            title: "Tiếng Tây Ban Nha cơ bản",
            subtitle: "Những câu mở đầu thân thiện",
            iconName: "sun.and.horizon.fill",
            xpReward: 15,
            exercises: [
                LessonExercise(
                    id: "es-u1-1",
                    kind: .multipleChoice,
                    prompt: "Chọn nghĩa đúng",
                    targetText: "Buenos días",
                    phonetic: "/ˈbwenos ˈdias/",
                    correctAnswer: "Chào buổi sáng",
                    options: ["Chào buổi sáng", "Chúc ngủ ngon", "Cảm ơn", "Xin lỗi"],
                    explanation: "Dùng vào buổi sáng trước giờ trưa."
                ),
                LessonExercise(
                    id: "es-u1-2",
                    kind: .listening,
                    prompt: "Nghe và chọn nghĩa đúng",
                    targetText: "Muchas gracias",
                    phonetic: "/ˈmutʃas ˈɡɾasjas/",
                    correctAnswer: "Cảm ơn rất nhiều",
                    options: ["Cảm ơn rất nhiều", "Không sao", "Làm ơn", "Hẹn gặp lại"],
                    explanation: "Rất phổ biến trong giao tiếp hằng ngày."
                )
            ]
        ),

        // Vietnamese
        LessonUnit(
            id: "vi-u1",
            languageCode: "vi",
            unitNumber: 1,
            title: "Tiếng Việt cơ bản",
            subtitle: "Chào hỏi và giao tiếp hằng ngày",
            iconName: "leaf.fill",
            xpReward: 15,
            exercises: [
                LessonExercise(
                    id: "vi-u1-1",
                    kind: .multipleChoice,
                    prompt: "Chọn ý nghĩa tiếng Anh tương ứng",
                    targetText: "Xin chào",
                    phonetic: "/sin˧˧ tɕaːw˨˩/",
                    correctAnswer: "Hello",
                    options: ["Hello", "Goodbye", "Thank you", "Sorry"],
                    explanation: "Câu chào hỏi thân thiện, lịch sự."
                ),
                LessonExercise(
                    id: "vi-u1-2",
                    kind: .listening,
                    prompt: "Nghe và chọn nghĩa đúng",
                    targetText: "Cảm ơn bạn rất nhiều",
                    phonetic: nil,
                    correctAnswer: "Thank you very much",
                    options: ["Thank you very much", "See you again", "Excuse me", "Good morning"],
                    explanation: "Lời cảm ơn chân thành."
                )
            ]
        )
    ]
}
