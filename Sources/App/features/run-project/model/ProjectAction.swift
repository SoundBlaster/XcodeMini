import Foundation

enum ProjectAction {
    static func run(_ project: SavedProject) async throws -> String {
        try await perform(project, shouldRun: true)
    }

    static func stop(_ project: SavedProject) async throws -> String {
        try await perform(project, shouldRun: false)
    }

    private static func perform(_ project: SavedProject, shouldRun: Bool) async throws -> String {
        let client = XcodeMCPClient()
        _ = try await client.openWorkspace(at: project.url)
        let result = try await (shouldRun ? client.runProject(at: project.url) : client.stopProject(at: project.url))
        ProjectCatalog.setRunning(shouldRun, for: project)
        return result
    }
}
