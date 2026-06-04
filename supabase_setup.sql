-- ═══════════════════════════════════════════════════════════════
--  Termination Checklist — Supabase Database Setup
--  Run this in: Supabase Dashboard → SQL Editor → New Query → Run
-- ═══════════════════════════════════════════════════════════════


-- 1. CHECKLISTS TABLE
-- ───────────────────
create table if not exists public.checklists (
  id                     uuid         default gen_random_uuid() primary key,
  case_id                text         not null,
  employee               jsonb        default '{}'::jsonb,       -- form fields (name, dept, etc.)
  checks                 jsonb        default '{}'::jsonb,       -- all 53 item states + timestamps + notes
  completed_by           jsonb        default '{}'::jsonb,       -- HR/Manager/IT sign-off names
  progress               jsonb        default '{}'::jsonb,       -- {pct, done, total, hr:{}, mgr:{}, it:{}}
  status                 text         not null default 'pending'
                                      check (status in ('pending', 'complete')),
  created_at             timestamptz  not null default now(),
  updated_at             timestamptz  not null default now(),
  created_by             uuid         references auth.users(id) on delete set null,
  created_by_email       text,
  last_modified_by_email text
);


-- 2. ROW LEVEL SECURITY
-- ──────────────────────
-- All authenticated users (IT, HR, Managers) share full read/write access.
-- The anon role gets nothing — unauthenticated requests are rejected.
alter table public.checklists enable row level security;

create policy "auth_select" on public.checklists
  for select to authenticated using (true);

create policy "auth_insert" on public.checklists
  for insert to authenticated with check (true);

create policy "auth_update" on public.checklists
  for update to authenticated using (true);

create policy "auth_delete" on public.checklists
  for delete to authenticated using (true);


-- 3. AUTO-UPDATE updated_at ON EVERY SAVE
-- ─────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists checklists_set_updated_at on public.checklists;

create trigger checklists_set_updated_at
  before update on public.checklists
  for each row execute function public.set_updated_at();


-- ═══════════════════════════════════════════════════════════════
--  SETUP CHECKLIST (do these after running the SQL above)
-- ═══════════════════════════════════════════════════════════════
--
--  STEP 1 — Create user accounts
--    Authentication → Users → Add user
--    Create one account per IT/HR/Manager staff member.
--
--    Tip: Disable mandatory email confirmation for easier setup:
--    Authentication → Providers → Email → toggle off "Confirm email"
--    (Re-enable for production if you want verified addresses)
--
--  STEP 2 — Set the redirect URL for password reset emails
--    Authentication → URL Configuration → Redirect URLs → Add URL
--    Add your GitHub Pages URL, e.g.:
--      https://your-org.github.io/termination-checklist/
--    Without this, password reset links will not work.
--
--  STEP 3 — Get your API credentials
--    Settings → API
--    Copy "Project URL" and "anon public" key.
--    Paste them into index.html:
--      const SUPABASE_URL      = 'https://xxxx.supabase.co';
--      const SUPABASE_ANON_KEY = 'eyJhbGci...';
--
--  STEP 4 — Deploy to GitHub Pages
--    Commit index.html to your repo.
--    Settings → Pages → Source: Deploy from branch (main / root or /docs)
--    Your app will be live at:
--      https://your-org.github.io/repo-name/
--
-- ═══════════════════════════════════════════════════════════════
--  OPTIONAL: Verify everything is wired up correctly
-- ═══════════════════════════════════════════════════════════════
--
--  After logging in and creating a test checklist, run this to
--  confirm data is reaching the database:
--
--    select id, case_id, status, created_by_email, updated_at
--    from public.checklists
--    order by created_at desc
--    limit 10;
--
-- ═══════════════════════════════════════════════════════════════
