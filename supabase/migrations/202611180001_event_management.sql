alter table public.together_events add column cancelled_at timestamptz;

create function public.together_update_event(p_event_id uuid,p_event jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare e public.together_events;
begin
 if auth.uid() is null then raise exception 'Zaloguj się.' using errcode='42501'; end if;
 select * into e from public.together_events where id=p_event_id for update;
 if not found or e.host_id<>auth.uid() then raise exception 'Tylko organizator może zmieniać spotkanie.' using errcode='42501'; end if;
 if e.cancelled_at is not null then raise exception 'Spotkanie jest odwołane.'; end if;
 if e.starts_at<=now() then raise exception 'Spotkanie już się rozpoczęło.'; end if;
 if (p_event->>'starts_at')::timestamptz<=now() then raise exception 'Wybierz przyszłą datę.'; end if;
 if (p_event->>'capacity')::integer<e.attendee_count then raise exception 'Liczba miejsc nie może być mniejsza niż liczba zapisanych osób.'; end if;
 update public.together_events set title=btrim(p_event->>'title'),description=btrim(p_event->>'description'),city=btrim(p_event->>'city'),location=btrim(p_event->>'location'),category=p_event->>'category',starts_at=(p_event->>'starts_at')::timestamptz,capacity=(p_event->>'capacity')::integer where id=p_event_id;
end $$;
create function public.together_cancel_event(p_event_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare e public.together_events;
begin
 if auth.uid() is null then raise exception 'Zaloguj się.' using errcode='42501'; end if;
 select * into e from public.together_events where id=p_event_id for update;
 if not found or e.host_id<>auth.uid() then raise exception 'Tylko organizator może odwołać spotkanie.' using errcode='42501'; end if;
 if e.cancelled_at is not null then return; end if;
 if e.starts_at<=now() then raise exception 'Spotkanie już się rozpoczęło.'; end if;
 update public.together_events set cancelled_at=now() where id=p_event_id;
end $$;
create or replace function public.together_join_event(p_event_id uuid) returns void
language plpgsql security definer set search_path='' as $$
declare e public.together_events;
begin
 if auth.uid() is null then raise exception 'Zaloguj się.' using errcode='42501'; end if;
 select * into e from public.together_events where id=p_event_id for update;
 if not found then raise exception 'Spotkanie nie istnieje.'; end if;
 if e.cancelled_at is not null then raise exception 'Spotkanie jest odwołane.'; end if;
 if e.starts_at<=now() then raise exception 'Spotkanie już się rozpoczęło.'; end if;
 if e.host_id=auth.uid() or exists(select 1 from public.together_memberships where event_id=p_event_id and user_id=auth.uid()) then return; end if;
 if e.attendee_count>=e.capacity then raise exception 'Brak wolnych miejsc.'; end if;
 insert into public.together_memberships(event_id,user_id) values(p_event_id,auth.uid());
 update public.together_events set attendee_count=attendee_count+1 where id=p_event_id;
end $$;
create function public.together_list_events_v2(p_query text default '',p_city text default '',p_category text default '',p_mine boolean default false)
returns table(id uuid,title text,description text,city text,location text,category text,starts_at timestamptz,capacity integer,attendee_count integer,is_host boolean,joined boolean,cancelled_at timestamptz)
language sql stable security invoker set search_path='' as $$
 select e.id,e.title,e.description,e.city,e.location,e.category,e.starts_at,e.capacity,e.attendee_count,e.host_id=auth.uid(),exists(select 1 from public.together_memberships m where m.event_id=e.id and m.user_id=auth.uid()),e.cancelled_at
 from public.together_events e where e.starts_at>now()
 and (e.cancelled_at is null or e.host_id=auth.uid() or exists(select 1 from public.together_memberships m where m.event_id=e.id and m.user_id=auth.uid()))
 and (p_query='' or position(lower(p_query) in lower(e.title||' '||e.description))>0)
 and (p_city='' or position(lower(p_city) in lower(e.city))>0)
 and (p_category='' or e.category=p_category)
 and (not p_mine or e.host_id=auth.uid() or exists(select 1 from public.together_memberships m where m.event_id=e.id and m.user_id=auth.uid()))
 order by e.starts_at,e.id limit 100
$$;
-- Stary klient nie pokazuje odwołanych spotkań jako otwartych.
create or replace function public.together_list_events(p_query text default '',p_city text default '',p_category text default '',p_mine boolean default false)
returns table(id uuid,title text,description text,city text,location text,category text,starts_at timestamptz,capacity integer,attendee_count integer,is_host boolean,joined boolean)
language sql stable security invoker set search_path='' as $$
 select e.id,e.title,e.description,e.city,e.location,e.category,e.starts_at,e.capacity,e.attendee_count,e.is_host,e.joined from public.together_list_events_v2(p_query,p_city,p_category,p_mine) e where e.cancelled_at is null
$$;
revoke all on function public.together_update_event(uuid,jsonb),public.together_cancel_event(uuid),public.together_list_events_v2(text,text,text,boolean) from public,anon,authenticated;
grant execute on function public.together_update_event(uuid,jsonb),public.together_cancel_event(uuid),public.together_list_events_v2(text,text,text,boolean) to authenticated;
