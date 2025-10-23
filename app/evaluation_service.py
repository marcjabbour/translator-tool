"""
Evaluation Service for error detection and classification in Lebanese Arabic responses.
Implements hybrid approach combining regex heuristics with LLM judge for accuracy.
"""

import json
import logging
import re
import time
from typing import Dict, Any, List, Optional, Set
from dataclasses import dataclass
from anthropic import Anthropic

logger = logging.getLogger(__name__)


@dataclass
class ErrorDetail:
    """Individual error with type and metadata."""
    type: str  # EN_IN_AR, SPELL_T, GRAMMAR, VOCAB, OMISSION, EXTRA
    token: str  # The problematic word/phrase
    position: int  # Position in user response
    hint: Optional[str] = None  # Correction suggestion
    severity: str = "medium"  # low, medium, high


@dataclass
class QuestionFeedback:
    """Feedback for a single quiz question."""
    q_index: int
    is_correct: bool
    errors: List[ErrorDetail]
    suggestion: Optional[str] = None
    confidence: float = 1.0  # 0.0 to 1.0


@dataclass
class EvaluationRequest:
    """Request for quiz evaluation."""
    user_id: str
    lesson_id: str
    quiz_id: str
    responses: List[Dict[str, Any]]  # [{"q_index": 0, "value": "response"}]
    quiz_context: Dict[str, Any]  # Quiz questions and answers for context


@dataclass
class EvaluationResponse:
    """Response from evaluation service."""
    attempt_id: str
    score: float  # 0.0 to 1.0
    feedback: List[QuestionFeedback]
    overall_feedback: Optional[str] = None


class TransliterationHeuristics:
    """Regex-based heuristics for common transliteration errors."""

    # Common English words that shouldn't appear in Lebanese Arabic
    ENGLISH_WORDS = {
        "the", "and", "is", "are", "was", "were", "have", "has", "had",
        "will", "would", "could", "should", "can", "may", "might",
        "yes", "no", "ok", "okay", "please", "thank", "you", "me", "my",
        "your", "his", "her", "we", "they", "them", "this", "that",
        "here", "there", "where", "when", "what", "how", "why", "who"
    }

    # Common transliteration patterns
    TRANSLITERATION_PATTERNS = {
        # Common misspellings in Lebanese Arabic
        r'\bshou\b': 'shu',  # "what" - common spelling variation
        r'\bshoo\b': 'shu',
        r'\bkifik\b': 'kifik',  # "how are you (fem)" - ensure correct
        r'\bkifak\b': 'kifak',  # "how are you (masc)" - ensure correct
        r'\byala\b': 'yalla',   # "let's go" - common misspelling
        r'\byallah\b': 'yalla',
        r'\bmarhaba\b': 'mar7aba',  # "hello" - missing transliteration number
        r'\btislam\b': 'tislam',    # "thank you" - ensure correct
    }

    # Valid transliteration numbers
    VALID_NUMBERS = {'2', '3', '5', '7', '8', '9'}

    @classmethod
    def detect_english_in_arabic(cls, user_response: str) -> List[ErrorDetail]:
        """Detect English words in Lebanese Arabic response."""
        errors = []
        words = re.findall(r'\b\w+\b', user_response.lower())

        for i, word in enumerate(words):
            if word in cls.ENGLISH_WORDS:
                errors.append(ErrorDetail(
                    type="EN_IN_AR",
                    token=word,
                    position=i,
                    hint=f"Use Lebanese Arabic instead of English word '{word}'",
                    severity="high"
                ))

        return errors

    @classmethod
    def detect_spelling_errors(cls, user_response: str) -> List[ErrorDetail]:
        """Detect common transliteration spelling mistakes."""
        errors = []

        for pattern, correction in cls.TRANSLITERATION_PATTERNS.items():
            matches = re.finditer(pattern, user_response, re.IGNORECASE)
            for match in matches:
                if match.group().lower() != correction.lower():
                    errors.append(ErrorDetail(
                        type="SPELL_T",
                        token=match.group(),
                        position=match.start(),
                        hint=f"Consider using '{correction}' instead of '{match.group()}'",
                        severity="medium"
                    ))

        return errors

    @classmethod
    def detect_missing_transliteration(cls, user_response: str, expected_response: str) -> List[ErrorDetail]:
        """Detect missing transliteration numbers (2,3,5,7,8,9)."""
        errors = []

        # Check if expected response has transliteration numbers but user response doesn't
        expected_has_numbers = any(char in expected_response for char in cls.VALID_NUMBERS)
        user_has_numbers = any(char in user_response for char in cls.VALID_NUMBERS)

        if expected_has_numbers and not user_has_numbers:
            errors.append(ErrorDetail(
                type="SPELL_T",
                token=user_response,
                position=0,
                hint="Lebanese Arabic transliteration should include numbers for Arabic sounds (2,3,5,7,8,9)",
                severity="medium"
            ))

        return errors


