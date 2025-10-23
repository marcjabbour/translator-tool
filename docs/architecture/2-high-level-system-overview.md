# 2) High-Level System Overview

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
