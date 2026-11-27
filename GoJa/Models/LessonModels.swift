import Foundation

/// Guided Duolingo-style unit containing interactive exercises.
struct LessonUnit: Identifiable, Codable, Hashable {
    let id: String
    let languageCode: String
    let unitNumber: Int
    var title: String
    var subtitle: String
    var iconName: String
    var xpReward: Int
    var exercises: [LessonExercise]
}

/// Interactive exercise inside a lesson.
struct LessonExercise: Identifiable, Codable, Hashable {
    enum ExerciseKind: String, Codable, CaseIterable {
        case multipleChoice = "Chọn nghĩa đúng"
        case listening = "Nghe và chọn"
        case wordBuilder = "Ghép câu"
        case typeAnswer = "Điền đáp án"
    }

    let id: String
    let kind: ExerciseKind
    let prompt: String
    let targetText: String
    let phonetic: String?
    let correctAnswer: String
    let options: [String]
    let explanation: String?
}

/// Streak, XP, and daily activity tracking ready for future streak features.
struct StreakStats: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var totalXP: Int
    var todayXP: Int
    var dailyXPGoal: Int
    var studyDays: [String] // "yyyy-MM-dd"
    var streakFreezeCount: Int
    var completedLessonIDs: [String]

    init(
        currentStreak: Int = 0,
        longestStreak: Int = 0,
        totalXP: Int = 0,
        todayXP: Int = 0,
        dailyXPGoal: Int = 30,
        studyDays: [String] = [],
        streakFreezeCount: Int = 1,
        completedLessonIDs: [String] = []
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.totalXP = totalXP
        self.todayXP = todayXP
        self.dailyXPGoal = dailyXPGoal
        self.studyDays = studyDays
        self.streakFreezeCount = streakFreezeCount
        self.completedLessonIDs = completedLessonIDs
    }
}
