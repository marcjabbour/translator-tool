# 13) Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Inconsistent transliteration | Confusing UX | Post-proc normalizer; glossary enforcement; user style pinned |
| LLM latency/cost | Slow UX/$$ | Cache aggressively; pregenerate; split creative vs judge models |
| Evaluation false positives | User frustration | Hybrid regex + LLM; threshold for flags; show rationale |
| Scope creep | Delays | Phased roadmap; PRD acceptance criteria gate |
| Data privacy | Trust issues | Minimization, RLS, regional storage, audits |

---
