# 5) AI Integration Layer

## Routing Policy
- **Claude** (creative): scenario prose with cultural nuance; transliteration first pass via system prompt rules.
- **OpenAI** (evaluative): question set templating, response grading, error classification; TTS in V2 (or ElevenLabs).

## Prompting Strategy (summaries)
- **Story Prompt**: topic, level, target vocab; constraints on length & register.
- **Transliteration Guard**: enforce Latin mapping (e.g., `7` for ح, `3` for ع); forbid Arabic script.
- **Quiz Prompt**: derive 3–6 questions with answer key & rationales; specify JSON schema.
- **Evaluation Prompt**: classify mistakes into taxonomy; return structured JSON.

## Error Taxonomy (V1)
- `EN_IN_AR`: English word used where Arabic transliteration expected
- `SPELL_T`: transliteration misspelling (e.g., “shou” vs “shu”)
- `GRAMMAR`: tense/word order off (keep minimal in V1)
- `VOCAB`: incorrect word choice (mild)
- `OMISSION/EXTRA`: missing/added words changing meaning

---
