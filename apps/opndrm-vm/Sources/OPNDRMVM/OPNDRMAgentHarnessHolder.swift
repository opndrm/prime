import Foundation

/// Minimal hidden harness holder for one user-named agent bound to one VM.
///
/// The product surface is OPNDRM VM: users name the agent, give it an emoji and
/// instructions, assign it to one VM, then chat in OPNDRM. Prime Agent/JCode are
/// implementation details hidden behind this holder.
@MainActor
final class OPNDRMAgentHarnessHolder {
    enum Kind: String, CaseIterable, Codable {
        case prime = "Prime Agent"
        case jcode = "JCode"

        var safeName: String {
            switch self {
            case .prime: return "prime"
            case .jcode: return "jcode"
            }
        }

        var displayName: String { rawValue }
    }

    enum State: String {
        case stopped
        case starting
        case running
        case failed
    }

    let vmName: String
    let kind: Kind
    let agentName: String
    let emoji: String
    let instructions: String

    private(set) var state: State = .stopped
    private(set) var statusText = "Agent not started."
    private var process: Process?

    var stateDidChange: ((State, String) -> Void)?

    init(
        vmName: String,
        kind: Kind = .prime,
        agentName: String = "Helper",
        emoji: String = "🤖",
        instructions: String = "Help the user inside your assigned VM."
    ) {
        self.vmName = vmName
        self.kind = kind
        self.agentName = agentName
        self.emoji = emoji
        self.instructions = instructions.isEmpty ? "Help the user inside your assigned VM." : instructions
    }

    var isRunning: Bool { process?.isRunning == true }

    var agentID: String {
        "\(vmName):\(kind.safeName):\(Self.safeFileComponent(agentName))"
    }

    var displayTitle: String {
        "\(emoji) \(agentName)"
    }

    func start() throws {
        if isRunning {
            state = .running
            statusText = "\(displayTitle) is already running for \(vmName)."
            stateDidChange?(state, statusText)
            return
        }

        let command = Self.agentCommand(kind: kind)
        guard FileManager.default.isExecutableFile(atPath: command.path) else {
            throw Self.error("\(kind.displayName) executable not found at \(command.path). Set \(Self.commandOverrideName(kind: kind)) to override.")
        }

        let root = try self.agentRoot()
        let promptURL = root.appendingPathComponent("vm-binding-prompt.md")
        let launchURL = root.appendingPathComponent("launch.sh")
        let logURL = root.appendingPathComponent("agent.log")
        let errURL = root.appendingPathComponent("agent.err.log")
        try bindingPrompt().write(to: promptURL, atomically: true, encoding: .utf8)
        try Self.launchScript(command: command, kind: kind, promptURL: promptURL).write(to: launchURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: launchURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [launchURL.path]
        process.currentDirectoryURL = root

        var environment = ProcessInfo.processInfo.environment
        environment["OPNDRM_AGENT_NAME"] = agentName
        environment["OPNDRM_AGENT_EMOJI"] = emoji
        environment["OPNDRM_VM_NAME"] = vmName
        environment["OPNDRM_VM_SOCKET"] = "127.0.0.1:7777"
        environment["OPNDRM_VM_BINDING_PROMPT"] = promptURL.path
        environment["OPNDRM_AGENT_CHAT"] = root.appendingPathComponent("chat.jsonl").path
        environment["OPNDRM_GHOST_MODE"] = "1"
        environment["OPNDRM_HARNESS_KIND"] = kind.safeName
        process.environment = environment

        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        FileManager.default.createFile(atPath: errURL.path, contents: nil)
        let stdout = try FileHandle(forWritingTo: logURL)
        let stderr = try FileHandle(forWritingTo: errURL)
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice

        state = .starting
        statusText = "Starting \(displayTitle) on \(vmName)…"
        stateDidChange?(state, statusText)

        process.terminationHandler = { [weak self] proc in
            Task { @MainActor [weak self] in
                guard let self else { return }
                stdout.closeFile()
                stderr.closeFile()
                if proc.terminationStatus == 0 {
                    self.state = .stopped
                    self.statusText = "\(self.displayTitle) stopped."
                } else {
                    self.state = .failed
                    self.statusText = "\(self.displayTitle) exited (status \(proc.terminationStatus)). See \(errURL.path)."
                }
                self.process = nil
                self.stateDidChange?(self.state, self.statusText)
            }
        }

        do {
            try process.run()
            self.process = process
            state = .running
            statusText = "\(displayTitle) is running silently on \(vmName)."
            stateDidChange?(state, statusText)
        } catch {
            stdout.closeFile()
            stderr.closeFile()
            state = .failed
            statusText = error.localizedDescription
            stateDidChange?(state, statusText)
            throw error
        }
    }

    func stop() {
        guard let process else {
            state = .stopped
            statusText = "\(displayTitle) is not running."
            stateDidChange?(state, statusText)
            return
        }
        if process.isRunning { process.terminate() }
        self.process = nil
        state = .stopped
        statusText = "\(displayTitle) stopped."
        stateDidChange?(state, statusText)
    }

    @discardableResult
    func appendUserMessage(_ message: String) throws -> URL {
        let root = try agentRoot()
        let chatURL = root.appendingPathComponent("chat.jsonl")
        let object: [String: Any] = [
            "time": ISO8601DateFormatter().string(from: Date()),
            "role": "user",
            "agent": agentName,
            "emoji": emoji,
            "vm": vmName,
            "content": message
        ]
        let data = try JSONSerialization.data(withJSONObject: object, options: [])
        if FileManager.default.fileExists(atPath: chatURL.path) {
            let handle = try FileHandle(forWritingTo: chatURL)
            defer { handle.closeFile() }
            try handle.seekToEnd()
            handle.write(data)
            handle.write(Data("\n".utf8))
        } else {
            try (data + Data("\n".utf8)).write(to: chatURL, options: .atomic)
        }
        try message.write(to: root.appendingPathComponent("latest-user-message.txt"), atomically: true, encoding: .utf8)
        return chatURL
    }

    func transcriptText() -> String {
        guard let root = try? agentRoot() else { return "" }
        let chatURL = root.appendingPathComponent("chat.jsonl")
        guard let raw = try? String(contentsOf: chatURL, encoding: .utf8) else { return "" }
        return raw.split(separator: "\n").compactMap { line in
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return String(line)
            }
            let role = obj["role"] as? String ?? "message"
            let content = obj["content"] as? String ?? ""
            if role == "user" { return "You: \(content)" }
            return "\(displayTitle): \(content)"
        }.joined(separator: "\n\n")
    }

