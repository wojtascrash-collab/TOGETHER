-- TOGETHER: nowy moduł, bez zmian istniejącej tabeli profiles i kolumny unsername.
begin;
create table public.together_events (
 id uuid primary key default gen_random_uuid(),
 host_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
 title text not null check (char_length(btrim(title)) between 3 and 100),
 description text not null check (char_length(btrim(description)) between 10 and 2000),
 city text not null check (char_length(btrim(city)) between 2 and 80),
 location text not null check (char_length(btrim(location)) between 3 and 160),
 category text not null check (category in ('Spacer','Sport','Kultura','Kawa','Inne')),
 starts_at timestamptz not null,
 capacity integer not null check (capacity between 2 and 100),
 attendee_count integer not null default 1 check (attendee_count between 1 and capacity),
 created_at timestamptz not null default now()
);
create index together_events_start_idx on public.together_events(starts_at);
create index together_events_host_idx on public.together_events(host_id);
create table public.together_memberships (
 event_id uuid not null references public.together_events(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade default auth.uid(),
 created_at timestamptz not null default now(),
 primary key(event_id,user_id)
);
create index together_memberships_user_idx on public.together_memberships(user_id);
alter table public.together_events enable row level security;
alter table public.together_memberships enable row level security;
create policy together_events_read on public.together_events for select to authenticated using (true);
create policy together_memberships_read_own on public.together_memberships for select to authenticated using (user_id=(select auth.uid()));
revoke all on public.together_events, public.together_memberships from anon, authenticated;
grant select on public.together_events, public.together_memberships to authenticated;

create function public.together_create_event(p_event jsonb) returns uuid
language plpgsql security definer set search_path='' as $$
declare event_id uuid;
begin
 if auth.uid() is null then raise exception 'Zaloguj się.' using errcode='42501'; end if;
 if (p_event->>'starts_at')::timestamptz <= now() then raise exception 'Wybierz przyszłą datę.'; end if;
 insert into public.together_events(host_id,title,description,city,location,category,starts_at,capacity)
 values(auth.uid(),btrim(p_event->>'title'),btrim(p_event->>'description'),btrim(p_event->>'city'),btrim(p_event->>'location'),p_event->>'category',(p_event->>'starts_at')::timestamptz,(p_event->>'capacity')::integer)
 returning id into event_id;
 return event_id;
end $$;

create function public.together_join_event(p_event_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare e public.together_events;
begin
 if auth.uid() is null then raise exception 'Zaloguj się.' using errcode='42501'; end if;
 select * into e from public.together_events where id=p_event_id for update;
 if not found then raise exception 'Spotkanie nie istnieje.'; end if;
 if e.starts_at<=now() then raise exception 'Spotkanie już się rozpoczęło.'; end if;
 if e.host_id=auth.uid() or exists(select 1 from public.together_memberships where event_id=p_event_id and user_id=auth.uid()) then return; end if;
 if e.attendee_count>=e.capacity then raise exception 'Brak wolnych miejsc.'; end if;
 insert into public.together_memberships(event_id,user_id) values(p_event_id,auth.uid());
 update public.together_events set attendee_count=attendee_count+1 where id=p_event_id;
end $$;

create function public.together_leave_event(p_event_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare e public.together_events;
begin
 if auth.uid() is null then raise exception 'Zaloguj się.' using errcode='42501'; end if;
 select * into e from public.together_events where id=p_event_id for update;
 if not found then raise exception 'Spotkanie nie istnieje.'; end if;
 if e.host_id=auth.uid() then raise exception 'Organizator nie może opuścić własnego spotkania.'; end if;
 if e.starts_at<=now() then raise exception 'Spotkanie już się rozpoczęło.'; end if;
 delete from public.together_memberships where event_id=p_event_id and user_id=auth.uid();
 if found then update public.together_events set attendee_count=attendee_count-1 where id=p_event_id; end if;
end $$;

-- Usunięcie konta zwalnia miejsce. Dla zwykłego wyjścia licznik zmienia RPC.
create function public.together_deleted_user_seat() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from auth.users where id=old.user_id) then
  update public.together_events set attendee_count=attendee_count-1 where id=old.event_id;
 end if;
 return old;
end $$;
create trigger together_deleted_user_seat after delete on public.together_memberships for each row execute function public.together_deleted_user_seat();

create function public.together_list_events(p_query text default '',p_city text default '',p_category text default '',p_mine boolean default false)
returns table(id uuid,title text,description text,city text,location text,category text,starts_at timestamptz,capacity integer,attendee_count integer,is_host boolean,joined boolean)
language sql stable security invoker set search_path='' as $$
 select e.id,e.title,e.description,e.city,e.location,e.category,e.starts_at,e.capacity,e.attendee_count,e.host_id=auth.uid(),exists(select 1 from public.together_memberships m where m.event_id=e.id and m.user_id=auth.uid())
 from public.together_events e
 where e.starts_at>now()
 and (p_query='' or position(lower(p_query) in lower(e.title||' '||e.description))>0)
 and (p_city='' or position(lower(p_city) in lower(e.city))>0)
 and (p_category='' or e.category=p_category)
 and (not p_mine or e.host_id=auth.uid() or exists(select 1 from public.together_memberships m where m.event_id=e.id and m.user_id=auth.uid()))
 order by e.starts_at,e.id limit 100
$$;
revoke all on function public.together_create_event(jsonb),public.together_join_event(uuid),public.together_leave_event(uuid),public.together_list_events(text,text,text,boolean),public.together_deleted_user_seat() from public,anon,authenticated;
grant execute on function public.together_create_event(jsonb),public.together_join_event(uuid),public.together_leave_event(uuid),public.together_list_events(text,text,text,boolean) to authenticated;
commit;
