-- SRP Warranty setup for existing tables. Review before running.
-- Public clients can only call the constrained RPC functions.
-- Customer PII remains readable only to users in admin_users.

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create unique index if not exists serial_numbers_serial_number_unique
  on public.serial_numbers (upper(serial_number));
create unique index if not exists warranty_registrations_serial_id_unique
  on public.warranty_registrations (serial_id);

alter table public.products enable row level security;
alter table public.serial_numbers enable row level security;
alter table public.warranty_registrations enable row level security;
alter table public.admin_users enable row level security;

drop policy if exists "admin read products" on public.products;
create policy "admin read products" on public.products for select to authenticated
using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));
drop policy if exists "admin insert products" on public.products;
create policy "admin insert products" on public.products for insert to authenticated
with check (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));
drop policy if exists "admin update products" on public.products;
create policy "admin update products" on public.products for update to authenticated
using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()))
with check (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));

drop policy if exists "admin read serial numbers" on public.serial_numbers;
create policy "admin read serial numbers" on public.serial_numbers for select to authenticated
using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));
drop policy if exists "admin insert serial numbers" on public.serial_numbers;
create policy "admin insert serial numbers" on public.serial_numbers for insert to authenticated
with check (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));
drop policy if exists "admin update serial numbers" on public.serial_numbers;
create policy "admin update serial numbers" on public.serial_numbers for update to authenticated
using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()))
with check (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));

drop policy if exists "admin read warranty registrations" on public.warranty_registrations;
create policy "admin read warranty registrations" on public.warranty_registrations for select to authenticated
using (exists (select 1 from public.admin_users a where a.user_id = auth.uid()));

drop policy if exists "admin read own admin row" on public.admin_users;
create policy "admin read own admin row" on public.admin_users for select to authenticated
using (user_id = auth.uid());

create or replace function public.srp_register_warranty(
  p_serial_number text, p_customer_name text, p_phone text, p_email text, p_purchase_date date
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_serial public.serial_numbers%rowtype;
  v_product public.products%rowtype;
  v_registration_id bigint;
  v_end date;
begin
  if nullif(trim(p_serial_number), '') is null or nullif(trim(p_customer_name), '') is null
     or nullif(trim(p_phone), '') is null or p_purchase_date is null then
    return jsonb_build_object('success', false, 'message', 'missing required fields');
  end if;
  if p_purchase_date > current_date then
    return jsonb_build_object('success', false, 'message', 'purchase date cannot be in the future');
  end if;
  select * into v_serial from public.serial_numbers where upper(serial_number) = upper(trim(p_serial_number)) limit 1;
  if not found then return jsonb_build_object('success', false, 'message', 'invalid serial not found'); end if;
  select * into v_product from public.products where id = v_serial.product_id;
  if not found then return jsonb_build_object('success', false, 'message', 'product not found'); end if;
  if exists (select 1 from public.warranty_registrations where serial_id = v_serial.id) then
    return jsonb_build_object('success', false, 'message', 'serial already registered');
  end if;
  insert into public.warranty_registrations (serial_id, customer_name, phone, email, purchase_date)
  values (v_serial.id, trim(p_customer_name), trim(p_phone), nullif(trim(p_email), ''), p_purchase_date)
  returning id into v_registration_id;
  v_end := (p_purchase_date + make_interval(months => greatest(v_product.warranty_months, 0)))::date;
  return jsonb_build_object('success', true, 'registration_id', v_registration_id,
    'serial_number', v_serial.serial_number, 'product_name', v_product.name,
    'model', v_product.model, 'warranty_end', v_end);
exception when unique_violation then
  return jsonb_build_object('success', false, 'message', 'serial already registered');
end;
$$;

create or replace function public.srp_check_warranty(p_serial_number text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_serial public.serial_numbers%rowtype;
  v_product public.products%rowtype;
  v_reg public.warranty_registrations%rowtype;
  v_end date;
begin
  select * into v_serial from public.serial_numbers where upper(serial_number) = upper(trim(p_serial_number)) limit 1;
  if not found then return jsonb_build_object('found', false); end if;
  select * into v_product from public.products where id = v_serial.product_id;
  if not found then return jsonb_build_object('found', false); end if;
  select * into v_reg from public.warranty_registrations where serial_id = v_serial.id limit 1;
  if not found then
    return jsonb_build_object('found', true, 'registered', false, 'serial_number', v_serial.serial_number,
      'product_name', v_product.name, 'model', v_product.model, 'warranty_months', v_product.warranty_months);
  end if;
  v_end := (v_reg.purchase_date + make_interval(months => greatest(v_product.warranty_months, 0)))::date;
  return jsonb_build_object('found', true, 'registered', true, 'serial_number', v_serial.serial_number,
    'product_name', v_product.name, 'model', v_product.model, 'warranty_months', v_product.warranty_months,
    'purchase_date', v_reg.purchase_date, 'warranty_end', v_end, 'active', v_end >= current_date);
end;
$$;

revoke all on function public.srp_register_warranty(text,text,text,text,date) from public;
revoke all on function public.srp_check_warranty(text) from public;
grant execute on function public.srp_register_warranty(text,text,text,text,date) to anon, authenticated;
grant execute on function public.srp_check_warranty(text) to anon, authenticated;
grant usage on schema public to anon, authenticated;
grant select, insert, update on public.products to authenticated;
grant select, insert, update on public.serial_numbers to authenticated;
grant select on public.warranty_registrations to authenticated;
grant select on public.admin_users to authenticated;
