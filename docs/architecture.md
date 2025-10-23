# Architecture — Lebanese Arabic Translator & Practice Tool
**Owner:** Winston (🏗️ Architect, BMAD Method)  
**Date:** 2025-10-22  
**Status:** Draft → Review → Finalize after V1 spike

---

## 1) Goals & Constraints

### Primary Goals
- Deliver a **non-gamified**, context-driven learning loop: read → translate toggle → test → feedback → progress.
- Guarantee **fast UI interactions** (toggle < 200ms, cached lesson loads).
- Provide **adaptive study guidance** based on error history.
- Keep platform **iOS-first** (Flutter), with portable architecture for Android later.

### Non-Goals (V1)
- Native Arabic script rendering (transliteration only).
- Speech/pronunciation scoring (planned V3).
- Community content pipeline (planned V3).

### Key Constraints
- Cost control (cache + pregen).
- Privacy (PII minimal; region-aware storage).
- Vendor portability (Claude/OpenAI switchable).

---

## 2) High-Level System Overview

```
+---------------------+            HTTPS/JSON             +-------------------------+
|  Flutter iOS App    |  <-------------------------------->  FastAPI Backend (REST) |
|---------------------|                                     |-------------------------|
|  - Lesson Reader    | requests stories/quizzes            |  - /story  /quiz        |
|  - Toggle EN↔LA     | submits answers for eval            |  - /evaluate            |
|  - Test Mode UI     | fetches study guides & progress     |  - /study-guide         |
|  - Progress Charts  | downloads audio (V2)                |  - /progress  /audio    |
+---------------------+                                     +-------------------------+
                                                               |           |           |
                                                               |           |           |
                                                         +-----v----+  +---v-----+  +------------------+
                                                         |  AI LLM  |  |  DB     |  |  Object Storage  |
                                                         | Gateway  |  | (SQL)   |  |  (audio/json)    |
                                                         | (Claude/ |  |         |  |                  |
                                                         |  OpenAI) |  | Supabase|  |  Supabase/S3/GCS |
                                                         +----------+  +---------+  +------------------+
```

**Principles**
- **Separation of Concerns**: UI, API, AI orchestration, data each isolated.
- **Phase-based scaling**: simple now; incrementally add services (V2/V3).
- **LLM duality**: creative gen (Claude) vs evaluative tasks (OpenAI) to control cost/quality.

---

## 3) Frontend (Flutter, iOS-first)

### Tech & Structure
- **Flutter** (Dart), **Cupertino** look & feel.
- State management: **Riverpod** (or Bloc).
- HTTP client: **dio** with interceptors (auth, retry, backoff).
- Local persistence: **Hive** or **SQLite (sqflite)** for:
  - Last N lessons (content + quiz)
  - Last answers and error highlights
  - User prefs (dialect, difficulty, transliteration flavor)

### Core Screens
1. **Home / Today’s Lesson**
   - Contextual English text
   - **Toggle**: English ↔ transliterated Lebanese Arabic (no layout shift).
2. **Test Mode**
   - 3–6 questions (mix of MCQ, short-text, translation).
   - Inline feedback.
3. **Progress**
   - Accuracy over time, error categories, time-on-task.
4. **History**
   - Replay lesson with user’s previous answers & explanations.
5. **Settings**
   - Difficulty, topical interests, transliteration style (e.g., “shou/shu”, “7/aa” variants).

### UX Guarantees
- Toggle latency: < **200 ms** (pre-render both texts, cached).
- Offline mode (V2): full read/test for cached lessons, queued sync.

---

## 4) Backend (FastAPI)

### Services (app modules)
- `ai_controller.py` — Orchestrates LLM calls (story, transliteration, quiz).
- `evaluation_service.py` — Hybrid error detection (regex heuristics + LLM judge).
- `study_guide_service.py` — Aggregates errors → recommends targeted review.
- `progress_service.py` — Summaries, trends, KPIs.
- `auth_controller.py` — Supabase/Firebase JWT validation.
- `audio_service.py` — TTS URL retrieval (V2).

### Cross-cutting
- **Caching**: Redis or Supabase KV (if available) for:
  - Prompt→completion cache (story/quiz)
  - Study guide snapshots
