-- WriteAI: ユーザープロファイルテーブル
-- Supabase SQL Editor で実行してください

create table if not exists public.user_profiles (
  user_id       uuid primary key references auth.users(id) on delete cascade,
  genre         text not null default 'real_estate',
  content_types text[] not null default '{}',
  display_name  text default '',
  company_name  text default '',
  tone          text not null default 'formal',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- RLS 有効化（自分のデータしか読み書きできない）
alter table public.user_profiles enable row level security;

create policy "自分のプロファイルのみ参照可能"
  on public.user_profiles for select
  using (auth.uid() = user_id);

create policy "自分のプロファイルのみ作成可能"
  on public.user_profiles for insert
  with check (auth.uid() = user_id);

create policy "自分のプロファイルのみ更新可能"
  on public.user_profiles for update
  using (auth.uid() = user_id);
