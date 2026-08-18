#!/usr/bin/env node
/**
 * Data-only MCP ingress for an owner-local BuzzBot overlay receiver.
 *
 * This process deliberately has no process, shell, web-client, credential, or VM
 * capabilities.  Its only side effect is one bounded write to an explicitly
 * configured Unix-domain socket after the complete request has been checked.
 */
import fs from 'node:fs';
import net from 'node:net';
import path from 'node:path';
import readline from 'node:readline';

const JSON_RPC_VERSION = '2.0';
const SCHEMA_VERSION = 1;
const ACTION = 'presentExactVMOverlay';
const TOOL_NAME = 'open_buzzbot_vm';
const FOUNDATION_REFERENCE_UNIX_SECONDS = 978307200;
const MAX_INPUT_BYTES = 16 * 1024;
const MAX_SOCKET_RESPONSE_BYTES = 8 * 1024;
const SOCKET_TIMEOUT_MS = 1500;
const ZERO_UUID = '00000000-0000-0000-0000-000000000000';
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const UUID_SCHEMA_PATTERN = '^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$';
const AGENT_ID_PATTERN = /^[A-Za-z0-9._:-]+$/;
const TASK_ID_PATTERN = /^[A-Za-z0-9._:/-]+$/;
const REFUSAL_REASONS = new Set([
  'malformedSchema', 'actionNotApproved', 'requestNotApproved', 'leaseNotActive',
  'leaseBindingMismatch', 'exactVMMismatch', 'bootEpochMismatch', 'leaseExpired',
  'invalidValidationTime',
]);

const requestSchema = {
  type: 'object',
  additionalProperties: false,
  required: ['schemaVersion', 'action', 'binding'],
  properties: {
    schemaVersion: { type: 'integer', const: SCHEMA_VERSION },
    action: { type: 'string', const: ACTION },
    binding: {
      type: 'object',
      additionalProperties: false,
      required: ['requestID', 'agentID', 'taskID', 'leaseID', 'persistentVMID', 'bootEpoch', 'expiresAt'],
      properties: {
        requestID: { type: 'string', pattern: UUID_SCHEMA_PATTERN },
        agentID: { type: 'string', minLength: 1, maxLength: 128, pattern: '^[A-Za-z0-9._:-]+$' },
        taskID: { type: 'string', minLength: 1, maxLength: 256, pattern: '^[A-Za-z0-9._:/-]+$' },
        leaseID: { type: 'string', pattern: UUID_SCHEMA_PATTERN },
        persistentVMID: { type: 'string', pattern: UUID_SCHEMA_PATTERN },
        bootEpoch: { type: 'string', pattern: UUID_SCHEMA_PATTERN },
        // Foundation's default Codable Date JSON representation: seconds since 2001-01-01.
        expiresAt: { type: 'number' },
      },
    },
  },
};

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value) && Object.getPrototypeOf(value) === Object.prototype;
}

function hasOnlyKeys(value, keys) {
  return isPlainObject(value) && Object.keys(value).every((key) => keys.has(key));
}

function schemaError() {
  // Intentionally fixed: never reflect potentially unbounded caller data.
  return new Error('invalid overlay request schema');
}

function normalizeUUID(value) {
  if (typeof value !== 'string' || !UUID_PATTERN.test(value)) throw schemaError();
  const normalized = value.toLowerCase();
  if (normalized === ZERO_UUID) throw schemaError();
  return normalized;
}