- **Background jobs** (V2):
  - Celery/RQ/Arq (async) for pre-generation of next lessons & weekly aggregation.
- **Observability**:
  - Structured logging (JSON), request IDs
  - Prometheus/OpenTelemetry exporters (latency, error rate, LLM usage)

---

## 5) AI Integration Layer

### Routing Policy
- **Claude** (creative): scenario prose with cultural nuance; transliteration first pass via system prompt rules.
- **OpenAI** (evaluative): question set templating, response grading, error classification; TTS in V2 (or ElevenLabs).

### Prompting Strategy (summaries)
- **Story Prompt**: topic, level, target vocab; constraints on length & register.
- **Transliteration Guard**: enforce Latin mapping (e.g., `7` for ح, `3` for ع); forbid Arabic script.
- **Quiz Prompt**: derive 3–6 questions with answer key & rationales; specify JSON schema.
- **Evaluation Prompt**: classify mistakes into taxonomy; return structured JSON.

### Error Taxonomy (V1)
- `EN_IN_AR`: English word used where Arabic transliteration expected
- `SPELL_T`: transliteration misspelling (e.g., “shou” vs “shu”)
- `GRAMMAR`: tense/word order off (keep minimal in V1)
- `VOCAB`: incorrect word choice (mild)
- `OMISSION/EXTRA`: missing/added words changing meaning

---

## 6) Data Model (SQL — Supabase/Postgres)

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

## 7) API Contract (V1)

### POST `/api/v1/story`
**Req**
```json
{ "topic": "coffee_chat", "level": "beginner", "seed": 42 }
```
**Res**
```json
{
  "lesson_id": "uuid",
  "en_text": "Hey, want to grab coffee?",
  "la_text": "ahlan, baddak nrou7 neeshrab ahwe?",
  "meta": { "topic": "coffee_chat", "level": "beginner" }
}
```

### POST `/api/v1/quiz`
**Req**
```json
{ "lesson_id": "uuid" }
```
**Res**
```json
{
  "quiz_id": "uuid",
  "questions": [
    { "type": "mcq", "q": "What does 'ahwe' mean?", "choices": ["tea","coffee","juice"], "answer": 1 },
    { "type": "translate", "q": "Translate to LA: 'How are you?'", "answer": "kifak?" }
  ]
}
```

### POST `/api/v1/evaluate`
**Req**
```json
{
  "user_id": "uuid",
  "lesson_id": "uuid",
  "quiz_id": "uuid",
  "responses": [
    { "q_index": 0, "value": 1 },
    { "q_index": 1, "value": "kifik 7abibi" }
  ]
}
```
**Res**
```json
{
  "attempt_id": "uuid",
  "score": 0.8,
  "feedback": [
    { "q_index": 0, "ok": true },
    { "q_index": 1, "ok": false,
      "errors": [
        { "type": "VOCAB", "token": "7abibi", "hint": "use neutral 'kifak?' or 'kifik?'" }
      ],
      "suggestion": "Prefer 'kifak?' (to a male) or 'kifik?' (to a female)."
    }
  ]
}
```

### GET `/api/v1/study-guide?user_id=...`
**Res**
```json
{
  "focus": ["greetings", "coffee-ordering-verbs"],
  "patterns": [
    { "type": "SPELL_T", "example": ["shou→shu"] },
    { "type": "EN_IN_AR", "example": ["use 'shu' instead of 'what'"] }
  ],
  "next_recs": ["short greetings drill", "ordering coffee mini-lesson"]
}
```

### GET `/api/v1/progress?user_id=...`
**Res**
```json
{ "weekly": { "accuracy": 0.76, "time_minutes": 42, "errors_by_type": { "SPELL_T": 5, "EN_IN_AR": 2 } } }
```

### GET `/api/v1/audio?lesson_id=...` (V2)
Returns signed URL to TTS asset.

**Auth**: Bearer JWT (Supabase/Firebase).  
**Rate-limits**: e.g., `100 req/day` per user for generation endpoints.

---

## 8) Transliteration Rules (Baseline)

- **Consonants**: `7`→ح, `3`→ع, `2`→ء, `kh`→خ, `sh`→ش, `j`→ج (Levantine “j”), `gh`→غ  
- **Vowels**: prefer short forms (`a`, `e`, `o`, `i`, `u`); avoid diacritics.  
- **Consistency** over pedantic accuracy; aim for **speakability**.  
- Normalize to one style in V1; allow user preference overrides later.

