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
            container = try ModelContainer(for: Person.self, Tag.self, configurations: cloudConfig)
        } catch {
            // CloudKit not available yet — running in local-only mode
            let localConfig = ModelConfiguration(isStoredInMemoryOnly: false)
            container = try! ModelContainer(for: Person.self, Tag.self, configurations: localConfig)
        }

        seedBuiltInTagsIfNeeded(in: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }

    // Inserts the built-in tags on first launch (or if they were wiped).
    private func seedBuiltInTagsIfNeeded(in context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Tag>())) ?? 0
        guard existing == 0 else { return }

        for (index, spec) in Tag.builtIns.enumerated() {
            context.insert(Tag(
                name: spec.name,
                emoji: spec.emoji,
                colorName: spec.colorName,
                isBuiltIn: true,
                sortOrder: index
            ))
        }
    }
}
