-- ==============================================================================
-- سكيما قاعدة بيانات كوت بو ٤ (Supabase Database Schema)
-- شغّل هذا الملف كاملاً في Supabase → SQL Editor (مرة واحدة).
-- ==============================================================================

-- 1. جدول الملف الشخصي للاعبين (Profiles)
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  name          text not null default 'لاعب',
  is_guest      boolean not null default true,
  games_played  int not null default 0,
  wins          int not null default 0,
  losses        int not null default 0,
  total_points  int not null default 0,
  highest_bid   int not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- 2. جدول الغرف (Rooms)
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

-- 3. جدول نتائج المباريات (Game Results)
create table if not exists public.game_results (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  player_name      text not null default 'لاعب',
  room_code        text,
  game_mode        text not null default 'solo' check (game_mode in ('solo', 'online')),
  won              boolean not null,
  score_us         int not null,
  score_them       int not null,
  duration_seconds int not null default 0,
  rounds           int not null default 1,
  created_at       timestamptz not null default now()
);

-- 4. جدول تفاصيل الجولات لكل مباراة (Game Round Logs)
create table if not exists public.game_round_logs (
  id             uuid primary key default gen_random_uuid(),
  game_result_id uuid references public.game_results(id) on delete cascade,
  user_id        uuid not null references auth.users(id) on delete cascade,
  round_number   int not null default 1,
  bid            int not null default 5,
  trump          text,
  bidder_team    int not null default 0,
  scoring_team   int not null default 0,
  points         int not null default 0,
  success        boolean not null default true,
  created_at     timestamptz not null default now()
);

-- ───────────────────────────── تفعيل الأمان (RLS) ─────────────────────────────
alter table public.profiles enable row level security;
alter table public.rooms enable row level security;
alter table public.game_results enable row level security;
alter table public.game_round_logs enable row level security;

-- سياسات البروفايل (Profiles)
drop policy if exists "profiles readable by all authenticated" on public.profiles;
create policy "profiles readable by all authenticated" on public.profiles
  for select to authenticated using (true);

drop policy if exists "profiles insert own" on public.profiles;
create policy "profiles insert own" on public.profiles
  for insert to authenticated with check (id = auth.uid());

drop policy if exists "profiles update own" on public.profiles;
create policy "profiles update own" on public.profiles
  for update to authenticated using (id = auth.uid());

-- سياسات الغرف (Rooms)
drop policy if exists "rooms readable" on public.rooms;
create policy "rooms readable" on public.rooms
  for select to authenticated using (true);

-- سياسات نتائج المباريات (Game Results)
drop policy if exists "results select all authenticated" on public.game_results;
create policy "results select all authenticated" on public.game_results
  for select to authenticated using (true);

drop policy if exists "results insert own" on public.game_results;
create policy "results insert own" on public.game_results
  for insert to authenticated with check (user_id = auth.uid());

-- سياسات الجولات (Round Logs)
drop policy if exists "round logs select own" on public.game_round_logs;
create policy "round logs select own" on public.game_round_logs
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "round logs insert own" on public.game_round_logs;
create policy "round logs insert own" on public.game_round_logs
  for insert to authenticated with check (user_id = auth.uid());

-- ───────────────────────────── Realtime ─────────────────────────────
do $$ begin
  alter publication supabase_realtime add table public.rooms;
exception when duplicate_object then null; end $$;

do $$ begin
  alter publication supabase_realtime add table public.profiles;
exception when duplicate_object then null; end $$;

-- ───────────────────── فيو المتصدرين (Leaderboard View) ─────────────────────
create or replace view public.leaderboard as
select
  id as user_id,
  name,
  is_guest,
  games_played,
  wins,
  losses,
  case when games_played > 0
       then round((wins::numeric / games_played::numeric) * 100)
       else 0
  end as win_rate,
  total_points,
  created_at
from public.profiles
where games_played > 0
order by wins desc, total_points desc
limit 50;

-- ───────────────────── دوال البروفايل والتحديث التلقائي ─────────────────────

-- مزامنة أو إنشاء بروفايل اللاعب
create or replace function public.sync_profile(p_name text, p_is_guest boolean default true)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  p_name := left(btrim(coalesce(p_name, '')), 24);
  if p_name = '' then p_name := 'لاعب'; end if;

  insert into public.profiles (id, name, is_guest, updated_at)
  values (v_uid, p_name, p_is_guest, now())
  on conflict (id) do update
    set name = p_name,
        is_guest = p_is_guest,
        updated_at = now()
  returning * into v_profile;

  return v_profile;
end $$;

-- تحديث البروفايل تلقائياً عند حفظ نتيجة أي مباراة في الداتا بيز
create or replace function public._on_game_result_insert()
returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name, is_guest, games_played, wins, losses, total_points, updated_at)
  values (
    new.user_id,
    new.player_name,
    true,
    1,
    case when new.won then 1 else 0 end,
    case when new.won then 0 else 1 end,
    new.score_us,
    now()
  )
  on conflict (id) do update
    set games_played = public.profiles.games_played + 1,
        wins = public.profiles.wins + (case when new.won then 1 else 0 end),
        losses = public.profiles.losses + (case when new.won then 0 else 1 end),
        total_points = public.profiles.total_points + new.score_us,
        updated_at = now();
  return new;
end $$;

drop trigger if exists trg_game_result_insert on public.game_results;
create trigger trg_game_result_insert
  after insert on public.game_results
  for each row execute function public._on_game_result_insert();

-- ───────────── دوال الغرف (Rooms RPCs) ─────────────

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

  delete from public.rooms where host_id = v_uid;
  v_code := public._gen_room_code();
  insert into public.rooms (code, host_id, target_score, turn_seconds, seats)
  values (
    v_code, v_uid, p_target, p_turn,
    jsonb_set('[null,null,null,null]'::jsonb, '{0}', jsonb_build_object('id', v_uid, 'name', p_name, 'bot', false))
  );

  -- تأكيد وجود البروفايل
  perform public.sync_profile(p_name);
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

  -- موجود بالفعل في الغرفة؟
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

  perform public.sync_profile(p_name);
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

-- ───────────── حذف الحساب ─────────────
create or replace function public.delete_account() returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  delete from auth.users where id = auth.uid();
end $$;

-- الصلاحيات
grant execute on function public.sync_profile(text, boolean) to authenticated;
grant execute on function public.create_room(text, int, int) to authenticated;
grant execute on function public.join_room(text, text) to authenticated;
grant execute on function public.leave_room(text) to authenticated;
grant execute on function public.set_seat_bot(text, int, boolean) to authenticated;
grant execute on function public.start_room(text) to authenticated;
grant execute on function public.finish_room(text) to authenticated;
grant execute on function public.delete_account() to authenticated;

-- الفهارس لسرعة الاستعلامات
create index if not exists game_results_user_idx on public.game_results (user_id, created_at desc);
create index if not exists game_round_logs_game_idx on public.game_round_logs (game_result_id);
create index if not exists profiles_wins_idx on public.profiles (wins desc, total_points desc);
