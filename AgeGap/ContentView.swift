import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Query private var people: [Person]
    @State private var selectedTab: AppTab? = .people

    enum AppTab: String, CaseIterable, Identifiable {
        var id: Self { self }
        case people    = "People"
        case timeline  = "Timeline"
        case tree      = "Tree"
        case ageGaps   = "Age Gaps"
        case birthdays = "Birthdays"

        var icon: String {
            switch self {
            case .people:    return "person.3"
            case .timeline:  return "calendar"
            case .tree:      return "tree"
            case .ageGaps:   return "arrow.left.and.right"
            case .birthdays: return "gift"
            }
        }
    }

    var body: some View {
        Group {
            if hSizeClass == .regular {
                // iPad — sidebar + detail
                NavigationSplitView {
                    List(AppTab.allCases, id: \.rawValue, selection: $selectedTab) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                    .navigationTitle("Age Gap")
                } detail: {
                    detailView(for: selectedTab ?? .people)
                }
            } else {
                // iPhone — tab bar
                TabView {
                    ForEach(AppTab.allCases) { tab in
                        detailView(for: tab)
                            .tabItem { Label(tab.rawValue, systemImage: tab.icon) }
                    }
                }
            }
        }
        // Reschedule notifications whenever the app returns to the foreground
        // (catches changes made in Contacts or Settings while away)
        .onReceive(NotificationCenter.default.publisher(
            for: UIApplication.didBecomeActiveNotification)
        ) { _ in
            NotificationManager.shared.rescheduleAll(people: people)
        }
    }

    @ViewBuilder
    private func detailView(for tab: AppTab) -> some View {
        switch tab {
        case .people:    PeopleListView()
        case .timeline:  BirthdayTimelineView()
        case .tree:      FamilyTreeView()
        case .ageGaps:   AgeGapAnalysisView()
        case .birthdays: UpcomingBirthdaysView()
        }
    }
}
