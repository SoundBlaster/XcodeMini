import SwiftUI

struct ProjectsMenuView: View {
    @Bindable var model: RunProjectModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if model.savedProjects.isEmpty {
            Text("No projects yet")
            Button("Open Project…") { openImporter() }
        } else {
            ForEach(model.savedProjects) { project in
                Button {
                    model.selectAndToggle(project)
                } label: {
                    Label(project.name, systemImage: ProjectCatalog.isRunning(project) ? "stop.fill" : "play.fill")
                }
                .help(ProjectCatalog.isRunning(project) ? "Stop \(project.name)" : "Run \(project.name)")
            }
            Divider()
            Button("Open Project…") { openImporter() }
        }
        Divider()
        Button("Show Xcode mini") { NSApp.activate(ignoringOtherApps: true) }
    }

    private func openImporter() {
        model.isShowingImporter = true
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
