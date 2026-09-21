const $=s=>document.querySelector(s), $$=s=>document.querySelectorAll(s);
const app=$('#app'); let state={players:[],reports:[]}; let pending=null;
const resource=()=>GetParentResourceName();
function post(endpoint,body={}){return fetch(`https://${resource()}/${endpoint}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)})}
function esc(v){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
function toast(msg){const el=document.createElement('div');el.className='toast';el.textContent=msg;$('#toastStack').appendChild(el);setTimeout(()=>el.remove(),3200)}
const titles={dashboard:['Dashboard','Server administration overview'],players:['Players','Manage connected players and moderation actions'],reports:['Reports','Review, reply to, and resolve player reports'],world:['World Controls','Server-wide time, weather and environment effects'],adminlogs:['Admin Logs','Persistent audit trail for administrative actions'],developer:['Developer','Coordinates and development utilities'],reportForm:['Submit Report','Send a report to the administration team']};
function go(tab){
 const meta=titles[tab]||[String(tab||'Admin').replace(/([A-Z])/g,' $1').trim()||'Admin','Administration controls'];
 $$('.nav').forEach(x=>x.classList.toggle('active',x.dataset.tab===tab));
 $$('.page').forEach(x=>x.classList.toggle('active',x.id===tab));
 const title=$('#pageTitle'),sub=$('#pageSub');
 if(title) title.textContent=meta[0];
 if(sub) sub.textContent=meta[1];
}
$$('.nav').forEach(b=>b.onclick=()=>go(b.dataset.tab)); $$('[data-jump]').forEach(b=>b.onclick=()=>go(b.dataset.jump));
function initials(n){return String(n||'?').split(/\s+/).slice(0,2).map(x=>x[0]).join('').toUpperCase()}
function render(){
 const q=$('#playerSearch').value.toLowerCase();
 const players=state.players.filter(p=>String(p.id).includes(q)||String(p.rockstarName||p.name||'').toLowerCase().includes(q)||String(p.characterName||'').toLowerCase().includes(q));
 $('#playerCount').textContent=state.players.length; $('#dashPlayers').textContent=state.players.length;
 $('#playersList').innerHTML=players.length?players.map(p=>`<article class="player-card"><div class="player-main"><div class="avatar">${esc(initials(p.name))}</div><div class="player-info"><b>${esc(p.characterName||'Character not loaded')}</b><div class="identity-line"><span>FiveM / Rockstar:</span> ${esc(p.rockstarName||p.name||'Unknown')}</div><div class="muted">Server ID #${p.id}</div></div></div><div class="actions">
 <button type="button" class="primary" data-player-info data-id="${p.id}">Manage Player</button><button type="button" class="primary" data-teleport="goto" data-id="${p.id}">Go To</button><button type="button" data-waypoint-player data-id="${p.id}">Set Waypoint</button><button type="button" class="primary" data-teleport="bring" data-id="${p.id}">Bring</button><button type="button" data-give-item data-id="${p.id}" data-name="${esc(p.name)}">Give Item</button><button type="button" data-set-job data-id="${p.id}" data-name="${esc(p.characterName||p.name)}">Set Job</button><button type="button" data-transfer-vehicle data-id="${p.id}" data-name="${esc(p.name)}">Transfer Vehicle</button><button data-act="spectate" data-id="${p.id}">Spectate</button><button data-act="freeze" data-id="${p.id}">Freeze</button><button data-act="unfreeze" data-id="${p.id}">Unfreeze</button><button data-act="revive" data-id="${p.id}">Revive</button><button data-act="heal" data-id="${p.id}">Heal</button>
 <button data-act="stripclothes" data-id="${p.id}">Remove Clothes</button><button data-act="restoreclothes" data-id="${p.id}">Restore Clothes</button> <button data-act="ragdoll" data-id="${p.id}">Ragdoll</button><button data-act="dogs" data-id="${p.id}">Wild Dogs</button><button class="soft-danger" data-act="fire" data-id="${p.id}">Set Fire</button><button class="soft-danger" data-act="explodevehicle" data-id="${p.id}">Explode Vehicle</button><button class="soft-danger" data-act="kill" data-id="${p.id}">Kill</button><button class="soft-danger" data-act="ban" data-id="${p.id}" data-name="${esc(p.name)}">Ban</button>
 </div></article>`).join(''):'<div class="player-card muted">No players match your search.</div>';
 renderReports();
}
function renderReports(){
 const f=$('#reportFilter').value; const reports=[...state.reports].reverse().filter(r=>f==='all'||r.status===f); const open=state.reports.filter(r=>r.status==='open').length;
 $('#reportCount').textContent=open;$('#dashReports').textContent=open;
 $('#reportsList').innerHTML=reports.length?reports.map(r=>`<article class="report-card" data-report-id="${r.id}"><div class="report-top"><div><b>Report #${r.id}</b><div class="muted">From ${esc(r.reporter)} (#${r.reporterId}) · Target: ${esc(r.targetName)}${r.target?` (#${r.target})`:''}</div></div><span class="badge ${esc(r.status)}">${esc(r.status)}</span></div><div class="report-msg">${esc(r.message)}</div>
 ${(r.replies||[]).length?`<div class="reply-history">${r.replies.map(x=>`<div class="admin-reply"><b>${esc(x.admin)}</b> ${esc(x.message)}<div class="muted">${esc(x.created||'')}</div></div>`).join('')}</div>`:''}
 ${r.status==='open'?`<div class="actions">${r.target?`<button data-act="spectate" data-id="${r.target}">Spectate target</button><button data-act="freeze" data-id="${r.target}">Freeze</button><button data-act="revive" data-id="${r.target}">Revive</button>`:''}<button class="primary" data-reply="${r.id}">Reply</button><button data-close-report="${r.id}">Close report</button></div>`:''}</article>`).join(''):'<div class="report-card muted">No reports in this view.</div>';
}
function confirmAction(action,id,name='player'){const dangerous=['ban','kill','fire','dogs','explodevehicle'];if(!dangerous.includes(action)){post('action',{action,target:+id});return}pending={action,id:+id};$('#confirmTitle').textContent=action==='ban'?'Ban player':'Confirm admin action';$('#confirmText').textContent=action==='ban'?`Ban ${name} from the server?`:`Run "${action}" on server ID ${id}?`;$('#reasonWrap').classList.toggle('hidden',action!=='ban');$('#confirmReason').value='';$('#confirm').classList.remove('hidden')}
document.addEventListener('click',e=>{const a=e.target.closest('[data-act]');if(a)confirmAction(a.dataset.act,a.dataset.id,a.dataset.name);const r=e.target.closest('[data-reply]');if(r)openReply(+r.dataset.reply);const c=e.target.closest('[data-close-report]');if(c)post('closeReport',{id:+c.dataset.closeReport})});
function openReply(id){const card=document.querySelector(`[data-report-id="${id}"]`);if(!card)return toast('Unable to open report reply.');const old=$(`#reply-box-${id}`);if(old){old.remove();return}const box=document.createElement('div');box.id=`reply-box-${id}`;box.className='reply-box';box.innerHTML=`<textarea maxlength="500" placeholder="Write a reply to the reporting player..."></textarea><div class="actions"><button class="primary send">Send Reply</button><button class="cancel">Cancel</button></div>`;card.appendChild(box);const ta=box.querySelector('textarea');ta.focus();box.querySelector('.cancel').onclick=()=>box.remove();box.querySelector('.send').onclick=()=>{const message=ta.value.trim();if(!message)return toast('Enter a reply message.');post('replyReport',{id,message});box.remove();toast('Reply sent to player.')}}
$('#confirmCancel').onclick=()=>{$('#confirm').classList.add('hidden');pending=null};$('#confirmGo').onclick=()=>{if(!pending)return;
 if(pending.transferVehicle){
   post('transferVehicle',{target:pending.target});
   toast(`Vehicle transfer requested for ${pending.name}.`);
   $('#confirm').classList.add('hidden');
   pending=null;
   return;
 }if(pending.restartSequence){post('startRestartSequence');toast('Restart warning sequence started.');$('#confirm').classList.add('hidden');pending=null;return}if(pending.worldAction==='earthquake'){post('worldAction',{action:'earthquake'});toast('Earthquake initiated.');$('#confirm').classList.add('hidden');pending=null;return}const reason=$('#confirmReason').value.trim();if(pending.action==='ban'&&!reason)return toast('Enter a ban reason.');post('action',{action:pending.action,target:pending.id,reason});$('#confirm').classList.add('hidden');pending=null};
$('#playerSearch').oninput=render;$('#reportFilter').onchange=renderReports;$('#refresh').onclick=()=>post('refresh');$('#close').onclick=()=>post('close');
$('#quickVehicle').onclick=()=>$('#vehiclePanel').classList.toggle('hidden');$('#spawnVehicle').onclick=()=>{const model=$('#vehicleModel').value.trim();if(!model)return toast('Enter a vehicle model.');post('spawnVehicle',{model});$('#vehicleModel').value='';toast(`Spawning ${model}...`)};
$('#reportMessage').oninput=e=>$('#charCount').textContent=`${e.target.value.length} / 500`;$('#submitReport').onclick=()=>{const message=$('#reportMessage').value.trim(),target=$('#reportTarget').value;if(!message)return toast('Enter report details.');post('submitReport',{target:target||null,message});$('#reportMessage').value='';$('#charCount').textContent='0 / 500';toast('Report submitted.')};

$$('[data-world]').forEach(b=>b.onclick=()=>{
  post('worldAction',{action:b.dataset.world,value:b.dataset.value});
  if(b.dataset.world==='time') toast(b.dataset.value==='0'?'Changing server to night...':'Changing server to day...');
  else if(b.dataset.world==='dynamicweather') toast(b.dataset.value==='true'?'Enabling dynamic weather...':'Disabling dynamic weather...');
  else if(b.dataset.world==='blackout') toast(b.dataset.value==='true'?'Enabling blackout...':'Disabling blackout...');
});
$('#applyWeather').onclick=()=>{const value=$('#weatherPreset').value;post('worldAction',{action:'weather',value});toast(`Applying ${value.toLowerCase()} weather...`)};
$('#earthquakeBtn').onclick=()=>{
  pending={worldAction:'earthquake'};
  $('#confirmTitle').textContent='Initiate earthquake?';
  $('#confirmText').textContent='This will gently shake the world for all players for 15 seconds. Players on foot may fall over.';
  $('#reasonWrap').classList.add('hidden');
  $('#confirm').classList.remove('hidden');
};


$('#restartSequenceBtn').onclick=()=>{
  pending={restartSequence:true};
  $('#confirmTitle').textContent='Start server restart warning?';
  $('#confirmText').textContent='This starts a severe thunderstorm, sounds the warning siren, and begins a 2-minute restart countdown for all players.';
  $('#reasonWrap').classList.add('hidden');
  $('#confirm').classList.remove('hidden');
};
function formatRestartTime(seconds){seconds=Math.max(0,Number(seconds)||0);return `${Math.floor(seconds/60)}:${String(seconds%60).padStart(2,'0')}`}

window.addEventListener('message',e=>{const m=e.data;if(m.action==='show'){app.classList.remove('hidden');if(m.data){state=m.data;render()}}else if(m.action==='hide')app.classList.add('hidden');else if(m.action==='data'){state=m.data;render()}else if(m.action==='newReport'){state.reports.push(m.report);renderReports();toast(`New report #${m.report.id}`)}else if(m.action==='toast'||m.action==='reportReplyNotification')toast(m.message);else if(m.action==='restartWarning'){const b=$('#restartBanner');b.classList.remove('hidden');$('#restartBannerText').textContent=`Server restart in ${formatRestartTime(m.seconds)}`;let remaining=Number(m.seconds)||120;clearInterval(window.__restartTimer);window.__restartTimer=setInterval(()=>{remaining--;$('#restartBannerText').textContent=`Server restart in ${formatRestartTime(remaining)}`;if(remaining<=0)clearInterval(window.__restartTimer)},1000)}else if(m.action==='restartCountdown'){$('#restartBanner').classList.remove('hidden');$('#restartBannerText').textContent=`Server restart in ${formatRestartTime(m.seconds)}`}else if(m.action==='restartNow'){$('#restartBanner').classList.remove('hidden');$('#restartBannerText').textContent='Server restarting now...'}else if(m.action==='spectating'){$('#pageSub').textContent=`Spectating player ${m.target} — ESC to stop`}else if(m.action==='spectateOff')$('#pageSub').textContent=titles[$('.page.active').id][1]});
document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!$('#confirm').classList.contains('hidden')){$('#confirm').classList.add('hidden');pending=null}else if(e.key==='Escape')post('close')});