/** Return a clean object containing only the bounded, allowlisted wire fields. */
function validateOverlayRequest(value, nowUnixSeconds = Date.now() / 1000) {
  const requestKeys = new Set(['schemaVersion', 'action', 'binding']);
  const bindingKeys = new Set(['requestID', 'agentID', 'taskID', 'leaseID', 'persistentVMID', 'bootEpoch', 'expiresAt']);
  if (!hasOnlyKeys(value, requestKeys) || Object.keys(value).length !== 3 ||
      value.schemaVersion !== SCHEMA_VERSION || value.action !== ACTION ||
      !hasOnlyKeys(value.binding, bindingKeys) || Object.keys(value.binding).length !== 7) {
    throw schemaError();
  }

  const binding = value.binding;
  if (typeof binding.agentID !== 'string' || Buffer.byteLength(binding.agentID, 'utf8') < 1 ||
      Buffer.byteLength(binding.agentID, 'utf8') > 128 || !AGENT_ID_PATTERN.test(binding.agentID) ||
      typeof binding.taskID !== 'string' || Buffer.byteLength(binding.taskID, 'utf8') < 1 ||
      Buffer.byteLength(binding.taskID, 'utf8') > 256 || !TASK_ID_PATTERN.test(binding.taskID) ||
      typeof binding.expiresAt !== 'number' || !Number.isFinite(binding.expiresAt) ||
      !Number.isFinite(nowUnixSeconds)) {
    throw schemaError();
  }

  const requestID = normalizeUUID(binding.requestID);
  const leaseID = normalizeUUID(binding.leaseID);
  const persistentVMID = normalizeUUID(binding.persistentVMID);
  const bootEpoch = normalizeUUID(binding.bootEpoch);
  if (new Set([requestID, leaseID, persistentVMID, bootEpoch]).size !== 4) throw schemaError();

  const expiryUnixSeconds = binding.expiresAt + FOUNDATION_REFERENCE_UNIX_SECONDS;
  // Reject stale requests. This bridge does not queue, retry, or retain
  // requests, and forwards no request that is no longer valid at call time.
  if (!Number.isFinite(expiryUnixSeconds) || expiryUnixSeconds <= nowUnixSeconds) {
    throw schemaError();
  }

  return {
    schemaVersion: SCHEMA_VERSION,
    action: ACTION,
    binding: {
      requestID,
      agentID: binding.agentID,
      taskID: binding.taskID,
      leaseID,
      persistentVMID,
      bootEpoch,
      expiresAt: binding.expiresAt,
    },
  };
}

function validateReceiverResponse(value, request) {
  const responseKeys = new Set(['schemaVersion', 'outcome', 'action', 'binding', 'refusalReason']);
  if (!hasOnlyKeys(value, responseKeys) || value.schemaVersion !== SCHEMA_VERSION ||
      (value.outcome !== 'approved' && value.outcome !== 'refused') || value.action !== ACTION ||
      !Object.prototype.hasOwnProperty.call(value, 'binding')) {
    throw new Error('invalid local receiver response');
  }
  const responseBinding = validateOverlayRequest({
    schemaVersion: value.schemaVersion, action: value.action, binding: value.binding,
  });
  // The response must reproduce the request that was checked immediately
  // before it was sent; an expired response is refused as malformed.
  if (JSON.stringify(responseBinding.binding) !== JSON.stringify(request.binding)) {
    throw new Error('invalid local receiver response');
  }
  const hasReason = Object.prototype.hasOwnProperty.call(value, 'refusalReason');
  if ((value.outcome === 'approved' && hasReason) ||
      (value.outcome === 'refused' && (!hasReason || typeof value.refusalReason !== 'string' || !REFUSAL_REASONS.has(value.refusalReason)))) {
    throw new Error('invalid local receiver response');
  }
  return value.outcome === 'approved'
    ? { schemaVersion: SCHEMA_VERSION, outcome: 'approved', action: ACTION, binding: request.binding }
    : { schemaVersion: SCHEMA_VERSION, outcome: 'refused', action: ACTION, binding: request.binding, refusalReason: value.refusalReason };
}

async function configuredOwnerSocketPath() {
  const socketPath = process.env.BUZZBOT_OVERLAY_SOCKET_PATH;
  if (typeof socketPath !== 'string' || socketPath.length === 0 || socketPath.length > 104 ||
      !path.isAbsolute(socketPath) || path.normalize(socketPath) !== socketPath || socketPath.includes('\0')) {
    throw new Error('local receiver unavailable');
  }
  let stat;
  try {
    stat = await fs.promises.lstat(socketPath);
  } catch {
    throw new Error('local receiver unavailable');
  }
  // Do not connect to a substituted regular file, a symlink, a socket owned by
  // someone else, or a socket writable by group/other users.
  if (!stat.isSocket() || (typeof process.getuid === 'function' && stat.uid !== process.getuid()) || (stat.mode & 0o022) !== 0) {
    throw new Error('local receiver unavailable');
  }
  return socketPath;
}

async function sendToLocalReceiver(request) {
  const socketPath = await configuredOwnerSocketPath();
  const payload = JSON.stringify(request);
  if (Buffer.byteLength(payload, 'utf8') > MAX_SOCKET_RESPONSE_BYTES) throw new Error('invalid overlay request schema');

  return new Promise((resolve, reject) => {
    let settled = false;
    let received = '';
    const fail = (message) => {
      if (settled) return;
      settled = true;
      socket.destroy();
      reject(new Error(message));
    };
    const socket = net.createConnection({ path: socketPath });
    socket.setTimeout(SOCKET_TIMEOUT_MS);
    socket.once('connect', () => socket.end(`${payload}\n`, 'utf8'));
    socket.on('data', (chunk) => {
      received += chunk.toString('utf8');
      if (Buffer.byteLength(received, 'utf8') > MAX_SOCKET_RESPONSE_BYTES) fail('invalid local receiver response');
    });
    socket.once('timeout', () => fail('local receiver unavailable'));
    socket.once('error', () => fail('local receiver unavailable'));
    socket.once('end', () => {
      if (settled) return;
      settled = true;
      try {
        // One newline-delimited JSON response only; no arbitrary stream or envelope.
        if (!received.endsWith('\n') || received.indexOf('\n') !== received.length - 1) throw new Error('invalid');
        resolve(validateReceiverResponse(JSON.parse(received.slice(0, -1)), request));
      } catch {
        reject(new Error('invalid local receiver response'));
      }
    });
  });
}

