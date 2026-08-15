const crypto = require('crypto');
function readBody(request) { return new Promise((resolve, reject) => { let body = ''; request.on('data', (chunk) => { body += chunk; }); request.on('end', () => resolve(body)); request.on('error', reject); }); }
function sessionValue(secret) { return crypto.createHmac('sha256', secret).update('opndrm-admin').digest('base64url'); }
module.exports = async (request, response) => {
  if (request.method !== 'POST') { response.status(405).end('Method not allowed'); return; }
  const passcode = process.env.ADMIN_PASSCODE; const sessionSecret = process.env.ADMIN_SESSION_SECRET;
  if (!passcode || !sessionSecret) { response.status(503).end('Admin access is not configured.'); return; }
  const form = new URLSearchParams(await readBody(request)); const supplied = Buffer.from(form.get('passcode') || ''); const expected = Buffer.from(passcode.trim());
  if (supplied.length !== expected.length || !crypto.timingSafeEqual(supplied, expected)) { response.writeHead(303, { Location: '/admin/login?error=1' }); response.end(); return; }
  response.writeHead(303, { Location: '/admin', 'Set-Cookie': `opndrm_admin=${sessionValue(sessionSecret)}; Path=/; Max-Age=28800; HttpOnly; Secure; SameSite=Strict` }); response.end();
};
