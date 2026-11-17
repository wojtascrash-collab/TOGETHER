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
    async health(){const settings=await request('/auth/v1/settings');const rows=await request('/rest/v1/profiles?select=id&limit=1');if(!Array.isArray(rows)||rows.length)throw new Error('Kontrola prywatności nie powiodła się.');return settings;},
    async signIn(email,password){const s=await request('/auth/v1/token?grant_type=password',{method:'POST',body:{email,password}});epoch++;store(normalize(s));return session;},
    signUp:(email,password)=>request('/auth/v1/signup',{method:'POST',body:{email,password}}),
    resend:email=>request('/auth/v1/resend',{method:'POST',body:{type:'signup',email}}),
    async signOut(){const s=session;epoch++;try{if(s)await request('/auth/v1/logout?scope=local',{method:'POST',token:s.access_token});}finally{store(null);}},
    async currentUser(){const u=await authorized('/auth/v1/user');if(!u?.id)throw new Error('Brak danych użytkownika.');return u;},
    getSession,
    async listEvents({query='',city='',category='',mine=false}={}){const rows=await authorized('/rest/v1/rpc/together_list_events',{method:'POST',body:{p_query:query.trim().slice(0,100),p_city:city.trim().slice(0,80),p_category:category,p_mine:Boolean(mine)}});if(!Array.isArray(rows))throw new Error('Nieprawidłowa lista spotkań.');return rows;},
    async createEvent(values){return authorized('/rest/v1/rpc/together_create_event',{method:'POST',body:{p_event:values}});},
    async joinEvent(id){return authorized('/rest/v1/rpc/together_join_event',{method:'POST',body:{p_event_id:id}});},
    async leaveEvent(id){return authorized('/rest/v1/rpc/together_leave_event',{method:'POST',body:{p_event_id:id}});},
    async loadProfile(id){const rows=await authorized(`/rest/v1/profiles?select=${columns}&id=eq.${encodeURIComponent(id)}`);if(!Array.isArray(rows))throw new Error('Nieprawidłowa odpowiedź profilu.');return rows[0]||null;},
    async saveProfile(user,values,exists){const payload={full_name:values.full_name.trim(),unsername:values.username.trim()};if(payload.full_name.length>100||payload.unsername.length>50)throw new Error('Podana nazwa jest zbyt długa.');const rows=await authorized(`/rest/v1/profiles?select=${columns}${exists?'&id=eq.'+encodeURIComponent(user.id):''}`,{method:exists?'PATCH':'POST',body:exists?payload:{id:user.id,...payload},headers:{Prefer:'return=representation'}});if(!Array.isArray(rows)||rows.length!==1||rows[0].id!==user.id)throw new Error('Nie zapisano profilu. Odśwież stronę i spróbuj ponownie.');return rows[0];},
    async auditRead(user,otherId){if(!/^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i.test(otherId)||otherId.toLowerCase()===user.id.toLowerCase())throw new Error('Wpisz poprawny identyfikator innego konta.');const own=await authorized('/rest/v1/profiles?select=id');if(!Array.isArray(own))throw new Error('Nieprawidłowa odpowiedź bazy.');const leaked=own.some(row=>row.id!==user.id);const rows=await authorized('/rest/v1/profiles?select=id&id=eq.'+encodeURIComponent(otherId));if(!Array.isArray(rows))throw new Error('Nieprawidłowa odpowiedź bazy.');return {leaked:leaked||rows.length>0,ownVisible:own.some(row=>row.id===user.id)};}
  };
}
