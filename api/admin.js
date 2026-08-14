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

function buzzInviteUrl() {
  try {
    const url = new URL(process.env.OPNDRM_BUZZ_INVITE_URL);
    if (url.protocol !== 'https:' || url.hostname !== 'opndrm.communities.buzz.xyz' || !url.pathname.startsWith('/invite/')) return '';
    return url.toString();
  } catch {
    return '';
  }
}

function attribute(value) {
  return value.replace(/&/g, '&amp;').replace(/"/g, '&quot;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

module.exports = (request, response) => {
  if (!isAuthorized(request)) {
    response.writeHead(303, { Location: '/admin/login' });
    response.end();
    return;
  }
  const inviteUrl = buzzInviteUrl();
  response.setHeader('Content-Type', 'text/html; charset=utf-8');
  response.setHeader('Cache-Control', 'private, no-store, max-age=0');
  response.setHeader('Referrer-Policy', 'no-referrer');
  response.end(`<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Open Dream Prime — Team</title>
<style>:root{--ink:#0a0a0a;--paper:#fff;--warm:#f7f6f2;--focus:#2c59ff}*{box-sizing:border-box}body{margin:0;background:var(--warm);color:var(--ink);font-family:Arial,Helvetica,sans-serif}.page{width:min(100% - 2rem,72rem);margin:auto;padding:4rem 0}p,code,button,a.button{font:700 .76rem/1.4 SFMono-Regular,Consolas,monospace;letter-spacing:.08em;text-transform:uppercase}h1{max-width:10ch;margin:.5rem 0 2rem;font-size:clamp(4rem,10vw,9rem);line-height:.78;letter-spacing:-.1em}h2{margin:.5rem 0 1rem;font-size:clamp(2.5rem,5vw,5rem);line-height:.85;letter-spacing:-.08em}section{border-top:1px solid var(--ink);padding:1.25rem 0 3rem}.cards{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:2rem}.card{border-top:1px solid var(--ink);padding:1rem 0}.tabs{display:flex;flex-wrap:wrap;gap:.5rem;margin:1.25rem 0}button,a.button{display:inline-flex;align-items:center;justify-content:center;min-height:3.25rem;padding:0 1rem;border:1px solid var(--ink);background:var(--paper);color:var(--ink);cursor:pointer;text-decoration:none}button:focus-visible,a.button:focus-visible{outline:3px solid var(--focus);outline-offset:3px}button[aria-pressed=true],#copy,a.button{background:var(--ink);color:var(--paper)}pre{padding:1rem;border:1px solid var(--ink);background:var(--paper);overflow:auto}.detail{max-width:34rem;font:400 1.05rem/1.35 Arial,Helvetica,sans-serif;letter-spacing:0;text-transform:none}.installer-actions{display:flex;flex-wrap:wrap;align-items:stretch;gap:1rem;margin:1.5rem 0 0}.installer-actions #copy{flex:1 1 18rem;min-height:3.75rem;padding:0 1.5rem;font-size:.9rem;box-shadow:4px 4px 0 var(--ink)}.installer-actions #guide{flex:0 1 auto;min-height:3.25rem;background:transparent;color:var(--ink)}.installer-actions #guide:hover{background:var(--paper)}.action-help{margin:.75rem 0 0;max-width:42rem;color:#3f3f3f;font:400 .9rem/1.45 Arial,Helvetica,sans-serif;letter-spacing:0;text-transform:none}@media(max-width:42rem){.cards{grid-template-columns:1fr}}@media(max-width:34rem){.page{width:min(100% - 1.25rem,72rem);padding:2.5rem 0}.installer-actions{display:grid;grid-template-columns:1fr;gap:.875rem}.installer-actions #copy,.installer-actions #guide{width:100%;min-height:3.5rem}}</style></head>
<body><main class="page"><p>OPEN DREAM PRIME · TEAM ONLY</p><h1>TEAM<br>WORK.</h1>
<section><p>Choose your computer and the app assigned to you. Copy its one-click installer, then follow that app’s work card.</p><div class="tabs"><button data-platform="mac" aria-pressed="true">MAC</button><button data-platform="windows" aria-pressed="false">WINDOWS</button></div><div class="tabs"><button data-lane="ADAM" aria-pressed="true">ADAM</button><button data-lane="FRNKLY.ONE" aria-pressed="false">FRNKLY.ONE</button></div><p class="detail" id="selected-app"></p><p class="detail" id="github-access"></p><pre><code id="command"></code></pre><div class="installer-actions" role="group" aria-label="Selected installer actions"><button id="copy" aria-label="Copy the selected installer command">COPY INSTALLER COMMAND</button><a class="button" id="guide" href="/guide/" aria-label="Open the selected app guide to change app">CHANGE APP</a></div><p class="action-help" id="installer-action-help">Copy the command above to install the selected app. Change app opens its guide if you need a different lane.</p></section>
<section><div class="cards"><article class="card"><p>ADAM</p><h2>PROTECT<br>THE FAMILY.</h2><p class="detail">ADAM is the Mac-first parental-control app. It gives a parent clear Internet Off, Approved Only, and Block Known AI modes while keeping family privacy intact.</p><p class="detail">After installation: open the assigned GitHub issue, work in the ADAM checkout, and use the app’s documented Mac build path. Do not present it as ready to ship until its real-Mac enforcement and recovery work is complete.</p></article><article class="card"><p>FRNKLY.ONE</p><h2>BUILD THE<br>PRODUCT.</h2><p class="detail">FRNKLY.ONE is the team’s web application workspace. Your assigned GitHub issue defines the feature, repair, or investigation you own.</p><p class="detail">After installation: open the assigned issue, read its acceptance check, work in the FRNKLY.ONE checkout, then keep the branch and review attached to that issue. Start its local web workflow from the project’s own developer instructions.</p></article></div></section>
<section><p>OPNDRM BUZZ</p><h2>JOIN THE<br>TEAM.</h2><p class="detail">Use this private invitation only on the teammate’s own computer. It opens the OPNDRM Buzz community, where people and approved agents coordinate work. GitHub Issues remains the source of truth for work assignments.</p>${inviteUrl ? `<a class="button" href="${attribute(inviteUrl)}" target="_blank" rel="noreferrer">OPEN OPNDRM BUZZ</a>` : '<p class="detail">THE TEAM INVITATION IS NOT CONFIGURED YET.</p>'}</section>
<section><p>NEW BUILD</p><a href="/#install">OPEN PUBLIC OPNDRM APP INSTALLER</a></section></main>
<script>let platform='mac',lane='ADAM';const githubAccess={ADAM:'Before ADAM is installed, GitHub CLI performs one personal sign-in. Sign in with your own GitHub account and enter its one-time code only on GitHub’s official device page. No shared Open Dream login, token, credential, or GitHub administrator repository access is needed. The installer verifies that account can read ADAM before cloning; if it cannot, ask the repository owner for a normal collaborator invitation with the needed repository access.', 'FRNKLY.ONE':'FRNKLY.ONE is the Rust rebuild at opndrm/Frnkly.one. Before it is installed, GitHub CLI performs one personal sign-in. Sign in with your own GitHub account and enter its one-time code only on GitHub’s official device page. No shared Open Dream login, token, credential, or GitHub administrator repository access is needed. FRNKLY.ONE requires that personal account to be invited as a normal collaborator with the needed repository access before installation.'};const render=()=>{document.querySelectorAll('[data-platform]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.platform===platform)));document.querySelectorAll('[data-lane]').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.lane===lane)));document.querySelector('#selected-app').textContent='Selected app: '+lane+'.';document.querySelector('#github-access').textContent=githubAccess[lane];document.querySelector('#command').textContent=platform==='mac'?'sudo -v && curl -fsSL https://opndrm.com/install-macos.sh | bash -s -- '+lane:'& ([scriptblock]::Create((irm https://opndrm.com/install-windows.ps1))) -Lane '+lane;const copy=document.querySelector('#copy');copy.textContent='COPY INSTALLER COMMAND';copy.setAttribute('aria-label','Copy the '+platform+' installer command for '+lane);const guide=document.querySelector('#guide');guide.href='/guide/?platform='+platform+'&lane='+encodeURIComponent(lane);guide.setAttribute('aria-label','Open the '+lane+' guide for '+platform+' to change app');};document.querySelectorAll('[data-platform]').forEach(b=>b.onclick=()=>{platform=b.dataset.platform;render()});document.querySelectorAll('[data-lane]').forEach(b=>b.onclick=()=>{lane=b.dataset.lane;render()});document.querySelector('#copy').onclick=async()=>{await navigator.clipboard.writeText(document.querySelector('#command').textContent);document.querySelector('#copy').textContent='COPIED'};render();</script></body></html>`);
};