function jsonRpcError(id, code, message) {
  return { jsonrpc: JSON_RPC_VERSION, id: id ?? null, error: { code, message } };
}

function isValidId(id) {
  return typeof id === 'string' ? Buffer.byteLength(id, 'utf8') <= 128 : typeof id === 'number' && Number.isFinite(id);
}

function serverInfo() {
  return { name: 'buzzbot-overlay-mcp', version: '1.0.0' };
}

async function handleMessage(message) {
  const rpcKeys = new Set(['jsonrpc', 'id', 'method', 'params']);
  if (!hasOnlyKeys(message, rpcKeys) || message.jsonrpc !== JSON_RPC_VERSION || typeof message.method !== 'string') {
    return jsonRpcError(null, -32600, 'invalid request');
  }
  // MCP completes initialization with a JSON-RPC notification, which has no id
  // and therefore must not receive a JSON-RPC response.
  if (message.method === 'notifications/initialized' && !Object.prototype.hasOwnProperty.call(message, 'id')) return null;
  if (!Object.prototype.hasOwnProperty.call(message, 'id') || !isValidId(message.id)) return jsonRpcError(null, -32600, 'invalid request');
  const { id, method, params } = message;
  if (method === 'initialize') {
    if (params !== undefined && !isPlainObject(params)) return jsonRpcError(id, -32602, 'invalid params');
    return { jsonrpc: JSON_RPC_VERSION, id, result: {
      protocolVersion: typeof params?.protocolVersion === 'string' ? params.protocolVersion : '2024-11-05',
      capabilities: { tools: {} }, serverInfo: serverInfo(),
    } };
  }
  if (method === 'tools/list') {
    if (params !== undefined && (!isPlainObject(params) || Object.keys(params).length !== 0)) return jsonRpcError(id, -32602, 'invalid params');
    return { jsonrpc: JSON_RPC_VERSION, id, result: { tools: [{
      name: TOOL_NAME,
      description: 'Send a pre-authorized exact-VM overlay request to the owner-local receiver.',
      inputSchema: requestSchema,
    }] } };
  }
  if (method === 'tools/call') {
    if (!hasOnlyKeys(params, new Set(['name', 'arguments'])) || params.name !== TOOL_NAME || !Object.prototype.hasOwnProperty.call(params, 'arguments')) {
      return jsonRpcError(id, -32602, 'invalid params');
    }
    let request;
    try {
      request = validateOverlayRequest(params.arguments);
    } catch {
      return jsonRpcError(id, -32602, 'invalid overlay request schema');
    }
    try {
      const response = await sendToLocalReceiver(request);
      return { jsonrpc: JSON_RPC_VERSION, id, result: { content: [{ type: 'text', text: JSON.stringify(response) }] } };
    } catch (error) {
      const message = error?.message === 'invalid local receiver response' ? 'invalid local receiver response' : 'local receiver unavailable';
      return jsonRpcError(id, -32001, message);
    }
  }
  return jsonRpcError(id, -32601, 'method not found');
}

function emit(value) {
  process.stdout.write(`${JSON.stringify(value)}\n`);
}

const input = readline.createInterface({ input: process.stdin, crlfDelay: Infinity, terminal: false });

async function processLine(line) {
  if (Buffer.byteLength(line, 'utf8') > MAX_INPUT_BYTES) {
    emit(jsonRpcError(null, -32600, 'invalid request'));
    return;
  }
  let message;
  try { message = JSON.parse(line); } catch { emit(jsonRpcError(null, -32700, 'parse error')); return; }
  try {
    const response = await handleMessage(message);
    if (response !== null) emit(response);
  } catch { emit(jsonRpcError(null, -32603, 'internal error')); }
}

// Process one stdin record at a time. The async iterator applies stdin
// backpressure while a bounded local receiver call is in progress.
try {
  for await (const line of input) await processLine(line);
} catch {
  // Stdio transport failure cannot safely be reported on that same transport.
  process.exitCode = 1;
}
