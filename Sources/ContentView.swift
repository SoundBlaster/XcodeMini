import SwiftUI
import NestedA11yIDs
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var model: AppModel

    private let acceptedTypes: [UTType] = [
        .folder,
        UTType(filenameExtension: "xcodeproj", conformingTo: .package) ?? .package,
        UTType(filenameExtension: "xcworkspace", conformingTo: .package) ?? .package,
    ]

    var body: some View {
        ZStack {
            RunControl(isRunning: model.phase.isActive, action: model.toggleRun)
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
        .onDrop(of: [UTType.fileURL], isTargeted: nil, perform: model.handleDrop)
        .onChange(of: model.phase) { _, newValue in
            if newValue == .failed {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            }
        }
    }
}

private struct AppHeader: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("Xcode mini")
                .font(.system(.title2, design: .rounded, weight: .medium))
            Text("Build small. Dream big.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct RunControl: View {
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                ButtonGlassSurface()
                    .overlay {
                        Circle().strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.09), radius: 20, y: 10)

                Image(systemName: isRunning ? "stop.fill" : "play.fill")
                    .font(.system(size: 84, weight: .medium))
                    .foregroundStyle(.primary)
                    .offset(x: isRunning ? 0 : 4)
            }
            .frame(width: 170, height: 170)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRunning ? "Stop" : "Play")
        .accessibilityHint(isRunning ? "Stops the running Xcode project" : "Builds and runs the selected Xcode project")
        .nestedAccessibilityIdentifier("toggle")
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
    let phase: AppModel.Phase
    let message: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hammer.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(projectName)
                .lineLimit(1)
                .truncationMode(.middle)
                .nestedAccessibilityIdentifier("project")

            Spacer(minLength: 18)

            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(statusText)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .help(message ?? phase.title)
                .nestedAccessibilityIdentifier("phase")
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
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
