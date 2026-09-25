import Foundation

struct SavedProject: Codable, Hashable, Identifiable, Sendable {
    var id: String { url.standardizedFileURL.path }
    let url: URL
    var name: String { url.deletingPathExtension().lastPathComponent }
}

enum ProjectCatalog {
    static let appGroup = "P8T2366K8X.XcodeMini"
    private static let projectsKey = "savedProjects"
    private static let runningKey = "runningProjectPaths"

    static var projects: [SavedProject] {
        get { (defaults?.data(forKey: projectsKey)).flatMap { try? JSONDecoder().decode([SavedProject].self, from: $0) } ?? [] }
        set { if let data = try? JSONEncoder().encode(newValue) { defaults?.set(data, forKey: projectsKey) } }
    }

    static func add(_ project: XcodeProject) -> SavedProject {
        let saved = SavedProject(url: project.url)
        var all = projects.filter { $0.id != saved.id }
        all.insert(saved, at: 0)
        projects = all
        return saved
    }

    static func isRunning(_ project: SavedProject) -> Bool {
        runningPaths.contains(project.id)
    }

    static func setRunning(_ running: Bool, for project: SavedProject) {
        var paths = runningPaths
        if running { paths.insert(project.id) } else { paths.remove(project.id) }
        defaults?.set(Array(paths), forKey: runningKey)
    }

    private static var runningPaths: Set<String> {
        Set(defaults?.stringArray(forKey: runningKey) ?? [])
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }
}
