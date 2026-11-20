alter table public.together_memberships add column display_name text
 check (display_name is null or char_length(btrim(display_name)) between 2 and 60);

create function public.together_join_event_named(p_event_id uuid,p_display_name text) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Zaloguj się.' using errcode='42501'; end if;
 if p_display_name is null or char_length(btrim(p_display_name)) not between 2 and 60 then raise exception 'Podaj nazwę od 2 do 60 znaków.'; end if;
 perform public.together_join_event(p_event_id);
 -- Tożsamość bierze się z sesji; klient nie może podać cudzego ID.
 update public.together_memberships set display_name=btrim(p_display_name)
 where event_id=p_event_id and user_id=auth.uid() and display_name is null;
end $$;

create function public.together_event_attendees(p_event_id uuid)
returns table(display_name text,joined_at timestamptz)
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not exists(select 1 from public.together_events e where e.id=p_event_id and e.host_id=auth.uid()) then
  raise exception 'Listę uczestników widzi tylko organizator.' using errcode='42501';
 end if;
 return query select coalesce(m.display_name,'Uczestnik bez podanej nazwy'),m.created_at
 from public.together_memberships m where m.event_id=p_event_id order by m.created_at,m.user_id;
end $$;
revoke all on function public.together_join_event_named(uuid,text),public.together_event_attendees(uuid) from public,anon,authenticated;
grant execute on function public.together_join_event_named(uuid,text),public.together_event_attendees(uuid) to authenticated;