document.addEventListener('click', async (e) => {
  const btn = e.target.closest('button[data-teleport]');
  if (!btn) return;
  e.preventDefault();
  e.stopPropagation();

  const action = btn.dataset.teleport;
  const target = Number(btn.dataset.id);
  if (!target || (action !== 'goto' && action !== 'bring')) return;

  try {
    await post('teleportAction', { action, target });
    toast(action === 'bring' ? 'Bring request sent.' : 'Go To request sent.');
  } catch (err) {
    toast('Teleport request failed.');
  }
});

let giveItemTarget = null;

document.addEventListener('click', (e) => {
  const btn = e.target.closest('button[data-give-item]');
  if (!btn) return;
  e.preventDefault();
  giveItemTarget = Number(btn.dataset.id);
  document.querySelector('#giveItemPlayer').textContent = `${btn.dataset.name || 'Player'} (#${giveItemTarget})`;
  document.querySelector('#giveItemName').value = '';
  document.querySelector('#giveItemAmount').value = '1';
  document.querySelector('#giveItemModal').classList.remove('hidden');
  setTimeout(() => document.querySelector('#giveItemName').focus(), 0);
});

document.addEventListener('click', async (e) => {
  if (e.target.closest('#giveItemCancel')) {
    const modal = document.querySelector('#giveItemModal');
    if (modal) modal.classList.add('hidden');
    giveItemTarget = null;
    return;
  }

  if (e.target.closest('#giveItemSubmit')) {
    const nameInput = document.querySelector('#giveItemName');
    const amountInput = document.querySelector('#giveItemAmount');
    const modal = document.querySelector('#giveItemModal');

    const item = nameInput ? nameInput.value.trim() : '';
    const amount = Math.max(1, Math.min(1000, Number(amountInput ? amountInput.value : 1) || 1));

    if (!giveItemTarget || !item) {
      toast('Enter a valid item spawn name.');
      return;
    }

    try {
      await post('giveItem', { target: giveItemTarget, item, amount });
      if (modal) modal.classList.add('hidden');
      toast(`Give item request sent: ${amount}x ${item}`);
      giveItemTarget = null;
    } catch (err) {
      toast('Give item request failed.');
    }
  }
});