---

## 9) Performance & Caching

- **Edge cache** (Cloudflare/Fastly) for GET resources (audio, public lesson manifests).
- **Server cache** for prompt outputs (hash of prompt template + inputs).
- **Pregen**: create next 2–3 lessons per user overnight (V2 background jobs).
- **Batching**: group evaluation requests when feasible.

---

## 10) Security, Privacy, Compliance

- JWT verification at API gateway; **row-level security (RLS)** in Supabase.
- Encrypt at rest; minimal PII (email, auth ID).
- Redact/Hash user responses before sending to LLMs where possible.
- Region selection (US/EU) for data locality.
- Audit log for admin operations.

---

## 11) Deployment & Environments

- **Infra**:  
  - Backend: Fly.io/Render/Railway (starter) → containerized on GKE/EKS (V3).  
  - DB: Supabase (managed Postgres, Auth, Storage).  
  - Caching: Redis (managed) if needed.

- **Envs**: `dev`, `staging`, `prod` with isolated projects & keys.  
- **CI/CD**: GitHub Actions  
  - Lint, type-check, unit tests, contract tests (Pydantic schemas), integration smoke tests.  
  - Tag and promote via `release/*` branches.

---

## 12) Testing Strategy

- **Contract Tests**: freeze API JSON schemas (Pydantic + pytest).  
- **Prompt Tests**: golden files for LLM prompts & sanity constraints (length, translit only).  
- **Heuristic Tests**: transliteration validator (no Arabic script, allowed alphabet).  
- **Latency Budgets**: Story gen P50 < 1.5s (cached), Quiz gen P50 < 1.0s (cached).  
- **Mobile E2E**: Flutter integration tests for toggle, offline replay, and evaluation flow.

---

## 13) Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Inconsistent transliteration | Confusing UX | Post-proc normalizer; glossary enforcement; user style pinned |
| LLM latency/cost | Slow UX/$$ | Cache aggressively; pregenerate; split creative vs judge models |
| Evaluation false positives | User frustration | Hybrid regex + LLM; threshold for flags; show rationale |
| Scope creep | Delays | Phased roadmap; PRD acceptance criteria gate |
| Data privacy | Trust issues | Minimization, RLS, regional storage, audits |

---

## 14) Roadmap Alignment

- **V1**: `/story`, `/quiz`, `/evaluate`, `/progress` (basic); no audio; single service.
- **V2**: `/study-guide`, `/audio`, offline cache; background jobs; TTS integration.
- **V3**: Voice practice (Whisper), Coach Agent service, multi-dialect switch, community curation pipeline.

---

## 15) Open Questions (for Review)

1. Transliteration style defaults: “shu” vs “shou” — pick a baseline?  
2. Topics inventory depth for V1 (target 20+, confirm list).  
3. Supabase vs Firebase preference (auth & pricing tradeoffs).  
4. Minimum offline pack size (N lessons? audio later?).  
5. Region hosting preference (US/EU).

---

## 16) Appendix — Example Prompts (Abbrev.)

**Story (Claude)**
```
System: You generate short, friendly dialogues in English about Lebanese daily life.
Constraints: 80–120 words, beginner level, culturally authentic.
User: topic=coffee_chat, level=beginner, target_vocab=["ahwe","ma3loum","yalla"]
```

**Transliteration Enforcement**
```
System: Convert the English dialogue to Lebanese Arabic in LATIN transliteration only.
Rules: 7=ح, 3=ع, 2=ء, sh=ش, kh=خ, gh=غ. No Arabic script. Keep punctuation.
```

**Quiz (OpenAI)**
```
System: Generate 4 questions (2 MCQ, 1 translate EN→LA, 1 comprehension).
Return strict JSON with fields: type, q, choices?, answer, rationale.
```

**Evaluation (OpenAI)**
```
System: Classify errors per taxonomy [EN_IN_AR, SPELL_T, VOCAB, GRAMMAR, OMISSION, EXTRA].
Return JSON: {q_index, ok, errors:[{type, token, hint}], suggestion}
```
