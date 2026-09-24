import Foundation

@MainActor
protocol XcodeMCPServicing {
    func openWorkspace(at url: URL) async throws -> String
    func runProject(at url: URL) async throws -> String
    func stopProject(at url: URL) async throws -> String
}
