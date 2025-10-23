# 6) Data Model (SQL — Supabase/Postgres)

```sql
-- Users & profile
create table users (
  user_id uuid primary key,
  email text unique,
  created_at timestamptz default now()
);

create table user_profile (
  user_id uuid primary key references users(user_id) on delete cascade,
  dialect text default 'lebanese',
  difficulty text default 'beginner',
  translit_style jsonb default '{}'  -- e.g., {"h": "7", "ain": "3"}
);

-- Lessons (generated content)
create table lessons (
  lesson_id uuid primary key,
  topic text,
  level text,
  en_text text not null,
  la_text text not null,           -- transliterated Lebanese Arabic
  meta jsonb,                      -- seed, constraints
  created_at timestamptz default now(),
  unique(topic, en_text)           -- dedupe cache hint
);

-- Quizzes (per lesson)
create table quizzes (
  quiz_id uuid primary key,
  lesson_id uuid references lessons(lesson_id) on delete cascade,
  questions jsonb not null,        -- typed schema (see API)
  answer_key jsonb not null,
  created_at timestamptz default now()
);

-- User attempts & evaluations
create table attempts (
  attempt_id uuid primary key,
  user_id uuid references users(user_id) on delete cascade,
  lesson_id uuid references lessons(lesson_id) on delete cascade,
  quiz_id uuid references quizzes(quiz_id) on delete cascade,
  responses jsonb not null,
  score numeric,                   -- 0..1
  eval jsonb,                      -- model feedback per question
  created_at timestamptz default now()
);

-- Error log (normalized from eval)
create table errors (
  error_id uuid primary key,
  user_id uuid references users(user_id) on delete cascade,
  lesson_id uuid,
  quiz_id uuid,
  q_index int,
  error_type text,                 -- taxonomy
  token text,                      -- offending token/word
  details jsonb,
  created_at timestamptz default now()
);

-- Aggregated study guide
create table study_guides (
  user_id uuid primary key references users(user_id) on delete cascade,
  snapshot jsonb not null,         -- categories → examples → tips
  updated_at timestamptz default now()
);

-- Progress snapshots
create table progress (
  user_id uuid references users(user_id) on delete cascade,
  period date,
  metrics jsonb,                   -- accuracy, time_spent, error_breakdown
  primary key (user_id, period)
);
```

**Indexes**
- `errors(user_id, created_at)`
- `attempts(user_id, created_at)`
- `lessons(topic, level)`

---
