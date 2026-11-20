create table public.together_discovery_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(btrim(display_name)) between 2 and 40),
  city text not null check (char_length(btrim(city)) between 2 and 80),
  bio text not null check (char_length(btrim(bio)) between 10 and 500),
  interests text[] not null default '{}',
  visible boolean not null default true,
  updated_at timestamptz not null default now(),
  check (cardinality(interests) between 1 and 8)
);
create unique index together_discovery_display_name_ci on public.together_discovery_profiles (lower(display_name));

create table public.together_swipes (
  actor_id uuid not null references auth.users(id) on delete cascade,
  target_id uuid not null references auth.users(id) on delete cascade,
  decision text not null check (decision in ('like','pass')),
  created_at timestamptz not null default now(),
  primary key (actor_id, target_id), check (actor_id <> target_id)
);

create table public.together_matches (
  id uuid primary key default gen_random_uuid(),
  user_a uuid not null references auth.users(id) on delete cascade,
  user_b uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  check (user_a < user_b), unique (user_a, user_b)
);

alter table public.together_discovery_profiles enable row level security;
alter table public.together_swipes enable row level security;
alter table public.together_matches enable row level security;
revoke all on public.together_discovery_profiles, public.together_swipes, public.together_matches from public, anon, authenticated;

create or replace function public.together_my_discovery_profile()
returns table (display_name text, city text, bio text, interests text[], visible boolean)
language sql security definer set search_path = '' stable as $$
 select p.display_name,p.city,p.bio,p.interests,p.visible from public.together_discovery_profiles p where p.user_id=auth.uid();
$$;

create or replace function public.together_save_discovery_profile(p_profile jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare v_uid uuid:=auth.uid(); v_interests text[];
begin
 if v_uid is null then raise exception 'authentication required' using errcode='42501'; end if;
 select coalesce(array_agg(distinct btrim(value)) filter(where btrim(value)<>''),'{}') into v_interests
 from jsonb_array_elements_text(coalesce(p_profile->'interests','[]'::jsonb));
 insert into public.together_discovery_profiles(user_id,display_name,city,bio,interests,visible,updated_at)
 values(v_uid,btrim(p_profile->>'display_name'),btrim(p_profile->>'city'),btrim(p_profile->>'bio'),v_interests,coalesce((p_profile->>'visible')::boolean,true),now())
 on conflict(user_id) do update set display_name=excluded.display_name,city=excluded.city,bio=excluded.bio,interests=excluded.interests,visible=excluded.visible,updated_at=now();
end; $$;

create or replace function public.together_discovery_cards(p_limit integer default 20)
returns table (display_name text, city text, bio text, interests text[])
language sql security definer set search_path = '' stable as $$
 select p.display_name,p.city,p.bio,p.interests from public.together_discovery_profiles p
 where auth.uid() is not null and p.visible and p.user_id<>auth.uid()
 and not exists(select 1 from public.together_swipes s where s.actor_id=auth.uid() and s.target_id=p.user_id)
 order by p.updated_at desc limit least(greatest(coalesce(p_limit,20),1),50);
$$;

create or replace function public.together_discovery_swipe(p_display_name text,p_decision text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_uid uuid:=auth.uid(); v_target uuid; v_a uuid; v_b uuid; v_match boolean:=false;
begin
 if v_uid is null then raise exception 'authentication required' using errcode='42501'; end if;
 if p_decision not in ('like','pass') then raise exception 'invalid decision' using errcode='22023'; end if;
 select user_id into v_target from public.together_discovery_profiles where lower(display_name)=lower(btrim(p_display_name)) and visible and user_id<>v_uid;
 if v_target is null then raise exception 'card unavailable' using errcode='P0002'; end if;
 insert into public.together_swipes(actor_id,target_id,decision) values(v_uid,v_target,p_decision)
 on conflict(actor_id,target_id) do update set decision=excluded.decision,created_at=now();
 if p_decision='like' and exists(select 1 from public.together_swipes where actor_id=v_target and target_id=v_uid and decision='like') then
  v_a:=least(v_uid,v_target);v_b:=greatest(v_uid,v_target);
  insert into public.together_matches(user_a,user_b) values(v_a,v_b) on conflict do nothing;v_match:=true;
 end if;
 return jsonb_build_object('matched',v_match);
end; $$;

create or replace function public.together_my_matches()
returns table (display_name text, city text, bio text, interests text[], matched_at timestamptz)
language sql security definer set search_path = '' stable as $$
 select p.display_name,p.city,p.bio,p.interests,m.created_at from public.together_matches m
 join public.together_discovery_profiles p on p.user_id=case when m.user_a=auth.uid() then m.user_b else m.user_a end
 where auth.uid() is not null and (m.user_a=auth.uid() or m.user_b=auth.uid()) order by m.created_at desc;
$$;

revoke all on function public.together_my_discovery_profile(),public.together_save_discovery_profile(jsonb),public.together_discovery_cards(integer),public.together_discovery_swipe(text,text),public.together_my_matches() from public,anon;
grant execute on function public.together_my_discovery_profile(),public.together_save_discovery_profile(jsonb),public.together_discovery_cards(integer),public.together_discovery_swipe(text,text),public.together_my_matches() to authenticated;
