import AppKit
@preconcurrency import Virtualization

enum VMLayoutMode: Int, CaseIterable {
    case single = 0, split = 1, triple = 2, quad = 3

    var tileCount: Int {
        switch self {
        case .single: return 1
        case .split: return 2
        case .triple: return 3
        case .quad: return 4
        }
    }
}

@MainActor
final class OPNDRMVMLayoutView: NSView {
    var layoutMode: VMLayoutMode = .single {
        didSet { relayout() }
    }
    private var tiles: [OPNDRMVMLayoutTile] = []
    private let containerView = NSView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.cgColor
        addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        relayout()
    }

    func setVMViews(_ views: [VZVirtualMachineView]) {
        tiles.forEach { $0.removeFromSuperview() }
        tiles = views.enumerated().map { idx, vmView in
            let tile = OPNDRMVMLayoutTile(index: idx)
            tile.vmView = vmView
            return tile
        }
        relayout()
    }

    private func relayout() {
        tiles.forEach { $0.removeFromSuperview() }
        let count = min(tiles.count, layoutMode.tileCount)
        let active = Array(tiles.prefix(count))

        for tile in active {
            containerView.addSubview(tile)
            tile.translatesAutoresizingMaskIntoConstraints = false
        }

        let bounds = containerView.bounds
        switch layoutMode {
        case .single:
            guard let tile = active.first else { return }
            NSLayoutConstraint.activate([
                tile.topAnchor.constraint(equalTo: containerView.topAnchor),
                tile.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                tile.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                tile.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            ])
        case .split:
            guard active.count >= 2 else { fallBackToSingle(active) ; return }
            let half = bounds.width / 2
            NSLayoutConstraint.activate([
                active[0].topAnchor.constraint(equalTo: containerView.topAnchor),
                active[0].bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                active[0].leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                active[0].widthAnchor.constraint(equalToConstant: half),

                active[1].topAnchor.constraint(equalTo: containerView.topAnchor),
                active[1].bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                active[1].leadingAnchor.constraint(equalTo: active[0].trailingAnchor),
                active[1].trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            ])
        case .triple:
            guard active.count >= 3 else { fallBackToSingle(active) ; return }
            let half = bounds.width / 2
            let thirdHeight = bounds.height / 2
            NSLayoutConstraint.activate([
                active[0].topAnchor.constraint(equalTo: containerView.topAnchor),
                active[0].bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                active[0].leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                active[0].widthAnchor.constraint(equalToConstant: half),

                active[1].topAnchor.constraint(equalTo: containerView.topAnchor),
                active[1].heightAnchor.constraint(equalToConstant: thirdHeight),
                active[1].leadingAnchor.constraint(equalTo: active[0].trailingAnchor),
                active[1].trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

                active[2].topAnchor.constraint(equalTo: active[1].bottomAnchor),
                active[2].bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                active[2].leadingAnchor.constraint(equalTo: active[0].trailingAnchor),
                active[2].trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            ])
        case .quad:
            guard active.count >= 4 else { fallBackToSingle(active) ; return }
            let half = bounds.width / 2
            let halfHeight = bounds.height / 2
            NSLayoutConstraint.activate([
                active[0].topAnchor.constraint(equalTo: containerView.topAnchor),
                active[0].heightAnchor.constraint(equalToConstant: halfHeight),
                active[0].leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                active[0].widthAnchor.constraint(equalToConstant: half),

                active[1].topAnchor.constraint(equalTo: containerView.topAnchor),
                active[1].heightAnchor.constraint(equalToConstant: halfHeight),
                active[1].leadingAnchor.constraint(equalTo: active[0].trailingAnchor),
                active[1].trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

                active[2].topAnchor.constraint(equalTo: active[0].bottomAnchor),
                active[2].bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                active[2].leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                active[2].widthAnchor.constraint(equalToConstant: half),

                active[3].topAnchor.constraint(equalTo: active[1].bottomAnchor),
                active[3].bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                active[3].leadingAnchor.constraint(equalTo: active[2].trailingAnchor),
                active[3].trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            ])
        }
    }

    private func fallBackToSingle(_ active: [OPNDRMVMLayoutTile]) {
        guard let tile = active.first else { return }
        NSLayoutConstraint.activate([
            tile.topAnchor.constraint(equalTo: containerView.topAnchor),
            tile.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            tile.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tile.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])
    }
}

@MainActor
final class OPNDRMVMLayoutTile: NSView {
    let index: Int
    var vmView: VZVirtualMachineView? {
        didSet {
            oldValue?.removeFromSuperview()
            guard let vmView else { return }
            vmView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(vmView)
            NSLayoutConstraint.activate([
                vmView.topAnchor.constraint(equalTo: topAnchor),
                vmView.bottomAnchor.constraint(equalTo: bottomAnchor),
                vmView.leadingAnchor.constraint(equalTo: leadingAnchor),
                vmView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }
    }

    init(index: Int) {
        self.index = index
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.darkGray.cgColor
    }

    required init?(coder: NSCoder) { nil }
}
