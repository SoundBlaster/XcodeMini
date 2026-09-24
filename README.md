# Xcode Mini

A small macOS front end for the Xcode 27 MCP server. Open an `.xcodeproj` or
`.xcworkspace`, or drop one project folder onto the window, then press Play.
Xcode Mini calls `XcodeOpenWorkspace`, `RunProject`, and `StopProject` through
Apple's `xcrun mcpbridge`; it does not invoke `xcodebuild` itself.

## Requirements

- macOS 15 or later on Apple silicon
- Xcode 27 selected with `xcode-select`
- Xcode 27 headless MCP service enabled by an administrator:

  ```sh
  sudo xcrun mcp-server enable
  ```

The MCP service can ask you to approve Xcode Mini and the selected project the
first time they connect. Leave `--unsafe-always-allow-all-agents` disabled.

## Build

```sh
xcodegen generate
xcodebuild -project XcodeMini.xcodeproj -scheme XcodeMini -destination 'platform=macOS' build
```

## Release 0.0.1

Download `XcodeMini-0.0.1-macos-arm64.zip` from the [GitHub Releases](https://github.com/SoundBlaster/XcodeMini/releases) page and move `Xcode Mini.app` to Applications. This first release is not notarized; macOS may require opening it once from Finder using Control-click > Open.
