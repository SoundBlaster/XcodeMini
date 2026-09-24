import Foundation

@MainActor
final class XcodeMCPClient {
    private struct JSONRPCResponse: @unchecked Sendable {
        let values: [String: Any]
    }

    private struct PendingRequest {
        let continuation: CheckedContinuation<JSONRPCResponse, Error>
    }

    private var process: Process?
    private var input: FileHandle?
    private var pending: [String: PendingRequest] = [:]
    private var receiveBuffer = Data()
    private var nextID = 1
    private var isInitialized = false

    func openWorkspace(at url: URL) async throws -> String {
        try ensureHeadlessMode()
        try await ensureInitialized()
        let result = try await callTool("XcodeOpenWorkspace", arguments: ["path": url.path])
        return result
    }

    func runProject(at url: URL) async throws -> String {
        try await ensureInitialized()
        return try await callTool("RunProject", arguments: ["workspaceIdentifier": url.path])
    }

    func stopProject(at url: URL) async throws -> String {
        try await ensureInitialized()
        return try await callTool("StopProject", arguments: ["workspaceIdentifier": url.path])
    }

    private func ensureInitialized() async throws {
        guard !isInitialized else { return }
        try startBridge()

        _ = try await sendRequest("initialize", params: [
            "protocolVersion": "2025-06-18",
            "capabilities": [String: Any](),
            "clientInfo": ["name": "Xcode Mini", "version": "1.0.0"],
        ], timeout: 20)
        try sendNotification("notifications/initialized")
        isInitialized = true
    }

    private func startBridge() throws {
        guard process?.isRunning != true else { return }

        let bridge = Process()
        bridge.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        bridge.arguments = ["mcpbridge"]

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        bridge.standardInput = stdin
        bridge.standardOutput = stdout
        bridge.standardError = stderr

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                Task { @MainActor [weak self] in self?.bridgeDidStop() }
                return
            }
            Task { @MainActor [weak self] in self?.receive(data) }
        }
        stderr.fileHandleForReading.readabilityHandler = { handle in
            if handle.availableData.isEmpty { handle.readabilityHandler = nil }
        }

        bridge.terminationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.failPendingRequests(with: MCPError.bridgeStopped)
                self?.isInitialized = false
            }
        }

        try bridge.run()
        process = bridge
        input = stdin.fileHandleForWriting
    }

    private func callTool(_ name: String, arguments: [String: Any]) async throws -> String {
        let response = try await sendRequest("tools/call", params: [
            "name": name,
            "arguments": arguments,
        ], timeout: 30 * 60)

        if response["isError"] as? Bool == true {
            throw MCPError.toolFailure(extractText(from: response) ?? "Xcode could not complete the request.")
        }

        let structured = response["structuredContent"] as? [String: Any]
        if let runResult = structured?["runResult"] as? String {
            if runResult.localizedCaseInsensitiveContains("fail") {
                throw MCPError.toolFailure(runResult)
            }
            return runResult
        }
        if let stopResult = structured?["stopResult"] as? String { return stopResult }
        if let text = extractText(from: response) { return text }
        return ""
    }

    private func sendRequest(
        _ method: String,
        params: [String: Any],
        timeout: TimeInterval
    ) async throws -> [String: Any] {
        let id = nextID
        nextID += 1

        let response: JSONRPCResponse = try await withCheckedThrowingContinuation { continuation in
            pending[String(id)] = PendingRequest(continuation: continuation)

            do {
                try writeMessage(["jsonrpc": "2.0", "id": id, "method": method, "params": params])
            } catch {
                pending.removeValue(forKey: String(id))?.continuation.resume(throwing: error)
                return
            }

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                guard let self,
                      let request = self.pending.removeValue(forKey: String(id))
                else { return }
                request.continuation.resume(throwing: MCPError.timedOut(method))
            }
        }
        return response.values
    }

    private func sendNotification(_ method: String) throws {
        try writeMessage(["jsonrpc": "2.0", "method": method])
    }

    private func writeMessage(_ message: [String: Any]) throws {
        guard let input else { throw MCPError.bridgeUnavailable }
        var data = try JSONSerialization.data(withJSONObject: message)
        data.append(0x0A)
        try input.write(contentsOf: data)
    }

    private func receive(_ data: Data) {
        receiveBuffer.append(data)
        while let newline = receiveBuffer.firstIndex(of: 0x0A) {
            let line = receiveBuffer.prefix(upTo: newline)
            receiveBuffer.removeSubrange(...newline)
            guard let response = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let id = response["id"]
            else { continue }

            let key = String(describing: id)
            guard let request = pending.removeValue(forKey: key) else { continue }

            if let error = response["error"] as? [String: Any] {
                let message = error["message"] as? String ?? "The Xcode MCP request failed."
                request.continuation.resume(throwing: MCPError.toolFailure(message))
            } else {
                request.continuation.resume(returning: JSONRPCResponse(
                    values: response["result"] as? [String: Any] ?? [:]
                ))
            }
        }
    }

    private func failPendingRequests(with error: Error) {
        let requests = Array(pending.values)
        pending.removeAll()
        for request in requests {
            request.continuation.resume(throwing: error)
        }
    }

    private func extractText(from response: [String: Any]) -> String? {
        let content = response["content"] as? [[String: Any]] ?? []
        return content.compactMap { $0["text"] as? String }.first
    }

    private func bridgeDidStop() {
        process = nil
        input = nil
        isInitialized = false
        failPendingRequests(with: MCPError.bridgeStopped)
    }

    private func ensureHeadlessMode() throws {
        let statusProcess = Process()
        statusProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        statusProcess.arguments = ["mcp-server", "status", "--format", "json"]

        let output = Pipe()
        let errors = Pipe()
        statusProcess.standardOutput = output
        statusProcess.standardError = errors

        do {
            try statusProcess.run()
            statusProcess.waitUntilExit()
        } catch {
            throw MCPError.headlessUnavailable
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard statusProcess.terminationStatus == 0,
              let status = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let permission = status["permission"] as? [String: Any]
        else { throw MCPError.headlessUnavailable }

        guard permission["enabled"] as? Bool == true else {
            throw MCPError.headlessDisabled
        }
    }
}

private enum MCPError: LocalizedError {
    case bridgeUnavailable
    case bridgeStopped
    case headlessUnavailable
    case headlessDisabled
    case timedOut(String)
    case toolFailure(String)

    var errorDescription: String? {
        switch self {
        case .bridgeUnavailable:
            "Xcode’s MCP bridge is unavailable. Check that Xcode 27 is selected in xcode-select."
        case .bridgeStopped:
            "The Xcode MCP bridge stopped unexpectedly. Try again."
        case .headlessUnavailable:
            "Xcode 27’s headless MCP server isn’t available. Select Xcode 27 in xcode-select and try again."
        case .headlessDisabled:
            "Xcode 27 headless mode is off. Enable it with `sudo xcrun mcp-server enable`."
        case let .timedOut(method):
            "Xcode did not respond to \(method). Check that the headless MCP server is enabled and the project is approved."
        case let .toolFailure(message):
            message
        }
    }
}
