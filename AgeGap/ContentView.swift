import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PeopleListView()
                .tabItem {
                    Label("People", systemImage: "person.3")
                }
            BirthdayTimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "calendar")
                }
            FamilyTreeView()
                .tabItem {
                    Label("Tree", systemImage: "tree")
                }
            AgeGapAnalysisView()
                .tabItem {
                    Label("Age Gaps", systemImage: "arrow.left.and.right")
                }
            UpcomingBirthdaysView()
                .tabItem {
                    Label("Birthdays", systemImage: "gift")
                }
        }
    }
}