class LLMEvaluationJudge:
    """LLM-based evaluation for sophisticated error classification."""

    def __init__(self, anthropic_client: Optional[Anthropic] = None):
        """Initialize LLM judge with Anthropic client."""
        self.client = anthropic_client or Anthropic()

    def evaluate_translation_response(
        self,
        question: str,
        expected_answer: str,
        user_response: str,
        context: Dict[str, Any] = None
    ) -> QuestionFeedback:
        """
        Use LLM to evaluate translation response with detailed error analysis.

        Args:
            question: The quiz question
            expected_answer: Expected correct answer
            user_response: User's actual response
            context: Additional context (lesson content, etc.)

        Returns:
            QuestionFeedback with detailed error analysis
        """
        try:
            prompt = self._create_evaluation_prompt(
                question, expected_answer, user_response, context
            )

            response = self.client.messages.create(
                model="claude-3-sonnet-20240229",
                max_tokens=1000,
                temperature=0.1,  # Low temperature for consistent evaluation
                system=self._get_evaluation_system_prompt(),
                messages=[{"role": "user", "content": prompt}]
            )

            content = response.content[0].text
            evaluation_data = self._parse_evaluation_response(content)

            return self._convert_to_feedback(evaluation_data, user_response)

        except Exception as e:
            logger.error(f"LLM evaluation failed: {e}")
            # Fallback to basic comparison
            is_correct = self._basic_comparison(expected_answer, user_response)
            return QuestionFeedback(
                q_index=0,  # Will be set by caller
                is_correct=is_correct,
                errors=[],
                confidence=0.5
            )

    def _create_evaluation_prompt(
        self,
        question: str,
        expected_answer: str,
        user_response: str,
        context: Dict[str, Any] = None
    ) -> str:
        """Create evaluation prompt for LLM judge."""
        context_info = ""
        if context:
            context_info = f"""
CONTEXT:
Lesson Topic: {context.get('topic', 'Unknown')}
Level: {context.get('level', 'Unknown')}
"""

        prompt = f"""
Evaluate this Lebanese Arabic translation response for a language learning quiz.

QUESTION: {question}
EXPECTED ANSWER: {expected_answer}
USER RESPONSE: {user_response}
{context_info}

EVALUATION CRITERIA:
1. Is the user response semantically correct?
2. Are there transliteration errors?
3. Are there vocabulary mistakes?
4. Are there grammatical issues?
5. Are there omissions or extra words?

ERROR TAXONOMY:
- EN_IN_AR: English word used where Arabic transliteration expected
- SPELL_T: Transliteration spelling mistake (e.g., "shou" vs "shu")
- GRAMMAR: Word order or grammatical structure issues
- VOCAB: Wrong word choice but understandable
- OMISSION: Missing required words that change meaning
- EXTRA: Added words that change or confuse meaning

RESPONSE FORMAT (exact JSON):
{{
    "is_correct": true/false,
    "confidence": 0.0-1.0,
    "errors": [
        {{
            "type": "error_type",
            "token": "problematic_word",
            "hint": "specific correction suggestion",
            "severity": "low/medium/high"
        }}
    ],
    "suggestion": "overall improvement suggestion (optional)",
    "rationale": "brief explanation of evaluation"
}}

Focus on Lebanese Arabic dialect, not Modern Standard Arabic.
Be lenient with minor spelling variations that don't affect meaning.
Prioritize communicative success over perfect transliteration.
"""

        return prompt.strip()

    def _get_evaluation_system_prompt(self) -> str:
        """Get system prompt for evaluation LLM."""
        return """
You are an expert Lebanese Arabic language instructor evaluating student responses.

Your role is to fairly and accurately assess Lebanese Arabic transliteration responses.

Key principles:
- Lebanese Arabic uses Latin alphabet with numbers: 7=ح, 3=ع, 2=ء, 5=خ, 8=غ, 9=ق
- Focus on meaning and communication over perfect spelling
- Be encouraging and constructive in feedback
- Recognize regional variations in Lebanese dialect
- Distinguish between minor errors and communication-breaking mistakes
- Consider the learner's level and provide appropriate feedback

Always respond with valid JSON format as specified.
"""

    def _parse_evaluation_response(self, content: str) -> Dict[str, Any]:
        """Parse LLM evaluation response."""
        try:
            # Extract JSON from response
            json_match = re.search(r'\{.*\}', content, re.DOTALL)
            if not json_match:
                raise ValueError("No JSON found in evaluation response")

            data = json.loads(json_match.group())

            # Validate required fields
            required_fields = ["is_correct", "confidence", "errors"]
            for field in required_fields:
                if field not in data:
                    raise ValueError(f"Missing required field: {field}")

            return data

        except json.JSONDecodeError as e:
            logger.error(f"JSON parsing failed in evaluation: {e}")
            raise ValueError("Invalid JSON in evaluation response")
        except Exception as e:
            logger.error(f"Evaluation response parsing failed: {e}")
            raise ValueError(f"Failed to parse evaluation response: {str(e)}")

    def _convert_to_feedback(self, evaluation_data: Dict[str, Any], user_response: str) -> QuestionFeedback:
        """Convert LLM evaluation data to QuestionFeedback object."""
        errors = []
        for error_data in evaluation_data.get("errors", []):
            errors.append(ErrorDetail(
                type=error_data.get("type", "UNKNOWN"),
                token=error_data.get("token", ""),
                position=0,  # LLM doesn't provide position
                hint=error_data.get("hint", ""),
                severity=error_data.get("severity", "medium")
            ))

        return QuestionFeedback(
            q_index=0,  # Will be set by caller
            is_correct=evaluation_data.get("is_correct", False),
            errors=errors,
            suggestion=evaluation_data.get("suggestion"),
            confidence=evaluation_data.get("confidence", 0.5)
        )

    def _basic_comparison(self, expected: str, actual: str) -> bool:
        """Basic fallback comparison if LLM fails."""
        # Simple case-insensitive comparison with some normalization
        expected_clean = re.sub(r'[^\w\s]', '', expected.lower().strip())
        actual_clean = re.sub(r'[^\w\s]', '', actual.lower().strip())

        # Check exact match
        if expected_clean == actual_clean:
            return True

        # Check if they're close (allow for minor variations)
        expected_words = expected_clean.split()
        actual_words = actual_clean.split()

        if len(expected_words) != len(actual_words):
            return False

        # Allow one word to be different (for minor spelling variations)
        differences = sum(1 for e, a in zip(expected_words, actual_words) if e != a)
        return differences <= 1