// v21 Give Item modal safety: allow Escape to close it without closing/sticking NUI.
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    const modal = document.querySelector('#giveItemModal');
    if (modal && !modal.classList.contains('hidden')) {
      e.preventDefault();
      e.stopImmediatePropagation();
      modal.classList.add('hidden');
      giveItemTarget = null;
    }
  }
}, true);

document.addEventListener('click', (e) => {
  const modal = document.querySelector('#giveItemModal');
  if (modal && e.target === modal) {
    modal.classList.add('hidden');
    giveItemTarget = null;
  }
});

document.addEventListener('click', (e) => {
  const btn = e.target.closest('button[data-transfer-vehicle]');
  if (!btn) return;
  e.preventDefault();

  pending = {
    transferVehicle: true,
    target: Number(btn.dataset.id),
    name: btn.dataset.name || 'this player'
  };

  document.querySelector('#confirmTitle').textContent = 'Transfer vehicle?';
  document.querySelector('#confirmText').textContent =
    `Transfer the vehicle you are currently sitting in to ${pending.name}? Ownership will move to that player.`;
  document.querySelector('#reasonWrap').classList.add('hidden');
  document.querySelector('#confirm').classList.remove('hidden');
});

let jobTarget=null;
document.addEventListener('click',async e=>{
 const b=e.target.closest('button[data-set-job]');
 if(b){e.preventDefault();jobTarget=Number(b.dataset.id);$('#jobPlayer').textContent=`${b.dataset.name||'Player'} (#${jobTarget})`;$('#jobName').value='';$('#jobGrade').value='0';$('#jobModal').classList.remove('hidden');return}
 if(e.target.closest('#jobCancel')){$('#jobModal').classList.add('hidden');jobTarget=null;return}
 if(e.target.closest('#jobSubmit')){
   const job=$('#jobName').value.trim().toLowerCase(),grade=Math.max(0,Math.floor(Number($('#jobGrade').value)||0));
   if(!jobTarget||!job){toast('Enter a valid QBCore job name.');return}
   await post('setPlayerJob',{target:jobTarget,job,grade});
   $('#jobModal').classList.add('hidden');toast(`Job request sent: ${job} grade ${grade}`);jobTarget=null;
 }
});

