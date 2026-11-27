import SwiftUI

@main
struct GoJaApp: App {
    @StateObject private var storage = StorageService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storage)
        }
    }
}
