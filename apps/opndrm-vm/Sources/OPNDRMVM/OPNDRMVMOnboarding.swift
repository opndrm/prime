import AppKit

@MainActor
final class OPNDRMVMOnboardingView: NSView {
    var onCreateVM: (() -> Void)?

    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let titleLabel = NSTextField(labelWithString: "Welcome to OPNDRM VM")
        titleLabel.font = NSFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        let subtitleLabel = NSTextField(labelWithString: "A safe sandbox for AI agents. Create a VM, connect any AI, and watch it work.")
        subtitleLabel.font = NSFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)

        let createButton = NSButton(title: "Create Your First VM", target: self, action: #selector(createClicked))
        createButton.bezelStyle = .rounded
        createButton.controlSize = .large
        createButton.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        createButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(createButton)

        let docsButton = NSButton(title: "Read the Docs", target: self, action: #selector(docsClicked))
        docsButton.bezelStyle = .rounded
        docsButton.controlSize = .large
        docsButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(docsButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 120),

            subtitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),

            createButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            createButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),

            docsButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            docsButton.topAnchor.constraint(equalTo: createButton.bottomAnchor, constant: 12),
        ])
    }

    @objc private func createClicked() { onCreateVM?() }
    @objc private func docsClicked() {
        NSWorkspace.shared.open(URL(string: "https://opndrm.com/docs")!)
    }
}

@MainActor
final class OPNDRMVMDocsView: NSView {
    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        addSubview(scrollView)

        let contentView = NSView()
        scrollView.documentView = contentView

        let titleLabel = NSTextField(labelWithString: "Quick Start")
        titleLabel.font = NSFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        let installLabel = NSTextField(labelWithString: "Install the Open Dream AI Workflow inside your VM:")
        installLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        installLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(installLabel)

        let installCommand = NSTextField(labelWithString: "curl -fsSL https://opndrm.com/install | bash")
        installCommand.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        installCommand.translatesAutoresizingMaskIntoConstraints = false
        installCommand.wantsLayer = true
        installCommand.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        installCommand.layer?.cornerRadius = 6
        contentView.addSubview(installCommand)

        let copyButton = NSButton(title: "Copy", target: self, action: #selector(copyCommand))
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(copyButton)

        let installsLabel = NSTextField(labelWithString:
            "Installs: WezTerm, HERDR, Prime Agent, JCode, Ollama, oMLX, OpenAdapt, Handy\n\n" +
            "HERDR Layout:\n" +
            "  OFFLINE     → Prime Agent + oMLX / Qwen3.8-27B\n" +
            "  OPNDRM      → Prime Agent + Ollama Cloud\n" +
            "  OPNDRM JC   → JCode\n" +
            "  OPNDRM NM   → inactive"
        )
        installsLabel.font = NSFont.systemFont(ofSize: 12)
        installsLabel.textColor = .secondaryLabelColor
        installsLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(installsLabel)

        let docsLink = NSButton(title: "Full documentation at opndrm.com/docs", target: self, action: #selector(openDocs))
        docsLink.bezelStyle = .inline
        docsLink.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(docsLink)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),

            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),

            installLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            installLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),

            installCommand.topAnchor.constraint(equalTo: installLabel.bottomAnchor, constant: 8),
            installCommand.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            installCommand.widthAnchor.constraint(equalToConstant: 380),

            copyButton.centerYAnchor.constraint(equalTo: installCommand.centerYAnchor),
            copyButton.leadingAnchor.constraint(equalTo: installCommand.trailingAnchor, constant: 8),

            installsLabel.topAnchor.constraint(equalTo: installCommand.bottomAnchor, constant: 24),
            installsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),

            docsLink.topAnchor.constraint(equalTo: installsLabel.bottomAnchor, constant: 16),
            docsLink.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            docsLink.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24),
        ])
    }

    @objc private func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("curl -fsSL https://opndrm.com/install | bash", forType: .string)
    }

    @objc private func openDocs() {
        NSWorkspace.shared.open(URL(string: "https://opndrm.com/docs")!)
    }
}
