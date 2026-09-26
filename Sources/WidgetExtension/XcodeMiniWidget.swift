import AppIntents
import SwiftUI
import WidgetKit

private let widgetKind = "XcodeMiniProjectWidget"

struct ProjectWidgetEntry: TimelineEntry {
    let date: Date
    let project: SavedProject?
    let isRunning: Bool
}

struct ProjectWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ProjectWidgetEntry { ProjectWidgetEntry(date: .now, project: nil, isRunning: false) }

    func snapshot(for configuration: ConfigureProjectWidgetIntent, in context: Context) async -> ProjectWidgetEntry {
        makeEntry(configuration)
    }

    func timeline(for configuration: ConfigureProjectWidgetIntent, in context: Context) async -> Timeline<ProjectWidgetEntry> {
        Timeline(entries: [makeEntry(configuration)], policy: .never)
    }

    private func resolve(_ configuration: ConfigureProjectWidgetIntent) -> SavedProject? {
        guard let id = configuration.project?.id else { return ProjectCatalog.projects.first }
        return ProjectCatalog.projects.first { $0.id == id }
    }

    private func makeEntry(_ configuration: ConfigureProjectWidgetIntent) -> ProjectWidgetEntry {
        let project = resolve(configuration)
        return ProjectWidgetEntry(date: .now, project: project, isRunning: project.map(ProjectCatalog.isRunning) ?? false)
    }
}

struct ProjectWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: widgetKind, intent: ConfigureProjectWidgetIntent.self, provider: ProjectWidgetProvider()) { entry in
            ProjectWidgetView(entry: entry)
        }
        .configurationDisplayName("Xcode Project")
        .description("Run or stop a saved Xcode project.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct ProjectWidgetView: View {
    let entry: ProjectWidgetEntry
    @Environment(\.widgetRenderingMode) private var widgetRenderingMode

    var body: some View {
        if let project = entry.project {
            VStack(alignment: .leading, spacing: 12) {
                Label(project.name, systemImage: "hammer.fill")
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                HStack {
                    if entry.isRunning {
                        Button(intent: StopProjectWidgetIntent(projectID: project.id)) {
                            actionLabel("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(intent: RunProjectWidgetIntent(projectID: project.id)) {
                            actionLabel("Run", systemImage: "play.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .containerBackground(.background, for: .widget)
        } else {
            ContentUnavailableView("Choose a project", systemImage: "folder", description: Text("Open Xcode mini and add a project to use this widget."))
                .containerBackground(.background, for: .widget)
        }
    }

    private func actionLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                widgetRenderingMode == .vibrant ? AnyShapeStyle(.clear) : AnyShapeStyle(.tint),
                in: Capsule()
            )
    }
}

@main
struct XcodeMiniWidgetBundle: WidgetBundle {
    var body: some Widget { ProjectWidget() }
}
