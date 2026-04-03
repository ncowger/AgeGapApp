import SwiftUI
import SwiftData

@main
struct AgeGapApp: App {
    let container: ModelContainer

    init() {
        // Tries CloudKit-backed sync automatically.
        // Falls back to local-only storage if iCloud capability isn't enabled yet.
        //
        // ─── To activate iCloud sync (requires $99/yr Apple Developer account) ───
        //  1. Open project in Xcode
        //  2. Select the AgeGap target → Signing & Capabilities
        //  3. Click "+ Capability" → iCloud → check "CloudKit"
        //  4. That's it. No code changes needed — this init handles it automatically.
        // ─────────────────────────────────────────────────────────────────────────
        do {
            let cloudConfig = ModelConfiguration(cloudKitDatabase: .automatic)
            container = try ModelContainer(for: Person.self, configurations: cloudConfig)
        } catch {
            // CloudKit not available yet — running in local-only mode
            let localConfig = ModelConfiguration(isStoredInMemoryOnly: false)
            container = try! ModelContainer(for: Person.self, configurations: localConfig)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
