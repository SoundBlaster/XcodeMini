import Foundation

struct XcodeProject: Equatable, Sendable {
    let url: URL

    var name: String {
        url.deletingPathExtension().lastPathComponent
    }

    static func resolve(from url: URL) throws -> Self {
        Self(url: try XcodeProjectResolver.resolve(from: url))
    }
}
