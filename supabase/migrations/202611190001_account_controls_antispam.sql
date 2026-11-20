create index if not exists together_messages_sender_created_idx on public.together_messages(sender_id,created_at desc);
create index if not exists together_reports_reporter_created_idx on public.together_reports(reporter_id,created_at desc);
create index if not exists together_swipes_actor_created_idx on public.together_swipes(actor_id,created_at desc);

create or replace function public.together_my_blocks()
returns table(display_name text,city text,blocked_at timestamptz)
language sql security definer set search_path='' stable as $$
 select p.display_name,p.city,b.created_at
 from public.together_blocks b
 join public.together_discovery_profiles p on p.user_id=b.blocked_id
 where auth.uid() is not null and b.blocker_id=auth.uid()
 order by b.created_at desc;
$$;

create or replace function public.together_unblock_person(p_display_name text)
returns void language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_target uuid;
begin
 if v_uid is null then raise exception 'authentication required' using errcode='42501';end if;
 select user_id into v_target from public.together_discovery_profiles where lower(display_name)=lower(btrim(p_display_name)) and user_id<>v_uid;
 if v_target is null then raise exception 'person unavailable' using errcode='P0002';end if;
 delete from public.together_blocks where blocker_id=v_uid and blocked_id=v_target;
end$$;

create or replace function public.together_send_message(p_match_id uuid,p_body text)
returns void language plpgsql security definer set search_path='' as $$
declare m public.together_matches;r uuid;v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'authentication required' using errcode='42501';end if;
 if char_length(btrim(coalesce(p_body,''))) not between 1 and 1000 then raise exception 'Wiadomość musi mieć od 1 do 1000 znaków.' using errcode='22023';end if;
 if (select count(*) from public.together_messages where sender_id=v_uid and created_at>now()-interval '1 minute')>=8 then raise exception 'Wysyłasz wiadomości zbyt szybko. Odczekaj minutę.' using errcode='P0001';end if;
 if (select count(*) from public.together_messages where sender_id=v_uid and created_at>now()-interval '1 day')>=250 then raise exception 'Osiągnięto dzienny limit wiadomości.' using errcode='P0001';end if;
 select * into m from public.together_matches where id=p_match_id;
 if m.id is null or v_uid not in(m.user_a,m.user_b) then raise exception 'match unavailable' using errcode='42501';end if;
 if exists(select 1 from public.together_blocks b where (b.blocker_id=m.user_a and b.blocked_id=m.user_b) or (b.blocker_id=m.user_b and b.blocked_id=m.user_a)) then raise exception 'contact blocked' using errcode='42501';end if;
 r:=case when m.user_a=v_uid then m.user_b else m.user_a end;
 insert into public.together_messages(match_id,sender_id,recipient_id,body) values(p_match_id,v_uid,r,btrim(p_body));
end$$;

create or replace function public.together_report_person(p_display_name text,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare t uuid;v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'authentication required' using errcode='42501';end if;
 if char_length(btrim(coalesce(p_reason,''))) not between 3 and 500 then raise exception 'Powód zgłoszenia musi mieć od 3 do 500 znaków.' using errcode='22023';end if;
 select user_id into t from public.together_discovery_profiles where lower(display_name)=lower(btrim(p_display_name)) and user_id<>v_uid;
 if t is null then raise exception 'person unavailable' using errcode='P0002';end if;
 if (select count(*) from public.together_reports where reporter_id=v_uid and created_at>now()-interval '1 day')>=5 then raise exception 'Osiągnięto dzienny limit zgłoszeń.' using errcode='P0001';end if;
 if exists(select 1 from public.together_reports where reporter_id=v_uid and reported_id=t and created_at>now()-interval '7 days') then raise exception 'Ta osoba została już niedawno zgłoszona.' using errcode='P0001';end if;
 insert into public.together_reports(reporter_id,reported_id,reason) values(v_uid,t,btrim(p_reason));
end$$;

create or replace function public.together_discovery_swipe(p_display_name text,p_decision text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();v_target uuid;v_a uuid;v_b uuid;v_match boolean:=false;
begin
 if v_uid is null then raise exception 'authentication required' using errcode='42501';end if;
 if p_decision not in('like','pass') then raise exception 'invalid decision' using errcode='22023';end if;
 if (select count(*) from public.together_swipes where actor_id=v_uid and created_at>now()-interval '1 day')>=200 then raise exception 'Osiągnięto dzienny limit wyborów. Wróć jutro.' using errcode='P0001';end if;
 select user_id into v_target from public.together_discovery_profiles where lower(display_name)=lower(btrim(p_display_name)) and visible and user_id<>v_uid;
 if v_target is null then raise exception 'card unavailable' using errcode='P0002';end if;
 insert into public.together_swipes(actor_id,target_id,decision) values(v_uid,v_target,p_decision)
 on conflict(actor_id,target_id) do update set decision=excluded.decision,created_at=now();
 if p_decision='like' and exists(select 1 from public.together_swipes where actor_id=v_target and target_id=v_uid and decision='like') then
  v_a:=least(v_uid,v_target);v_b:=greatest(v_uid,v_target);insert into public.together_matches(user_a,user_b) values(v_a,v_b) on conflict do nothing;v_match:=true;
 end if;
 return jsonb_build_object('matched',v_match);
end$$;

create or replace function public.together_delete_own_account(p_confirmation text)
returns void language plpgsql security definer set search_path='' as $$
declare v_uid uuid:=auth.uid();
begin
 if v_uid is null then raise exception 'authentication required' using errcode='42501';end if;
 if p_confirmation<>'USUŃ KONTO' then raise exception 'Nieprawidłowe potwierdzenie.' using errcode='22023';end if;
 delete from auth.sessions where user_id=v_uid;
 delete from auth.users where id=v_uid;
 if not found then raise exception 'account unavailable' using errcode='P0002';end if;
end$$;

revoke all on function public.together_my_blocks(),public.together_unblock_person(text),public.together_send_message(uuid,text),public.together_report_person(text,text),public.together_discovery_swipe(text,text),public.together_delete_own_account(text) from public,anon;
grant execute on function public.together_my_blocks(),public.together_unblock_person(text),public.together_send_message(uuid,text),public.together_report_person(text,text),public.together_discovery_swipe(text,text),public.together_delete_own_account(text) to authenticated;
