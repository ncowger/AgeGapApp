# AgeGap

An iPhone app for tracking birthdays across your extended family and friend group — with a visual family tree, chronological timeline, age gap analysis, and smart birthday reminders.

Built with **SwiftUI + SwiftData** (iOS 17+).

---

## Features

### 👥 People
Add anyone with a name, birthday, optional photo, and notes. Assign a **Spouse/Partner**, **Father**, and **Mother** to build the family tree automatically.

- Swipe to delete, tap to edit
- Mark one person as **Me ⭐️** — they anchor the family tree and "vs Me" analysis
- Spouse links are bidirectional (setting A's spouse to B automatically sets B's spouse to A)
- Two parents supported per person, enabling blended and divorced family structures

---

### 📅 Timeline
A chronological list sorted by birth year with two levels of gap info:

- **Between consecutive entries** — compact gap badges always visible as you scroll ("2y 4mo", "3mo 5d", "18d")
- **Tap-to-compare** — tap any two people to reveal a detail card showing the exact gap in years, months, and days (e.g. "2y 4mo 11d apart")

---

### 🌳 Family Tree
A generational tree built automatically from the spouse/parent relationships you define:

- BFS layout engine anchors at **Me** and assigns generations
- Spouses sit side-by-side, connected by a line
- Children sorted **oldest to youngest** left to right
- Parent → child edges drawn as smooth Bézier curves
- Children with parents in two different family units (blended families) show two separate edges
- People with no tree links appear in a strip below the tree
- **Pinch to zoom** (0.15× – 4×) and **drag to pan** simultaneously
- **Tap-to-compare** — same as the timeline, tap any two nodes to see their age gap
- Tap a single node for a birthday/age detail sheet
- Toolbar button to reset zoom and position

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
| Minimum iOS | 17.0 |

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
    ├── PeopleListView.swift           # Searchable people list
    ├── AddEditPersonView.swift        # Add/edit form: photo, spouse, father, mother, notes, Me toggle
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
5. Choose an iPhone simulator (iOS 17+) or your connected device
6. Press **⌘R**

---

## Tips

- **Set a "Me" person first** — the family tree and "vs Me" gap analysis both anchor to whoever has the Me ⭐️ flag set.
- **Link spouses and parents in the edit sheet** — the tree is built from these structural links.
- **Blended families** — assign a Father and Mother from different couples; the tree draws two edges to that child and positions them between both parent groups.
- **Dark Mode** works throughout; toggle it in iOS Settings or the Xcode simulator via **Features → Toggle Appearance**.

---

## Roadmap

- [ ] iCloud sync across devices
- [ ] Import from Contacts
- [ ] Export tree as image or PDF
- [ ] App Store listing
