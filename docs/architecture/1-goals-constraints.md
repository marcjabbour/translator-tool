# 1) Goals & Constraints

## Primary Goals
- Deliver a **non-gamified**, context-driven learning loop: read → translate toggle → test → feedback → progress.
- Guarantee **fast UI interactions** (toggle < 200ms, cached lesson loads).
- Provide **adaptive study guidance** based on error history.
- Keep platform **iOS-first** (Flutter), with portable architecture for Android later.

## Non-Goals (V1)
- Native Arabic script rendering (transliteration only).
- Speech/pronunciation scoring (planned V3).
- Community content pipeline (planned V3).

## Key Constraints
- Cost control (cache + pregen).
- Privacy (PII minimal; region-aware storage).
- Vendor portability (Claude/OpenAI switchable).

---