function coordNum(v){ return Number(v||0).toFixed(4); }
async function refreshDeveloperCoords(){
  try{
    const r=await post('getCoords');
    const d=await r.json();
    if(!d || !d.ok) return;
    const x=coordNum(d.x), y=coordNum(d.y), z=coordNum(d.z), h=coordNum(d.heading);
    $('#coordX').value=x; $('#coordY').value=y; $('#coordZ').value=z;
    $('#coordVector3').value=`vector3(${x}, ${y}, ${z})`;
    $('#coordVector4').value=`vector4(${x}, ${y}, ${z}, ${h})`;
  }catch(e){ toast('Could not read coordinates.'); }
}
$('#getCoords').onclick=refreshDeveloperCoords;
$('#copyVector3').onclick=async()=>{try{await navigator.clipboard.writeText($('#coordVector3').value);toast('Vector3 copied.')}catch(e){toast('Copy unavailable; select the text manually.')}};
$('#copyVector4').onclick=async()=>{try{await navigator.clipboard.writeText($('#coordVector4').value);toast('Vector4 copied.')}catch(e){toast('Copy unavailable; select the text manually.')}};
document.querySelector('[data-tab="developer"]').addEventListener('click',()=>setTimeout(refreshDeveloperCoords,0));

document.addEventListener('click', async (e) => {
  const btn = e.target.closest('button[data-waypoint-player]');
  if (!btn) return;
  e.preventDefault();
  const target = Number(btn.dataset.id);
  if (!target) return;
  try {
    await post('waypointPlayer', {target});
    toast(`Waypoint requested for player #${target}.`);
  } catch (err) {
    toast('Could not set player waypoint.');
  }
});

let godModeEnabled=false;
$('#godModeBtn').onclick=async()=>{
  try{
    const r=await post('toggleGodMode');
    const d=await r.json();
    godModeEnabled=!!d.enabled;
    $('#godModeStatus').textContent=godModeEnabled?'ON':'OFF';
    $('#godModeBtn').textContent=godModeEnabled?'Disable God Mode':'Enable God Mode';
    $('#godModeBtn').classList.toggle('danger',godModeEnabled);
    toast(`God Mode ${godModeEnabled?'enabled':'disabled'}.`);
  }catch(e){toast('Could not toggle God Mode.')}
};

