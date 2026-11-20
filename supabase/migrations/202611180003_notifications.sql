create table public.together_notifications (
 id uuid primary key default gen_random_uuid(),
 event_id uuid not null references public.together_events(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 kind text not null check (kind in ('event_changed','event_cancelled')),
 event_title text not null,
 old_details jsonb not null,
 new_details jsonb not null,
 created_at timestamptz not null default now(),
 read_at timestamptz
);
create index together_notifications_user_time_idx on public.together_notifications(user_id,created_at desc,id);
alter table public.together_notifications enable row level security;
create policy together_notifications_read_own on public.together_notifications for select to authenticated using (user_id=(select auth.uid()));
revoke all on public.together_notifications from public,anon,authenticated;
grant select on public.together_notifications to authenticated;

create function public.together_notify_event_change() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.cancelled_at is not distinct from old.cancelled_at and new.starts_at is not distinct from old.starts_at and new.city is not distinct from old.city and new.location is not distinct from old.location then return new; end if;
 insert into public.together_notifications(event_id,user_id,kind,event_title,old_details,new_details)
 select new.id,m.user_id,case when old.cancelled_at is null and new.cancelled_at is not null then 'event_cancelled' else 'event_changed' end,new.title,
 jsonb_build_object('starts_at',old.starts_at,'city',old.city,'location',old.location),
 jsonb_build_object('starts_at',new.starts_at,'city',new.city,'location',new.location)
 from public.together_memberships m where m.event_id=new.id and m.user_id<>new.host_id;
 return new;
end $$;
revoke all on function public.together_notify_event_change() from public,anon,authenticated;
create trigger together_notify_event_change after update on public.together_events for each row execute function public.together_notify_event_change();

create function public.together_list_notifications()
returns table(id uuid,event_id uuid,kind text,event_title text,old_details jsonb,new_details jsonb,created_at timestamptz,read_at timestamptz,unread_count bigint)
language sql stable security invoker set search_path='' as $$
 select n.id,n.event_id,n.kind,n.event_title,n.old_details,n.new_details,n.created_at,n.read_at,
 count(*) filter(where n.read_at is null) over()
 from public.together_notifications n order by n.created_at desc,n.id limit 100
$$;
create function public.together_read_notification(p_notification_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Zaloguj się.' using errcode='42501'; end if;
 update public.together_notifications set read_at=coalesce(read_at,now()) where id=p_notification_id and user_id=auth.uid();
 if not found then raise exception 'Brak dostępu do powiadomienia.' using errcode='42501'; end if;
end $$;
revoke all on function public.together_list_notifications(),public.together_read_notification(uuid) from public,anon,authenticated;
grant execute on function public.together_list_notifications(),public.together_read_notification(uuid) to authenticated;
