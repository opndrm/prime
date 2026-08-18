/**
 * Provider-neutral contract for one OpenDream Prime agent computer.
 *
 * This is intentionally descriptive, not a cloud client. A future remote
 * adapter must implement this contract only after an owner chooses a provider,
 * explicitly authorizes an account and billing, and approves a separate work
 * card. Until then the remote record is nonfunctional by design.
 */

export const agentComputerIdentity = Object.freeze({
  id: 'prime-agent-computer',
  agentId: 'prime',
  displayName: 'PRIME — Prime Agent',
  workspaceId: 'prime-default',
  owner: 'local-mac-owner',
});

export const lifecycleStates = Object.freeze(['idle', 'starting', 'ready', 'stopped', 'failed']);

export const persistenceContract = Object.freeze({
  workspace: 'project-local persistent workspace',
  metadata: '.opndrm/agent-computers/prime/metadata.json',
  snapshot: {
    state: 'not-created',
    note: 'Snapshot capture and restore require a separately approved provider implementation.',
  },
});

export function providersFor(localStatus) {
  const localAvailable = localStatus.runtime === 'ready' && localStatus.image === 'ready';
  return [
    {
      id: 'apple-container-local',
      kind: 'local',
      displayName: 'Apple Container — This Mac',
      state: localStatus.state,
      available: localAvailable,
      capabilities: ['persistent-workspace', 'interactive-terminal', 'local-live-view'],
      limits: ['no browser control', 'no network or DNS', 'no remote access'],
    },
    {
      id: 'remote-provider-unconfigured',
      kind: 'remote',
      displayName: 'Remote provider — Not configured',
      state: 'unavailable',
      available: false,
      capabilities: [],
      limits: ['no provider selected', 'no account, credentials, billing, VM, or deployment created'],
      activationGate: 'Owner must select a provider and separately approve account, billing, and implementation.',
    },
  ];
}

export function agentComputerContract(localStatus) {
  const providers = providersFor(localStatus);
  return {
    identity: agentComputerIdentity,
    lifecycle: { current: localStatus.state, allowed: lifecycleStates },
    activeProvider: providers[0],
    providers,
    persistence: {
      ...persistenceContract,
      workspacePath: localStatus.workspace.path,
      workspaceState: localStatus.workspace.state,
      metadataPath: localStatus.workspace.metadataPath,
    },
    liveView: {
      state: localStatus.state === 'ready' ? 'available' : 'waiting',
      source: 'local lifecycle status and scoped workspace index',
      session: localStatus.state === 'ready' ? 'interactive terminal available on this Mac' : 'start the local computer to open a terminal session',
      browser: 'not included in the first slice',
      remoteSession: 'unavailable — remote provider is not configured',
    },
  };
}
