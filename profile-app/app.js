import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.119.0';
import { avatarDataUrl, prepareAvatar } from './avatar-webp.js';
const db=createClient('https://yogcyrxmxuqxazwlbfna.supabase.co','sb_publishable_obVfD8F9C4SQtSc8PNd7aQ_ZOxSzcJK');
const $=id=>document.getElementById(id);
const categories=['Wszystkie','Sport','Kawa','Wyjazdy','Rozrywka','Inne'];
const icons={Sport:'🏋️',Kawa:'☕',Wyjazdy:'🚗',Rozrywka:'🎳',Inne:'✨'};
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let user=null,events=[],joined=new Set(),current='Wszystkie',pending=new Set(),loadVersion=0;
let participantView = null;
let profileEditor = null;

function showAvatar(host, base64, name) {
  const fallback = document.createElement('span');
  fallback.className = 'avatar-fallback';
  fallback.setAttribute('aria-hidden', 'true');
  fallback.textContent = Array.from(name || '?')[0].toLocaleUpperCase('pl-PL');
  host.replaceChildren(fallback);
  if (!base64) return;

  const image = document.createElement('img');
  image.alt = '';
  image.addEventListener('load', () => fallback.remove(), { once: true });
  image.addEventListener('error', () => image.remove(), { once: true });
  host.append(image);
  image.src = avatarDataUrl(base64);
}

function avatarFromHex(value) {
  if (!value?.startsWith('\\x')) return null;
  const bytes = value.slice(2).match(/.{2}/g) || [];
  return btoa(bytes.map(byte => String.fromCharCode(parseInt(byte, 16))).join(''));
}

function clearProfileEditor() {
  profileEditor = null;
  if ($('profileDialog').open) $('profileDialog').close();
  $('profileForm').reset();
  $('profilePhotoPreview').replaceChildren();
  $('profileStatus').textContent = '';
}

function setProfileControls(enabled) {
  for (const id of ['displayName', 'profilePhoto', 'profileRemove', 'profileSave']) $(id).disabled = !enabled;
}

async function openProfileEditor() {
  if (!user) return;
  clearProfileEditor();
  const editor = { userId: user.id, avatar: null, remove: false, ready: false };
  profileEditor = editor;
  setProfileControls(false);
  $('profileStatus').textContent = 'Wczytywanie profilu…';
  $('profileDialog').showModal();
  try {
    const { data, error } = await db.from('profiles').select('display_name, avatar_webp').eq('id', editor.userId).maybeSingle();
    if (editor !== profileEditor) return;
    if (error) throw error;
    $('displayName').value = data?.display_name ?? '';
    editor.avatar = avatarFromHex(data?.avatar_webp);
    showAvatar($('profilePhotoPreview'), editor.avatar, data?.display_name);
    editor.ready = true;
    setProfileControls(true);
    $('profileRemove').disabled = !editor.avatar;
    $('profileStatus').textContent = '';
  } catch {
    if (editor === profileEditor) $('profileStatus').textContent = 'Nie udało się wczytać profilu. Zamknij okno i spróbuj ponownie.';
  }
}

$('profileOpen').addEventListener('click', openProfileEditor);
$('profileDialog').addEventListener('close', () => {
  if (!$('profileDialog').open) clearProfileEditor();
});
$('profileRemove').addEventListener('click', () => {
  if (!profileEditor?.ready) return;
  profileEditor.remove = true;
  $('profilePhoto').value = '';
  $('profileRemove').disabled = true;
  showAvatar($('profilePhotoPreview'), null, $('displayName').value);
  $('profileStatus').textContent = 'Zdjęcie zostanie usunięte po zapisaniu.';
});
$('profilePhoto').addEventListener('change', () => {
  if (!$('profilePhoto').files.length || !profileEditor?.ready) return;
  $('profileStatus').textContent = 'Nowe zdjęcie zostanie użyte po zapisaniu.';
});
$('profileForm').addEventListener('submit', async event => {
  event.preventDefault();
  const editor = profileEditor;
  if (!editor?.ready || editor.userId !== user?.id) return;
  const name = $('displayName').value.trim();
  const file = $('profilePhoto').files[0];
  if (name && (Array.from(name).length < 2 || Array.from(name).length > 40 || /[@\p{Cc}]/u.test(name))) {
    $('profileStatus').textContent = 'Podaj nazwę od 2 do 40 znaków, bez adresu e-mail.';
    return;
  }
  editor.ready = false;
  setProfileControls(false);
  $('profileStatus').textContent = 'Zapisywanie profilu…';
  try {
    const thumbnail = file ? await prepareAvatar(file) : null;
    if (editor !== profileEditor || editor.userId !== user?.id) return;
    const profile = { id: editor.userId, display_name: name || null };
    if (thumbnail || editor.remove) profile.avatar_webp = thumbnail?.hex ?? null;
    const { error } = await db.from('profiles').upsert(profile, { onConflict: 'id' });
    if (editor !== profileEditor) return;
    if (error) throw new Error('Nie udało się zapisać profilu. Spróbuj ponownie.');
    editor.avatar = thumbnail?.base64 ?? (editor.remove ? null : editor.avatar);
    editor.remove = false;
    $('profilePhoto').value = '';
    showAvatar($('profilePhotoPreview'), editor.avatar, name);
    $('profileStatus').textContent = 'Profil zapisany.';
  } catch (error) {
    if (editor === profileEditor) $('profileStatus').textContent = error.message;
  } finally {
    if (editor === profileEditor) {
      editor.ready = true;
      setProfileControls(true);
      $('profileRemove').disabled = !editor.avatar || editor.remove;
    }
  }
});

