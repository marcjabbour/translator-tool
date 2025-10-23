# 9) Performance & Caching

- **Edge cache** (Cloudflare/Fastly) for GET resources (audio, public lesson manifests).
- **Server cache** for prompt outputs (hash of prompt template + inputs).
- **Pregen**: create next 2–3 lessons per user overnight (V2 background jobs).
- **Batching**: group evaluation requests when feasible.

---
