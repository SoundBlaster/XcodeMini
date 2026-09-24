import Foundation

enum XcodeProjectResolver {
    enum ResolutionError: LocalizedError {
        case notFound
        case ambiguous

        var errorDescription: String? {
            switch self {
            case .notFound:
                "No .xcodeproj or .xcworkspace was found in that folder."
            case .ambiguous:
                "More than one Xcode project was found. Choose a specific project or workspace from File."
            }
        }
    }

    static func resolve(from url: URL) throws -> URL {
        if isContainer(url) { return url.standardizedFileURL }

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ResolutionError.notFound
        }

        var matches: [URL] = []
        try collectContainers(in: url, depth: 0, into: &matches)

        let workspaces = matches.filter { $0.pathExtension.lowercased() == "xcworkspace" }
        let candidates = workspaces.isEmpty ? matches : workspaces
        guard !candidates.isEmpty else { throw ResolutionError.notFound }
        guard candidates.count == 1 else { throw ResolutionError.ambiguous }
        return candidates[0].standardizedFileURL
    }

    private static func collectContainers(in directory: URL, depth: Int, into matches: inout [URL]) throws {
        guard depth <= 4 else { return }
        let children = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        for child in children {
            if isContainer(child) {
                matches.append(child)
                continue
            }

            guard depth < 4,
                  ![".git", "Pods", "DerivedData", "build", "Carthage"].contains(child.lastPathComponent)
            else { continue }

            let values = try child.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                try collectContainers(in: child, depth: depth + 1, into: &matches)
            }
        }
    }

    private static func isContainer(_ url: URL) -> Bool {
        ["xcodeproj", "xcworkspace"].contains(url.pathExtension.lowercased())
    }
}
