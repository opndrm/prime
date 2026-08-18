import SwiftUI

struct BuzzContainerOverlay: View {
    @Environment(ContainerPresentationState.self) private var state

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Agent Computer")
                        .font(.title2.weight(.semibold))
                    Text("A private task workspace, when one is explicitly assigned.")
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 12) {
                    status(label: "Provider", value: state.provider)
                    status(label: "Task", value: state.lifecycle)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("Live view \(state.viewer)", systemImage: "eye.slash")
                        .foregroundStyle(.secondary)
                    Text(state.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                if let proofFrame = state.proofFrame {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NATIVE PIXELS · WATCH-ONLY")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        ScrollView([.horizontal, .vertical]) {
                            // Keep the producer's native dimensions. A larger
                            // desktop scrolls instead of being silently
                            // downscaled or blurred; nearest interpolation
                            // preserves the exact source pixels when shown.
                            Image(nsImage: proofFrame)
                                .interpolation(.none)
                                .fixedSize()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .accessibilityLabel("View-only container proof frame at native pixels")
                }

                HStack {
                    Button(action: {}) {
                        Label("Buzz Record \(state.record)", systemImage: "record.circle")
                    }
                    .disabled(true)
                    .help("Buzz Record stays unavailable until a real watch-only container view is proven. It will record only the task container, never this Mac.")
                    Spacer()
                    Text("Nothing is running")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            Spacer(minLength: 0)
        }
        .frame(minWidth: 560, minHeight: 420)
        .background(.background)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: 24, height: 17)
                Text("B")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.yellow)
            }
            Text("Buzz Container")
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 18)
        .frame(height: 52)
    }

    private func status(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ContainerBubble: View {
    @Environment(ContainerPresentationState.self) private var state
    let open: () -> Void
    let drag: (CGSize, Bool) -> Void

    var body: some View {
        Button(action: open) {
            ZStack {
                VStack(spacing: 3) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.yellow, lineWidth: 3)
                            .frame(width: 39, height: 27)
                        Text("B")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.yellow)
                    }
                    Capsule()
                        .fill(Color.yellow)
                        .frame(width: 46, height: 4)
                }
            }
            .frame(width: 62, height: 62)
        }
        .buttonStyle(.plain)
        .help("Buzz Container: \(state.lifecycle). Click to open or drag to move.")
        .accessibilityLabel("Open Buzz Container")
        .simultaneousGesture(
            DragGesture(minimumDistance: 4)
                .onChanged { drag($0.translation, false) }
                .onEnded { drag($0.translation, true) }
        )
    }
}
