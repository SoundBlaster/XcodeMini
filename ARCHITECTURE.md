# Architecture

Xcode Mini follows the single-module Feature-Sliced Design (FSD) contract from
the [FSD iOS project](https://github.com/SoundBlaster/FSD). FSD makes ownership
and dependency direction visible in the source tree; Xcode and Swift still build
one application module.

```text
Sources/App/
  app/entrypoint/                 application composition and startup
  pages/run-project/ui/           the one-screen Run Project experience
  features/run-project/model/     project selection and run/stop state
  features/run-project/ui/        menu bar project picker and actions
  entities/xcode-project/model/   Xcode project resolution and shared catalog
  shared/api/xcode-mcp/           Xcode MCP transport and service contract
  features/run-project/model/     widget intents and run/stop orchestration
Sources/WidgetExtension/          configurable desktop widget UI and provider
```

Dependencies point downward:

```text
app -> pages -> widgets -> features -> entities -> shared
```

The app entry point creates the MCP service and injects it into the run feature.
The page owns SwiftUI composition and file/drop presentation. The feature model
owns project/run state and uses the injected `XcodeMCPServicing` interface. The
project entity resolves `.xcodeproj` and `.xcworkspace` containers. The MCP
client stays in `shared` and knows nothing about the app's presentation state.
The menu bar and desktop widget share a project catalog and running state in a
team-scoped App Group. On macOS 26 and later, widget App Intents run in the app
process in the background and invoke the Xcode MCP client there.

The main page's header, run control, and status bar stay private to that page.
The linter checks the layer and slice structure, then checks local Swift type
references for upward and sibling-slice dependencies.

## Checks

Install SwiftLint and the pinned FSD iOS tooling once, then run both linters:

```sh
brew install swiftlint
make setup-fsd-tooling
make lint
```

`make lint-swift` runs SwiftLint in strict mode. `make lint-architecture` runs
FSD iOS `v0.4.0` with strict layer and dependency checks. CI checks out the same
FSD iOS commit by SHA, so local and CI architecture rules stay aligned.