let noclipEnabled=false,invisibleEnabled=false;
$('#noclipBtn').onclick=async()=>{const d=await(await post('toggleNoclip')).json();noclipEnabled=!!d.enabled;$('#noclipStatus').textContent=noclipEnabled?'ON':'OFF';$('#noclipBtn').textContent=noclipEnabled?'Disable Noclip':'Enable Noclip';toast(`Noclip ${noclipEnabled?'enabled':'disabled'}.`)};
$('#invisibleBtn').onclick=async()=>{const d=await(await post('toggleInvisible')).json();invisibleEnabled=!!d.enabled;$('#invisibleStatus').textContent=invisibleEnabled?'ON':'OFF';$('#invisibleBtn').textContent=invisibleEnabled?'Become Visible':'Become Invisible';toast(`Invisible Mode ${invisibleEnabled?'enabled':'disabled'}.`)};
$('#tpWaypointBtn').onclick=async()=>{const d=await(await post('teleportWaypoint')).json();toast(d.ok?'Teleported to waypoint.':d.message)};
$('#inspectEntityBtn').onclick=async()=>{const d=await(await post('inspectEntity')).json();if(!d.ok){$('#entityDebug').textContent=d.message;return}$('#entityDebug').innerHTML=`<b>${esc(d.type)}</b><br>Entity: ${d.entity}<br>Network ID: ${d.networkId}<br>Model Hash: ${d.model}<br>Coords: ${Number(d.x).toFixed(3)}, ${Number(d.y).toFixed(3)}, ${Number(d.z).toFixed(3)}<br>Heading: ${Number(d.heading).toFixed(3)}<br>Health: ${d.health}`};


// v35: FiveM NUI wheel fallback.
// Some CEF/FiveM setups do not naturally scroll the nested workspace.
// Route wheel input directly to the admin content container.
(() => {
  const adminMain = document.querySelector('.workspace main');
  if (!adminMain) return;

  document.addEventListener('wheel', (event) => {
    if (document.getElementById('app')?.classList.contains('hidden')) return;
    const modalOpen = document.querySelector('.modal:not(.hidden)');
    if (modalOpen && modalOpen.contains(event.target)) return;
    adminMain.scrollTop += event.deltaY;
    event.preventDefault();
  }, { passive: false });

  document.addEventListener('keydown', (event) => {
    if (document.getElementById('app')?.classList.contains('hidden')) return;
    if (event.key === 'PageDown') {
      adminMain.scrollBy({top: Math.max(250, adminMain.clientHeight * .75), behavior: 'smooth'});
      event.preventDefault();
    } else if (event.key === 'PageUp') {
      adminMain.scrollBy({top: -Math.max(250, adminMain.clientHeight * .75), behavior: 'smooth'});
      event.preventDefault();
    } else if (event.key === 'Home') {
      adminMain.scrollTop = 0;
    } else if (event.key === 'End') {
      adminMain.scrollTop = adminMain.scrollHeight;
    }
  });
})();

