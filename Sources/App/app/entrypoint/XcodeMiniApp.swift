import SwiftUI

@main
struct XcodeMiniApp: App {
    @State private var model = RunProjectModel(xcode: XcodeMCPClient())

    var body: some Scene {
        WindowGroup(id: "main") {
            RunProjectPage(model: model)
                .frame(minWidth: 420, minHeight: 360)
        }
        .defaultSize(width: 480, height: 420)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Project…") {
                    model.isShowingImporter = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }

        MenuBarExtra("Xcode mini", systemImage: "hammer") {
            ProjectsMenuView(model: model)
        }
        .menuBarExtraStyle(.menu)
    }
}
