const app = document.getElementById('app');
const playersList = document.getElementById('playersList');
const reportsList = document.getElementById('reportsList');
const reportCount = document.getElementById('reportCount');
const toast = document.getElementById('toast');
let data = {players: [], reports: []};

const resource = () => GetParentResourceName();

function post(endpoint, body={}) {
  return fetch(`https://${resource()}/${endpoint}`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify(body)
  });
}

function escapeHtml(s) {
  return String(s ?? '').replace(/[&<>"']/g, c => ({
    '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#039;'
  }[c]));
}

function renderPlayers() {
  const q = document.getElementById('playerSearch').value.toLowerCase();
  const players = data.players.filter(p =>
    String(p.id).includes(q) || p.name.toLowerCase().includes(q)
  );

  playersList.innerHTML = players.length ? players.map(p => `
    <div class="row">
      <div class="meta">
        <div class="name">${escapeHtml(p.name)}</div>
        <div class="sub">Server ID: ${p.id}</div>
      </div>
      <div class="actions">
        <button onclick="action('spectate',${p.id})">Spectate</button>
        <button onclick="action('freeze',${p.id})">Freeze</button>
        <button onclick="action('unfreeze',${p.id})">Unfreeze</button>
        <button class="warn" onclick="action('fire',${p.id})">Fire</button>
        <button class="danger" onclick="action('kill',${p.id})">Kill</button>
        <button class="danger" onclick="banPlayer(${p.id})">Ban</button>
      </div>
    </div>
  `).join('') : '<div class="card">No players found.</div>';
}

function renderReports() {
  const open = data.reports.filter(r => r.status === 'open').length;
  reportCount.textContent = open;

  reportsList.innerHTML = data.reports.length ? [...data.reports].reverse().map(r => `
    <div class="card">
      <div class="name">Report #${r.id} — ${escapeHtml(r.status.toUpperCase())}</div>
      <div class="sub">From ${escapeHtml(r.reporter)} (${r.reporterId}) · Target: ${escapeHtml(r.targetName)}${r.target ? ` (${r.target})` : ''}</div>
      <div class="sub">${escapeHtml(r.created)}</div>
      <div class="report-msg">${escapeHtml(r.message)}</div>
      ${r.status === 'open' ? `
        <div class="actions">
          ${r.target ? `<button onclick="action('spectate',${r.target})">Spectate</button>
          <button onclick="action('freeze',${r.target})">Freeze</button>
          <button class="danger" onclick="action('kill',${r.target})">Kill</button>` : ''}
          <button onclick="closeReport(${r.id})">Close Report</button>
        </div>` : ''}
    </div>
  `).join('') : '<div class="card">No reports.</div>';
}

function render() {
  renderPlayers();
  renderReports();
}

function action(name, target) {
  let reason = '';
  if (name === 'ban') {
    reason = prompt('Ban reason:', 'Rule violation') || '';
  }
  post('action', {action: name, target, reason});
}

function banPlayer(id) {
  action('ban', id);
}

function closeReport(id) {
  post('closeReport', {id});
}

function showToast(msg) {
  toast.textContent = msg;
  toast.style.display = 'block';
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => toast.style.display = 'none', 3000);
}

document.querySelectorAll('.tab').forEach(btn => {
  btn.addEventListener('click', () => {
    document.querySelectorAll('.tab').forEach(x => x.classList.remove('active'));
    document.querySelectorAll('.tabpage').forEach(x => x.classList.remove('active'));
    btn.classList.add('active');
    document.getElementById(btn.dataset.tab).classList.add('active');
  });
});

document.getElementById('playerSearch').addEventListener('input', renderPlayers);
document.getElementById('refresh').addEventListener('click', () => post('refresh'));

document.getElementById('submitReport').addEventListener('click', () => {
  const target = document.getElementById('reportTarget').value;
  const message = document.getElementById('reportMessage').value.trim();
  if (!message) return showToast('Enter a report message.');
  post('submitReport', {target: target || null, message});
  document.getElementById('reportMessage').value = '';
  showToast('Report submitted.');
});

document.getElementById('close').addEventListener('click', () => post('close'));

window.addEventListener('message', e => {
  const m = e.data;
  if (m.action === 'show') {
    app.classList.remove('hidden');
    if (m.data) { data = m.data; render(); }
  } else if (m.action === 'hide') {
    app.classList.add('hidden');
  } else if (m.action === 'data') {
    data = m.data;
    render();
  } else if (m.action === 'newReport') {
    data.reports.push(m.report);
    renderReports();
    showToast(`New report #${m.report.id}`);
  } else if (m.action === 'toast') {
    showToast(m.message);
  } else if (m.action === 'spectating') {
    document.getElementById('status').textContent = `Spectating player ${m.target} — press ESC to stop`;
  } else if (m.action === 'spectateOff') {
    document.getElementById('status').textContent = 'Ready';
  }
});

document.addEventListener('keydown', e => {
  if (e.key === 'Escape') post('close');
});
