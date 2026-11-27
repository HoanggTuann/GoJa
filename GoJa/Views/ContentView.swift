import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var storage: StorageService

    var body: some View {
        TabView {
            LearnView()
                .tabItem {
                    Label("Học tập", systemImage: "graduationcap")
                }

            ExploreView()
                .tabItem {
                    Label("Đọc & Nguồn", systemImage: "book")
                }

            DictionaryView()
                .tabItem {
                    Label("Tra từ", systemImage: "character.book.closed")
                }

            FlashcardsView()
                .tabItem {
                    Label("Ôn tập", systemImage: "rectangle.stack")
                }
                .badge(storage.dueFlashcards.count)

            SettingsView()
                .tabItem {
                    Label("Cài đặt", systemImage: "gearshape")
                }
        }
    }
}