let selectedPlayerInfo=null;
function fmtMoney(v){return '$'+Number(v||0).toLocaleString()}
function closePlayerInfo(){document.querySelector('#playerInfoModal').classList.add('hidden');selectedPlayerInfo=null}
async function renderPlayerInfo(p){
 selectedPlayerInfo=p;document.querySelector('#piTitle').textContent=`${p.characterName||p.name} (#${p.id})`;
 try{
   const fresh=await(await post('getFreshPlayerInfo',{id:p.id})).json();
   if(fresh&&fresh.ok){
     Object.assign(p,fresh);
     if(selectedPlayerInfo&&Number(selectedPlayerInfo.id)===Number(p.id)) Object.assign(selectedPlayerInfo,fresh);
   }
 }catch(e){}
 let live={ok:false};try{live=await(await post('getPlayerLiveInfo',{id:p.id})).json()}catch(e){}
 let liveHtml=live.ok?`<div class="pi-grid"><div class="pi-stat"><span>Health</span><b>${live.health} / ${live.maxHealth}</b></div><div class="pi-stat"><span>Armor</span><b>${live.armor}</b></div><div class="pi-stat"><span>Heading</span><b>${Number(live.heading).toFixed(1)}</b></div><div class="pi-stat"><span>Coordinates</span><b>${Number(live.x).toFixed(2)}, ${Number(live.y).toFixed(2)}, ${Number(live.z).toFixed(2)}</b></div></div>${live.vehicle?`<div class="pi-section"><h3>Current Vehicle</h3><div class="pi-grid"><div class="pi-stat"><span>Plate</span><b>${esc(live.vehicle.plate)}</b></div><div class="pi-stat"><span>Model Hash</span><b>${live.vehicle.model}</b></div><div class="pi-stat"><span>Engine</span><b>${Math.round(live.vehicle.engine)}</b></div><div class="pi-stat"><span>Speed</span><b>${Number(live.vehicle.speed).toFixed(1)} MPH</b></div></div></div>`:''}`:`<div class="pi-note">${esc(live.message||'Live data unavailable.')}</div>`;
 document.querySelector('#piBody').innerHTML=`<div class="pi-section"><h3>Identity</h3><div class="pi-grid"><div class="pi-stat"><span>Character</span><b>${esc(p.characterName||'Unknown')}</b></div><div class="pi-stat"><span>FiveM / Rockstar</span><b>${esc(p.rockstarName||p.name)}</b></div><div class="pi-stat"><span>Server ID</span><b>#${p.id}</b></div><div class="pi-stat"><span>Citizen ID</span><b>${esc(p.citizenid||'N/A')}</b></div></div></div><div class="pi-section"><h3>QBCore</h3><div class="pi-grid"><div class="pi-stat"><span>Job</span><b>${esc(p.jobLabel||p.jobName||'Unemployed')}</b></div><div class="pi-stat"><span>Grade</span><b>${esc(String(p.jobGradeName||p.jobGrade||0))} (${p.jobGrade||0})</b></div><div class="pi-stat"><span>Gang</span><b>${esc(p.gang||'None')}</b></div><div class="pi-stat"><span>Cash</span><b>${fmtMoney(p.cash)}</b></div><div class="pi-stat"><span>Bank</span><b>${fmtMoney(p.bank)}</b></div></div></div><div class="pi-section"><h3>Live Status</h3>${liveHtml}</div><div class="pi-section"><h3>Quick Actions</h3><div class="pi-actions"><button data-pi-act="goto">Go To</button><button data-pi-act="bring">Bring</button><button data-pi-act="spectate">Spectate</button><button data-pi-act="freeze">Freeze</button><button data-pi-act="unfreeze">Unfreeze</button><button data-pi-act="revive">Revive</button><button data-pi-act="heal">Heal</button><button data-pi-act="ragdoll">Ragdoll</button><button data-pi-extra="waypoint">Set Waypoint</button><button data-pi-extra="giveitem">Give Item</button><button data-pi-extra="setjob">Set Job</button><button data-pi-extra="transfer">Transfer Vehicle</button><button data-pi-extra="vehicles">Owned Vehicles</button><button data-pi-extra="money">Manage Money</button><button class="soft-danger" data-pi-extra="kick">Kick</button><button class="soft-danger" data-pi-act="kill">Kill</button></div></div>`;
 document.querySelector('#playerInfoModal').classList.remove('hidden')
}
document.addEventListener('click',e=>{const m=e.target.closest('[data-player-info]');if(m){const source = Array.isArray(players) ? players : (Array.isArray(players?.players) ? players.players : (Array.isArray(state?.players) ? state.players : []));const p=source.find(x=>Number(x.id)===Number(m.dataset.id));if(p)renderPlayerInfo(p);else toast('Unable to find that player in the current player list.');return}const a=e.target.closest('[data-pi-act]');if(a&&selectedPlayerInfo){const act=a.dataset.piAct;if(act==='goto'||act==='bring')post('teleportAction',{action:act,target:selectedPlayerInfo.id});else post('action',{action:act,target:selectedPlayerInfo.id});toast(`${act} sent.`)}});
document.querySelector('#piClose').onclick=closePlayerInfo;document.querySelector('#piDone').onclick=closePlayerInfo;document.querySelector('#piRefresh').onclick=()=>selectedPlayerInfo&&renderPlayerInfo(selectedPlayerInfo);

let managementTarget=null;
function hideManagementModal(id){document.querySelector(id).classList.add('hidden')}
document.addEventListener('click',e=>{
 const b=e.target.closest('[data-pi-extra]');
 if(!b||!selectedPlayerInfo)return;
 const p=selectedPlayerInfo, a=b.dataset.piExtra;
 if(a==='waypoint'){post('waypointPlayer',{target:p.id});toast('Waypoint request sent.');return}
 if(a==='giveitem'){
   closePlayerInfo();
   const existing=document.querySelector(`[data-give-item][data-id="${p.id}"]`);
   if(existing) existing.click(); else toast('Give Item action is unavailable.');
   return
 }
 if(a==='setjob'){
   closePlayerInfo();
   const existing=document.querySelector(`[data-set-job][data-id="${p.id}"]`);
   if(existing) existing.click(); else toast('Set Job action is unavailable.');
   return
 }
 if(a==='transfer'){
   closePlayerInfo();
   const existing=document.querySelector(`[data-transfer-vehicle][data-id="${p.id}"]`);
   if(existing) existing.click(); else toast('Transfer Vehicle action is unavailable.');
   return
 }
 if(a==='vehicles'){
   managementTarget=p;closePlayerInfo();openOwnedVehicles(p);return
 }
 if(a==='money'){
   managementTarget=p;closePlayerInfo();
   document.querySelector('#moneyAmount').value='';
   document.querySelector('#moneyModal').classList.remove('hidden');return
 }
 if(a==='kick'){
   managementTarget=p;closePlayerInfo();
   document.querySelector('#kickReason').value='';
   document.querySelector('#kickModal').classList.remove('hidden');return
 }
});
document.querySelector('#moneyClose').onclick=()=>hideManagementModal('#moneyModal');
document.querySelector('#moneyCancel').onclick=()=>hideManagementModal('#moneyModal');
document.querySelector('#moneySubmit').onclick=async()=>{
 if(!managementTarget)return;
 const amount=Number(document.querySelector('#moneyAmount').value);
 if(!Number.isFinite(amount)||amount<1){toast('Enter a valid amount.');return}
 await post('manageMoney',{target:managementTarget.id,account:document.querySelector('#moneyAccount').value,operation:document.querySelector('#moneyOperation').value,amount});
 hideManagementModal('#moneyModal');toast('Money action sent.');
};
document.querySelector('#kickClose').onclick=()=>hideManagementModal('#kickModal');
document.querySelector('#kickCancel').onclick=()=>hideManagementModal('#kickModal');
document.querySelector('#kickSubmit').onclick=async()=>{
 if(!managementTarget)return;
 const reason=document.querySelector('#kickReason').value.trim()||'Removed by an administrator.';
 await post('kickPlayer',{target:managementTarget.id,reason});
 hideManagementModal('#kickModal');closePlayerInfo();toast('Kick sent.');
};

