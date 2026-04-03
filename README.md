# AgeGap

An iPhone app for tracking birthdays across your extended family and friend group — with a visual timeline, age gap analysis, family tree, and birthday reminders.

---

## Features

### People
Add anyone with a name, birthday, photo, and relationship tag. Filter and search the list by tag. Swipe to delete.

**Relationship tags:** Me, Parent, Sibling, Child, Cousin, Grandparent, Grandchild, Aunt/Uncle, Niece/Nephew, Friend, Spouse/Partner, Other

### Timeline
A chronological timeline of everyone sorted by birth year. Tap any two people to instantly see the exact age gap between them — down to years and months. Gap badges between consecutive entries show spacing at a glance.

### Family Tree
A visual generational tree grouping people by relationship:
- Grandparents
- Parents & Family (Parents, Aunts/Uncles)
- My Generation (Me, Spouse/Partner, Siblings, Cousins)
- Children's Generation (Children, Nieces/Nephews)
- Grandchildren
- Friends & Others (shown separately below the family tree)

Tap any person to see their detail card. The "Me" entry is highlighted as the anchor of the tree.

### Age Gaps
All pairwise age gap comparisons across your group. Toggle between closest-first and furthest-first. Filter to a specific relationship group (e.g. "show only cousins"). Stats banner shows total people, closest gap, and biggest gap at a glance.

### Birthdays
Upcoming birthdays sorted by days remaining. Today's birthdays are broken out at the top. Annual birthday reminders via local notifications at 9am on each person's birthday.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Persistence | SwiftData |
| Sync (future) | CloudKit |
| Notifications | UserNotifications |
| Minimum iOS | 17.0 |

---

## iCloud Sync

The app is architected to support iCloud sync with a single configuration change. Data currently persists locally on each device.

**To activate sync (requires Apple Developer Program — $99/yr):**
1. In Xcode: **Target → Signing & Capabilities → + Capability → iCloud**
2. Check **CloudKit**
3. Build and run — no code changes needed

The `AgeGap.entitlements` file and CloudKit `ModelConfiguration` are already in place.

---

## Project Structure

```
AgeGap/
├── AgeGapApp.swift          # App entry point, ModelContainer setup with CloudKit fallback
├── ContentView.swift        # Tab bar (People, Timeline, Tree, Age Gaps, Birthdays)
│
├── Models/
│   └── Person.swift         # SwiftData model + RelationshipTag enum
│
├── Views/
│   ├── PeopleListView.swift          # People list with search and tag filter
│   ├── AddEditPersonView.swift       # Add/edit sheet with photo picker
│   ├── BirthdayTimelineView.swift    # Chronological timeline with tap-to-compare
│   ├── FamilyTreeView.swift          # Generational tree view
│   ├── AgeGapAnalysisView.swift      # All pairwise gap comparisons
│   └── UpcomingBirthdaysView.swift   # Birthday countdown list
│
├── Managers/
│   └── NotificationManager.swift    # Local notification scheduling
│
├── Assets.xcassets/
└── AgeGap.entitlements      # iCloud/CloudKit declarations (ready, not yet active)
```

---

## Getting Started

1. Install [Xcode](https://apps.apple.com/us/app/xcode/id497799835) (free, requires macOS)
2. Clone the repo
3. Open `AgeGap.xcodeproj`
4. Select an iPhone simulator or your device
5. Set your Team in **Signing & Capabilities** (a free Apple ID works for simulator and personal device)
6. Press **⌘R**

---

## Roadmap

- [ ] iCloud sync across devices (requires Apple Developer account)
- [ ] CloudKit family sharing (invite family members to share a pool of data)
- [ ] Dynamic/custom relationship tags
- [ ] Import from Contacts
- [ ] App icon