function clearParticipantView() {
  participantView = null;
  if ($('participantsDialog').open) $('participantsDialog').close();
  $('participantsTitle').textContent = '';
  $('participantsStatus').textContent = '';
  $('participantsList').replaceChildren();
  $('participantsMore').hidden = true;
}

async function loadParticipantPage() {
  const view = participantView;
  if (!view || view.loading || view.organizerId !== user?.id) return;

  view.loading = true;
  const more = $('participantsMore');
  more.hidden = true;
  $('participantsStatus').textContent = 'Wczytywanie uczestników…';

  try {
    const { data, error } = await db.rpc('together_event_roster', {
      p_event_id: view.eventId,
      p_after_time: view.cursor?.joined_at ?? null,
      p_after_key: view.cursor?.key ?? null,
    });
    if (view !== participantView || view.organizerId !== user?.id) return;
    if (error) throw error;

    const page = data.participants;
    const dateFormat = new Intl.DateTimeFormat('pl-PL', { dateStyle: 'medium', timeStyle: 'short' });
    for (const participant of page) {
      const row = document.createElement('li');
      const avatar = document.createElement('div');
      avatar.className = 'participant-avatar';
      showAvatar(avatar, participant.avatar_base64, participant.display_name);
      const name = document.createElement('strong');
      name.textContent = participant.display_name || 'Uczestnik';
      const date = document.createElement('span');
      const joinedAt = participant.joined_at ? new Date(participant.joined_at) : null;
      if (joinedAt && Number.isFinite(joinedAt.getTime())) date.textContent = 'Zapisano: ' + dateFormat.format(joinedAt);
      const label = document.createElement('div');
      label.className = 'participant-label';
      label.append(name, date);
      row.append(avatar, label);
      $('participantsList').append(row);
    }
    view.count += page.length;
    view.cursor = data.next_cursor;
    $('participantsStatus').textContent = view.count ? '' : 'Brak zapisanych uczestników.';
    more.textContent = 'Pokaż więcej';
    more.hidden = !view.cursor;
  } catch {
    if (view !== participantView || view.organizerId !== user?.id) return;
    $('participantsStatus').textContent = 'Nie udało się wczytać uczestników.';
    more.textContent = 'Spróbuj ponownie';
    more.hidden = false;
  } finally {
    view.loading = false;
  }
}

function openParticipantView(eventId) {
  const organizerId = user?.id;
  const event = events.find(item => item.id === eventId && item.organizer_id === organizerId);
  if (!organizerId || !event) return;

  clearParticipantView();
  participantView = { eventId, organizerId, count: 0, cursor: null, loading: false };
  $('participantsTitle').textContent = event.title;
  $('participantsDialog').showModal();
  void loadParticipantPage();
}

