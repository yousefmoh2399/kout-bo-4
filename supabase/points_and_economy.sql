-- ==============================================================================
-- سكيما نظام النقاط واقتصاد الغرف لـ كوت بو ٤ (Points & Economy System)
-- شغّل هذا الملف كاملاً في Supabase → SQL Editor (مرة واحدة بالكامل).
-- ==============================================================================

-- 1. إضافة عمود رصيد النقاط (coins) إلى جدول الملفات الشخصية (الافتراضي 0 للضيوف، و500 للحساب المسجل)
alter table public.profiles 
  add column if not exists coins bigint not null default 0;

-- 2. إضافة عمود رسم دخول الغرفة (stake_points) إلى جدول الغرف
alter table public.rooms 
  add column if not exists stake_points int not null default 0 check (stake_points in (0, 100, 250, 500, 1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000));

-- 3. جدول سجل معاملات وحركات النقاط (Transactions History)
create table if not exists public.coin_transactions (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  amount      int not null, -- موجب للشحن والجوائز، سالب للرسوم
  type        text not null check (type in ('welcome_bonus', 'apple_purchase', 'myfatoorah_purchase', 'room_entry', 'room_win', 'room_refund', 'room_extend_time', 'admin_gift')),
  room_code   text, -- كود الغرفة (بدون قيد خارجي حتى يبقى كود الغرفة في السجل المالي دائماً)
  order_id    text, -- رقم طلب شراء أبل أو رقم فاتورة ماي فاتورة
  balance_after bigint not null,
  description text,
  created_at  timestamptz not null default now()
);

-- تحديث قيد النوع ليشمل ماي فاتورة وتمديد الوقت إن كان الجدول موجوداً مسبقاً
alter table if exists public.coin_transactions 
  drop constraint if exists coin_transactions_type_check;
alter table if exists public.coin_transactions 
  add constraint coin_transactions_type_check 
  check (type in ('welcome_bonus', 'apple_purchase', 'myfatoorah_purchase', 'room_entry', 'room_win', 'room_refund', 'room_extend_time', 'admin_gift'));

-- إزالة أي قيد خارجي سابق لـ room_code لمنع أي تعارض مفاتيح عند إنشاء الغرف
alter table if exists public.coin_transactions 
  drop constraint if exists coin_transactions_room_code_fkey;

-- تفعيل الأمان وسياسات القراءة لسجل المعاملات
alter table public.coin_transactions enable row level security;
drop policy if exists "users can read own transactions" on public.coin_transactions;
create policy "users can read own transactions" 
  on public.coin_transactions for select 
  using (auth.uid() = user_id);

-- ───────────────────────────── دوال الخصم والإضافة الذرية (RPC) ─────────────────────────────

