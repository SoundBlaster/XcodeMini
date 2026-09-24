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
  entities/xcode-project/model/   Xcode project and workspace resolution
  shared/api/xcode-mcp/           Xcode MCP transport and service contract
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

This app currently has one page, so its header, run control, and status bar stay
private to that page. `widgets` is intentionally unused until a substantial UI
composition is reused. The linter checks the layer and slice structure, then
checks local Swift type references for upward and sibling-slice dependencies.

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
