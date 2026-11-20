export function notificationChanges(item){
 if(item.kind==='event_cancelled')return ['Organizator odwołał spotkanie.'];
 const before=item.old_details||{},after=item.new_details||{},changes=[];
 const date=v=>new Intl.DateTimeFormat('pl-PL',{dateStyle:'medium',timeStyle:'short'}).format(new Date(v));
 if(before.starts_at!==after.starts_at)changes.push('Termin: '+date(before.starts_at)+' → '+date(after.starts_at));
 if(before.city!==after.city||before.location!==after.location)changes.push('Miejsce: '+[before.city,before.location].filter(Boolean).join(', ')+' → '+[after.city,after.location].filter(Boolean).join(', '));
 return changes;
}
export function createNotificationInbox(api,{root,getUser}){
 let revision=0;
 const box=document.createElement('details');box.className='card notification-inbox';
 const summary=document.createElement('summary');summary.textContent='Powiadomienia';
 const info=document.createElement('p');info.className='fine';info.textContent='Zmiany Twoich spotkań. Odświeżamy podczas korzystania z aplikacji co 30 sekund. Pokazujemy ostatnie 100 powiadomień.';
 const refresh=document.createElement('button');refresh.type='button';refresh.className='text-button';refresh.textContent='Odśwież powiadomienia';
 const status=document.createElement('p');status.className='fine';status.setAttribute('role','status');
 const list=document.createElement('div');box.append(summary,info,refresh,status,list);root.prepend(box);
 async function load(){const uid=getUser()?.id;if(!uid)return;const version=++revision;try{const rows=await api.notifications();if(version!==revision||getUser()?.id!==uid)return;summary.textContent='Powiadomienia ('+(rows[0]?.unread_count||0)+' nieprzeczytanych)';status.textContent=rows.length?'':'Nie masz jeszcze powiadomień.';list.replaceChildren();for(const item of rows){const card=document.createElement('article');card.className='notification-item'+(item.read_at?'':' unread');const title=document.createElement('h3');title.textContent=(item.kind==='event_cancelled'?'Odwołane: ':'Zmiana: ')+item.event_title;const time=document.createElement('p');time.className='fine';time.textContent=new Intl.DateTimeFormat('pl-PL',{dateStyle:'short',timeStyle:'short'}).format(new Date(item.created_at))+(item.read_at?' · przeczytane':' · nowe');card.append(title,time);for(const text of notificationChanges(item)){const p=document.createElement('p');p.textContent=text;card.append(p);}if(!item.read_at){const read=document.createElement('button');read.type='button';read.className='text-button';read.textContent='Oznacz jako przeczytane';read.onclick=async()=>{read.disabled=true;try{await api.readNotification(item.id);await load();}catch{if(getUser()?.id===uid)status.textContent='Nie udało się oznaczyć powiadomienia. Spróbuj ponownie.';}finally{read.disabled=false;}};card.append(read);}list.append(card);}}catch{if(version===revision&&getUser()?.id===uid)status.textContent='Nie udało się pobrać powiadomień. Odśwież, aby spróbować ponownie.';}}
 refresh.onclick=()=>load();box.addEventListener('toggle',()=>{if(box.open)load();});
 return {load,clear(){revision++;list.replaceChildren();summary.textContent='Powiadomienia';status.textContent='';box.open=false;}};
}
