/**
 * A deliberately small, loopback-only control surface for the first Prime
 * local agent computer. It serves the existing site and only calls fixed
 * lifecycle commands; it does not accept terminal input, paths, credentials,
 * or remote connections.
 */

import { createServer } from 'node:http';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { readdir, lstat } from 'node:fs/promises';
import { agentComputerContract } from './agent-computer-contract.mjs';

const execFileAsync = promisify(execFile);
const scriptDirectory = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(scriptDirectory, '..', '..');
const lifecycle = join(scriptDirectory, 'agent-computer.sh');
const site = join(projectRoot, 'site', 'index.html');
const workspace = join(projectRoot, '.opndrm', 'agent-computers', 'prime', 'workspace');
const host = '127.0.0.1';
const configuredPort = Number(process.env.OPNDRM_AGENT_COMPUTER_PORT || 4177);
const port = Number.isInteger(configuredPort) && configuredPort > 0 && configuredPort < 65536 ? configuredPort : 4177;
const actions = new Set(['start', 'stop', 'restart', 'clean']);
let pendingStart = false;
let lastStartError = '';

function send(response, status, body, headers = {}) {
  response.writeHead(status, { 'Cache-Control': 'no-store', ...headers });
  response.end(body);
}

function json(response, status, value) {
  send(response, status, JSON.stringify(value), { 'Content-Type': 'application/json; charset=utf-8' });
}

async function lifecycleStatus() {
  const { stdout } = await execFileAsync('bash', [lifecycle, 'status', '--json'], { cwd: projectRoot, timeout: 10_000 });
  const local = JSON.parse(stdout);
  if (pendingStart && local.state !== 'ready') local.state = 'starting';
  if (lastStartError && local.state !== 'ready') {
    local.state = 'failed';
    local.error = lastStartError;
  }
  return { ...local, architecture: agentComputerContract(local) };
}

async function runAction(action) {
  await execFileAsync('bash', [lifecycle, action], { cwd: projectRoot, timeout: 45_000 });
  return lifecycleStatus();
}

async function beginStart(action) {
  if (!pendingStart) {
    pendingStart = true;
    lastStartError = '';
    execFileAsync('bash', [lifecycle, action], { cwd: projectRoot, timeout: 90_000 })
      .catch((error) => { lastStartError = String(error?.stderr || error?.message || 'Local startup failed.').trim().split('\n').at(-1); })
      .finally(() => { pendingStart = false; });
  }
  return lifecycleStatus();
}

async function workspaceFiles() {
  try {
    const entries = await readdir(workspace, { withFileTypes: true });
    const files = await Promise.all(entries.slice(0, 100).sort((a, b) => a.name.localeCompare(b.name)).map(async (entry) => {
      const stat = await lstat(join(workspace, entry.name));
      return { name: entry.name, kind: entry.isDirectory() ? 'folder' : entry.isSymbolicLink() ? 'link' : 'file', updatedAt: stat.mtime.toISOString() };
    }));
    return { workspace, files, truncated: entries.length > 100 };
  } catch (error) {
    if (error?.code === 'ENOENT') return { workspace, files: [], truncated: false };
    throw error;
  }
}

function isLocalOrigin(request) {
  const origin = request.headers.origin;
  return !origin || origin === `http://${host}:${port}`;
}

const server = createServer(async (request, response) => {
  try {
    const url = new URL(request.url || '/', `http://${host}:${port}`);
    if (request.method === 'GET' && (url.pathname === '/' || url.pathname === '/index.html')) {
      const content = await import('node:fs/promises').then(({ readFile }) => readFile(site));
      send(response, 200, content, { 'Content-Type': 'text/html; charset=utf-8' });
      return;
    }
    if (request.method === 'GET' && url.pathname === '/api/agent-computer/status') {
      json(response, 200, await lifecycleStatus());
      return;
    }
    if (request.method === 'GET' && url.pathname === '/api/agent-computer/files') {
      json(response, 200, await workspaceFiles());
      return;
    }
    if (request.method === 'POST' && url.pathname.startsWith('/api/agent-computer/')) {
      if (!isLocalOrigin(request)) {
        json(response, 403, { error: 'Local-origin request required.' });
        return;
      }
      const action = url.pathname.split('/').at(-1);
      if (action === 'terminal') {
        const status = await lifecycleStatus();
        json(response, status.state === 'ready' ? 200 : 409, { status, terminalCommand: status.terminalCommand });
        return;
      }
      if (!actions.has(action)) {
        json(response, 404, { error: 'Unknown local agent computer action.' });
        return;
      }
      if (action === 'clean' && request.headers['x-opndrm-confirm'] !== 'clean-prime-local-agent-computer') {
        json(response, 400, { error: 'Explicit clean confirmation required.' });
        return;
      }
      if (action === 'start' || action === 'restart') {
        json(response, 202, await beginStart(action));
        return;
      }
      lastStartError = '';
      json(response, 200, await runAction(action));
      return;
    }
    json(response, 404, { error: 'Not found.' });
  } catch (error) {
    const detail = String(error?.stderr || error?.message || 'Local agent computer action failed.').trim().split('\n').at(-1);
    json(response, 500, { error: detail || 'Local agent computer action failed.' });
  }
});

server.listen(port, host, () => {
  process.stdout.write(`OpenDream Prime local agent computer view: http://${host}:${port}\n`);
});
