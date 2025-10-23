# Product Requirements Document (PRD)
### Project: Lebanese Arabic Translator & Practice Tool
**Owner:** John (📋 Product Manager — BMAD Method)  
**Date:** October 2025  
**Version:** 1.0

---

## 1. 🧭 Overview

### **Purpose**
To create an AI-powered learning companion that helps users develop real conversational fluency in Lebanese Arabic through **interactive reading, translation, and adaptive testing** — without gamification.

### **Product Vision**
Deliver a **context-driven, transliteration-first experience** that bridges everyday English usage and spoken Lebanese Arabic. Learners engage with natural dialogues, receive targeted feedback, and track progress through transparent analytics rather than game mechanics.

### **Target Audience**
- Lebanese diaspora seeking to reconnect with heritage language  
- Arabic learners focused on spoken dialects  
- Travelers or expats preparing for time in Lebanon  
- Non-native speakers who prefer phonetic learning without Arabic script  

---

## 2. 🧩 Problem Statement

### **Current Gap**
Most Arabic learning tools:
- Focus on Modern Standard Arabic (MSA), not Lebanese dialect  
- Rely on gamified engagement (points, streaks, etc.)  
- Don’t offer transliteration-based reading and testing  
- Provide little adaptive feedback on personal weaknesses  

### **Opportunity**
Create a **personalized, non-gamified dialect learning environment** that emphasizes conversational practice, transliteration accuracy, and measurable self-improvement.

---

## 3. 🎯 Goals & Success Metrics

| **Goal** | **Metric / KPI** |
|-----------|------------------|
| Enable users to read and understand everyday Lebanese dialogues | ≥ 80% comprehension accuracy after 10 lessons |
| Help users learn transliteration-based vocabulary effectively | Reduction in repeated transliteration errors by 50% |
| Deliver a seamless bilingual toggle experience | <200ms toggle latency (client-side) |
| Provide transparent learning progress tracking | ≥ 70% user retention across 2 weeks |
| Validate product-market fit with diaspora users | ≥ 4.5⭐ average feedback on usability |

---

## 4. 🧱 Product Scope

### **In Scope**
- AI-generated stories and transliteration
- Interactive question generation
- Error tracking and adaptive feedback
- User progress analytics dashboard
- Cloud sync and authentication

### **Out of Scope (Initial Phases)**
- Full speech recognition (planned V3)
- User-submitted content and community features
- Native Arabic script support
- Competitive multiplayer or social gamification

---

## 5. 🗺️ Phased Roadmap & Feature Breakdown

### **V1 — MVP (Core Learning Loop)**
**Goal:** Validate translation quality and learning flow.

| **Feature** | **Description** | **Acceptance Criteria** |
|--------------|-----------------|--------------------------|
| Contextual Story Generator | AI generates short, realistic dialogues in English | At least 20 scenario templates available |
| Dual Translation Toggle | Switch between English ↔ transliterated Arabic | Smooth toggle without screen reload |
| Interactive Test Mode | Generate comprehension or translation questions | Minimum 3 questions per lesson |
| Error Detection (Core) | Identify English or transliteration mistakes | Correctly classifies ≥ 80% test cases |
| Progress Dashboard (Basic) | Track completed lessons and accuracy rates | Displays trend chart and summary card |
| Cloud Sync & Auth | Save lessons and progress via user accounts | Works across devices; persistent storage |

---

### **V2 — Adaptive & Analytical Expansion**
**Goal:** Introduce personalization and deeper insight.

| **Feature** | **Description** | **Acceptance Criteria** |
|--------------|-----------------|--------------------------|
| Adaptive Study Guide | Personalized review list based on user mistakes | Generates updated guide after each session |
| Lesson History & Replay | View and redo previous lessons with prior answers | Works across all devices |
| Error Analytics Dashboard | Categorized breakdown of user mistakes | Tracks by type and frequency |
| Native Audio Playback | Audio narration of dialogues (TTS) | Accurate pronunciation for all lesson texts |
| Offline Mode | Cache lessons for offline access | Syncs progress when reconnected |

---

### **V3 — Advanced Coaching & Growth**
**Goal:** Build toward a personalized AI coaching experience.

| **Feature** | **Description** | **Acceptance Criteria** |
|--------------|-----------------|--------------------------|
| Voice Practice Mode | User pronounces transliterated Arabic for evaluation | AI rates pronunciation consistency ≥ 80% accuracy |
| AI Coach Agent | Personalized feedback and adaptive goals | Delivers learning summary after each week |
| Dialect Selector | Add Egyptian/Syrian dialects | Switch dialect without retraining base model |
| Community Story Submissions | User-submitted stories with AI moderation | Filtered and approved via semantic scoring |
| Advanced Analytics Dashboard | Deep dive into skill mastery, time trends | Displays longitudinal progress data |

---

## 6. ⚙️ Technical Overview

| **Layer** | **Technology** | **Purpose** |
|------------|----------------|--------------|
| Frontend | **Flutter (iOS-first)** | Native-feel interface, translation toggle, dashboard |
| Backend | **FastAPI / Node.js** | API orchestration and AI request handling |
| AI Layer | **Claude + OpenAI APIs** | Story, translation, and quiz generation |
| Database | **Supabase / Firebase** | User data, progress, analytics |
| Storage | **Cloud + Local Cache** | Offline lessons, user history |
| Speech (Future) | **Whisper + TTS (OpenAI/ElevenLabs)** | Voice evaluation and playback |

---

## 7. 🎨 UX & Design Goals

- **Minimalist UI:** Focused on content and learning clarity  
- **One-touch Translation Toggle:** No visual clutter or animations that distract  
- **Adaptive Progress Visuals:** Charts that inform, not gamify  
- **Error Feedback Tone:** Supportive and instructive, not judgmental  
- **Phonetic Fidelity:** Ensure transliteration is authentic and consistent  

---

## 8. 🚧 Dependencies & Risks

| **Type** | **Dependency / Risk** | **Mitigation** |
|-----------|-----------------------|----------------|
| Technical | Transliteration accuracy may require iterative tuning | Combine rule-based correction with LLM post-processing |
| AI | Claude/OpenAI latency for story generation | Implement caching and pre-generation |
| UX | Maintaining simplicity without losing engagement | Emphasize progress visualization and adaptive reflection |
| Data | Storing user responses securely | Use encrypted auth and anonymized analytics |
| Growth | Limited dialect datasets | Build custom corpus with Lebanese speakers in V3 |

---

## 9. 📊 Success Metrics by Version

| **Phase** | **Key Metric** | **Target** |
|------------|----------------|-------------|
| V1 | Comprehension accuracy | ≥ 80% |
| V1 | Translation toggle latency | ≤ 200ms |
| V2 | Reduction in recurring errors | ≥ 50% |
| V2 | Weekly active retention | ≥ 60% |
| V3 | Pronunciation accuracy (AI feedback) | ≥ 80% |
| V3 | User satisfaction (Coach feature) | ≥ 4.5⭐ rating |

---

## 10. 🧩 Next Steps

1. **Handoff to Architect (🏗️ Winston):** Design backend + AI service architecture for V1–V3.  
2. **Collaborate with UX Expert (🎨 Sally):** Build user journey and visual wireframes for reading and testing modes.  
3. **Prepare Development Plan:** Shard this PRD into epics and stories for implementation.  

---

**Document Owner:**  
John — Product Manager (BMAD-Method Team Fullstack)  
**Status:** Draft for review  
**Next Agent:** `*architect` (Winston)