async function openOwnedVehicles(p){
 managementTarget=p;
 document.querySelector('#vehiclesTitle').textContent=`Owned Vehicles — ${p.characterName||p.name}`;
 document.querySelector('#vehiclesBody').innerHTML='<div class="pi-note">Loading vehicles...</div>';
 document.querySelector('#vehiclesModal').classList.remove('hidden');
 let d={ok:false,vehicles:[]};try{d=await(await post('getOwnedVehicles',{target:p.id})).json()}catch(e){}
 if(!d.ok){document.querySelector('#vehiclesBody').innerHTML='<div class="pi-note">Unable to load owned vehicles.</div>';return}
 if(!d.vehicles.length){document.querySelector('#vehiclesBody').innerHTML='<div class="pi-note">This character has no vehicles in player_vehicles.</div>';return}
 document.querySelector('#vehiclesBody').innerHTML=d.vehicles.map(v=>{
  const state=Number(v.state)===1?'Stored':Number(v.state)===0?'Out':'Impounded / Other';
  return `<div class="owned-vehicle-card"><div class="owned-vehicle-head"><div><b>${esc(v.vehicle||'Unknown')}</b><span>${esc(v.plate||'')}</span></div><strong>${state}</strong></div><div class="pi-grid"><div class="pi-stat"><span>Garage</span><b>${esc(v.garage||'None')}</b></div><div class="pi-stat"><span>Fuel</span><b>${Math.round(Number(v.fuel)||0)}%</b></div><div class="pi-stat"><span>Engine</span><b>${Math.round(Number(v.engine)||0)}</b></div><div class="pi-stat"><span>Body</span><b>${Math.round(Number(v.body)||0)}</b></div></div><div class="vehicle-garage-row"><input data-garage-input="${esc(v.plate)}" placeholder="Garage spawn name" value="${esc(v.garage||'')}"><button data-set-garage="${esc(v.plate)}">Move / Store</button></div></div>`
 }).join('');
}
document.addEventListener('click',async e=>{
 const b=e.target.closest('[data-set-garage]');
 if(!b||!managementTarget)return;
 const plate=b.dataset.setGarage;
 const input=[...document.querySelectorAll('[data-garage-input]')].find(x=>x.dataset.garageInput===plate);
 const garage=input?.value.trim();
 if(!garage){toast('Enter a garage spawn name.');return}
 await post('setVehicleGarage',{target:managementTarget.id,plate,garage});
 toast(`Vehicle ${plate} moved to ${garage}.`);
 setTimeout(()=>openOwnedVehicles(managementTarget),350);
});
document.querySelector('#vehiclesClose').onclick=()=>document.querySelector('#vehiclesModal').classList.add('hidden');
document.querySelector('#vehiclesDone').onclick=()=>document.querySelector('#vehiclesModal').classList.add('hidden');
document.querySelector('#vehiclesRefresh').onclick=()=>managementTarget&&openOwnedVehicles(managementTarget);

