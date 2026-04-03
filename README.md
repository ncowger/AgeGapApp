# AgeGap

An iPhone app for tracking birthdays across your extended family and friend group — with a visual timeline, age gap analysis, a structured family tree, and birthday reminders.

Built with SwiftUI + SwiftData (iOS 17+), designed to support iCloud sync across devices when ready.

---

## Screenshots

> _Run the app in the Xcode simulator to explore all views._

---

## Features

### People
Add anyone with a name, birthday, optional photo, and a relationship tag. Assign a **Spouse/Partner** or **Parent** link to build the family tree automatically. Swipe to delete; tap to edit.

**Relationship tags:**
`Me` · `Parent` · `Sibling` · `Child` · `Cousin` · `Grandparent` · `Grandchild` · `Aunt/Uncle` · `Niece/Nephew` · `Spouse/Partner` · `Friend` · `In-Law` · `Step-Family` · `Other`

---

### Timeline
A chronological list of everyone sorted by birth year. Two levels of gap info:

- **Between consecutive entries** — compact gap badges ("2y 4mo", "3 mo", "18d") always visible as you scroll
- **Tap-to-compare** — tap any two people to reveal a detail card showing the exact gap in **years, months, and days** (e.g. "2y 4mo 11d apart")

---

### Family Tree
A structured generational tree built from **spouse** and **parent** relationships you define on each person:

- BFS layout engine assigns each person a generation number anchored at **Me**
- Spouses sit side-by-side within a family unit, connected by a dashed line
- Parent → child edges drawn as smooth Bézier curves
- People with no tree links shown in a separate strip below the tree
- **Pinch to zoom** (0.15× – 4×) and **drag to pan** simultaneously
- Tap any node for a birthday/age detail sheet
- Double-tap or toolbar button to reset zoom/position

> For best results, set one person's tag to **Me** — they anchor the tree at the center generation.

---

### Age Gaps
Three analysis modes via a segmented picker:

| Mode | What it shows |
|---|---|
| **vs Me** | Everyone compared against the "Me" person, with older/younger direction labels |
| **By Group** | Per-tag sections with a closest/furthest summary card + full pair list |
| **All Pairs** | Every pairwise combination, sortable by gap size |

Notes added to a person appear inline on every pair row they appear in.

---

### Birthdays
Upcoming birthdays sorted by days remaining. Today's birthdays are called out at the top. Annual **local notifications** fire at 9 am on each person's birthday — permission requested on first launch.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Persistence | SwiftData (`@Model`) |
| Sync (ready, not active) | CloudKit |
| Notifications | `UNUserNotificationCenter` |
| Minimum iOS | 17.0 |

---

## iCloud Sync

The app is wired for CloudKit — all `@Model` properties have default values (required for CloudKit compatibility) and the app entry point attempts a `cloudKitDatabase: .automatic` container first, falling back to local storage silently.

**To activate sync (requires Apple Developer Program membership — $99/yr):**

1. Open the project in Xcode
2. Select the **AgeGap** target → **Signing & Capabilities**
3. Click **+ Capability** → **iCloud**, then check **CloudKit**
4. Build and run — no code changes needed

`AgeGap.entitlements` and the CloudKit `ModelConfiguration` are already committed and ready.

---

## Project Structure

```
AgeGap/
├── AgeGapApp.swift               # App entry point; CloudKit-first ModelContainer w/ local fallback
├── ContentView.swift             # 5-tab bar: People · Timeline · Tree · Age Gaps · Birthdays
├── AgeGap.entitlements           # iCloud/CloudKit declarations (inert until capability enabled)
│
├── Models/
│   └── Person.swift              # SwiftData model, RelationshipTag enum, computed date helpers
│
├── Managers/
│   ├── NotificationManager.swift # Annual birthday notification scheduling
│   └── TreeLayoutEngine.swift    # BFS generation layout → PositionedPerson / TreeEdge / TreeLayout
│
└── Views/
    ├── PeopleListView.swift           # Searchable people list with tag filter chips
    ├── AddEditPersonView.swift        # Add/edit form: photo, tag, spouse picker, parent picker, notes
    ├── BirthdayTimelineView.swift     # Chronological timeline with inline gaps + tap-to-compare card
    ├── FamilyTreeView.swift           # Pinch-to-zoom/pan canvas tree with Bézier edges
    ├── AgeGapAnalysisView.swift       # vs-Me · By Group · All Pairs gap analysis
    └── UpcomingBirthdaysView.swift    # Birthday countdown with today's birthdays highlighted
```

---

## Getting Started

1. Install [Xcode](https://apps.apple.com/us/app/xcode/id497799835) (free, requires macOS 14+)
2. Clone this repo:
   ```bash
   git clone https://github.com/ncowger/AgeGapApp.git
   cd AgeGapApp
   ```
3. Open `AgeGap.xcodeproj` in Xcode
4. Select the **AgeGap** target → **Signing & Capabilities** → set your Team (a free Apple ID works for simulator + personal device)
5. Choose an iPhone simulator (iOS 17+) or your device
6. Press **⌘R**

---

## Tips

- **Set a "Me" person first** — the family tree and "vs Me" gap analysis both anchor to whoever has the `Me` tag.
- **Link spouses and parents in the edit sheet** — the tree is built from these structural links, not just tags.
- **Spouse links are bidirectional** — setting Person A's spouse to Person B automatically sets B's spouse to A.
- **Dark Mode** works throughout; toggle it in the iOS simulator via **Settings → Developer → Dark Appearance** or device Settings.

---

## Roadmap

- [ ] iCloud sync across devices (requires Apple Developer account)
- [ ] CloudKit family sharing (invite family members to a shared pool)
- [ ] Import from Contacts
- [ ] Export / share as PDF or image
- [ ] Custom relationship tags
- [ ] App icon + App Store listing
