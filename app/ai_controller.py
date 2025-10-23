"""
AI Controller for story generation and transliteration.
Orchestrates LLM calls for creative story generation with cultural nuance.
"""

import json
import logging
import re
import time
from typing import Dict, Any, Optional, List
from dataclasses import dataclass
from anthropic import Anthropic

logger = logging.getLogger(__name__)


@dataclass
class StoryGenerationRequest:
    """Request parameters for story generation."""
    topic: str
    level: str
    seed: Optional[int] = None


@dataclass
class StoryGenerationResponse:
    """Response from story generation."""
    en_text: str
    la_text: str
    meta: Dict[str, Any]


@dataclass
class QuizGenerationRequest:
    """Request parameters for quiz generation."""
    lesson_id: str
    en_text: str
    la_text: str
    topic: str
    level: str


@dataclass
class QuizQuestion:
    """Individual quiz question with type-specific properties."""
    type: str  # "mcq", "translate", "fill_blank"
    question: str
    answer: Any  # Can be int (for MCQ index), str (for translation), or List[str] (for fill_blank)
    choices: Optional[List[str]] = None  # For MCQ questions
    rationale: Optional[str] = None


@dataclass
class QuizGenerationResponse:
    """Response from quiz generation."""
    questions: List[QuizQuestion]
    answer_key: Dict[str, Any]
    meta: Dict[str, Any]


class TransliterationValidator:
    """Validates transliteration follows Latin mapping rules."""

    # Allowed characters for Lebanese Arabic transliteration
    ALLOWED_CHARS = set('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,!?\'"-')
    TRANSLITERATION_CHARS = {'7', '3', '2', '5', '8', '9'}  # Special transliteration numbers

    @classmethod
    def validate(cls, text: str) -> bool:
        """
        Validate that text contains only Latin characters and approved transliteration symbols.

        Args:
            text: Text to validate

        Returns:
            True if valid transliteration, False otherwise
        """
        allowed_set = cls.ALLOWED_CHARS | cls.TRANSLITERATION_CHARS
        return all(char in allowed_set for char in text)

    @classmethod
    def contains_arabic_script(cls, text: str) -> bool:
        """Check if text contains Arabic script characters."""
        arabic_range = range(0x0600, 0x06FF + 1)  # Arabic Unicode block
        return any(ord(char) in arabic_range for char in text)


