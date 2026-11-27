import SwiftUI

@main
struct GoJaApp: App {
    @StateObject private var storage = StorageService()
    @State private var importNotice: String?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storage)
                .onOpenURL { url in
                    handleIncomingJaPack(url: url)
                }
                .alert("Nhập gói .japack", isPresented: Binding(
                    get: { importNotice != nil },
                    set: { if !$0 { importNotice = nil } }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(importNotice ?? "")
                }
        }
    }

    private func handleIncomingJaPack(url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let data = try Data(contentsOf: url)
            let result = try storage.importJaPack(from: data)
            importNotice = "Đã nhập gói \"\(result.packName)\": +\(result.addedFlashcards) từ vựng, +\(result.addedSources) nguồn, +\(result.addedLessons) bài học."
        } catch {
            importNotice = "Không thể mở tệp .japack: \(error.localizedDescription)"
        }
    }
}
