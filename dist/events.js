export function validateEvent(values, now=Date.now()) {
  const text=(key,min,max)=>{const v=String(values[key]||'').trim();if(v.length<min||v.length>max)throw new Error(`Pole ${key}: wymagane ${min}–${max} znaków.`);return v;};
  const starts=new Date(values.starts_at), capacity=Number(values.capacity);
  if(!Number.isFinite(starts.getTime())||starts.getTime()<=now)throw new Error('Wybierz przyszłą datę spotkania.');
  if(!Number.isInteger(capacity)||capacity<2||capacity>100)throw new Error('Liczba miejsc musi wynosić od 2 do 100, łącznie z organizatorem.');
  const category=text('category',1,30);
  if(!['Spacer','Sport','Kultura','Kawa','Inne'].includes(category))throw new Error('Wybierz kategorię.');
  return {title:text('title',3,100),description:text('description',10,2000),city:text('city',2,80),location:text('location',3,160),category,starts_at:starts.toISOString(),capacity};
}

export function createEventsController(api,{render,report}) {
  let revision=0, filters={query:'',city:'',category:'',mine:false};
  return {
    clear(){revision++;render([]);},
    async load(next=filters){filters={...next};const version=++revision;try{const rows=await api.listEvents(filters);if(version===revision)render(rows);}catch(e){if(version===revision)report(e);}},
    async create(values){await api.createEvent(validateEvent(values));},
    async join(id){await api.joinEvent(id);},
    async leave(id){await api.leaveEvent(id);}
  };
}
