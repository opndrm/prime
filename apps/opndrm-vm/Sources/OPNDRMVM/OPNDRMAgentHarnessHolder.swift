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
    private let rootAgentName: String
    private(set) var agentName: String
    private(set) var emoji: String
    private(set) var instructions: String

    private(set) var state: State = .stopped
    private(set) var statusText = "Agent not started."
    private var process: Process?
    private var replyProcess: Process?

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
        self.rootAgentName = agentName
        self.agentName = agentName
        self.emoji = emoji
        self.instructions = instructions.isEmpty ? "Help the user inside your assigned VM." : instructions
    }

    var isRunning: Bool { process?.isRunning == true }

    var agentID: String {
        "\(vmName):\(kind.safeName):\(Self.safeFileComponent(rootAgentName))"
    }

    var displayTitle: String {
        "\(emoji) \(agentName)"
    }

    func start() throws {
        let command = Self.agentCommand(kind: kind)
        guard FileManager.default.isExecutableFile(atPath: command.path) else {
            throw Self.error("\(kind.displayName) executable not found at \(command.path). Set \(Self.commandOverrideName(kind: kind)) to override.")
        }

        let root = try self.agentRoot()
        let promptURL = root.appendingPathComponent("vm-binding-prompt.md")
        try bindingPrompt().write(to: promptURL, atomically: true, encoding: .utf8)
        try writeProfile(root: root)

        state = .running
        switch kind {
        case .jcode:
            statusText = "\(displayTitle) is awake. JCode will run each message through \(vmName)."
        case .prime:
            statusText = "\(displayTitle) is awake. Prime Agent will use \(vmName) when its run command is available."
        }
        stateDidChange?(state, statusText)
    }

    func stop() {
        if let process, process.isRunning { process.terminate() }
        if let replyProcess, replyProcess.isRunning { replyProcess.terminate() }
        self.process = nil
        self.replyProcess = nil
        state = .stopped
        statusText = "\(displayTitle) stopped."
        stateDidChange?(state, statusText)
    }

    private func writeProfile(root: URL) throws {
        let profile: [String: Any] = [
            "agentName": self.agentName,
            "emoji": self.emoji,
            "instructions": self.instructions,
            "vmName": self.vmName,
            "harness": self.kind.displayName,
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]
        let data = try JSONSerialization.data(withJSONObject: profile, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: root.appendingPathComponent("profile.json"), options: .atomic)
    }

    func updateProfile(agentName: String? = nil, emoji: String? = nil, instructions: String? = nil) {
        let newName = agentName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let newName, !newName.isEmpty {
            self.agentName = newName
        }
        let newEmoji = emoji?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let newEmoji, !newEmoji.isEmpty {
            self.emoji = newEmoji
        }
        let newInstructions = instructions?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let newInstructions, !newInstructions.isEmpty {
            self.instructions = newInstructions
        }

        if let root = try? agentRoot() {
            try? bindingPrompt().write(to: root.appendingPathComponent("vm-binding-prompt.md"), atomically: true, encoding: .utf8)
            try? writeProfile(root: root)
            _ = try? appendSystemMessage("Profile updated. The agent is now \(displayTitle).")
        }
        statusText = "\(displayTitle) updated."
        stateDidChange?(state, statusText)
    }

    @discardableResult
    private func appendSystemMessage(_ message: String) throws -> URL {
        try appendChatMessage(role: "system", content: message)
    }

    @discardableResult
    func appendUserMessage(_ message: String) throws -> URL {
        let chatURL = try appendChatMessage(role: "user", content: message)
        let root = try agentRoot()
        try message.write(to: root.appendingPathComponent("latest-user-message.txt"), atomically: true, encoding: .utf8)
        runReply(for: message, root: root)
        return chatURL
    }

    @discardableResult
    private func appendChatMessage(role: String, content: String) throws -> URL {
        let root = try agentRoot()
        let chatURL = root.appendingPathComponent("chat.jsonl")
        let object: [String: Any] = [
            "time": ISO8601DateFormatter().string(from: Date()),
            "role": role,
            "agent": agentName,
            "emoji": emoji,
            "vm": vmName,
            "content": content
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
        return chatURL
    }

    private func runReply(for message: String, root: URL) {
        guard replyProcess?.isRunning != true else {
            _ = try? appendSystemMessage("Still working — one tiny robot foot in front of the other.")
            return
        }

        _ = try? appendSystemMessage("Working on it in \(vmName)…")
        let prompt = oneShotPrompt(userMessage: message)
        switch kind {
        case .jcode:
            runJCode(prompt: prompt, root: root)
        case .prime:
            runPrime(prompt: prompt, root: root)
        }
    }

    private func runJCode(prompt: String, root: URL) {
        let command = Self.agentCommand(kind: .jcode)
        let process = Process()
        process.executableURL = command
        process.currentDirectoryURL = root
        var args = ["run", "--quiet", "--no-update", "-C", root.path, "--tools", "bash", prompt]
        if let extra = ProcessInfo.processInfo.environment["OPNDRM_JCODE_RUN_ARGS"], !extra.isEmpty {
            args = extra.split(separator: " ").map(String.init) + args
        }
        process.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["OPNDRM_VM_NAME"] = vmName
        env["OPNDRM_VM_SOCKET"] = "127.0.0.1:7777"
        env["OPNDRM_AGENT_CHAT"] = root.appendingPathComponent("chat.jsonl").path
        process.environment = env
        runReplyProcess(process, root: root, engineName: "JCode")
    }

    private func runPrime(prompt: String, root: URL) {
        guard let command = Self.primeRunCommand() else {
            let message = "Prime Agent is not connected yet. macOS is blocking the local Prime bundle; set OPNDRM_PRIME_AGENT_RUN_COMMAND and I will use it. JCode can run this VM now."
            _ = try? appendSystemMessage(message)
            statusText = message
            state = .failed
            stateDidChange?(state, statusText)
            return
        }
        let process = Process()
        process.executableURL = command
        process.currentDirectoryURL = root
        var args = Self.primeRunArguments(prompt: prompt)
        if args.isEmpty { args = [prompt] }
        process.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["OPNDRM_VM_NAME"] = vmName
        env["OPNDRM_VM_SOCKET"] = "127.0.0.1:7777"
        env["OPNDRM_AGENT_CHAT"] = root.appendingPathComponent("chat.jsonl").path
        process.environment = env
        runReplyProcess(process, root: root, engineName: "Prime Agent")
    }

    private func runReplyProcess(_ process: Process, root: URL, engineName: String) {
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = FileHandle.nullDevice

        state = .starting
        statusText = "\(displayTitle) is working in \(vmName)…"
        stateDidChange?(state, statusText)

        let outURL = root.appendingPathComponent("agent.log")
        let errURL = root.appendingPathComponent("agent.err.log")
        process.terminationHandler = { [weak self] proc in
            let output = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let errorText = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            try? output.write(to: outURL, atomically: true, encoding: .utf8)
            try? errorText.write(to: errURL, atomically: true, encoding: .utf8)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.replyProcess = nil
                self.state = proc.terminationStatus == 0 ? .running : .failed
                let cleanOutput = Self.cleanEngineOutput(output)
                if proc.terminationStatus == 0, !cleanOutput.isEmpty {
                    _ = try? self.appendChatMessage(role: "assistant", content: cleanOutput)
                    self.statusText = "\(self.displayTitle) answered from \(engineName)."
                } else {
                    let reason = Self.cleanEngineOutput(errorText).isEmpty ? "No response." : Self.cleanEngineOutput(errorText)
                    _ = try? self.appendSystemMessage("\(engineName) could not answer yet: \(reason)")
                    self.statusText = "\(engineName) could not answer yet."
                }
                self.stateDidChange?(self.state, self.statusText)
            }
        }

        do {
            try process.run()
            replyProcess = process
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self, weak process] in
                guard let self, let process, process.isRunning else { return }
                self.statusText = "Still working in \(self.vmName)… no ghosting, just gears."
                self.stateDidChange?(self.state, self.statusText)
            }
        } catch {
            state = .failed
            let message = "\(engineName) could not start: \(error.localizedDescription)"
            _ = try? appendSystemMessage(message)
            statusText = message
            stateDidChange?(state, statusText)
        }
    }

    private func oneShotPrompt(userMessage: String) -> String {
        """
        \(bindingPrompt())

        User message:
        \(userMessage)

        First verify/control the assigned VM through OPNDRM's local socket if needed:
        printf '{"action":"boot","name":"\(vmName)"}\n' | nc -w 2 127.0.0.1 7777
        printf '{"action":"status"}\n' | nc -w 2 127.0.0.1 7777
        printf '{"action":"console.write","name":"\(vmName)","text":"root\n"}\n' | nc -w 2 127.0.0.1 7777
        printf '{"action":"console.read","name":"\(vmName)","limit":4000}\n' | nc -w 2 127.0.0.1 7777

        For Linux actions, use console.write with shell commands and console.read for proof. Do not just describe work; operate the VM when the user asks.

        Reply in the OPNDRM voice: curious, helpful, minimal, truthful. A tiny smart joke is okay; fake certainty is not.
        If a requested guest action is not available through the current VM API, say that clearly and offer the next useful step.
        """
    }

    private static func cleanEngineOutput(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\u{001B}\\[[0-9;]*[A-Za-z]", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
            if role == "system" { return "OPNDRM: \(content)" }
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
        printf '{"action":"boot","name":"\(vmName)"}\n' | nc 127.0.0.1 7777
        printf '{"action":"status"}\n' | nc 127.0.0.1 7777

        Linux console control:
        printf '{"action":"console.write","name":"\(vmName)","text":"root\n"}\n' | nc 127.0.0.1 7777
        printf '{"action":"console.write","name":"\(vmName)","text":"uname -a\n"}\n' | nc 127.0.0.1 7777
        printf '{"action":"console.read","name":"\(vmName)","limit":4000}\n' | nc 127.0.0.1 7777

        Chat bridge:
        - OPNDRM_AGENT_CHAT points to the in-app chat log for this agent.
        - Read new user messages from that file when available.
        - Keep replies short and focused on work inside \(vmName).
        - Stay alive: give small status updates while working, and never pretend a capability exists.

        Voice:
        - Curious, helpful, and calm.
        - Minimal output, but enough that the user knows you are working.
        - Tiny intelligent jokes are welcome when they reduce stress. No clown car.

        Policy:
        - One named agent per VM assignment.
        - Ask before destructive VM or guest operations.
        - Open Dream workflow install is optional; run it only if the user asks.
        """
    }

    private func agentRoot() throws -> URL {
        try Self.agentRoot(for: vmName, kind: kind, agentName: rootAgentName)
    }

    private static func launchScript(command: URL, kind: Kind, promptURL: URL) -> String {
        let quotedCommand = shellQuote(command.path)
        let workdir = shellQuote(promptURL.deletingLastPathComponent().path)
        let extraArgs = agentArguments(kind: kind, promptURL: promptURL).map(shellQuote).joined(separator: " ")
        let execLine: String
        switch kind {
        case .jcode:
            execLine = "exec /usr/bin/script -q -F agent.pty.log \(quotedCommand) \(extraArgs)"
        case .prime:
            execLine = "exec \(quotedCommand) \(extraArgs)"
        }
        return """
        #!/bin/zsh
        set -euo pipefail
        cd \(workdir)
        echo "OPNDRM VM ghost harness starting: kind=\(kind.safeName) vm=${OPNDRM_VM_NAME:-} agent=${OPNDRM_AGENT_NAME:-}"
        echo "Binding prompt: ${OPNDRM_VM_BINDING_PROMPT:-}"
        echo "Chat file: ${OPNDRM_AGENT_CHAT:-}"
        \(execLine)
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

    private static func primeRunCommand() -> URL? {
        if let raw = ProcessInfo.processInfo.environment["OPNDRM_PRIME_AGENT_RUN_COMMAND"], !raw.isEmpty {
            let url = URL(fileURLWithPath: NSString(string: raw).expandingTildeInPath)
            return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
        }
        // The bundled prime-agent-acp is an ACP adapter, not a one-shot runner.
        // Do not pretend it can chat until a runnable Prime command is configured.
        return nil
    }

    private static func primeRunArguments(prompt: String) -> [String] {
        if let raw = ProcessInfo.processInfo.environment["OPNDRM_PRIME_AGENT_RUN_ARGS"], !raw.isEmpty {
            return raw.split(separator: " ").map(String.init) + [prompt]
        }
        return []
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
