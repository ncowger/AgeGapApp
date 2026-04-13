# AgeGap

An iPhone and iPad app for tracking birthdays across your extended family and friend group — with a visual family tree, chronological timeline, age gap analysis, and smart birthday reminders.

Built with **SwiftUI + SwiftData** (iOS 17+, iPadOS 17+).

---

## Features

### 👥 People
Add anyone with a name, birthday, optional photo, and notes. Assign a **Spouse/Partner**, **Father**, and **Mother** to build the family tree automatically.

- Swipe to delete, tap to edit
- Mark one person as **Me ⭐️** — they anchor the family tree and "vs Me" analysis (optional)
- Spouse links are bidirectional (setting A's spouse to B automatically sets B's spouse to A)
- Father and Mother can each be set independently — leaving one as None is fully supported
- Two parents supported per person, enabling blended and divorced family structures
- **Import from Contacts** — tap the import icon in the People list to browse your Contacts, pick one or more people with birthdays, and import them along with their photos in one step

---

### 📅 Timeline
A chronological list sorted by birth year with two levels of gap info:

- **Between consecutive entries** — compact gap badges always visible as you scroll ("2y 4mo", "3mo 5d", "18d")
- **Tap-to-compare** — tap any two people to reveal a detail card showing the exact gap in years, months, and days (e.g. "2y 4mo 11d apart")

---

### 🌳 Family Tree
A generational tree built automatically from the spouse/parent relationships you define:

- BFS layout engine places everyone with at least one relationship in the tree — **Me ⭐️ is optional**
- Disconnected family groups (e.g. your side and your spouse's side before linking) appear as separate clusters stacked vertically
- Spouses sit side-by-side, connected by a dashed line
- Children sorted **oldest to youngest** left to right
- Parent → child edges drawn as smooth Bézier curves
- Children with parents in two different family units (blended families) show two separate edges
- People with no relationships at all appear in a "Not yet linked" strip below the tree
- **Pinch to zoom** (0.15× – 4×) and **drag to pan** simultaneously
- **Tap-to-compare** — same as the timeline, tap any two nodes to see their age gap
- Toolbar button to reset zoom and position
- **Export** — tap the share icon to export the tree as a PNG or PDF; rendered at 4× resolution in light mode for crisp, readable output regardless of device appearance

---

### 📊 Age Gaps
Two analysis modes via a segmented picker:

| Mode | What it shows |
|---|---|
| **vs Me** | Everyone compared against the "Me" person, with older/younger direction |
| **All Pairs** | Every pairwise combination, sortable closest or furthest first |

Stat cards at the top always show the true closest and furthest pair regardless of sort order. Gap values include years, months, and days (e.g. "1 month 1d", "5 years 3mo 2d").

---

### 🎂 Birthdays
Upcoming birthdays sorted by days remaining. Today's birthdays are highlighted at the top with a 🎂.

- Tap the **⚙️ gear icon** (top right) to open reminder settings
- Reminders fire at **9 AM** and apply globally to every person

**Reminder options:**
- **Birthday reminder** — fires on the birthday or a custom number of days in advance (1–365)
- **Monthly summary** — a single notification on the 1st of each month listing everyone with a birthday that month

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Persistence | SwiftData (`@Model`) |
| Notifications | `UNUserNotificationCenter` (repeating annual triggers) |
| Export | `ImageRenderer` + `UIGraphicsPDFRenderer` |
| Minimum OS | iOS 17.0 / iPadOS 17.0 |
| Devices | iPhone + iPad (native) |

---

## Project Structure

```
AgeGap/
├── AgeGapApp.swift               # App entry point; ModelContainer with local fallback
├── ContentView.swift             # 5-tab bar: People · Timeline · Tree · Age Gaps · Birthdays
│
├── Models/
│   └── Person.swift              # SwiftData model + colorForPerson() helper
│
├── Managers/
│   ├── NotificationManager.swift # Birthday + monthly notification scheduling
│   └── TreeLayoutEngine.swift    # BFS generation layout → PositionedPerson / TreeEdge / TreeLayout
│
└── Views/
    ├── PeopleListView.swift           # Searchable people list + Contacts import entry point
    ├── AddEditPersonView.swift        # Add/edit form: photo, spouse, father, mother, notes, Me toggle
    ├── ContactImportView.swift        # CNContactStore browser: search, multi-select, photo import
    ├── BirthdayTimelineView.swift     # Chronological timeline with inline gaps + tap-to-compare card
    ├── FamilyTreeView.swift           # Pinch-to-zoom/pan canvas tree with Bézier edges + tap-to-compare
    ├── AgeGapAnalysisView.swift       # vs-Me · All Pairs gap analysis
    ├── UpcomingBirthdaysView.swift    # Birthday countdown with today's birthdays highlighted
    └── SettingsView.swift             # Global reminder settings (sheet from Birthdays tab)
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
4. Select the **AgeGap** target → **Signing & Capabilities** → set your Team (a free Apple ID works for the simulator and personal device testing)
5. Choose an iPhone or iPad simulator (iOS/iPadOS 17+) or your connected device
6. Press **⌘R**

---

## Tips

- **"Me" is optional** — the family tree shows all linked people without it, but setting Me ⭐️ unlocks the "vs Me" gap analysis.
- **Link spouses and parents in the edit sheet** — the tree is built entirely from these structural links.
- **Blended families** — assign a Father and Mother from different couples; the tree draws two separate edges to that child and positions them between both parent groups. Either parent can be left as None.
- **Contacts import** — contacts whose birthdays have no year stored are handled gracefully; the app picks a sensible past year and you can correct it with the birthday picker.
- **Birthday picker** — tap the birthday row in the edit sheet to open a three-wheel month/day/year selector. Tap Cancel to discard changes.
- **iPad** — the app runs natively on iPad at full screen. The family tree especially benefits from the larger canvas.
- **Export** — exports are always rendered in light mode at 4× resolution so they look sharp when shared or printed, regardless of your device's appearance setting.
- **Dark Mode** works throughout; toggle it in iOS Settings or the Xcode simulator via **Features → Toggle Appearance**.

---

## Roadmap

- [ ] iCloud sync across devices
- [ ] App Store listing