$('participantsDialog').addEventListener('close', () => {
  if (!$('participantsDialog').open) clearParticipantView();
});
$('participantsMore').addEventListener('click', loadParticipantPage);
function notify(message,error=false){$('alert').textContent=message;$('alert').className=error?'notice':'success';}
function authMessage(message){$('authMessage').textContent=message;}
function openAuth(){ $('authDialog').showModal(); }
window.openForm=()=>{if(!user){openAuth();return;}const now=new Date(Date.now()+3600000);$('date').min=new Date(Date.now()-new Date().getTimezoneOffset()*60000).toISOString().slice(0,16);$('date').value=new Date(now-now.getTimezoneOffset()*60000).toISOString().slice(0,16);$('dlg').showModal();};
function render(){
 $('account').textContent=user?'Zalogowano: '+user.email:'Przeglądasz bez logowania';
 $('login').hidden=!!user;$('logout').hidden=!user;
 $('profileOpen').hidden=!user;
 $('filters').innerHTML=categories.map(c=>`<button class="filter ${c===current?'active':''}" data-filter="${esc(c)}">${esc(c)}</button>`).join('');
 $('count').textContent=events.length+' spotkań online';
 const list=events.filter(e=>current==='Wszystkie'||e.category===current);
 $('cards').innerHTML=list.length?list.map(e=>`<article class="card"><div class="art">${icons[e.category]||'✨'}</div><div class="content"><div class="tag">${esc(e.category)}${e.organizer_id===user?.id?' · moje spotkanie':''}</div><h3>${esc(e.title)}</h3><div class="meta">📍 ${esc(e.place)}<br>🗓️ ${esc(new Date(e.starts_at).toLocaleString('pl-PL',{dateStyle:'medium',timeStyle:'short'}))}<br>${esc(e.detail)}</div><div class="bottom"><span class="hint">Zapisane online</span><button class="btn ${joined.has(e.id)?'out':''}" data-join="${e.id}" ${pending.has(e.id)||new Date(e.starts_at)<=new Date()?'disabled':''}>${joined.has(e.id)?'✓ Zapisano — zrezygnuj':'Dołącz'}</button></div>${e.organizer_id===user?.id?`<div class="event-tools"><button class="btn out" data-participants="${e.id}" aria-haspopup="dialog">Uczestnicy</button><button class="btn danger" data-delete="${e.id}" ${pending.has(e.id)?'disabled':''}>Usuń moje spotkanie</button></div>`:''}</div></article>`).join(''):'<div class="empty">Brak spotkań. Dodaj pierwsze!</div>';
}
async function load(){const version=++loadVersion;const {data,error}=await db.from('events').select('*').order('starts_at');if(error)throw error;let nextJoined=[];if(user){const result=await db.from('event_participants').select('event_id').eq('user_id',user.id);if(result.error)throw result.error;nextJoined=result.data;}if(version!==loadVersion)return;events=data;joined=new Set(nextJoined.map(x=>x.event_id));render();}
async function safely(fn){try{await fn();}catch(e){notify('Nie udało się wykonać operacji: '+e.message,true);}}
$('login').onclick=openAuth;
$('logout').onclick=()=>safely(async()=>{const {error}=await db.auth.signOut();if(error)throw error;notify('Wylogowano.');});
$('authForm').addEventListener('submit',async e=>{e.preventDefault();const button=e.submitter;button.disabled=true;authMessage('Trwa logowanie…');try{const credentials={email:$('email').value.trim(),password:$('password').value};const result=button.value==='signup'?await db.auth.signUp(credentials):await db.auth.signInWithPassword(credentials);if(result.error)throw result.error;if(result.data.session){$('authDialog').close();$('authForm').reset();notify('Zalogowano.');}else{authMessage('Konto utworzone. Potwierdź adres w wiadomości e-mail, następnie wróć tutaj i zaloguj się.');}}catch(error){authMessage(error.message);}finally{button.disabled=false;}});
$('filters').onclick=e=>{const b=e.target.closest('[data-filter]');if(b){current=b.dataset.filter;render();}};
$('refresh').onclick=()=>safely(load);
$('cards').addEventListener('click', event => {
  const button = event.target.closest('[data-participants]');
  if (button) openParticipantView(button.dataset.participants);
});
$('cards').onclick=e=>safely(async()=>{const j=e.target.closest('[data-join]'),d=e.target.closest('[data-delete]');if(!j&&!d)return;if(!user){openAuth();return;}const id=j?.dataset.join||d.dataset.delete;if(pending.has(id))return;if(d&&!confirm('Usunąć spotkanie i jego zapisy?'))return;pending.add(id);render();try{let result;if(d){result=await db.from('events').delete().eq('id',id).select('id');if(!result.error&&!result.data.length)throw new Error('Brak uprawnień do usunięcia spotkania.');}else if(joined.has(id)){result=await db.from('event_participants').delete().eq('event_id',id).eq('user_id',user.id);}else{result=await db.from('event_participants').insert({event_id:id,user_id:user.id});}if(result.error)throw result.error;await load();notify(d?'Spotkanie usunięte.':joined.has(id)?'Zapisano na spotkanie.':'Zrezygnowano z udziału.');}finally{pending.delete(id);render();}});
$('eventForm').addEventListener('submit',e=>{e.preventDefault();safely(async()=>{if(!user){openAuth();return;}const button=e.submitter;button.disabled=true;try{const f=new FormData(e.target),date=new Date(f.get('date'));if(!Number.isFinite(date.getTime())||date<=new Date())throw new Error('Wybierz przyszły termin.');const item={organizer_id:user.id,title:String(f.get('title')).trim(),category:String(f.get('category')),place:String(f.get('place')).trim(),starts_at:date.toISOString(),detail:String(f.get('detail')).trim()};if(!item.title||!item.place)throw new Error('Uzupełnij nazwę i miejsce.');const {error}=await db.from('events').insert(item);if(error)throw error;$('dlg').close();e.target.reset();current='Wszystkie';await load();notify('Spotkanie opublikowane online.');}finally{button.disabled=false;}});});
db.auth.onAuthStateChange((_event, session) => {
  const nextUser = session?.user ?? null;
  const accountChanged = user?.id !== nextUser?.id;
  user = nextUser;
  if (accountChanged) {
    ++loadVersion;
    joined.clear();
    clearParticipantView();
    clearProfileEditor();
    render();
  }
  setTimeout(() => safely(load), 0);
});
render();safely(load);
