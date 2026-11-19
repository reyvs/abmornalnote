
import SwiftUI
import SwiftData

@main
struct AbmornalNoteApp: App {
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: DailyJot.self)
    }
}
