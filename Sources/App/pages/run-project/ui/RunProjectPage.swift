import SwiftUI
import NestedA11yIDs
import UniformTypeIdentifiers

struct RunProjectPage: View {
    @Bindable var model: RunProjectModel

    private let acceptedTypes: [UTType] = [
        .folder,
        UTType(filenameExtension: "xcodeproj", conformingTo: .package) ?? .package,
        UTType(filenameExtension: "xcworkspace", conformingTo: .package) ?? .package,
    ]

    var body: some View {
        GeometryReader { geometry in
            let maxControlDiameter = min(geometry.size.width * 0.55, geometry.size.height * 0.68)
            let displayedControlDiameter = min(170, maxControlDiameter)

            ZStack {
                RunControl(
                    isActive: model.phase.isActive,
                    hasProject: model.project != nil,
                    status: model.phase.title,
                    diameter: displayedControlDiameter,
                    symbolSize: min(84, displayedControlDiameter * 0.5),
                    action: model.toggleRun
                )
                .nestedAccessibilityIdentifier("run")

                VStack(spacing: 0) {
                    AppHeader()
                        .nestedAccessibilityIdentifier("header")
                        .padding(.top, 30)

                    Spacer(minLength: 0)

                    StatusBar(projectName: model.projectName, phase: model.phase, message: model.message)
                        .nestedAccessibilityIdentifier("status")
                }
            }
        }
        .a11yRoot("xcodeMini")
        .background(Color(nsColor: .windowBackgroundColor).ignoresSafeArea())
        .fileImporter(
            isPresented: $model.isShowingImporter,
            allowedContentTypes: acceptedTypes,
            allowsMultipleSelection: false
        ) { result in
            if case let .success(urls) = result, let url = urls.first {
                model.select(url)
            }
        }
        .onDrop(of: [UTType.fileURL], isTargeted: nil, perform: handleDrop)
        .onChange(of: model.phase) { _, newValue in
            if newValue == .failed {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in model.select(url) }
        }
        return true
    }
}

private struct AppHeader: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("Xcode mini")
                .font(.system(.title2, design: .rounded, weight: .medium))
                .accessibilityHeading(.h1)
            Text("Build small. Dream big.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct RunControl: View {
    let isActive: Bool
    let hasProject: Bool
    let status: String
    let diameter: CGFloat
    let symbolSize: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                ButtonGlassSurface()
                    .overlay {
                        Circle().strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.09), radius: 20, y: 10)

                Image(systemName: isActive ? "stop.fill" : "play.fill")
                    .font(.system(size: symbolSize, weight: .medium))
                    .foregroundStyle(.primary)
                    .offset(x: isActive ? 0 : 4)
            }
            .frame(width: diameter, height: diameter)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(hasProject ? status : "No project selected")
        .accessibilityHint(accessibilityHint)
        .nestedAccessibilityIdentifier("toggle")
    }

    private var accessibilityLabel: String {
        if isActive { "Stop Xcode project" } else if hasProject { "Run Xcode project" } else { "Choose an Xcode project" }
    }

    private var accessibilityHint: String {
        if isActive { "Stops the selected Xcode project" } else if hasProject {
            "Builds and runs the selected Xcode project"
        } else {
            "Opens a dialog to choose an Xcode project or workspace"
        }
    }
}

private struct ButtonGlassSurface: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            Circle()
                .fill(.clear)
                .glassEffect(.regular.interactive(), in: Circle())
        } else {
            Circle().fill(.regularMaterial)
        }
    }
}

private struct StatusBar: View {
    let projectName: String
    let phase: RunProjectModel.Phase
    let message: String?

    var body: some View {
        HStack(spacing: 8) {
            projectLabel(lineLimit: 1)
            Spacer(minLength: 18)
            statusLabel(lineLimit: 1)
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private func projectLabel(lineLimit: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "hammer.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(projectName)
                .lineLimit(lineLimit)
                .truncationMode(.middle)
                .accessibilityLabel("Selected Xcode project")
                .accessibilityValue(projectName)
                .nestedAccessibilityIdentifier("project")
        }
    }

    private func statusLabel(lineLimit: Int) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(statusText)
                .foregroundStyle(.secondary)
                .lineLimit(lineLimit)
                .help(message ?? phase.title)
                .accessibilityLabel("Project status")
                .accessibilityValue(statusText)
                .nestedAccessibilityIdentifier("phase")
        }
    }

    private var indicatorColor: Color {
        switch phase {
        case .ready: .green
        case .starting, .stopping: .orange
        case .running: .green
        case .failed: .red
        }
    }

    private var statusText: String {
        phase == .failed ? message ?? phase.title : phase.title
    }
}

#Preview("Default") {
    RunProjectPage(model: RunProjectModel(xcode: XcodeMCPClient()))
        .frame(width: 480, height: 420)
}

#Preview("Dark") {
    RunProjectPage(model: RunProjectModel(xcode: XcodeMCPClient()))
        .frame(width: 480, height: 420)
        .preferredColorScheme(.dark)
}
