export class ApiError extends Error {
  constructor(message,status,code){super(message);this.status=status;this.code=code;}
}
export function createTogetherClient({url,key,fetcher=fetch,storage=sessionStorage,now=()=>Date.now()}){
  const sessionKey='together.session.v1';
  let session=null, refreshing=null, epoch=0;
  try{session=JSON.parse(storage.getItem(sessionKey)||'null');}catch{storage.removeItem(sessionKey);}
  const store=s=>{session=s;try{s?storage.setItem(sessionKey,JSON.stringify(s)):storage.removeItem(sessionKey);}catch{throw new Error('Włącz pamięć sesji w przeglądarce, aby się zalogować.');}};
  function normalize(s){if(!s?.access_token||!s?.refresh_token)throw new Error('Nie udało się utworzyć sesji.');return {...s,expires_at:s.expires_at||Math.floor(now()/1000)+(s.expires_in||3600)};}
  async function request(path,{method='GET',body,token,headers={}}={}){
    let r;
    try{r=await fetcher(url+path,{method,headers:{apikey:key,'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`} : {}),...headers},...(body!==undefined?{body:JSON.stringify(body)}:{}),cache:'no-store',signal:AbortSignal.timeout(20000)});}catch{throw new Error('Nie można połączyć się z Supabase. Sprawdź internet i spróbuj ponownie.');}
    const text=await r.text();let data;try{data=text?JSON.parse(text):null;}catch{throw new Error('Supabase zwrócił nieprawidłową odpowiedź.');}
    if(!r.ok)throw new ApiError(data?.msg||data?.error_description||data?.message||'Żądanie nie powiodło się.',r.status,data?.error_code||data?.code||data?.error);
    return data;
  }
  async function getSession(){
    if(!session)return null;
    if(session.expires_at*1000>now()+60000)return session;
    if(!refreshing){const started=epoch;refreshing=(async()=>{try{const s=await request('/auth/v1/token?grant_type=refresh_token',{method:'POST',body:{refresh_token:session.refresh_token}});if(started!==epoch)return null;store(normalize(s));return session;}catch(e){if(started===epoch&&(e.status===400||e.status===401)){epoch++;store(null);}throw e;}finally{refreshing=null;}})();}
    return refreshing;
  }
  async function authorized(path,opts={}){const s=await getSession();if(!s)throw new ApiError('Zaloguj się ponownie.',401,'session_expired');return request(path,{...opts,token:s.access_token});}
  const columns='id,created_at,unsername,full_name';
  return {
    consumeRecoveryUrl(){const q=new URLSearchParams(location.hash.slice(1));if(q.get('type')!=='recovery'||!q.get('access_token')||!q.get('refresh_token'))return false;epoch++;store(normalize({access_token:q.get('access_token'),refresh_token:q.get('refresh_token'),expires_in:Number(q.get('expires_in')||3600)}));history.replaceState(null,'',location.pathname);return true;},
    async health(){const settings=await request('/auth/v1/settings');const rows=await request('/rest/v1/profiles?select=id&limit=1');if(!Array.isArray(rows)||rows.length)throw new Error('Kontrola prywatności nie powiodła się.');return settings;},
    async signIn(email,password){const s=await request('/auth/v1/token?grant_type=password',{method:'POST',body:{email,password}});epoch++;store(normalize(s));return session;},
    signUp:(email,password)=>request('/auth/v1/signup',{method:'POST',body:{email,password}}),
    resend:email=>request('/auth/v1/resend',{method:'POST',body:{type:'signup',email}}),
    recover:email=>request('/auth/v1/recover?redirect_to='+encodeURIComponent(location.origin+'/'),{method:'POST',body:{email}}),
    updatePassword:password=>authorized('/auth/v1/user',{method:'PUT',body:{password}}),
    async signOut(){const s=session;epoch++;try{if(s)await request('/auth/v1/logout?scope=local',{method:'POST',token:s.access_token});}finally{store(null);}},
    async currentUser(){const u=await authorized('/auth/v1/user');if(!u?.id)throw new Error('Brak danych użytkownika.');return u;},
    getSession,
    async listEvents({query='',city='',category='',mine=false}={}){const rows=await authorized('/rest/v1/rpc/together_list_events_v2',{method:'POST',body:{p_query:query.trim().slice(0,100),p_city:city.trim().slice(0,80),p_category:category,p_mine:Boolean(mine)}});if(!Array.isArray(rows))throw new Error('Nieprawidłowa lista spotkań.');return rows;},
    async updateEvent(id,values){return authorized('/rest/v1/rpc/together_update_event',{method:'POST',body:{p_event_id:id,p_event:values}});},
    async cancelEvent(id){return authorized('/rest/v1/rpc/together_cancel_event',{method:'POST',body:{p_event_id:id}});},
    async createEvent(values){return authorized('/rest/v1/rpc/together_create_event',{method:'POST',body:{p_event:values}});},
    async joinEvent(id){return authorized('/rest/v1/rpc/together_join_event',{method:'POST',body:{p_event_id:id}});},
    async joinEventNamed(id,name){return authorized('/rest/v1/rpc/together_join_event_named',{method:'POST',body:{p_event_id:id,p_display_name:name.trim()}});},
    async eventAttendees(id){const rows=await authorized('/rest/v1/rpc/together_event_attendees',{method:'POST',body:{p_event_id:id}});if(!Array.isArray(rows))throw new Error('Nieprawidłowa lista uczestników.');return rows;},
    async notifications(){const rows=await authorized('/rest/v1/rpc/together_list_notifications',{method:'POST',body:{}});if(!Array.isArray(rows))throw new Error('Nieprawidłowe powiadomienia.');return rows;},
    async readNotification(id){return authorized('/rest/v1/rpc/together_read_notification',{method:'POST',body:{p_notification_id:id}});},
    async myDiscoveryProfile(){const rows=await authorized('/rest/v1/rpc/together_my_discovery_profile',{method:'POST',body:{}});return rows?.[0]||null;},
    async saveDiscoveryProfile(profile){
      const clean={...profile,display_name:String(profile?.display_name||'').trim(),city:String(profile?.city||'').trim(),bio:String(profile?.bio||'').trim(),prompt_question:String(profile?.prompt_question||'').trim(),prompt_answer:String(profile?.prompt_answer||'').trim(),age:profile?.age==null||profile.age===''?null:Number(profile.age),min_age:Number(profile?.min_age||18),max_age:Number(profile?.max_age||99),max_distance_km:Number(profile?.max_distance_km||100),identity:String(profile?.identity||'other'),relationship_goal:String(profile?.relationship_goal||'friends'),looking_for:[...new Set((profile?.looking_for||['all']).map(String))],interests:[...new Set((profile?.interests||[]).map(x=>String(x).trim()).filter(Boolean))]};
      if(clean.display_name.length<2||clean.display_name.length>40)throw new ApiError('Nazwa widoczna musi mieć od 2 do 40 znaków.',400,'display_name_invalid');
      if(clean.city.length<2||clean.city.length>80)throw new ApiError('Nazwa miasta musi mieć od 2 do 80 znaków.',400,'city_invalid');
      if(clean.bio.length<10||clean.bio.length>500)throw new ApiError('Opis „O mnie” musi mieć od 10 do 500 znaków, nie licząc spacji na początku i końcu.',400,'bio_invalid');
      if(clean.interests.length<1||clean.interests.length>8)throw new ApiError('Podaj od 1 do 8 zainteresowań, oddzielonych przecinkami.',400,'interests_invalid');
      if(Boolean(clean.prompt_question)!==Boolean(clean.prompt_answer)||clean.prompt_question.length>100||clean.prompt_answer.length>240)throw new ApiError('Wybierz pytanie i wpisz odpowiedź (maksymalnie 240 znaków) albo pozostaw oba pola puste.',400,'prompt_invalid');
      if(clean.age!==null&&(!Number.isInteger(clean.age)||clean.age<18||clean.age>99))throw new ApiError('Wiek musi wynosić od 18 do 99 lat.',400,'age_invalid');
      if(!Number.isInteger(clean.min_age)||!Number.isInteger(clean.max_age)||clean.min_age<18||clean.max_age>99||clean.min_age>clean.max_age)throw new ApiError('Sprawdź wybrany zakres wieku.',400,'age_range_invalid');
      if(![5,10,25,50,100,500].includes(clean.max_distance_km))throw new ApiError('Wybierz dostępny zasięg odległości.',400,'distance_invalid');
      try{return await authorized('/rest/v1/rpc/together_save_discovery_profile',{method:'POST',body:{p_profile:clean}});}catch(e){if(e?.code==='23505'&&String(e.message).includes('together_discovery_display_name_ci'))throw new ApiError('Ta nazwa jest już zajęta. Wybierz inną nazwę widoczną.',409,'display_name_taken');if(e?.code==='23514'&&String(e.message).includes('bio_check'))throw new ApiError('Opis „O mnie” musi mieć od 10 do 500 znaków.',400,'bio_invalid');throw e;}
    },
    async discoveryCards({city='',interest=''}={}){const rows=await authorized('/rest/v1/rpc/together_discovery_cards',{method:'POST',body:{p_limit:20,p_city:city.trim(),p_interest:interest.trim()}});return Array.isArray(rows)?rows:[];},
    async discoverySwipe(displayName,decision,note=''){const clean=String(note||'').trim();if(clean.length>150)throw new ApiError('Notatka może mieć maksymalnie 150 znaków.',400,'note_invalid');return authorized('/rest/v1/rpc/together_discovery_swipe',{method:'POST',body:{p_display_name:displayName,p_decision:decision,p_note:decision==='like'?clean:''}});},
    async undoLastPass(){return Boolean(await authorized('/rest/v1/rpc/together_undo_last_pass',{method:'POST',body:{}}));},
    async setDiscoveryLocation(lat,lng){return authorized('/rest/v1/rpc/together_set_discovery_location',{method:'POST',body:{p_lat:lat,p_lng:lng}});},
    async clearDiscoveryLocation(){return authorized('/rest/v1/rpc/together_clear_discovery_location',{method:'POST',body:{}});},
    async myMatches(){const rows=await authorized('/rest/v1/rpc/together_my_matches',{method:'POST',body:{}});return Array.isArray(rows)?rows:[];},
    async myConsent(){const rows=await authorized('/rest/v1/rpc/together_my_consent',{method:'POST',body:{}});return rows?.[0]||null;},
    acceptRules:()=>authorized('/rest/v1/rpc/together_accept_rules',{method:'POST',body:{p_adult:true,p_terms_version:'2026-11-18',p_privacy_version:'2026-11-18'}}),
    async isAdmin(){return Boolean(await authorized('/rest/v1/rpc/together_is_admin',{method:'POST',body:{}}));},
    async adminReports(){const rows=await authorized('/rest/v1/rpc/together_admin_reports',{method:'POST',body:{}});return Array.isArray(rows)?rows:[];},
    reviewReport:(id,status)=>authorized('/rest/v1/rpc/together_admin_review_report',{method:'POST',body:{p_report_id:id,p_status:status}}),
    async matchMessages(id){const rows=await authorized('/rest/v1/rpc/together_match_messages',{method:'POST',body:{p_match_id:id}});return Array.isArray(rows)?rows:[];},
    async sendMessage(id,body){return authorized('/rest/v1/rpc/together_send_message',{method:'POST',body:{p_match_id:id,p_body:body}});},
    async unmatch(id){return authorized('/rest/v1/rpc/together_unmatch',{method:'POST',body:{p_match_id:id}});},
    async blockPerson(name){return authorized('/rest/v1/rpc/together_block_person',{method:'POST',body:{p_display_name:name}});},
    async myBlocks(){const rows=await authorized('/rest/v1/rpc/together_my_blocks',{method:'POST',body:{}});return Array.isArray(rows)?rows:[];},
    async unblockPerson(name){return authorized('/rest/v1/rpc/together_unblock_person',{method:'POST',body:{p_display_name:name}});},
    async reportPerson(name,reason){return authorized('/rest/v1/rpc/together_report_person',{method:'POST',body:{p_display_name:name,p_reason:reason}});},
    avatarUrl:path=>path?url+'/storage/v1/object/public/together-avatars/'+path.split('/').map(encodeURIComponent).join('/'):null,
    async uploadAvatar(userId,file){if(!['image/jpeg','image/png','image/webp'].includes(file.type)||file.size>2097152)throw new Error('Zdjęcie musi być JPG, PNG lub WebP i mieć maksymalnie 2 MB.');const s=await getSession();if(!s)throw new ApiError('Zaloguj się ponownie.',401,'session_expired');const ext=file.type==='image/png'?'png':file.type==='image/webp'?'webp':'jpg',path=userId+'/avatar-'+Date.now()+'.'+ext;const r=await fetcher(url+'/storage/v1/object/together-avatars/'+path,{method:'POST',headers:{apikey:key,Authorization:`Bearer ${s.access_token}`,'Content-Type':file.type,'x-upsert':'false'},body:file,signal:AbortSignal.timeout(30000)});if(!r.ok)throw new Error('Nie udało się wysłać zdjęcia.');return path;},
    async deleteAvatar(path){if(!path)return;const s=await getSession();if(!s)throw new ApiError('Zaloguj się ponownie.',401,'session_expired');const encoded=path.split('/').map(encodeURIComponent).join('/'),r=await fetcher(url+'/storage/v1/object/together-avatars/'+encoded,{method:'DELETE',headers:{apikey:key,Authorization:`Bearer ${s.access_token}`},signal:AbortSignal.timeout(20000)});if(!r.ok&&r.status!==404)throw new Error('Nie udało się usunąć poprzedniego zdjęcia.');},
    async deleteOwnAccount(confirmation,photoPath){
      const s=await getSession();if(!s)throw new ApiError('Zaloguj się ponownie.',401,'session_expired');
      if(photoPath){const path=photoPath.split('/').map(encodeURIComponent).join('/'),r=await fetcher(url+'/storage/v1/object/together-avatars/'+path,{method:'DELETE',headers:{apikey:key,Authorization:`Bearer ${s.access_token}`},signal:AbortSignal.timeout(20000)});if(!r.ok&&r.status!==404)throw new Error('Nie udało się usunąć zdjęcia. Konto nie zostało usunięte.');}
      const result=await authorized('/rest/v1/rpc/together_delete_own_account',{method:'POST',body:{p_confirmation:confirmation}});epoch++;store(null);return result;
    },
    async leaveEvent(id){return authorized('/rest/v1/rpc/together_leave_event',{method:'POST',body:{p_event_id:id}});},
    async loadProfile(id){const rows=await authorized(`/rest/v1/profiles?select=${columns}&id=eq.${encodeURIComponent(id)}`);if(!Array.isArray(rows))throw new Error('Nieprawidłowa odpowiedź profilu.');return rows[0]||null;},
    async saveProfile(user,values,exists){const payload={full_name:values.full_name.trim(),unsername:values.username.trim()};if(payload.full_name.length>100||payload.unsername.length>50)throw new Error('Podana nazwa jest zbyt długa.');const rows=await authorized(`/rest/v1/profiles?select=${columns}${exists?'&id=eq.'+encodeURIComponent(user.id):''}`,{method:exists?'PATCH':'POST',body:exists?payload:{id:user.id,...payload},headers:{Prefer:'return=representation'}});if(!Array.isArray(rows)||rows.length!==1||rows[0].id!==user.id)throw new Error('Nie zapisano profilu. Odśwież stronę i spróbuj ponownie.');return rows[0];},
    async auditRead(user,otherId){if(!/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(otherId)||otherId.toLowerCase()===user.id.toLowerCase())throw new Error('Wpisz poprawny identyfikator innego konta.');const own=await authorized('/rest/v1/profiles?select=id');if(!Array.isArray(own))throw new Error('Nieprawidłowa odpowiedź bazy.');const leaked=own.some(row=>row.id!==user.id);const rows=await authorized('/rest/v1/profiles?select=id&id=eq.'+encodeURIComponent(otherId));if(!Array.isArray(rows))throw new Error('Nieprawidłowa odpowiedź bazy.');return {leaked:leaked||rows.length>0,ownVisible:own.some(row=>row.id===user.id)};}
  };
}