class EvaluationService:
    """Main evaluation service coordinating heuristics and LLM judge."""

    def __init__(self, anthropic_client: Optional[Anthropic] = None, cache_service=None):
        """Initialize evaluation service."""
        self.heuristics = TransliterationHeuristics()
        self.llm_judge = LLMEvaluationJudge(anthropic_client)
        self.cache_service = cache_service

    def evaluate_quiz_responses(self, request: EvaluationRequest) -> EvaluationResponse:
        """
        Evaluate all quiz responses using hybrid approach.

        Args:
            request: Evaluation request with user responses and quiz context

        Returns:
            EvaluationResponse with detailed feedback
        """
        start_time = time.time()

        try:
            logger.info(f"Evaluating quiz responses for user {request.user_id}")

            feedback_list = []
            correct_count = 0
            total_questions = len(request.responses)

            for response_data in request.responses:
                q_index = response_data.get("q_index", 0)
                user_value = response_data.get("value", "")

                # Get question context from quiz
                question_context = self._get_question_context(q_index, request.quiz_context)

                if question_context is None:
                    logger.warning(f"No context found for question {q_index}")
                    continue

                # Evaluate the response
                feedback = self._evaluate_single_response(
                    q_index=q_index,
                    user_response=user_value,
                    question_context=question_context,
                    lesson_context={
                        "topic": request.quiz_context.get("topic"),
                        "level": request.quiz_context.get("level")
                    }
                )

                feedback_list.append(feedback)

                if feedback.is_correct:
                    correct_count += 1

            # Calculate overall score
            score = correct_count / total_questions if total_questions > 0 else 0.0

            # Generate attempt ID (would typically be from database)
            import uuid
            attempt_id = str(uuid.uuid4())

            # Generate overall feedback
            overall_feedback = self._generate_overall_feedback(score, feedback_list)

            response = EvaluationResponse(
                attempt_id=attempt_id,
                score=score,
                feedback=feedback_list,
                overall_feedback=overall_feedback
            )

            elapsed_time = time.time() - start_time
            logger.info(f"Quiz evaluation completed in {elapsed_time:.3f}s (score: {score:.2f})")

            return response

        except Exception as e:
            elapsed_time = time.time() - start_time
            logger.error(f"Quiz evaluation failed after {elapsed_time:.3f}s: {str(e)}")
            raise

    def _evaluate_single_response(
        self,
        q_index: int,
        user_response: str,
        question_context: Dict[str, Any],
        lesson_context: Dict[str, Any]
    ) -> QuestionFeedback:
        """Evaluate a single question response using hybrid approach."""

        question_type = question_context.get("type", "translate")
        question_text = question_context.get("question", "")
        expected_answer = question_context.get("answer", "")

        # Handle different question types
        if question_type == "mcq":
            return self._evaluate_mcq_response(q_index, user_response, question_context)
        elif question_type == "fill_blank":
            return self._evaluate_fill_blank_response(q_index, user_response, question_context)
        else:  # translate or other text-based
            return self._evaluate_translation_response(
                q_index, user_response, expected_answer, question_text, lesson_context
            )

    def _evaluate_mcq_response(self, q_index: int, user_response: Any, question_context: Dict[str, Any]) -> QuestionFeedback:
        """Evaluate multiple choice question."""
        expected_index = question_context.get("answer", 0)
        choices = question_context.get("choices", [])

        try:
            user_index = int(user_response)
            is_correct = user_index == expected_index

            errors = []
            if not is_correct:
                suggestion = f"The correct answer is '{choices[expected_index]}'" if expected_index < len(choices) else "Incorrect choice"
            else:
                suggestion = None

            return QuestionFeedback(
                q_index=q_index,
                is_correct=is_correct,
                errors=errors,
                suggestion=suggestion,
                confidence=1.0
            )

        except (ValueError, IndexError):
            return QuestionFeedback(
                q_index=q_index,
                is_correct=False,
                errors=[ErrorDetail(type="INVALID", token=str(user_response), position=0, hint="Invalid choice")],
                suggestion="Please select a valid option",
                confidence=1.0
            )

    def _evaluate_fill_blank_response(self, q_index: int, user_response: str, question_context: Dict[str, Any]) -> QuestionFeedback:
        """Evaluate fill-in-the-blank question."""
        expected_answers = question_context.get("answer", [])
        if isinstance(expected_answers, str):
            expected_answers = [expected_answers]

        # Check if user response matches any expected answer
        user_clean = user_response.strip().lower()
        is_correct = any(user_clean == expected.strip().lower() for expected in expected_answers)

        errors = []
        if not is_correct and user_response.strip():
            # Use heuristics to detect common errors
            for expected in expected_answers:
                errors.extend(self.heuristics.detect_english_in_arabic(user_response))
                errors.extend(self.heuristics.detect_spelling_errors(user_response))
                errors.extend(self.heuristics.detect_missing_transliteration(user_response, expected))

        suggestion = None
        if not is_correct:
            suggestion = f"Expected: {' or '.join(expected_answers)}"

        return QuestionFeedback(
            q_index=q_index,
            is_correct=is_correct,
            errors=errors,
            suggestion=suggestion,
            confidence=0.8
        )

    def _evaluate_translation_response(
        self,
        q_index: int,
        user_response: str,
        expected_answer: str,
        question_text: str,
        lesson_context: Dict[str, Any]
    ) -> QuestionFeedback:
        """Evaluate translation response using hybrid approach."""

        # First, apply heuristic checks
        heuristic_errors = []
        heuristic_errors.extend(self.heuristics.detect_english_in_arabic(user_response))
        heuristic_errors.extend(self.heuristics.detect_spelling_errors(user_response))
        heuristic_errors.extend(self.heuristics.detect_missing_transliteration(user_response, expected_answer))

        # Then use LLM judge for sophisticated analysis
        llm_feedback = self.llm_judge.evaluate_translation_response(
            question=question_text,
            expected_answer=expected_answer,
            user_response=user_response,
            context=lesson_context
        )

        # Combine heuristic and LLM results
        all_errors = heuristic_errors + llm_feedback.errors

        # Remove duplicate errors
        unique_errors = self._deduplicate_errors(all_errors)

        # Final correctness decision (LLM judge takes precedence unless heuristics find critical errors)
        critical_heuristic_errors = [e for e in heuristic_errors if e.severity == "high"]
        is_correct = llm_feedback.is_correct and len(critical_heuristic_errors) == 0

        return QuestionFeedback(
            q_index=q_index,
            is_correct=is_correct,
            errors=unique_errors,
            suggestion=llm_feedback.suggestion,
            confidence=llm_feedback.confidence
        )

    def _deduplicate_errors(self, errors: List[ErrorDetail]) -> List[ErrorDetail]:
        """Remove duplicate errors based on type and token."""
        seen = set()
        unique_errors = []

        for error in errors:
            key = (error.type, error.token.lower())
            if key not in seen:
                seen.add(key)
                unique_errors.append(error)

        return unique_errors

    def _get_question_context(self, q_index: int, quiz_context: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Extract question context from quiz data."""
        questions = quiz_context.get("questions", [])

        if q_index < len(questions):
            return questions[q_index]

        return None

    def _generate_overall_feedback(self, score: float, feedback_list: List[QuestionFeedback]) -> str:
        """Generate overall feedback message based on performance."""
        percentage = int(score * 100)

        if score >= 0.9:
            return f"Excellent work! You scored {percentage}%. Your Lebanese Arabic skills are developing nicely."
        elif score >= 0.7:
            return f"Good job! You scored {percentage}%. Review the feedback below to improve further."
        elif score >= 0.5:
            return f"Keep practicing! You scored {percentage}%. Focus on the areas highlighted in the feedback."
        else:
            return f"You scored {percentage}%. Don't worry - learning Lebanese Arabic takes time. Review the lesson content and try again."