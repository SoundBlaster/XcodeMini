import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class RunProjectModel {
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

    var project: XcodeProject?
    var phase: Phase = .ready
    var message: String?
    var isShowingImporter = false
    var savedProjects: [SavedProject] { ProjectCatalog.projects }

    private let xcode: any XcodeMCPServicing

    var projectName: String {
        project?.name ?? "Choose a project"
    }

    func select(_ url: URL) {
        do {
            let resolved = try XcodeProject.resolve(from: url)
            project = resolved
            _ = ProjectCatalog.add(resolved)
            WidgetCenter.shared.reloadTimelines(ofKind: "XcodeMiniProjectWidget")
            phase = ProjectCatalog.isRunning(SavedProject(url: resolved.url)) ? .running : .ready
            message = nil
        } catch {
            message = error.localizedDescription
            phase = .failed
        }
    }

    init(xcode: any XcodeMCPServicing) {
        self.xcode = xcode
        if let saved = ProjectCatalog.projects.first {
            project = XcodeProject(url: saved.url)
            phase = ProjectCatalog.isRunning(saved) ? .running : .ready
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
        guard let project else {
            isShowingImporter = true
            return
        }

        perform(project, shouldRun: true)
    }

    private func stop() {
        guard let project else { return }
        perform(project, shouldRun: false)
    }

    func selectAndToggle(_ saved: SavedProject) {
        project = XcodeProject(url: saved.url)
        phase = ProjectCatalog.isRunning(saved) ? .running : .ready
        toggleRun()
    }

    private func perform(_ project: XcodeProject, shouldRun: Bool) {
        phase = shouldRun ? .starting : .stopping
        message = nil
        Task {
            do {
                _ = try await xcode.openWorkspace(at: project.url)
                let result = try await (shouldRun ? xcode.runProject(at: project.url) : xcode.stopProject(at: project.url))
                ProjectCatalog.setRunning(shouldRun, for: SavedProject(url: project.url))
                WidgetCenter.shared.reloadTimelines(ofKind: "XcodeMiniProjectWidget")
                phase = shouldRun ? .running : .ready
                message = result
            } catch {
                phase = .failed
                message = error.localizedDescription
            }
        }
    }
}
