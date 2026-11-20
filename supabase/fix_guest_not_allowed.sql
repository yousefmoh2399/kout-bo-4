-- ==============================================================================
-- تحديث قاعدة بيانات كوت بو ٤ لحل مشكلة guest_not_allowed وتمكين اللعب للجميع
-- انسخ هذا الكود بالكامل والصقه في Supabase → SQL Editor واضغط RUN
-- ==============================================================================

-- 1. دالة مزامنة بروفايل اللاعب (منح 500 نقطة ترحيبية للجميع وعدم حظر الضيوف)
create or replace function public.sync_profile(p_name text, p_is_guest boolean default false)
returns public.profiles
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_profile public.profiles;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  p_name := left(btrim(coalesce(p_name, '')), 24);
  if p_name = '' then p_name := 'لاعب'; end if;

  insert into public.profiles (id, name, is_guest, coins, updated_at)
  values (v_uid, p_name, coalesce(p_is_guest, false), 500, now())
  on conflict (id) do update
    set name = p_name,
        coins = coalesce(profiles.coins, 500),
        is_guest = case 
          when profiles.is_guest is false then false 
          else coalesce(p_is_guest, profiles.is_guest, false)
        end,
        updated_at = now()
  returning * into v_profile;

  -- تسجيل معاملة welcome_bonus عند منح 500 نقطة لأول مرة
  if not exists (
    select 1 from public.coin_transactions 
    where user_id = v_uid and type = 'welcome_bonus'
  ) and v_profile.coins >= 500 then
    insert into public.coin_transactions (user_id, amount, type, balance_after, description)
    values (v_uid, 500, 'welcome_bonus', v_profile.coins, 'مكافأة التسجيل والترحيب باللاعب');
  end if;

  return v_profile;
end $$;

-- 2. دالة إنشاء الغرفة (إزالة حظر الضيوف نهائياً)
create or replace function public.create_room_with_stake(
  p_name text, 
  p_target int, 
  p_turn int, 
  p_stake int default 0
) returns text
language plpgsql security definer set search_path = public as $$
declare
  v_code text;
  v_uid uuid := auth.uid();
  v_balance bigint;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_target not in (51, 101) or p_turn < 0 or p_turn > 120 then raise exception 'bad_settings'; end if;
  if p_stake not in (0, 100, 250, 500, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000) then raise exception 'bad_stake'; end if;

  p_name := left(btrim(coalesce(p_name, '')), 16);
  if p_name = '' then p_name := 'لاعب'; end if;

  -- مزامنة البروفايل
  perform public.sync_profile(p_name, false);

  -- التحقق من رصيد اللاعب
  select coins into v_balance from public.profiles where id = v_uid for update;
  if p_stake > 0 and (v_balance is null or v_balance < p_stake) then
    raise exception 'insufficient_coins';
  end if;

  -- استرداد أي غرف سابقة لم تبدأ كان المضيف فيها
  perform public.refund_room_stakes_for_user(v_uid);
  delete from public.rooms where host_id = v_uid;

  v_code := public._gen_room_code();

  -- إدراج الغرفة
  insert into public.rooms (code, host_id, target_score, turn_seconds, stake_points, seats)
  values (
    v_code, v_uid, p_target, p_turn, p_stake,
    jsonb_set('[null,null,null,null]'::jsonb, '{0}', jsonb_build_object('id', v_uid, 'name', p_name, 'bot', false))
  );

  -- خصم النقاط من المضيف إذا كانت الغرفة بنقاط
  if p_stake > 0 then
    update public.profiles set coins = coins - p_stake where id = v_uid;
    insert into public.coin_transactions (user_id, amount, type, room_code, balance_after, description)
    values (v_uid, -p_stake, 'room_entry', v_code, v_balance - p_stake, 'رسم إنشاء غرفة بنقاط ' || p_stake);
  end if;

  return v_code;
end $$;

-- 3. دالة الانضمام للغرفة (إزالة حظر الضيوف نهائياً)
create or replace function public.join_room_with_stake(p_code text, p_name text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  r public.rooms;
  v_uid uuid := auth.uid();
  v_seat int := null;
  v_order int[] := array[2, 1, 3];
  i int;
  v_balance bigint;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  p_name := left(btrim(coalesce(p_name, '')), 16);
  if p_name = '' then p_name := 'لاعب'; end if;

  -- مزامنة البروفايل
  perform public.sync_profile(p_name, false);

  select * into r from public.rooms where code = upper(p_code) for update;
  if r.code is null then raise exception 'room_not_found'; end if;
  if r.status <> 'waiting' then raise exception 'room_not_waiting'; end if;

  -- إذا كان اللاعب موجوداً مسبقاً في الغرفة
  for i in 0..3 loop
    if (r.seats->i->>'id') = v_uid::text then
      return to_jsonb(r);
    end if;
  end loop;

  -- البحث عن مقعد فارغ
  foreach i in array v_order loop
    if r.seats->i is null or r.seats->i = 'null'::jsonb or coalesce((r.seats->i->>'bot')::boolean, false) then
      v_seat := i;
      exit;
    end if;
  end loop;
  if v_seat is null then raise exception 'room_full'; end if;

  -- التحقق من رصيد اللاعب وخصم رسم الدخول
  if r.stake_points > 0 then
    select coins into v_balance from public.profiles where id = v_uid for update;
    if v_balance is null or v_balance < r.stake_points then
      raise exception 'insufficient_coins';
    end if;

    update public.profiles set coins = coins - r.stake_points where id = v_uid;
    insert into public.coin_transactions (user_id, amount, type, room_code, balance_after, description)
    values (v_uid, -r.stake_points, 'room_entry', r.code, v_balance - r.stake_points, 'رسم دخول غرفة ' || r.code);
  end if;

  -- الجلوس في المقعد وتحديث الغرفة
  r.seats := jsonb_set(r.seats, array[v_seat::text], jsonb_build_object('id', v_uid, 'name', p_name, 'bot', false));
  update public.rooms set seats = r.seats where code = r.code;

  return to_jsonb(r);
end $$;

-- 4. دالة تمديد الوقت (إزالة حظر الضيوف نهائياً)
create or replace function public.extend_room_time(p_room_code text, p_minutes int) returns bigint
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_cost bigint;
  v_balance bigint;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_minutes <= 0 then raise exception 'invalid_minutes'; end if;

  -- حساب التكلفة: كل 20 دقيقة = 500 نقطة
  v_cost := ((p_minutes + 19) / 20) * 500;

  select coins into v_balance from public.profiles where id = v_uid for update;
  if v_balance is null or v_balance < v_cost then
    raise exception 'insufficient_coins';
  end if;

  update public.profiles 
  set coins = coins - v_cost, updated_at = now()
  where id = v_uid
  returning coins into v_balance;

  insert into public.coin_transactions (user_id, amount, type, room_code, balance_after, description)
  values (v_uid, -v_cost, 'room_extend_time', upper(coalesce(p_room_code, '')), v_balance, 'تمديد وقت الغرفة ' || p_minutes || ' دقيقة');

  return v_balance;
end $$;
