import Foundation
import Observation

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

    private let xcode: any XcodeMCPServicing

    var projectName: String {
        project?.name ?? "Choose a project"
    }

    func select(_ url: URL) {
        do {
            project = try XcodeProject.resolve(from: url)
            phase = .ready
            message = nil
        } catch {
            message = error.localizedDescription
            phase = .failed
        }
    }

    init(xcode: any XcodeMCPServicing) {
        self.xcode = xcode
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

        phase = .starting
        message = nil
        Task {
            do {
                _ = try await xcode.openWorkspace(at: project.url)
                guard phase == .starting else { return }
                let result = try await xcode.runProject(at: project.url)
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
        guard let project else { return }
        phase = .stopping
        Task {
            do {
                let result = try await xcode.stopProject(at: project.url)
                phase = .ready
                message = result
            } catch {
                phase = .failed
                message = error.localizedDescription
            }
        }
    }
}
