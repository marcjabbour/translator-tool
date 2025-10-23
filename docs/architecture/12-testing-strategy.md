# 12) Testing Strategy

- **Contract Tests**: freeze API JSON schemas (Pydantic + pytest).  
- **Prompt Tests**: golden files for LLM prompts & sanity constraints (length, translit only).  
- **Heuristic Tests**: transliteration validator (no Arabic script, allowed alphabet).  
- **Latency Budgets**: Story gen P50 < 1.5s (cached), Quiz gen P50 < 1.0s (cached).  
- **Mobile E2E**: Flutter integration tests for toggle, offline replay, and evaluation flow.

---