    func bindingPrompt() -> String {
        Self.bindingPrompt(
            vmName: vmName,
            kind: kind,
            agentName: agentName,
            emoji: emoji,
            instructions: instructions
        )
    }

    static func bindingPrompt(
        vmName: String,
        kind: Kind = .prime,
        agentName: String = "Helper",
        emoji: String = "🤖",
        instructions: String = "Help the user inside your assigned VM."
    ) -> String {
        """
        You are \(emoji) \(agentName), an OPNDRM VM agent powered by \(kind.displayName).

        The user should not need to know about \(kind.displayName), terminals, ACP, or harness internals. The product surface is OPNDRM VM.

        Your assigned VM:
        - VM name: \(vmName)
        - You may only work inside this VM.
        - Do not operate the host desktop except through OPNDRM VM's local controller/API.

        Your instructions from the user:
        \(instructions.isEmpty ? "Help the user inside your assigned VM." : instructions)

        OPNDRM VM local API:
        - Socket: 127.0.0.1:7777
        - Protocol: one newline-delimited JSON object per command.

        Boot/check your VM:
        printf '{"action":"boot","name":"\(vmName)"}\\n' | nc 127.0.0.1 7777
        printf '{"action":"status"}\\n' | nc 127.0.0.1 7777

        Chat bridge:
        - OPNDRM_AGENT_CHAT points to the in-app chat log for this agent.
        - Read new user messages from that file when available.
        - Keep replies short and focused on work inside \(vmName).

        Policy:
        - One named agent per VM assignment.
        - Ask before destructive VM or guest operations.
        - Open Dream workflow install is optional; run it only if the user asks.
        """
    }

    private func agentRoot() throws -> URL {
        try Self.agentRoot(for: vmName, kind: kind, agentName: agentName)
    }

    private static func launchScript(command: URL, kind: Kind, promptURL: URL) -> String {
        let quotedCommand = shellQuote(command.path)
        let workdir = shellQuote(promptURL.deletingLastPathComponent().path)
        let extraArgs = agentArguments(kind: kind, promptURL: promptURL).map(shellQuote).joined(separator: " ")
        return """
        #!/bin/zsh
        set -euo pipefail
        cd \(workdir)
        echo "OPNDRM VM ghost harness starting: kind=\(kind.safeName) vm=${OPNDRM_VM_NAME:-} agent=${OPNDRM_AGENT_NAME:-}"
        echo "Binding prompt: ${OPNDRM_VM_BINDING_PROMPT:-}"
        echo "Chat file: ${OPNDRM_AGENT_CHAT:-}"
        exec \(quotedCommand) \(extraArgs)
        """
    }

    private static func agentCommand(kind: Kind) -> URL {
        let overrideName = commandOverrideName(kind: kind)
        if let override = ProcessInfo.processInfo.environment[overrideName], !override.isEmpty {
            return URL(fileURLWithPath: NSString(string: override).expandingTildeInPath)
        }
        switch kind {
        case .prime:
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/prime-agent-acp")
        case .jcode:
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/jcode")
        }
    }

    private static func commandOverrideName(kind: Kind) -> String {
        switch kind {
        case .prime: return "OPNDRM_PRIME_AGENT_COMMAND"
        case .jcode: return "OPNDRM_JCODE_COMMAND"
        }
    }

    private static func agentArguments(kind: Kind, promptURL: URL) -> [String] {
        let envName: String
        switch kind {
        case .prime: envName = "OPNDRM_PRIME_AGENT_ARGS"
        case .jcode: envName = "OPNDRM_JCODE_ARGS"
        }
        if let raw = ProcessInfo.processInfo.environment[envName], !raw.isEmpty {
            return raw.split(separator: " ").map(String.init)
        }
        // Keep default minimal. The binding prompt/chat paths are in env; the
        // embedded Handy/ACP bridge can supply exact args later without changing
        // the user-facing Agent Builder.
        return []
    }

    private static func agentRoot(for vmName: String, kind: Kind, agentName: String) throws -> URL {
        let appSupport = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: "/tmp")
        let safeVM = safeFileComponent(vmName)
        let safeAgent = safeFileComponent(agentName)
        let root = appSupport.appendingPathComponent("OPNDRM-VM/Agents/\(safeVM)/\(kind.safeName)-\(safeAgent)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        return root
    }

    private static func safeFileComponent(_ raw: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let value = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return value.isEmpty ? "agent" : value
    }

    private static func shellQuote(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func error(_ message: String) -> NSError {
        NSError(domain: "OPNDRMAgentHarnessHolder", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
