-- شغّل هذا الملف كاملاً في Supabase → SQL Editor (مرة واحدة).
-- ثم من Authentication → Providers: فعّل Email و "Allow anonymous sign-ins".
-- (للتجربة السريعة عطّل "Confirm email".)

create table if not exists public.rooms (
  code          text primary key,
  host_id       uuid not null references auth.users(id) on delete cascade,
  status        text not null default 'waiting' check (status in ('waiting', 'playing', 'finished')),
  target_score  int  not null default 101,
  turn_seconds  int  not null default 20,
  -- 4 مقاعد: كل مقعد null (فاضي) أو {"id": uuid|null, "name": text, "bot": bool}
  seats         jsonb not null default '[null,null,null,null]'::jsonb,
  created_at    timestamptz not null default now()
);

create table if not exists public.game_results (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  room_code        text,
  won              boolean not null,
  score_us         int not null,
  score_them       int not null,
  duration_seconds int not null,
  rounds           int not null,
  created_at       timestamptz not null default now()
);

alter table public.rooms enable row level security;
alter table public.game_results enable row level security;

drop policy if exists "rooms readable" on public.rooms;
create policy "rooms readable" on public.rooms for select to authenticated using (true);

drop policy if exists "results select own" on public.game_results;
create policy "results select own" on public.game_results for select to authenticated using (user_id = auth.uid());
drop policy if exists "results insert own" on public.game_results;
create policy "results insert own" on public.game_results for insert to authenticated with check (user_id = auth.uid());

-- Realtime لجدول الغرف
do $$ begin
  alter publication supabase_realtime add table public.rooms;
exception when duplicate_object then null; end $$;

-- ───────────── دوال الغرف (الكتابة تتم فقط عبرها) ─────────────

create or replace function public._gen_room_code() returns text
language plpgsql as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text;
  i int;
begin
  loop
    result := '';
    for i in 1..5 loop
      result := result || substr(chars, 1 + floor(random() * length(chars))::int, 1);
    end loop;
    exit when not exists (select 1 from public.rooms where code = result);
  end loop;
  return result;
end $$;

create or replace function public.create_room(p_name text, p_target int, p_turn int) returns text
language plpgsql security definer set search_path = public as $$
declare
  v_code text;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_target not in (51, 101) or p_turn not in (0, 15, 20, 30) then raise exception 'bad_settings'; end if;
  p_name := left(btrim(coalesce(p_name, '')), 16);
  if p_name = '' then p_name := 'لاعب'; end if;
  -- غرفة واحدة لكل مضيف (يمنع الإغراق)
  delete from public.rooms where host_id = v_uid;
  v_code := public._gen_room_code();
  insert into public.rooms (code, host_id, target_score, turn_seconds, seats)
  values (
    v_code, v_uid, p_target, p_turn,
    jsonb_set('[null,null,null,null]'::jsonb, '{0}', jsonb_build_object('id', v_uid, 'name', p_name, 'bot', false))
  );
  return v_code;
end $$;

