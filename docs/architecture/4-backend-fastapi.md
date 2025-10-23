# 4) Backend (FastAPI)

## Services (app modules)
- `ai_controller.py` — Orchestrates LLM calls (story, transliteration, quiz).
- `evaluation_service.py` — Hybrid error detection (regex heuristics + LLM judge).
- `study_guide_service.py` — Aggregates errors → recommends targeted review.
- `progress_service.py` — Summaries, trends, KPIs.
- `auth_controller.py` — Supabase/Firebase JWT validation.
- `audio_service.py` — TTS URL retrieval (V2).

## Cross-cutting
- **Caching**: Redis or Supabase KV (if available) for:
  - Prompt→completion cache (story/quiz)
  - Study guide snapshots
- **Background jobs** (V2):
  - Celery/RQ/Arq (async) for pre-generation of next lessons & weekly aggregation.
- **Observability**:
  - Structured logging (JSON), request IDs
  - Prometheus/OpenTelemetry exporters (latency, error rate, LLM usage)

---