let adminLogRows=[];
async function loadAdminLogs(){const list=$('#adminLogList');list.innerHTML='<div class="pi-note">Loading logs...</div>';let d={logs:[]};try{d=await(await post('getAdminLogs')).json()}catch(e){}adminLogRows=d.logs||[];const acts=[...new Set(adminLogRows.map(x=>x.action).filter(Boolean))].sort(),f=$('#adminLogFilter'),cur=f.value;f.innerHTML='<option value="">All Actions</option>'+acts.map(a=>`<option value="${esc(a)}">${esc(a)}</option>`).join('');if(acts.includes(cur))f.value=cur;renderAdminLogs()}
function renderAdminLogs(){const q=($('#adminLogSearch').value||'').toLowerCase(),f=$('#adminLogFilter').value;const rows=adminLogRows.filter(x=>(!f||x.action===f)&&(!q||`${x.adminName} ${x.targetName} ${x.action} ${x.details} ${x.time}`.toLowerCase().includes(q)));$('#adminLogList').innerHTML=rows.length?rows.map(x=>`<div class="admin-log-row"><div><b>${esc(x.action)}</b><span>${esc(x.details||'')}</span></div><div class="admin-log-meta"><span><b>${esc(x.adminName)}</b> → ${esc(x.targetName)}</span><span>${esc(x.time)}</span></div></div>`).join(''):'<div class="pi-note">No matching admin logs.</div>'}
$('#refreshAdminLogs').onclick=loadAdminLogs;$('#adminLogSearch').addEventListener('input',renderAdminLogs);$('#adminLogFilter').addEventListener('change',renderAdminLogs);document.addEventListener('click',e=>{if(e.target.closest('[data-tab="adminlogs"]'))setTimeout(loadAdminLogs,0)});

// v43 full audit coverage for established admin UI actions.
// Money, Kick and Move Vehicle remain logged by their authoritative server handlers.
document.addEventListener('click', e => {
 const b=e.target.closest('button');
 if(!b) return;
 let action=null, details='', target=null;
 if(b.dataset.act){
   const map={
    spectate:'Spectate',freeze:'Freeze',unfreeze:'Unfreeze',revive:'Revive',heal:'Heal',
    stripclothes:'Remove Clothes',restoreclothes:'Restore Clothes',ragdoll:'Ragdoll',
    dogs:'Wild Dogs',fire:'Set Fire',explodevehicle:'Explode Vehicle',kill:'Kill',ban:'Ban'
   };
   action=map[b.dataset.act]||null; target=b.dataset.id||null;
 }
 if(b.dataset.teleport){action=b.dataset.teleport==='goto'?'Go To':'Bring';target=b.dataset.id||null}
 if(b.hasAttribute('data-waypoint-player')){action='Set Waypoint';target=b.dataset.id||null}
 if(b.hasAttribute('data-give-item')){action='Open Give Item';target=b.dataset.id||null}
 if(b.hasAttribute('data-set-job')){action='Open Set Job';target=b.dataset.id||null}
 if(b.hasAttribute('data-transfer-vehicle')){action='Open Transfer Vehicle';target=b.dataset.id||null}
 if(action) post('auditAction',{target,action,details}).catch(()=>{});
});

// Log confirmed modal submissions and global/world/developer actions by stable element IDs/text.
// This layer is intentionally additive and does not alter the working action handlers.
document.addEventListener('click', e => {
 const b=e.target.closest('button'); if(!b) return;
 const id=b.id||'', txt=(b.textContent||'').trim().toLowerCase();
 const map={
  giveItemConfirm:'Give Item',jobConfirm:'Set Job',transferVehicleConfirm:'Transfer Vehicle',
  dayBtn:'Set Day',nightBtn:'Set Night',earthquakeBtn:'Earthquake',
  restartBtn:'Restart Sequence',teleportWaypoint:'Teleport to Waypoint',
  noclipBtn:'Toggle Noclip',invisibleBtn:'Toggle Invisible',
  godModeBtn:'Toggle God Mode',entityDebuggerBtn:'Toggle Entity Debugger'
 };
 let action=map[id];
 if(!action){
   if(txt==='day') action='Set Day';
   else if(txt==='night') action='Set Night';
   else if(txt.includes('earthquake')) action='Earthquake';
 }
 if(action) post('auditAction',{target:null,action,details:''}).catch(()=>{});
});

// v46: audit the actual World Controls used by this UI.
(() => {
 const audit=(action,details='')=>post('auditAction',{target:null,action,details}).catch(()=>{});

 document.querySelectorAll('[data-world="time"]').forEach(b=>{
   b.addEventListener('click',()=>{
     const hour=String(b.dataset.value||'');
     audit(hour==='0'?'Set Night':'Set Day',`Server time hour: ${hour}`);
   });
 });

 const weatherApply=document.querySelector('#applyWeather');
 if(weatherApply) weatherApply.addEventListener('click',()=>{
   const preset=document.querySelector('#weatherPreset');
   const value=preset ? preset.value : '';
   audit('Set Weather',`Weather: ${value||'unknown'}`);
 });

 document.querySelectorAll('[data-world="dynamicweather"]').forEach(b=>{
   b.addEventListener('click',()=>audit(
     b.dataset.value==='true'?'Enable Dynamic Weather':'Disable Dynamic Weather',
     `Dynamic weather: ${b.dataset.value}`
   ));
 });

 document.querySelectorAll('[data-world="blackout"]').forEach(b=>{
   b.addEventListener('click',()=>audit(
     b.dataset.value==='true'?'Enable Blackout':'Disable Blackout',
     `Blackout: ${b.dataset.value}`
   ));
 });
})();
