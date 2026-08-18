import Foundation
@preconcurrency import Virtualization

enum MachineLifecycle: String {
    case unconfigured
    case ready
    case starting
    case running
    case pausing
    case paused
    case stopping
    case stopped
    case failed
}

@MainActor
final class VirtualMachineController: NSObject, VZVirtualMachineDelegate {
    private(set) var machine: VZVirtualMachine?
    private(set) var lifecycle: MachineLifecycle = .unconfigured {
        didSet { stateDidChange?(lifecycle, statusText) }
    }
    private(set) var statusText = "No machine available."

    var stateDidChange: ((MachineLifecycle, String) -> Void)?
    var machineDidStart: ((VZVirtualMachine) -> Void)?
    var becameSafeToTerminate: (() -> Void)?

    /// Guest command client, created when the VM starts and the socket device is available.
    private(set) var guestSocketClient: GuestSocketClient?

    var mayTerminateProcess: Bool { machine == nil }

    func setMachine(_ vm: VZVirtualMachine) {
        guard machine == nil, lifecycle == .unconfigured else { return }
        machine = vm
        lifecycle = .ready
        statusText = "Ready to start."
    }

    func start() {
        guard let machine, lifecycle == .ready else {
            statusText = "Cannot start: no machine ready."
            return
        }
        lifecycle = .starting
        statusText = "Starting guest..."
        machine.start { [weak self, machine] result in
            Task { @MainActor [weak self, machine] in
                guard let self, self.machine === machine else { return }
                switch result {
                case .success:
                    self.statusText = "Guest is running."
                    self.lifecycle = .running
                    FileHandle.standardError.write(Data("OPNDRMVM: VM started successfully\n".utf8))
                    self.setupGuestSocketClient(machine)
                    self.machineDidStart?(machine)
                case .failure(let error):
                    self.fail(error)
                }
            }
        }
    }

    private func setupGuestSocketClient(_ machine: VZVirtualMachine) {
        // Find the VZVirtioSocketDevice from the VM's socketDevices.
        for device in machine.socketDevices {
            if let virtioDevice = device as? VZVirtioSocketDevice {
                guestSocketClient = GuestSocketClient(socketDevice: virtioDevice)
                FileHandle.standardError.write(Data("OPNDRMVM: guest socket client ready\n".utf8))
                return
            }
        }
        FileHandle.standardError.write(Data("OPNDRMVM: no VZVirtioSocketDevice found\n".utf8))
    }

    func stop() {
        guard let machine, lifecycle == .running || lifecycle == .paused else { return }
        lifecycle = .stopping
        statusText = "Stopping guest..."
        machine.stop { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    self.fail(error)
                } else {
                    self.machine?.delegate = nil
                    self.machine = nil
                    self.statusText = "Guest stopped."
                    self.lifecycle = .stopped
                    self.becameSafeToTerminate?()
                }
            }
        }
    }

    func pause() {
        guard let machine, lifecycle == .running else { return }
        lifecycle = .pausing
        statusText = "Pausing guest..."
        machine.pause { [weak self] result in
            Task { @MainActor [weak self] in
                switch result {
                case .success:
                    self?.statusText = "Guest is paused."
                    self?.lifecycle = .paused
                case .failure(let error):
                    self?.fail(error)
                }
            }
        }
    }

    func resume() {
        guard let machine, lifecycle == .paused else { return }
        lifecycle = .starting
        statusText = "Resuming guest..."
        machine.resume { [weak self] result in
            Task { @MainActor [weak self] in
                switch result {
                case .success:
                    self?.statusText = "Guest is running."
                    self?.lifecycle = .running
                case .failure(let error):
                    self?.fail(error)
                }
            }
        }
    }

    func requestOrderlyStopForTermination() -> Bool {
        switch lifecycle {
        case .unconfigured, .stopped:
            return true
        case .ready:
            machine?.delegate = nil
            machine = nil
            lifecycle = .unconfigured
            return true
        case .running, .paused:
            stop()
            return false
        case .starting, .pausing, .stopping, .failed:
            return false
        }
    }

    nonisolated func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        let id = ObjectIdentifier(virtualMachine)
        Task { @MainActor [weak self] in
            guard let self, let m = self.machine, ObjectIdentifier(m) == id else { return }
            guard self.lifecycle != .stopping else { return }
            self.fail(VMError.unexpectedStop)
        }
    }

    nonisolated func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        let id = ObjectIdentifier(virtualMachine)
        let msg = error.localizedDescription
        Task { @MainActor [weak self] in
            guard let self, let m = self.machine, ObjectIdentifier(m) == id else { return }
            self.fail(VMError.delegateError(msg))
        }
    }

    private func fail(_ error: Error) {
        statusText = "Error: \(error.localizedDescription)"
        lifecycle = .failed
    }
}

enum VMError: LocalizedError {
    case unexpectedStop
    case delegateError(String)
    var errorDescription: String? {
        switch self {
        case .unexpectedStop: return "Guest stopped unexpectedly."
        case .delegateError(let m): return "Guest stopped with error: \(m)"
        }
    }
}
