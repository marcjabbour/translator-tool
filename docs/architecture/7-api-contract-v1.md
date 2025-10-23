# 7) API Contract (V1)

## POST `/api/v1/story`
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

## POST `/api/v1/quiz`
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

## POST `/api/v1/evaluate`
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

## GET `/api/v1/study-guide?user_id=...`
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

## GET `/api/v1/progress?user_id=...`
**Res**
```json
{ "weekly": { "accuracy": 0.76, "time_minutes": 42, "errors_by_type": { "SPELL_T": 5, "EN_IN_AR": 2 } } }
```

## GET `/api/v1/audio?lesson_id=...` (V2)
Returns signed URL to TTS asset.

**Auth**: Bearer JWT (Supabase/Firebase).  
**Rate-limits**: e.g., `100 req/day` per user for generation endpoints.

---
