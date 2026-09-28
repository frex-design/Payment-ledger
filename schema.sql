-- 外注加工費 管理システム（フラット単一テーブル）
-- Supabase project: twolywmokxggjnugzuig（frex-design-infra's Project）
create table if not exists public.gaichu_kakouhi (
  id         uuid primary key default gen_random_uuid(),
  pay_month  text        not null,                 -- 支払い月 'YYYY-MM'
  vendor     text        not null,                 -- 外注会社名
  job_name   text        not null,                 -- 業務名
  amount     bigint      not null default 0,       -- 金額（円・税込）
  note       text,                                 -- 備考
  status     text        not null default 'unpaid',-- 'unpaid'（未払）| 'paid'（支払済）
  paid_at    date,                                 -- 支払完了日 'YYYY-MM-DD'（未払は null）
  created_at timestamptz not null default now()
);

-- 既存テーブルへの追加（後付けでも安全）
alter table public.gaichu_kakouhi add column if not exists status  text not null default 'unpaid';
alter table public.gaichu_kakouhi add column if not exists paid_at date;

create index if not exists idx_gaichu_month  on public.gaichu_kakouhi(pay_month);
create index if not exists idx_gaichu_vendor on public.gaichu_kakouhi(vendor);
create index if not exists idx_gaichu_status on public.gaichu_kakouhi(status);

-- RLS：有効 ＋ anon 全許可（anon直アクセス設計）
alter table public.gaichu_kakouhi enable row level security;
drop policy if exists "anon all gaichu_kakouhi" on public.gaichu_kakouhi;
create policy "anon all gaichu_kakouhi" on public.gaichu_kakouhi
  for all to anon using (true) with check (true);

grant usage on schema public to anon;
grant all on public.gaichu_kakouhi to anon;

notify pgrst, 'reload schema';
