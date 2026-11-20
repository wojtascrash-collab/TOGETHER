alter table public.together_discovery_profiles
  add column prompt_question text,
  add column prompt_answer text,
  add constraint together_discovery_prompt_pair_check check (
    (prompt_question is null and prompt_answer is null) or
    (char_length(btrim(prompt_question)) between 5 and 100 and char_length(btrim(prompt_answer)) between 2 and 240)
  );

alter table public.together_swipes
  add column note text,
  add constraint together_swipes_note_check check (
    note is null or (decision = 'like' and char_length(btrim(note)) between 1 and 150)
  );

drop function public.together_my_discovery_profile();
create function public.together_my_discovery_profile()
returns table(display_name text,city text,bio text,interests text[],visible boolean,photo_path text,prompt_question text,prompt_answer text)
language sql security definer set search_path='' stable as $$
 select p.display_name,p.city,p.bio,p.interests,p.visible,p.photo_path,p.prompt_question,p.prompt_answer
 from public.together_discovery_profiles p where p.user_id=auth.uid()
$$;

create or replace function public.together_save_discovery_profile(p_profile jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare
 u uuid:=auth.uid();i text[];path text:=nullif(btrim(p_profile->>'photo_path'),'');
 q text:=nullif(btrim(p_profile->>'prompt_question'),'');a text:=nullif(btrim(p_profile->>'prompt_answer'),'');
begin
 if u is null then raise exception 'authentication required' using errcode='42501';end if;
 if path is not null and path not like u::text||'/%' then raise exception 'invalid photo path' using errcode='42501';end if;
 if (q is null)<>(a is null) then raise exception 'Pytanie i odpowiedź muszą być uzupełnione razem.' using errcode='22023';end if;
 select coalesce(array_agg(distinct btrim(value)) filter(where btrim(value)<>''),'{}') into i
 from jsonb_array_elements_text(coalesce(p_profile->'interests','[]'::jsonb));
 insert into public.together_discovery_profiles(user_id,display_name,city,bio,interests,visible,photo_path,prompt_question,prompt_answer,updated_at)
 values(u,btrim(p_profile->>'display_name'),btrim(p_profile->>'city'),btrim(p_profile->>'bio'),i,coalesce((p_profile->>'visible')::boolean,true),path,q,a,now())
 on conflict(user_id) do update set display_name=excluded.display_name,city=excluded.city,bio=excluded.bio,interests=excluded.interests,visible=excluded.visible,photo_path=excluded.photo_path,prompt_question=excluded.prompt_question,prompt_answer=excluded.prompt_answer,updated_at=now();
end$$;

drop function public.together_discovery_cards(integer,text,text);
create function public.together_discovery_cards(p_limit integer default 20,p_city text default '',p_interest text default '')
returns table(display_name text,city text,bio text,interests text[],photo_path text,prompt_question text,prompt_answer text)
language sql security definer set search_path='' stable as $$
 select p.display_name,p.city,p.bio,p.interests,p.photo_path,p.prompt_question,p.prompt_answer
 from public.together_discovery_profiles p
 where auth.uid() is not null and p.visible and p.user_id<>auth.uid()
 and (btrim(p_city)='' or lower(p.city)=lower(btrim(p_city)))
 and (btrim(p_interest)='' or exists(select 1 from unnest(p.interests) i where lower(i)=lower(btrim(p_interest))))
 and not exists(select 1 from public.together_swipes s where s.actor_id=auth.uid() and s.target_id=p.user_id)
 and not exists(select 1 from public.together_blocks b where (b.blocker_id=auth.uid() and b.blocked_id=p.user_id) or (b.blocker_id=p.user_id and b.blocked_id=auth.uid()))
 order by p.updated_at desc limit least(greatest(coalesce(p_limit,20),1),50)
$$;

drop function public.together_discovery_swipe(text,text);
create function public.together_discovery_swipe(p_display_name text,p_decision text,p_note text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_target uuid;v_a uuid;v_b uuid;v_match boolean:=false;v_note text:=nullif(btrim(coalesce(p_note,'')),'');
begin
 if v_uid is null then raise exception 'authentication required' using errcode='42501';end if;
 if p_decision not in('like','pass') then raise exception 'invalid decision' using errcode='22023';end if;
 if v_note is not null and (p_decision<>'like' or char_length(v_note)>150) then raise exception 'Notatka może mieć maksymalnie 150 znaków i można ją dodać tylko do polubienia.' using errcode='22023';end if;
 if (select count(*) from public.together_swipes where actor_id=v_uid and created_at>now()-interval '1 day')>=200 then raise exception 'Osiągnięto dzienny limit wyborów. Wróć jutro.' using errcode='P0001';end if;
 select user_id into v_target from public.together_discovery_profiles where lower(display_name)=lower(btrim(p_display_name)) and visible and user_id<>v_uid;
 if v_target is null then raise exception 'card unavailable' using errcode='P0002';end if;
 insert into public.together_swipes(actor_id,target_id,decision,note) values(v_uid,v_target,p_decision,v_note)
 on conflict(actor_id,target_id) do update set decision=excluded.decision,note=excluded.note,created_at=now();
 if p_decision='like' and exists(select 1 from public.together_swipes where actor_id=v_target and target_id=v_uid and decision='like') then
  v_a:=least(v_uid,v_target);v_b:=greatest(v_uid,v_target);insert into public.together_matches(user_a,user_b) values(v_a,v_b) on conflict do nothing;v_match:=true;
 end if;
 return jsonb_build_object('matched',v_match);
end$$;

create function public.together_undo_last_pass()
returns boolean language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_actor uuid;v_target uuid;
begin
 if v_uid is null then raise exception 'authentication required' using errcode='42501';end if;
 select s.actor_id,s.target_id into v_actor,v_target from public.together_swipes s
 where s.actor_id=v_uid and s.decision='pass' order by s.created_at desc limit 1;
 if v_target is null then return false;end if;
 delete from public.together_swipes where actor_id=v_actor and target_id=v_target;
 return true;
end$$;

drop function public.together_my_matches();
create function public.together_my_matches()
returns table(match_id uuid,display_name text,city text,bio text,interests text[],photo_path text,prompt_question text,prompt_answer text,received_note text,matched_at timestamptz,unread_count bigint)
language sql security definer set search_path='' stable as $$
 select m.id,p.display_name,p.city,p.bio,p.interests,p.photo_path,p.prompt_question,p.prompt_answer,
   (select s.note from public.together_swipes s where s.actor_id=p.user_id and s.target_id=auth.uid() and s.decision='like'),
   m.created_at,(select count(*) from public.together_messages x where x.match_id=m.id and x.recipient_id=auth.uid() and x.read_at is null)
 from public.together_matches m
 join public.together_discovery_profiles p on p.user_id=case when m.user_a=auth.uid() then m.user_b else m.user_a end
 where auth.uid() is not null and (m.user_a=auth.uid() or m.user_b=auth.uid())
 and not exists(select 1 from public.together_blocks b where (b.blocker_id=m.user_a and b.blocked_id=m.user_b) or (b.blocker_id=m.user_b and b.blocked_id=m.user_a))
 order by m.created_at desc
$$;

revoke all on function public.together_my_discovery_profile(),public.together_save_discovery_profile(jsonb),public.together_discovery_cards(integer,text,text),public.together_discovery_swipe(text,text,text),public.together_undo_last_pass(),public.together_my_matches() from public,anon;
grant execute on function public.together_my_discovery_profile(),public.together_save_discovery_profile(jsonb),public.together_discovery_cards(integer,text,text),public.together_discovery_swipe(text,text,text),public.together_undo_last_pass(),public.together_my_matches() to authenticated;
