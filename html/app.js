const $=s=>document.querySelector(s), $$=s=>document.querySelectorAll(s);
const app=$('#app'); let state={players:[],reports:[],radio:{available:false,radios:[]}}; let pending=null;
const resource=()=>GetParentResourceName();
function post(endpoint,body={}){return fetch(`https://${resource()}/${endpoint}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)})}
function esc(v){return String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'}[c]))}
function toast(msg){const el=document.createElement('div');el.className='toast';el.textContent=msg;$('#toastStack').appendChild(el);setTimeout(()=>el.remove(),3200)}
const titles={dashboard:['Dashboard','Server administration overview'],players:['Players','Manage connected players and moderation actions'],reports:['Reports','Review, reply to, and resolve player reports'],world:['World Controls','Server-wide time, weather and environment effects'],developer:['Developer','Coordinates and development utilities'],radio:['ACG Radio','Monitor and manage active vehicle radios'],reportForm:['Submit Report','Send a report to the administration team']};
function go(tab){$$('.nav').forEach(x=>x.classList.toggle('active',x.dataset.tab===tab));$$('.page').forEach(x=>x.classList.toggle('active',x.id===tab));$('#pageTitle').textContent=titles[tab][0];$('#pageSub').textContent=titles[tab][1]}
$$('.nav').forEach(b=>b.onclick=()=>go(b.dataset.tab)); $$('[data-jump]').forEach(b=>b.onclick=()=>go(b.dataset.jump));
function initials(n){return String(n||'?').split(/\s+/).slice(0,2).map(x=>x[0]).join('').toUpperCase()}
function render(){
 const q=$('#playerSearch').value.toLowerCase();
 const players=state.players.filter(p=>String(p.id).includes(q)||String(p.rockstarName||p.name||'').toLowerCase().includes(q)||String(p.characterName||'').toLowerCase().includes(q));
 $('#playerCount').textContent=state.players.length; $('#dashPlayers').textContent=state.players.length;
 $('#playersList').innerHTML=players.length?players.map(p=>`<article class="player-card"><div class="player-main"><div class="avatar">${esc(initials(p.name))}</div><div class="player-info"><b>${esc(p.characterName||'Character not loaded')}</b><div class="identity-line"><span>FiveM / Rockstar:</span> ${esc(p.rockstarName||p.name||'Unknown')}</div><div class="muted">Server ID #${p.id}</div></div></div><div class="actions">
 <button type="button" class="primary" data-teleport="goto" data-id="${p.id}">Go To</button><button type="button" data-waypoint-player data-id="${p.id}">Set Waypoint</button><button type="button" class="primary" data-teleport="bring" data-id="${p.id}">Bring</button><button type="button" data-give-item data-id="${p.id}" data-name="${esc(p.name)}">Give Item</button><button type="button" data-set-job data-id="${p.id}" data-name="${esc(p.characterName||p.name)}">Set Job</button><button type="button" data-transfer-vehicle data-id="${p.id}" data-name="${esc(p.name)}">Transfer Vehicle</button><button data-act="spectate" data-id="${p.id}">Spectate</button><button data-act="freeze" data-id="${p.id}">Freeze</button><button data-act="unfreeze" data-id="${p.id}">Unfreeze</button><button data-act="revive" data-id="${p.id}">Revive</button><button data-act="heal" data-id="${p.id}">Heal</button>
 <button data-act="stripclothes" data-id="${p.id}">Remove Clothes</button><button data-act="restoreclothes" data-id="${p.id}">Restore Clothes</button> <button data-act="ragdoll" data-id="${p.id}">Ragdoll</button><button data-act="dogs" data-id="${p.id}">Wild Dogs</button><button class="soft-danger" data-act="fire" data-id="${p.id}">Set Fire</button><button class="soft-danger" data-act="explodevehicle" data-id="${p.id}">Explode Vehicle</button><button class="soft-danger" data-act="kill" data-id="${p.id}">Kill</button><button class="soft-danger" data-act="ban" data-id="${p.id}" data-name="${esc(p.name)}">Ban</button>
 </div></article>`).join(''):'<div class="player-card muted">No players match your search.</div>';
 renderReports();
 renderRadios();
}
function fmtRadioTime(seconds){seconds=Math.max(0,Math.floor(Number(seconds)||0));return `${Math.floor(seconds/60)}:${String(seconds%60).padStart(2,'0')}`}
function renderRadios(){
 const integration=state.radio||{available:false,radios:[]};
 const radios=Array.isArray(integration.radios)?integration.radios:[];
 const count=$('#radioCount'); if(count) count.textContent=radios.length;
 const status=$('#radioAvailability');
 if(status){status.textContent=integration.available?'CONNECTED':'OFFLINE';status.classList.toggle('open',integration.available)}
 const summary=$('#radioSummary');
 if(summary) summary.innerHTML=`<div class="radio-stat"><span>ACTIVE RADIOS</span><strong>${radios.length}</strong></div><div class="radio-stat"><span>INTEGRATION</span><strong class="${integration.available?'good':''}">${integration.available?'CONNECTED':'STANDALONE / OFFLINE'}</strong></div>`;
 const list=$('#radioList'); if(!list)return;
 if(!integration.available){list.innerHTML='<div class="radio-card muted">agc-carradio is not running or the optional integration is disabled. The admin menu continues to work normally.</div>';return}
 if(!radios.length){list.innerHTML='<div class="radio-card muted">No vehicle radios are currently active.</div>';return}
 list.innerHTML=radios.map(r=>{
   const net=Number(r.netId)||0, source=String(r.source||'unknown');
   const name=source==='stream'?(r.stationName||r.name||'Live Stream'):(r.title||r.videoId||'YouTube');
   const detail=source==='stream'?(r.genre||'Live radio'):(r.author||r.videoId||'YouTube');
   const live=source==='stream'?'<span class="radio-live">● LIVE</span>':`<span class="badge">${esc(fmtRadioTime(r.position))}</span>`;
   const occupants=Array.isArray(r.occupants)?r.occupants:[];
   const occupantMeta=occupants.length?occupants.map(o=>`<span>${esc(o.role||'Occupant')} Character <b>${esc(o.characterName||'Character not loaded')}</b></span><span>${esc(o.role||'Occupant')} FiveM/Rockstar <b>${esc(o.rockstarName||'Unknown')}</b></span>`).join(''):'<span>Occupants <b>None detected</b></span>';
   return `<article class="radio-card"><div class="radio-card-top"><div><div class="radio-source">${esc(source.toUpperCase())} ${live}</div><h3>${esc(name)}</h3><p>${esc(detail)}</p></div><div class="radio-volume"><span>VOLUME</span><strong>${Math.max(0,Math.min(100,Number(r.volume)||0))}%</strong></div></div><div class="radio-meta"><span>Network ID <b>#${net}</b></span>${r.plate?`<span>Plate <b>${esc(r.plate)}</b></span>`:''}${occupantMeta}<span>Status <b>${r.playing===false?'PAUSED':'PLAYING'}</b></span>${r.queueLength!=null?`<span>Queue <b>${Number(r.queueLength)||0}</b></span>`:''}</div><div class="actions"><button class="primary" data-radio-teleport="${net}">Teleport To Vehicle</button><button class="soft-danger" data-radio-stop="${net}">Stop Radio</button></div></article>`
 }).join('');
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
 if(pending.radioStopAll){post('radioStopAll');toast('Stop all radios request sent.');$('#confirm').classList.add('hidden');pending=null;return}
 if(pending.radioStop){post('radioStop',{netId:pending.netId});toast('Stop radio request sent.');$('#confirm').classList.add('hidden');pending=null;return}
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

