drop function public.together_discovery_cards(integer,text,text);
create function public.together_discovery_cards(p_limit integer default 20,p_city text default '',p_interest text default '')
returns table(display_name text,city text,bio text,interests text[],photo_path text,prompt_question text,prompt_answer text,age smallint,identity text,relationship_goal text,distance_km integer,common_interests text[],compatibility_score integer)
language sql security definer set search_path='' stable as $$
 with me as (select * from public.together_discovery_profiles where user_id=auth.uid()), candidates as (
  select p.*,case when me.location_lat is not null and p.location_lat is not null then
   6371*acos(least(1,greatest(-1,sin(radians(me.location_lat::double precision))*sin(radians(p.location_lat::double precision))+cos(radians(me.location_lat::double precision))*cos(radians(p.location_lat::double precision))*cos(radians((p.location_lng-me.location_lng)::double precision))))) end as km,
   me.age me_age,me.identity me_identity,me.looking_for me_looking_for,me.min_age me_min_age,me.max_age me_max_age,me.max_distance_km me_distance,me.relationship_goal me_goal,
   array(select distinct i from unnest(p.interests) i where exists(select 1 from unnest(me.interests) mi where lower(mi)=lower(i))) common
  from public.together_discovery_profiles p cross join me where p.user_id<>auth.uid() and p.visible
 ), scored as (
  select c.*,least(100,40+(case when c.relationship_goal=c.me_goal then 25 else 0 end)+least(20,cardinality(c.common)*5)+(case when c.km<=10 then 15 when c.km<=25 then 10 when c.km<=50 then 5 else 0 end))::integer score
  from candidates c
 )
 select c.display_name,c.city,c.bio,c.interests,c.photo_path,c.prompt_question,c.prompt_answer,c.age,c.identity,c.relationship_goal,
   case when c.km is null then null else round(c.km)::integer end,c.common,c.score
 from scored c where auth.uid() is not null
 and (btrim(p_city)='' or lower(c.city)=lower(btrim(p_city)))
 and (btrim(p_interest)='' or exists(select 1 from unnest(c.interests) z where lower(z)=lower(btrim(p_interest))))
 and (c.age is null or c.age between c.me_min_age and c.me_max_age)
 and (c.me_age is null or c.age is null or c.me_age between c.min_age and c.max_age)
 and ('all'=any(c.me_looking_for) or c.identity=any(c.me_looking_for))
 and ('all'=any(c.looking_for) or c.me_identity=any(c.looking_for))
 and (c.km is null or c.km<=c.me_distance)
 and not exists(select 1 from public.together_swipes s where s.actor_id=auth.uid() and s.target_id=c.user_id)
 and not exists(select 1 from public.together_blocks b where (b.blocker_id=auth.uid() and b.blocked_id=c.user_id) or (b.blocker_id=c.user_id and b.blocked_id=auth.uid()))
 order by c.score desc,c.km nulls last,c.updated_at desc limit least(greatest(coalesce(p_limit,20),1),50)
$$;

drop function public.together_my_matches();
create function public.together_my_matches()
returns table(match_id uuid,display_name text,city text,bio text,interests text[],photo_path text,prompt_question text,prompt_answer text,age smallint,identity text,relationship_goal text,common_interests text[],received_note text,matched_at timestamptz,unread_count bigint)
language sql security definer set search_path='' stable as $$
 with me as (select interests from public.together_discovery_profiles where user_id=auth.uid())
 select m.id,p.display_name,p.city,p.bio,p.interests,p.photo_path,p.prompt_question,p.prompt_answer,p.age,p.identity,p.relationship_goal,
   array(select distinct i from unnest(p.interests) i where exists(select 1 from me cross join unnest(me.interests) mi where lower(mi)=lower(i))),
   (select s.note from public.together_swipes s where s.actor_id=p.user_id and s.target_id=auth.uid() and s.decision='like'),m.created_at,
   (select count(*) from public.together_messages x where x.match_id=m.id and x.recipient_id=auth.uid() and x.read_at is null)
 from public.together_matches m join public.together_discovery_profiles p on p.user_id=case when m.user_a=auth.uid() then m.user_b else m.user_a end
 where auth.uid() is not null and (m.user_a=auth.uid() or m.user_b=auth.uid())
 and not exists(select 1 from public.together_blocks b where (b.blocker_id=m.user_a and b.blocked_id=m.user_b) or (b.blocker_id=m.user_b and b.blocked_id=m.user_a)) order by m.created_at desc
$$;

revoke all on function public.together_discovery_cards(integer,text,text),public.together_my_matches() from public,anon;
grant execute on function public.together_discovery_cards(integer,text,text),public.together_my_matches() to authenticated;
