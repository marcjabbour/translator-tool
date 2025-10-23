# 16) Appendix — Example Prompts (Abbrev.)

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
