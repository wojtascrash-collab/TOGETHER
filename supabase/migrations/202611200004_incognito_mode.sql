alter table public.together_discovery_profiles
 add column visibility_mode text not null default 'public' check(visibility_mode in ('public','incognito','hidden'));
update public.together_discovery_profiles set visibility_mode='hidden' where visible is false;

drop function public.together_my_discovery_profile();
create function public.together_my_discovery_profile()
returns table(display_name text,city text,bio text,interests text[],visible boolean,photo_path text,prompt_question text,prompt_answer text,age smallint,identity text,relationship_goal text,looking_for text[],min_age smallint,max_age smallint,max_distance_km smallint,has_location boolean,visibility_mode text)
language sql security definer set search_path='' stable as $$
 select p.display_name,p.city,p.bio,p.interests,p.visible,p.photo_path,p.prompt_question,p.prompt_answer,p.age,p.identity,p.relationship_goal,p.looking_for,p.min_age,p.max_age,p.max_distance_km,p.location_lat is not null,p.visibility_mode
 from public.together_discovery_profiles p where p.user_id=auth.uid()
$$;

create function public.together_set_visibility_mode(p_mode text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'authentication required' using errcode='42501';end if;
 if p_mode not in('public','incognito','hidden') then raise exception 'invalid visibility mode' using errcode='22023';end if;
 update public.together_discovery_profiles set visibility_mode=p_mode,visible=p_mode<>'hidden',updated_at=now() where user_id=auth.uid();
 if not found then raise exception 'Najpierw zapisz wizytówkę.' using errcode='P0002';end if;
end$$;

drop function public.together_discovery_cards(integer,text,text);
create function public.together_discovery_cards(p_limit integer default 20,p_city text default '',p_interest text default '')
returns table(display_name text,city text,bio text,interests text[],photo_path text,prompt_question text,prompt_answer text,age smallint,identity text,relationship_goal text,distance_km integer,common_interests text[],compatibility_score integer)
language sql security definer set search_path='' stable as $$
 with me as (select * from public.together_discovery_profiles where user_id=auth.uid()), candidates as (
  select p.*,case when me.location_lat is not null and p.location_lat is not null then
   6371*acos(least(1,greatest(-1,sin(radians(me.location_lat::double precision))*sin(radians(p.location_lat::double precision))+cos(radians(me.location_lat::double precision))*cos(radians(p.location_lat::double precision))*cos(radians((p.location_lng-me.location_lng)::double precision))))) end as km,
   me.age me_age,me.identity me_identity,me.looking_for me_looking_for,me.min_age me_min_age,me.max_age me_max_age,me.max_distance_km me_distance,me.relationship_goal me_goal,
   array(select distinct i from unnest(p.interests) i where exists(select 1 from unnest(me.interests) mi where lower(mi)=lower(i))) common
  from public.together_discovery_profiles p cross join me where p.user_id<>auth.uid() and p.visible and p.visibility_mode<>'hidden'
  and (p.visibility_mode='public' or exists(select 1 from public.together_swipes s where s.actor_id=p.user_id and s.target_id=auth.uid() and s.decision='like'))
 ), scored as (
  select c.*,least(100,40+(case when c.relationship_goal=c.me_goal then 25 else 0 end)+least(20,cardinality(c.common)*5)+(case when c.km<=10 then 15 when c.km<=25 then 10 when c.km<=50 then 5 else 0 end))::integer score from candidates c
 )
 select c.display_name,c.city,c.bio,c.interests,c.photo_path,c.prompt_question,c.prompt_answer,c.age,c.identity,c.relationship_goal,case when c.km is null then null else round(c.km)::integer end,c.common,c.score
 from scored c where auth.uid() is not null
 and (btrim(p_city)='' or lower(c.city)=lower(btrim(p_city)))
 and (btrim(p_interest)='' or exists(select 1 from unnest(c.interests) z where lower(z)=lower(btrim(p_interest))))
 and (c.age is null or c.age between c.me_min_age and c.me_max_age) and (c.me_age is null or c.age is null or c.me_age between c.min_age and c.max_age)
 and ('all'=any(c.me_looking_for) or c.identity=any(c.me_looking_for)) and ('all'=any(c.looking_for) or c.me_identity=any(c.looking_for)) and (c.km is null or c.km<=c.me_distance)
 and not exists(select 1 from public.together_swipes s where s.actor_id=auth.uid() and s.target_id=c.user_id)
 and not exists(select 1 from public.together_blocks b where (b.blocker_id=auth.uid() and b.blocked_id=c.user_id) or (b.blocker_id=c.user_id and b.blocked_id=auth.uid()))
 order by c.score desc,c.km nulls last,c.updated_at desc limit least(greatest(coalesce(p_limit,20),1),50)
$$;

revoke all on function public.together_my_discovery_profile(),public.together_set_visibility_mode(text),public.together_discovery_cards(integer,text,text) from public,anon;
grant execute on function public.together_my_discovery_profile(),public.together_set_visibility_mode(text),public.together_discovery_cards(integer,text,text) to authenticated;