class AIController:
    """Orchestrates LLM calls for story generation and transliteration."""

    def __init__(self, anthropic_client: Optional[Anthropic] = None, cache_service=None):
        """
        Initialize AI Controller.

        Args:
            anthropic_client: Optional Anthropic client instance
            cache_service: Optional cache service for performance optimization
        """
        self.client = anthropic_client or Anthropic()
        self.validator = TransliterationValidator()
        self.cache_service = cache_service

    def generate_story(self, request: StoryGenerationRequest) -> StoryGenerationResponse:
        """
        Generate a contextual story with English and Lebanese Arabic transliteration.
        Uses cache for performance optimization to meet P50 < 1.5s latency budget.

        Args:
            request: Story generation parameters

        Returns:
            Generated story with English and transliterated Lebanese Arabic

        Raises:
            ValueError: If generated content fails validation
            Exception: For LLM API errors
        """
        start_time = time.time()

        try:
            # Check cache first for performance
            if self.cache_service:
                cached_response = self.cache_service.get_cached_story(request)
                if cached_response:
                    elapsed_time = time.time() - start_time
                    logger.info(f"Story retrieved from cache in {elapsed_time:.3f}s")
                    return cached_response

            # Generate new story if not cached
            logger.info("Generating new story via LLM")

            # Create culturally relevant prompt
            prompt = self._create_story_prompt(request)

            # Call Claude for story generation
            response = self.client.messages.create(
                model="claude-3-sonnet-20240229",
                max_tokens=1000,
                temperature=0.7,
                system=self._get_system_prompt(),
                messages=[{"role": "user", "content": prompt}]
            )

            # Parse response
            content = response.content[0].text
            story_data = self._parse_story_response(content)

            # Validate transliteration
            if not self.validator.validate(story_data["la_text"]):
                raise ValueError("Generated transliteration contains invalid characters")

            if self.validator.contains_arabic_script(story_data["la_text"]):
                raise ValueError("Generated transliteration contains Arabic script")

            # Create response
            story_response = StoryGenerationResponse(
                en_text=story_data["en_text"],
                la_text=story_data["la_text"],
                meta={
                    "topic": request.topic,
                    "level": request.level,
                    "seed": request.seed
                }
            )

            # Cache the response for future requests
            if self.cache_service:
                self.cache_service.cache_story(request, story_response)

            elapsed_time = time.time() - start_time
            logger.info(f"Story generated via LLM in {elapsed_time:.3f}s")

            return story_response

        except Exception as e:
            elapsed_time = time.time() - start_time
            logger.error(f"Story generation failed after {elapsed_time:.3f}s: {str(e)}")
            raise

    def generate_quiz(self, request: QuizGenerationRequest) -> QuizGenerationResponse:
        """
        Generate a quiz based on lesson content with multiple question types.
        Uses Claude LLM for contextual question generation and answer key creation.

        Args:
            request: Quiz generation parameters

        Returns:
            Generated quiz with questions and answer key

        Raises:
            ValueError: If generated content fails validation
            Exception: For LLM API errors
        """
        start_time = time.time()

        try:
            # Check cache first for performance
            if self.cache_service:
                cached_response = self.cache_service.get_cached_quiz(request)
                if cached_response:
                    elapsed_time = time.time() - start_time
                    logger.info(f"Quiz retrieved from cache in {elapsed_time:.3f}s")
                    return cached_response

            # Generate new quiz if not cached
            logger.info("Generating new quiz via LLM")

            # Create quiz prompt
            prompt = self._create_quiz_prompt(request)

            # Call Claude for quiz generation
            response = self.client.messages.create(
                model="claude-3-sonnet-20240229",
                max_tokens=2000,
                temperature=0.3,  # Lower temperature for more consistent quiz generation
                system=self._get_quiz_system_prompt(),
                messages=[{"role": "user", "content": prompt}]
            )

            # Parse response
            content = response.content[0].text
            quiz_data = self._parse_quiz_response(content)

            # Validate quiz structure
            questions = self._validate_and_parse_questions(quiz_data["questions"])

            # Create response
            quiz_response = QuizGenerationResponse(
                questions=questions,
                answer_key=quiz_data.get("answer_key", {}),
                meta={
                    "lesson_id": request.lesson_id,
                    "topic": request.topic,
                    "level": request.level,
                    "question_count": len(questions)
                }
            )

            # Cache the response for future requests
            if self.cache_service:
                self.cache_service.cache_quiz(request, quiz_response)

            elapsed_time = time.time() - start_time
            logger.info(f"Quiz generated via LLM in {elapsed_time:.3f}s")

            return quiz_response

        except Exception as e:
            elapsed_time = time.time() - start_time
            logger.error(f"Quiz generation failed after {elapsed_time:.3f}s: {str(e)}")
            raise

    def _create_quiz_prompt(self, request: QuizGenerationRequest) -> str:
        """Create prompt for quiz generation based on lesson content."""
        level_constraints = {
            "beginner": "Use simple vocabulary and basic comprehension questions",
            "intermediate": "Use moderate difficulty with some cultural context questions",
            "advanced": "Include complex comprehension and cultural nuance questions"
        }

        constraint = level_constraints.get(request.level, level_constraints["beginner"])

        prompt = f"""
Generate a quiz based on this Lebanese Arabic lesson content.

LESSON CONTENT:
English: {request.en_text}
Lebanese Arabic: {request.la_text}
Topic: {request.topic}
Level: {request.level}

REQUIREMENTS:
1. Create exactly 4-5 questions testing comprehension and translation
2. Use these question types:
   - Multiple Choice (MCQ): Test comprehension with 3-4 choices
   - Translation: Ask to translate specific phrases English ↔ Lebanese Arabic
   - Fill-in-blank: Remove key words from sentences for completion

3. Difficulty: {constraint}
4. Questions must be directly related to the lesson dialogue content
5. Provide clear rationales for each correct answer

RESPONSE FORMAT (exact JSON):
{{
    "questions": [
        {{
            "type": "mcq",
            "question": "What does 'ahwe' mean in English?",
            "choices": ["tea", "coffee", "water", "juice"],
            "answer": 1,
            "rationale": "The word 'ahwe' in Lebanese Arabic means coffee"
        }},
        {{
            "type": "translate",
            "question": "Translate to Lebanese Arabic: 'How are you?'",
            "answer": "kifak?",
            "rationale": "The Lebanese Arabic equivalent of 'How are you?' is 'kifak?'"
        }},
        {{
            "type": "fill_blank",
            "question": "Complete the sentence: 'ahlan, baddak _____ neeshrab ahwe?'",
            "answer": ["nrou7"],
            "rationale": "The missing word is 'nrou7' which means 'we go' in Lebanese Arabic"
        }}
    ],
    "answer_key": {{
        "total_questions": 3,
        "question_types": ["mcq", "translate", "fill_blank"]
    }}
}}

Generate questions that test both understanding of the dialogue and knowledge of Lebanese Arabic transliteration.
"""

        return prompt.strip()

    def _get_quiz_system_prompt(self) -> str:
        """Get system prompt for Claude with quiz generation rules."""
        return """
You are an expert Lebanese Arabic language instructor creating contextual quizzes.

Your role is to generate high-quality comprehension and translation questions based on lesson content.

Critical rules for quiz generation:
- Questions must be directly related to the provided lesson dialogue
- Use proper Lebanese Arabic transliteration (Latin alphabet with numbers: 7=ح, 3=ع, 2=ء, 5=خ, 8=غ, 9=ق)
- Multiple choice questions should have one clearly correct answer
- Translation questions should accept the most common Lebanese Arabic equivalent
- Fill-in-blank questions should test key vocabulary from the lesson
- Provide educational rationales explaining why answers are correct
- Ensure cultural appropriateness and beginner-friendly content
"""

    def _parse_quiz_response(self, content: str) -> Dict[str, Any]:
        """
        Parse Claude's response to extract quiz questions and answer key.

        Args:
            content: Raw response from Claude

        Returns:
            Dictionary with questions and answer_key

        Raises:
            ValueError: If response format is invalid
        """
        try:
            # Try to extract JSON from response
            json_match = re.search(r'\{.*\}', content, re.DOTALL)
            if not json_match:
                raise ValueError("No JSON found in response")

            data = json.loads(json_match.group())

            if "questions" not in data:
                raise ValueError("Missing questions array in response")

            return data

        except json.JSONDecodeError as e:
            logger.error(f"JSON parsing failed: {e}")
            raise ValueError("Invalid JSON in response")
        except Exception as e:
            logger.error(f"Quiz response parsing failed: {e}")
            raise ValueError(f"Failed to parse quiz response: {str(e)}")

    def _validate_and_parse_questions(self, questions_data: List[Dict[str, Any]]) -> List[QuizQuestion]:
        """
        Validate and parse questions from LLM response.

        Args:
            questions_data: List of question dictionaries

        Returns:
            List of validated QuizQuestion objects

        Raises:
            ValueError: If questions are invalid
        """
        if not questions_data:
            raise ValueError("No questions found in response")

        if len(questions_data) < 3:
            raise ValueError("Minimum 3 questions required")

        questions = []
        for i, q_data in enumerate(questions_data):
            try:
                question_type = q_data.get("type", "").lower()
                if question_type not in ["mcq", "translate", "fill_blank"]:
                    raise ValueError(f"Invalid question type: {question_type}")

                question_text = q_data.get("question", "").strip()
                if not question_text:
                    raise ValueError("Question text is required")

                answer = q_data.get("answer")
                if answer is None:
                    raise ValueError("Answer is required")

                # Validate specific question types
                if question_type == "mcq":
                    choices = q_data.get("choices", [])
                    if not isinstance(choices, list) or len(choices) < 2:
                        raise ValueError("MCQ requires at least 2 choices")
                    if not isinstance(answer, int) or answer < 0 or answer >= len(choices):
                        raise ValueError("MCQ answer must be valid choice index")

                elif question_type == "translate":
                    if not isinstance(answer, str) or not answer.strip():
                        raise ValueError("Translation answer must be non-empty string")
                    # Validate transliteration
                    if not self.validator.validate(answer):
                        raise ValueError("Translation answer contains invalid characters")

                elif question_type == "fill_blank":
                    if not isinstance(answer, list) or not answer:
                        raise ValueError("Fill-in-blank answer must be non-empty list")

                question = QuizQuestion(
                    type=question_type,
                    question=question_text,
                    answer=answer,
                    choices=q_data.get("choices") if question_type == "mcq" else None,
                    rationale=q_data.get("rationale", "").strip()
                )

                questions.append(question)

            except Exception as e:
                logger.error(f"Question {i} validation failed: {e}")
                raise ValueError(f"Question {i+1} is invalid: {str(e)}")

        return questions

    def _create_story_prompt(self, request: StoryGenerationRequest) -> str:
        """Create prompt for story generation based on request parameters."""
        level_constraints = {
            "beginner": "Use simple vocabulary and short sentences (5-10 words per sentence)",
            "intermediate": "Use moderate vocabulary and medium sentences (10-15 words per sentence)",
            "advanced": "Use rich vocabulary and varied sentence structures"
        }

        constraint = level_constraints.get(request.level, level_constraints["beginner"])

        prompt = f"""
Generate a short, realistic dialogue in English for language learning practice.

Topic: {request.topic}
Level: {request.level}
Constraints: {constraint}

Requirements:
1. Create a natural, contextual dialogue (2-3 exchanges)
2. Make it culturally relevant and appropriate for beginners
3. Keep it conversational and practical for daily use
4. Length: 15-25 words total
5. Use informal/casual register

Provide the response in this exact JSON format:
{{
    "en_text": "the English dialogue here",
    "la_text": "the Lebanese Arabic transliteration here"
}}

For the Lebanese Arabic transliteration:
- Use ONLY Latin characters and numbers
- Use these number mappings: 7=ح, 3=ع, 2=ء, 5=خ, 8=غ, 9=ق
- NO Arabic script allowed
- Keep it natural and conversational
"""

        if request.seed:
            prompt += f"\nSeed for consistency: {request.seed}"

        return prompt.strip()

    def _get_system_prompt(self) -> str:
        """Get system prompt for Claude with transliteration rules."""
        return """
You are an expert in Lebanese Arabic transliteration and cultural context.
You create realistic dialogues that Lebanese learners would find useful.

Critical rules for transliteration:
- NEVER use Arabic script
- Use Latin alphabet only with these number substitutions:
  7 for ح (ḥā'), 3 for ع ('ayn), 2 for ء (hamza), 5 for خ (khā'), 8 for غ (ghayn), 9 for ق (qāf)
- Make it pronounceable for English speakers learning Lebanese
- Use Lebanese dialect, not Modern Standard Arabic
- Keep cultural nuances authentic but beginner-friendly
"""

    def _parse_story_response(self, content: str) -> Dict[str, str]:
        """
        Parse Claude's response to extract English and Lebanese Arabic text.

        Args:
            content: Raw response from Claude

        Returns:
            Dictionary with en_text and la_text keys

        Raises:
            ValueError: If response format is invalid
        """
        try:
            # Try to extract JSON from response
            json_match = re.search(r'\{.*\}', content, re.DOTALL)
            if not json_match:
                raise ValueError("No JSON found in response")

            data = json.loads(json_match.group())

            if "en_text" not in data or "la_text" not in data:
                raise ValueError("Missing required fields in response")

            return {
                "en_text": data["en_text"].strip(),
                "la_text": data["la_text"].strip()
            }

        except json.JSONDecodeError as e:
            logger.error(f"JSON parsing failed: {e}")
            raise ValueError("Invalid JSON in response")
        except Exception as e:
            logger.error(f"Response parsing failed: {e}")
            raise ValueError(f"Failed to parse response: {str(e)}")