window.addEventListener('message',e=>{const m=e.data;if(m.action==='show'){app.classList.remove('hidden');if(m.data){state=m.data;render()}}else if(m.action==='hide')app.classList.add('hidden');else if(m.action==='data'){state=m.data;render()}else if(m.action==='newReport'){state.reports.push(m.report);renderReports();toast(`New report #${m.report.id}`)}else if(m.action==='toast'||m.action==='reportReplyNotification')toast(m.message);else if(m.action==='restartWarning'){const b=$('#restartBanner');b.classList.remove('hidden');$('#restartBannerText').textContent=`Server restart in ${formatRestartTime(m.seconds)}`;let remaining=Number(m.seconds)||120;clearInterval(window.__restartTimer);window.__restartTimer=setInterval(()=>{remaining--;$('#restartBannerText').textContent=`Server restart in ${formatRestartTime(remaining)}`;if(remaining<=0)clearInterval(window.__restartTimer)},1000)}else if(m.action==='restartCountdown'){$('#restartBanner').classList.remove('hidden');$('#restartBannerText').textContent=`Server restart in ${formatRestartTime(m.seconds)}`}else if(m.action==='restartNow'){$('#restartBanner').classList.remove('hidden');$('#restartBannerText').textContent='Server restarting now...'}else if(m.action==='radioData'){state.radio=m.data||{available:false,radios:[]};renderRadios()}else if(m.action==='spectating'){$('#pageSub').textContent=`Spectating player ${m.target} — ESC to stop`}else if(m.action==='spectateOff')$('#pageSub').textContent=titles[$('.page.active').id][1]});
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


// Optional ACG Radio controls
const radioNav=document.querySelector('[data-tab="radio"]');
if(radioNav) radioNav.addEventListener('click',()=>post('radioRefresh'));
const radioRefresh=$('#radioRefresh'); if(radioRefresh) radioRefresh.onclick=()=>post('radioRefresh');
const radioStopAll=$('#radioStopAll'); if(radioStopAll) radioStopAll.onclick=()=>{pending={radioStopAll:true};$('#confirmTitle').textContent='Stop all vehicle radios?';$('#confirmText').textContent='This will stop every active agc-carradio vehicle radio on the server.';$('#reasonWrap').classList.add('hidden');$('#confirm').classList.remove('hidden')};
document.addEventListener('click',e=>{const stop=e.target.closest('[data-radio-stop]');if(stop){const netId=Number(stop.dataset.radioStop);pending={radioStop:true,netId};$('#confirmTitle').textContent='Stop vehicle radio?';$('#confirmText').textContent=`Stop the active radio on vehicle network ID #${netId}?`;$('#reasonWrap').classList.add('hidden');$('#confirm').classList.remove('hidden');return}const tp=e.target.closest('[data-radio-teleport]');if(tp){post('radioTeleport',{netId:Number(tp.dataset.radioTeleport)});toast('Teleport request sent.')}});