-- أ. دالة استرداد النقاط في حال غادر لاعب أو أُلغيت الغرفة قبل بدئها
-- (تم وضعها أولاً لأن دوال إنشاء الغرف تعتمد عليها)
create or replace function public.refund_room_stakes_for_user(p_user_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare
  r record;
  v_bal bigint;
begin
  for r in 
    select ct.id as tx_id, ct.amount, ct.room_code 
    from public.coin_transactions ct
    join public.rooms rm on rm.code = ct.room_code
    where ct.user_id = p_user_id 
      and ct.type = 'room_entry' 
      and rm.status = 'waiting'
      and not exists (
        select 1 from public.coin_transactions ref
        where ref.user_id = p_user_id
          and ref.room_code = ct.room_code
          and ref.type = 'room_refund'
      )
  loop
    select coins into v_bal from public.profiles where id = p_user_id for update;
    update public.profiles set coins = coins + abs(r.amount) where id = p_user_id;
    insert into public.coin_transactions (user_id, amount, type, room_code, balance_after, description)
    values (p_user_id, abs(r.amount), 'room_refund', r.room_code, coalesce(v_bal, 0) + abs(r.amount), 'استرداد رسم الدخول لغرفة ملغاة');
  end loop;
end $$;

-- ب. دالة مزامنة وإنشاء بروفايل اللاعب (الجميع يبدأ بـ 500 نقطة ترحيبية = صكة أولى مجانية)
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

-- ج. دالة إنشاء غرفة مع رسم دخول (تنشئ الغرفة أولاً ثم تخصم الرصيد وتسجل المعاملة)
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

  -- التأكد من وجود بروفايل اللاعب ومزامنته
  perform public.sync_profile(p_name, false);

  -- التحقق من رصيد اللاعب
  select coins into v_balance from public.profiles where id = v_uid for update;
  if p_stake > 0 and (v_balance is null or v_balance < p_stake) then
    raise exception 'insufficient_coins';
  end if;
    raise exception 'insufficient_coins';
  end if;

  -- استرداد أي غرف سابقة لم تبدأ كان المضيف فيها
  perform public.refund_room_stakes_for_user(v_uid);
  delete from public.rooms where host_id = v_uid;

  v_code := public._gen_room_code();

  -- 1. إدراج الغرفة أولاً لضمان وجود كود الغرفة
  insert into public.rooms (code, host_id, target_score, turn_seconds, stake_points, seats)
  values (
    v_code, v_uid, p_target, p_turn, p_stake,
    jsonb_set('[null,null,null,null]'::jsonb, '{0}', jsonb_build_object('id', v_uid, 'name', p_name, 'bot', false))
  );

  -- 2. خصم النقاط من المضيف إذا كانت الغرفة برسم دخول وتسجيل المعاملة
  if p_stake > 0 then
    update public.profiles set coins = coins - p_stake where id = v_uid;
    insert into public.coin_transactions (user_id, amount, type, room_code, balance_after, description)
    values (v_uid, -p_stake, 'room_entry', v_code, v_balance - p_stake, 'رسم إنشاء غرفة بنقاط ' || p_stake);
  end if;

  return v_code;
end $$;

-- د. دالة الانضمام لغرفة مع خصم رسم الدخول من المنضم
create or replace function public.join_room_with_stake(p_code text, p_name text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  r public.rooms;
  v_uid uuid := auth.uid();
  v_seat int := null;
  v_order int[] := array[2, 1, 3];
  i int;
  v_balance bigint;
  v_is_guest boolean;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  p_name := left(btrim(coalesce(p_name, '')), 16);
  if p_name = '' then p_name := 'لاعب'; end if;

  -- التأكد من وجود بروفايل اللاعب ومزامنته
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

  -- إضافة اللاعب للمقعد
  r.seats := jsonb_set(r.seats, array[v_seat::text], jsonb_build_object('id', v_uid, 'name', p_name, 'bot', false));
  update public.rooms set seats = r.seats where code = r.code;

  perform public.sync_profile(p_name);
  return to_jsonb(r);
end $$;

-- د. دالة توزيع جائزة المباراة: تم إيقافها بالكامل لمنع أي رهانات أو أرباح على اللعب (لعب نظيف وبدون مراهنات)
create or replace function public.award_room_winnings(
  p_code text, 
  p_winning_team int -- 0: المقاعد (0, 2) | 1: المقاعد (1, 3)
) returns void
language plpgsql security definer set search_path = public as $$
begin
  -- تم إلغاء توزيع أي نقاط أو أرباح للفريق الفائز (النقاط هي رسم خدمة حجز الغرفة والوقت فقط ولا توجد أي مراهنات)
  return;
end $$;

-- هـ. دالة شحن النقاط عند الشراء من Apple In-App Purchase
create or replace function public.credit_apple_purchase(
  p_user_id uuid,
  p_coins int,
  p_order_id text,
  p_product_id text
) returns bigint
language plpgsql security definer set search_path = public as $$
declare
  v_new_balance bigint;
begin
  if p_user_id is null or p_coins <= 0 or p_order_id is null then
    raise exception 'invalid_parameters';
  end if;

  -- التأكد من وجود بروفايل اللاعب
  insert into public.profiles (id, name, is_guest, coins, updated_at)
  values (p_user_id, 'لاعب', true, 500, now())
  on conflict (id) do nothing;

  -- منع تكرار نفس المعاملة (Replay Protection)
  if exists (select 1 from public.coin_transactions where order_id = p_order_id) then
    select coins into v_new_balance from public.profiles where id = p_user_id;
    return coalesce(v_new_balance, 0);
  end if;

  update public.profiles 
  set coins = coalesce(coins, 0) + p_coins, updated_at = now()
  where id = p_user_id
  returning coins into v_new_balance;

  insert into public.coin_transactions (user_id, amount, type, order_id, balance_after, description)
  values (
    p_user_id, 
    p_coins, 
    'apple_purchase', 
    p_order_id, 
    coalesce(v_new_balance, p_coins), 
    'شراء عبر أبل: ' || coalesce(p_product_id, '')
  );

  return coalesce(v_new_balance, p_coins);
end $$;

-- و. دالة شحن النقاط عبر بوابة ماي فاتورة (MyFatoorah KNET / بطاقات الدفع)
create or replace function public.credit_myfatoorah_purchase(
  p_user_id uuid,
  p_coins int,
  p_invoice_id text,
  p_kwd_amount numeric,
  p_package_id text
) returns bigint
language plpgsql security definer set search_path = public as $$
declare
  v_new_balance bigint;
begin
  if p_user_id is null or p_coins <= 0 or p_invoice_id is null then
    raise exception 'invalid_parameters';
  end if;

  -- التأكد من وجود بروفايل اللاعب
  insert into public.profiles (id, name, is_guest, coins, updated_at)
  values (p_user_id, 'لاعب', true, 500, now())
  on conflict (id) do nothing;

  -- منع تكرار شحن نفس الفاتورة (Replay Protection)
  if exists (select 1 from public.coin_transactions where order_id = p_invoice_id) then
    select coins into v_new_balance from public.profiles where id = p_user_id;
    return coalesce(v_new_balance, 0);
  end if;

  update public.profiles 
  set coins = coalesce(coins, 0) + p_coins, updated_at = now()
  where id = p_user_id
  returning coins into v_new_balance;

  insert into public.coin_transactions (user_id, amount, type, order_id, balance_after, description)
  values (
    p_user_id, 
    p_coins, 
    'myfatoorah_purchase', 
    p_invoice_id, 
    coalesce(v_new_balance, p_coins), 
    'شحن ماي فاتورة (' || coalesce(p_kwd_amount::text, '') || ' د.ك): ' || coalesce(p_package_id, '')
  );

  return coalesce(v_new_balance, p_coins);
end $$;

-- و. دالة مغادرة الغرفة مع استرداد النقاط في حال كانت الغرفة قيد الانتظار
create or replace function public.leave_room(p_code text) returns void
language plpgsql security definer set search_path = public as $$
declare
  r public.rooms;
  v_uid uuid := auth.uid();
  i int;
  v_seat_uid uuid;
  v_bal bigint;
begin
  select * into r from public.rooms where code = upper(p_code) for update;
  if not found then return; end if;

  -- إذا غادر المضيف
  if r.host_id = v_uid then
    -- إذا كانت الغرفة في وضع الانتظار (لم تبدأ بعد)، نسترد الرسوم لجميع اللاعبين
    if r.status = 'waiting' and r.stake_points > 0 then
      for i in 0..3 loop
        v_seat_uid := (r.seats->i->>'id')::uuid;
        if v_seat_uid is not null and not coalesce((r.seats->i->>'bot')::boolean, false) then
          select coins into v_bal from public.profiles where id = v_seat_uid for update;
          update public.profiles set coins = coins + r.stake_points where id = v_seat_uid;
          insert into public.coin_transactions (user_id, amount, type, room_code, balance_after, description)
          values (v_seat_uid, r.stake_points, 'room_refund', r.code, coalesce(v_bal, 0) + r.stake_points, 'استرداد رسم إلغاء الغرفة ' || r.code);
        end if;
      end loop;
    end if;

    delete from public.rooms where code = r.code;
    return;
  end if;

  -- إذا غادر لاعب عادي (غير المضيف)
  for i in 1..3 loop
    if (r.seats -> i ->> 'id') = v_uid::text then
      -- إذا كانت الغرفة في وضع الانتظار، استرداد رسوم هذا اللاعب
      if r.status = 'waiting' and r.stake_points > 0 then
        select coins into v_bal from public.profiles where id = v_uid for update;
        update public.profiles set coins = coins + r.stake_points where id = v_uid;
        insert into public.coin_transactions (user_id, amount, type, room_code, balance_after, description)
        values (v_uid, r.stake_points, 'room_refund', r.code, coalesce(v_bal, 0) + r.stake_points, 'استرداد رسم مغادرة الغرفة ' || r.code);
      end if;

      update public.rooms set seats = jsonb_set(seats, array[i::text], 'null'::jsonb) where code = r.code;
    end if;
  end loop;
end $$;

-- ز. دالة تغيير المقعد للاعب داخل الغرفة قبل بدئها
create or replace function public.switch_seat(p_code text, p_target_seat int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  r public.rooms;
  v_uid uuid := auth.uid();
  v_curr_seat int := null;
  v_player_data jsonb;
  i int;
begin
  if v_uid is null then raise exception 'not_authenticated'; end if;
  if p_target_seat < 0 or p_target_seat > 3 then raise exception 'bad_seat'; end if;

  select * into r from public.rooms where code = upper(p_code) for update;
  if r.code is null then raise exception 'room_not_found'; end if;
  if r.status <> 'waiting' then raise exception 'room_not_waiting'; end if;

  -- العثور على مقعد اللاعب الحالي
  for i in 0..3 loop
    if (r.seats->i->>'id') = v_uid::text then
      v_curr_seat := i;
      v_player_data := r.seats->i;
      exit;
    end if;
  end loop;

  if v_curr_seat is null then raise exception 'not_in_room'; end if;
  if v_curr_seat = p_target_seat then return to_jsonb(r); end if;

  -- التأكد من أن المقعد الهدف فارغ أو به بوت
  if r.seats->p_target_seat is not null 
     and r.seats->p_target_seat <> 'null'::jsonb 
     and not coalesce((r.seats->p_target_seat->>'bot')::boolean, false) then
    raise exception 'seat_occupied';
  end if;

  -- نقل اللاعب: تفريغ المقعد القديم ووضع اللاعب في المقعد الجديد
  r.seats := jsonb_set(r.seats, array[v_curr_seat::text], 'null'::jsonb);
  r.seats := jsonb_set(r.seats, array[p_target_seat::text], v_player_data);

  update public.rooms set seats = r.seats where code = r.code;
  return to_jsonb(r);
end $$;

-- ح. دالة تمديد وقت الغرفة وخصم النقاط من الممدد (كل ٢٠ دقيقة = ٥٠٠ نقطة)
create or replace function public.extend_room_time(
  p_room_code text,
  p_minutes int default 20
) returns bigint
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  v_cost int;
  v_balance bigint;
  v_is_guest boolean;
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

-- ───────────────────────────── الصلاحيات (Grants) ─────────────────────────────
grant execute on function public.sync_profile(text, boolean) to authenticated;
grant execute on function public.refund_room_stakes_for_user(uuid) to authenticated;
grant execute on function public.create_room_with_stake(text, int, int, int) to authenticated;
grant execute on function public.join_room_with_stake(text, text) to authenticated;
grant execute on function public.award_room_winnings(text, int) to authenticated;
grant execute on function public.leave_room(text) to authenticated;
grant execute on function public.switch_seat(text, int) to authenticated;
grant execute on function public.extend_room_time(text, int) to authenticated;
grant execute on function public.credit_myfatoorah_purchase(uuid, int, text, numeric, text) to authenticated, anon;
grant execute on function public.credit_apple_purchase(uuid, int, text, text) to authenticated, anon;
