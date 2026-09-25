import AppIntents
import Foundation
import WidgetKit

struct ProjectEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Xcode Project")
    static let defaultQuery = ProjectEntityQuery()

    let id: String
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(_ project: SavedProject) {
        id = project.id
        name = project.name
    }
}

struct ProjectEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ProjectEntity] {
        ProjectCatalog.projects.filter { identifiers.contains($0.id) }.map(ProjectEntity.init)
    }

    func suggestedEntities() async throws -> [ProjectEntity] {
        ProjectCatalog.projects.map(ProjectEntity.init)
    }
}

struct ConfigureProjectWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Choose Project"
    static let description = IntentDescription("Select an Xcode project for Run and Stop.")

    @Parameter(title: "Project") var project: ProjectEntity?
}

struct RunProjectWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Run Xcode Project"
    @available(macOS 26.0, *)
    static let supportedModes: IntentModes = .background
    @Parameter(title: "Project ID") var projectID: String

    init() { projectID = "" }
    init(projectID: String) { self.projectID = projectID }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let project = ProjectCatalog.projects.first(where: { $0.id == projectID }) else { throw ProjectIntentError.missingProject }
        _ = try await ProjectAction.run(project)
        WidgetCenter.shared.reloadTimelines(ofKind: "XcodeMiniProjectWidget")
        return .result()
    }
}

struct StopProjectWidgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Xcode Project"
    @available(macOS 26.0, *)
    static let supportedModes: IntentModes = .background
    @Parameter(title: "Project ID") var projectID: String

    init() { projectID = "" }
    init(projectID: String) { self.projectID = projectID }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let project = ProjectCatalog.projects.first(where: { $0.id == projectID }) else { throw ProjectIntentError.missingProject }
        _ = try await ProjectAction.stop(project)
        WidgetCenter.shared.reloadTimelines(ofKind: "XcodeMiniProjectWidget")
        return .result()
    }
}

private enum ProjectIntentError: Error, CustomLocalizedStringResourceConvertible {
    case missingProject
    var localizedStringResource: LocalizedStringResource { "Project not found. Open it in Xcode Mini and try again." }
}
