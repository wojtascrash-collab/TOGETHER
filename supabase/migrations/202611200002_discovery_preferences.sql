alter table public.together_discovery_profiles
  add column age smallint check(age is null or age between 18 and 99),
  add column identity text not null default 'other' check(identity in ('woman','man','nonbinary','other')),
  add column relationship_goal text not null default 'friends' check(relationship_goal in ('friends','dating','relationship','activities')),
  add column looking_for text[] not null default array['all']::text[],
  add column min_age smallint not null default 18 check(min_age between 18 and 99),
  add column max_age smallint not null default 99 check(max_age between 18 and 99),
  add column max_distance_km smallint not null default 100 check(max_distance_km in (5,10,25,50,100,500)),
  add column location_lat numeric(8,5) check(location_lat is null or location_lat between -90 and 90),
  add column location_lng numeric(8,5) check(location_lng is null or location_lng between -180 and 180),
  add constraint together_discovery_age_range_check check(min_age<=max_age),
  add constraint together_discovery_looking_for_check check(
    cardinality(looking_for) between 1 and 4 and looking_for <@ array['all','woman','man','nonbinary','other']::text[]
  ),
  add constraint together_discovery_location_pair_check check((location_lat is null)=(location_lng is null));

drop function public.together_my_discovery_profile();
create function public.together_my_discovery_profile()
returns table(display_name text,city text,bio text,interests text[],visible boolean,photo_path text,prompt_question text,prompt_answer text,age smallint,identity text,relationship_goal text,looking_for text[],min_age smallint,max_age smallint,max_distance_km smallint,has_location boolean)
language sql security definer set search_path='' stable as $$
 select p.display_name,p.city,p.bio,p.interests,p.visible,p.photo_path,p.prompt_question,p.prompt_answer,p.age,p.identity,p.relationship_goal,p.looking_for,p.min_age,p.max_age,p.max_distance_km,p.location_lat is not null
 from public.together_discovery_profiles p where p.user_id=auth.uid()
$$;

