import SwiftUI
import UniformTypeIdentifiers

@main
struct XcodeMiniApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
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
    }
}

@MainActor
@Observable
final class AppModel {
    enum Phase: Equatable {
        case ready
        case starting
        case running
        case stopping
        case failed

        var title: String {
            switch self {
            case .ready: "Ready"
            case .starting: "Starting…"
            case .running: "Running"
            case .stopping: "Stopping…"
            case .failed: "Couldn’t start"
            }
        }

        var isActive: Bool {
            self == .starting || self == .running || self == .stopping
        }
    }

    var projectURL: URL?
    var phase: Phase = .ready
    var message: String?
    var isShowingImporter = false

    private let xcode = XcodeMCPClient()

    var projectName: String {
        projectURL?.deletingPathExtension().lastPathComponent ?? "Choose a project"
    }

    func select(_ url: URL) {
        do {
            let container = try ProjectContainer.resolve(from: url)
            projectURL = container
            phase = .ready
            message = nil
        } catch {
            message = error.localizedDescription
            phase = .failed
        }
    }

    func toggleRun() {
        if phase.isActive {
            stop()
        } else {
            run()
        }
    }

    private func run() {
        guard let projectURL else {
            isShowingImporter = true
            return
        }

        phase = .starting
        message = nil
        Task {
            do {
                _ = try await xcode.openWorkspace(at: projectURL)
                guard phase == .starting else { return }
                let result = try await xcode.runProject(at: projectURL)
                guard phase == .starting else { return }
                phase = .running
                message = result
            } catch {
                guard phase != .stopping else { return }
                phase = .failed
                message = error.localizedDescription
            }
        }
    }

    private func stop() {
        guard let projectURL else { return }
        phase = .stopping
        Task {
            do {
                let result = try await xcode.stopProject(at: projectURL)
                phase = .ready
                message = result
            } catch {
                phase = .failed
                message = error.localizedDescription
            }
        }
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
            guard let url else { return }
            Task { @MainActor in self?.select(url) }
        }
        return true
    }
}
