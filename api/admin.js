const crypto = require('crypto');

function cookieValue(request, name) {
  const entry = (request.headers.cookie || '').split(';').map((part) => part.trim()).find((part) => part.startsWith(`${name}=`));
  return entry ? entry.slice(name.length + 1) : '';
}

function sessionValue(secret) {
  return crypto.createHmac('sha256', secret).update('opndrm-admin').digest('base64url');
}

function isAuthorized(request) {
  const secret = process.env.ADMIN_SESSION_SECRET;
  const received = cookieValue(request, 'opndrm_admin');
  if (!secret || !received) return false;
  const expected = sessionValue(secret);
  return received.length === expected.length && crypto.timingSafeEqual(Buffer.from(received), Buffer.from(expected));
}

module.exports = (request, response) => {
  if (!isAuthorized(request)) {
    response.writeHead(303, { Location: '/admin/login' });
    response.end();
    return;
  }
  response.setHeader('Content-Type', 'text/html; charset=utf-8');
  response.end(`<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Open Dream Prime — Admin</title><style>:root{--ink:#0a0a0a;--paper:#fff;--warm:#f7f6f2}*{box-sizing:border-box}body{margin:0;background:var(--warm);color:var(--ink);font-family:Arial,Helvetica,sans-serif}.page{width:min(100% - 2rem,72rem);margin:auto;padding:4rem 0}p,code,button{font:700 .76rem/1.4 SFMono-Regular,Consolas,monospace;letter-spacing:.08em;text-transform:uppercase}h1{max-width:10ch;margin:.5rem 0 2rem;font-size:clamp(4rem,10vw,9rem);line-height:.78;letter-spacing:-.1em}section{border-top:1px solid var(--ink);padding:1.25rem 0 3rem}.tabs{display:flex;flex-wrap:wrap;gap:.5rem;margin:1.25rem 0}button{min-height:3.25rem;padding:0 1rem;border:1px solid var(--ink);background:var(--paper);color:var(--ink);cursor:pointer}button[aria-pressed=true]{background:var(--ink);color:var(--paper)}pre{padding:1rem;border:1px solid var(--ink);background:var(--paper);overflow:auto}a{color:inherit}</style></head><body><main class="page"><p>OPEN DREAM PRIME · TEAM ADMIN</p><h1>TEAM<br>WORK.</h1><section><p>Protected installers for existing team projects.</p><div class="tabs"><button data-platform="mac" aria-pressed="true">MAC</button><button data-platform="windows" aria-pressed="false">WINDOWS</button></div><div class="tabs"><button data-lane="ADAM" aria-pressed="true">ADAM</button><button data-lane="FRNKLY.ONE" aria-pressed="false">FRNKLY.ONE</button></div><pre><code id="command"></code></pre><button id="copy">COPY INSTALL</button></section><section><p>Public new-build installer</p><a href="/#install">OPEN OPNDRM APP</a></section></main><script>let platform='mac',lane='ADAM';const render=()=>{document.querySelectorAll('[data-platform]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.platform===platform)));document.querySelectorAll('[data-lane]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.lane===lane)));document.querySelector('#command').textContent=platform==='mac'?\`curl -fsSL https://opndrm.com/install-macos.sh | bash -s -- \${lane}\`:\`& ([scriptblock]::Create((irm https://opndrm.com/install-windows.ps1))) -Lane \${lane}\`;};document.querySelectorAll('[data-platform]').forEach(b=>b.onclick=()=>{platform=b.dataset.platform;render()});document.querySelectorAll('[data-lane]').forEach(b=>b.onclick=()=>{lane=b.dataset.lane;render()});document.querySelector('#copy').onclick=async()=>{await navigator.clipboard.writeText(document.querySelector('#command').textContent);document.querySelector('#copy').textContent='COPIED'};render();</script></body></html>`);
};