create or replace function public.together_save_discovery_profile(p_profile jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare
 u uuid:=auth.uid();i text[];lf text[];path text:=nullif(btrim(p_profile->>'photo_path'),'');
 q text:=nullif(btrim(p_profile->>'prompt_question'),'');a text:=nullif(btrim(p_profile->>'prompt_answer'),'');
 v_age smallint:=nullif(p_profile->>'age','')::smallint;v_min smallint:=coalesce(nullif(p_profile->>'min_age','')::smallint,18);v_max smallint:=coalesce(nullif(p_profile->>'max_age','')::smallint,99);
 v_identity text:=coalesce(nullif(p_profile->>'identity',''),'other');v_goal text:=coalesce(nullif(p_profile->>'relationship_goal',''),'friends');v_distance smallint:=coalesce(nullif(p_profile->>'max_distance_km','')::smallint,100);
 old_lat numeric;old_lng numeric;
begin
 if u is null then raise exception 'authentication required' using errcode='42501';end if;
 if path is not null and path not like u::text||'/%' then raise exception 'invalid photo path' using errcode='42501';end if;
 if (q is null)<>(a is null) then raise exception 'Pytanie i odpowiedź muszą być uzupełnione razem.' using errcode='22023';end if;
 select coalesce(array_agg(distinct btrim(value)) filter(where btrim(value)<>''),'{}') into i from jsonb_array_elements_text(coalesce(p_profile->'interests','[]'::jsonb));
 select coalesce(array_agg(distinct btrim(value)) filter(where btrim(value)<>''),array['all']) into lf from jsonb_array_elements_text(coalesce(p_profile->'looking_for','["all"]'::jsonb));
 if 'all'=any(lf) then lf:=array['all'];end if;
 select location_lat,location_lng into old_lat,old_lng from public.together_discovery_profiles where user_id=u;
 insert into public.together_discovery_profiles(user_id,display_name,city,bio,interests,visible,photo_path,prompt_question,prompt_answer,age,identity,relationship_goal,looking_for,min_age,max_age,max_distance_km,location_lat,location_lng,updated_at)
 values(u,btrim(p_profile->>'display_name'),btrim(p_profile->>'city'),btrim(p_profile->>'bio'),i,coalesce((p_profile->>'visible')::boolean,true),path,q,a,v_age,v_identity,v_goal,lf,v_min,v_max,v_distance,old_lat,old_lng,now())
 on conflict(user_id) do update set display_name=excluded.display_name,city=excluded.city,bio=excluded.bio,interests=excluded.interests,visible=excluded.visible,photo_path=excluded.photo_path,prompt_question=excluded.prompt_question,prompt_answer=excluded.prompt_answer,age=excluded.age,identity=excluded.identity,relationship_goal=excluded.relationship_goal,looking_for=excluded.looking_for,min_age=excluded.min_age,max_age=excluded.max_age,max_distance_km=excluded.max_distance_km,updated_at=now();
end$$;

create function public.together_set_discovery_location(p_lat numeric,p_lng numeric)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'authentication required' using errcode='42501';end if;
 if p_lat not between -90 and 90 or p_lng not between -180 and 180 then raise exception 'invalid location' using errcode='22023';end if;
 update public.together_discovery_profiles set location_lat=round(p_lat,5),location_lng=round(p_lng,5),updated_at=now() where user_id=auth.uid();
 if not found then raise exception 'Najpierw zapisz wizytówkę.' using errcode='P0002';end if;
end$$;

create function public.together_clear_discovery_location()
returns void language sql security definer set search_path='' as $$
 update public.together_discovery_profiles set location_lat=null,location_lng=null,updated_at=now() where user_id=auth.uid() and auth.uid() is not null
$$;

drop function public.together_discovery_cards(integer,text,text);
create function public.together_discovery_cards(p_limit integer default 20,p_city text default '',p_interest text default '')
returns table(display_name text,city text,bio text,interests text[],photo_path text,prompt_question text,prompt_answer text,age smallint,identity text,relationship_goal text,distance_km integer)
language sql security definer set search_path='' stable as $$
 with me as (select * from public.together_discovery_profiles where user_id=auth.uid()), candidates as (
  select p.*,case when me.location_lat is not null and p.location_lat is not null then
   6371*acos(least(1,greatest(-1,sin(radians(me.location_lat::double precision))*sin(radians(p.location_lat::double precision))+cos(radians(me.location_lat::double precision))*cos(radians(p.location_lat::double precision))*cos(radians((p.location_lng-me.location_lng)::double precision))))) end as km,me.age me_age,me.identity me_identity,me.looking_for me_looking_for,me.min_age me_min_age,me.max_age me_max_age,me.max_distance_km me_distance
  from public.together_discovery_profiles p cross join me where p.user_id<>auth.uid() and p.visible
 )
 select c.display_name,c.city,c.bio,c.interests,c.photo_path,c.prompt_question,c.prompt_answer,c.age,c.identity,c.relationship_goal,case when c.km is null then null else round(c.km)::integer end
 from candidates c where auth.uid() is not null
 and (btrim(p_city)='' or lower(c.city)=lower(btrim(p_city)))
 and (btrim(p_interest)='' or exists(select 1 from unnest(c.interests) z where lower(z)=lower(btrim(p_interest))))
 and (c.age is null or c.age between c.me_min_age and c.me_max_age)
 and (c.me_age is null or c.age is null or c.me_age between c.min_age and c.max_age)
 and ('all'=any(c.me_looking_for) or c.identity=any(c.me_looking_for))
 and ('all'=any(c.looking_for) or c.me_identity=any(c.looking_for))
 and (c.km is null or c.km<=c.me_distance)
 and not exists(select 1 from public.together_swipes s where s.actor_id=auth.uid() and s.target_id=c.user_id)
 and not exists(select 1 from public.together_blocks b where (b.blocker_id=auth.uid() and b.blocked_id=c.user_id) or (b.blocker_id=c.user_id and b.blocked_id=auth.uid()))
 order by c.km nulls last,c.updated_at desc limit least(greatest(coalesce(p_limit,20),1),50)
$$;

drop function public.together_my_matches();
create function public.together_my_matches()
returns table(match_id uuid,display_name text,city text,bio text,interests text[],photo_path text,prompt_question text,prompt_answer text,age smallint,identity text,relationship_goal text,received_note text,matched_at timestamptz,unread_count bigint)
language sql security definer set search_path='' stable as $$
 select m.id,p.display_name,p.city,p.bio,p.interests,p.photo_path,p.prompt_question,p.prompt_answer,p.age,p.identity,p.relationship_goal,
   (select s.note from public.together_swipes s where s.actor_id=p.user_id and s.target_id=auth.uid() and s.decision='like'),m.created_at,
   (select count(*) from public.together_messages x where x.match_id=m.id and x.recipient_id=auth.uid() and x.read_at is null)
 from public.together_matches m join public.together_discovery_profiles p on p.user_id=case when m.user_a=auth.uid() then m.user_b else m.user_a end
 where auth.uid() is not null and (m.user_a=auth.uid() or m.user_b=auth.uid())
 and not exists(select 1 from public.together_blocks b where (b.blocker_id=m.user_a and b.blocked_id=m.user_b) or (b.blocker_id=m.user_b and b.blocked_id=m.user_a)) order by m.created_at desc
$$;

revoke all on function public.together_my_discovery_profile(),public.together_save_discovery_profile(jsonb),public.together_set_discovery_location(numeric,numeric),public.together_clear_discovery_location(),public.together_discovery_cards(integer,text,text),public.together_my_matches() from public,anon;
grant execute on function public.together_my_discovery_profile(),public.together_save_discovery_profile(jsonb),public.together_set_discovery_location(numeric,numeric),public.together_clear_discovery_location(),public.together_discovery_cards(integer,text,text),public.together_my_matches() to authenticated;
