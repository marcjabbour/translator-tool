# 3) Frontend (Flutter, iOS-first)

## Tech & Structure
- **Flutter** (Dart), **Cupertino** look & feel.
- State management: **Riverpod** (or Bloc).
- HTTP client: **dio** with interceptors (auth, retry, backoff).
- Local persistence: **Hive** or **SQLite (sqflite)** for:
  - Last N lessons (content + quiz)
  - Last answers and error highlights
  - User prefs (dialect, difficulty, transliteration flavor)

## Core Screens
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

## UX Guarantees
- Toggle latency: < **200 ms** (pre-render both texts, cached).
- Offline mode (V2): full read/test for cached lessons, queued sync.

---