create or replace function public.join_room(p_code text, p_name text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  r public.rooms;
  v_uid uuid := auth.uid();
  v_seat int := null;
  v_order int[] := array[2, 1, 3];
  i int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  p_name := left(btrim(coalesce(p_name, '')), 16);
  if p_name = '' then p_name := 'لاعب'; end if;
  select * into r from public.rooms where code = upper(p_code) for update;
  if not found then raise exception 'room_not_found'; end if;

  -- موجود بالفعل؟
  for i in 0..3 loop
    if (r.seats -> i ->> 'id') = v_uid::text then
      return to_jsonb(r);
    end if;
  end loop;

  if r.status <> 'waiting' then raise exception 'room_started'; end if;

  foreach i in array v_order loop
    if jsonb_typeof(r.seats -> i) = 'null' or coalesce((r.seats -> i ->> 'bot')::boolean, false) then
      v_seat := i;
      exit;
    end if;
  end loop;
  if v_seat is null then raise exception 'room_full'; end if;

  update public.rooms
     set seats = jsonb_set(seats, array[v_seat::text], jsonb_build_object('id', v_uid, 'name', p_name, 'bot', false))
   where code = r.code
   returning * into r;
  return to_jsonb(r);
end $$;

create or replace function public.leave_room(p_code text) returns void
language plpgsql security definer set search_path = public as $$
declare
  r public.rooms;
  v_uid uuid := auth.uid();
  i int;
begin
  select * into r from public.rooms where code = upper(p_code) for update;
  if not found then return; end if;
  if r.host_id = v_uid then
    delete from public.rooms where code = r.code;
    return;
  end if;
  for i in 1..3 loop
    if (r.seats -> i ->> 'id') = v_uid::text then
      update public.rooms set seats = jsonb_set(seats, array[i::text], 'null'::jsonb) where code = r.code;
    end if;
  end loop;
end $$;

create or replace function public.set_seat_bot(p_code text, p_seat int, p_bot boolean) returns void
language plpgsql security definer set search_path = public as $$
declare
  r public.rooms;
begin
  select * into r from public.rooms where code = upper(p_code) for update;
  if not found or r.host_id <> auth.uid() or r.status <> 'waiting' then raise exception 'forbidden'; end if;
  if p_seat < 1 or p_seat > 3 then raise exception 'bad_seat'; end if;

  if p_bot then
    if jsonb_typeof(r.seats -> p_seat) = 'null' then
      update public.rooms
         set seats = jsonb_set(seats, array[p_seat::text],
               jsonb_build_object('id', 'null'::jsonb, 'name', 'بوت ' || p_seat, 'bot', true))
       where code = r.code;
    end if;
  else
    if coalesce((r.seats -> p_seat ->> 'bot')::boolean, false) then
      update public.rooms set seats = jsonb_set(seats, array[p_seat::text], 'null'::jsonb) where code = r.code;
    end if;
  end if;
end $$;

create or replace function public.start_room(p_code text) returns void
language plpgsql security definer set search_path = public as $$
declare
  r public.rooms;
  i int;
begin
  select * into r from public.rooms where code = upper(p_code) for update;
  if not found or r.host_id <> auth.uid() then raise exception 'forbidden'; end if;
  for i in 1..3 loop
    if jsonb_typeof(r.seats -> i) = 'null' then
      r.seats := jsonb_set(r.seats, array[i::text],
        jsonb_build_object('id', 'null'::jsonb, 'name', 'بوت ' || i, 'bot', true));
    end if;
  end loop;
  update public.rooms set seats = r.seats, status = 'playing' where code = r.code;
end $$;

create or replace function public.finish_room(p_code text) returns void
language plpgsql security definer set search_path = public as $$
begin
  update public.rooms set status = 'finished' where code = upper(p_code) and host_id = auth.uid();
end $$;

grant execute on function public.create_room(text, int, int) to authenticated;
grant execute on function public.join_room(text, text) to authenticated;
grant execute on function public.leave_room(text) to authenticated;
grant execute on function public.set_seat_bot(text, int, boolean) to authenticated;
grant execute on function public.start_room(text) to authenticated;
grant execute on function public.finish_room(text) to authenticated;

-- ───────────── حذف الحساب (مطلوب من متاجر التطبيقات) ─────────────
create or replace function public.delete_account() returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  delete from auth.users where id = auth.uid();  -- يحذف غرفه ونتائجه تلقائياً (cascade)
end $$;
grant execute on function public.delete_account() to authenticated;

-- ───────────── تنظيف الغرف القديمة ─────────────
create or replace function public.cleanup_old_rooms() returns void
language sql security definer set search_path = public as $$
  delete from public.rooms where created_at < now() - interval '1 day';
$$;
-- جدولة يومية (فعّل امتداد pg_cron من Database → Extensions ثم أزل التعليق):
-- select cron.schedule('cleanup-rooms', '0 4 * * *', $$select public.cleanup_old_rooms()$$);

-- ───────────── اقتراح: فهرس لسرعة الإحصائيات ─────────────
create index if not exists game_results_user_idx on public.game_results (user_id, created_at desc);
