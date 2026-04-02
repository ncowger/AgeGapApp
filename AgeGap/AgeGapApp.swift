import SwiftUI
import SwiftData

@main
struct AgeGapApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Person.self)
    }
}
