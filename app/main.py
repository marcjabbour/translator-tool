"""
FastAPI application for story generation service.
Implements POST /api/v1/story endpoint with authentication and rate limiting.
"""

import os
import logging
from typing import Dict, Any
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from .models import LessonRequest, LessonResponse, LessonCreate, QuizRequest, QuizResponse, QuizQuestion, DatabaseManager
from .ai_controller import AIController, StoryGenerationRequest, QuizGenerationRequest
from .auth_controller import AuthController
from .rate_limiter import RateLimiter
from .cache_service import create_cache_service

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global instances
db_manager: DatabaseManager = None
ai_controller: AIController = None
auth_controller: AuthController = None
rate_limiter: RateLimiter = None
cache_service = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager."""
    global db_manager, ai_controller, auth_controller, rate_limiter, cache_service

    # Initialize services
    database_url = os.getenv("DATABASE_URL", "postgresql://localhost/translator_tool")
    db_manager = DatabaseManager(database_url)
    db_manager.create_tables()

    # Initialize cache service (use Redis if available, otherwise in-memory)
    use_redis = os.getenv("REDIS_URL") is not None
    cache_service = create_cache_service(use_redis=use_redis)

    # Initialize AI controller with cache service
    ai_controller = AIController(cache_service=cache_service)
    auth_controller = AuthController()
    rate_limiter = RateLimiter()

    logger.info("Application startup completed")
    yield
    logger.info("Application shutdown")


# FastAPI app initialization
app = FastAPI(
    title="Translator Tool API",
    description="Story generation service for language learning",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Security
security = HTTPBearer()


async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> Dict[str, Any]:
    """
    Validate JWT token and return user information.

    Args:
        credentials: Bearer token from request

    Returns:
        User information from token

    Raises:
        HTTPException: If token is invalid or expired
    """
    try:
        user_data = auth_controller.validate_token(credentials.credentials)
        return user_data
    except Exception as e:
        logger.error(f"Authentication failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def check_rate_limit(user_data: Dict[str, Any] = Depends(get_current_user)) -> None:
    """
    Check rate limiting for story generation endpoint.

    Args:
        user_data: Authenticated user data

    Raises:
        HTTPException: If rate limit exceeded
    """
    user_id = user_data.get("sub") or user_data.get("user_id")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid user data in token"
        )

    if not rate_limiter.check_limit(user_id, "story_generation"):
        remaining = rate_limiter.get_remaining_requests(user_id, "story_generation")
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Rate limit exceeded. {remaining} requests remaining for today.",
            headers={"Retry-After": str(rate_limiter.get_reset_time())}
        )


@app.post("/api/v1/story", response_model=LessonResponse)
async def generate_story(
    request: LessonRequest,
    user_data: Dict[str, Any] = Depends(get_current_user),
    rate_check: None = Depends(check_rate_limit)
) -> LessonResponse:
    """
    Generate a contextual story for language learning.

    Args:
        request: Story generation parameters
        user_data: Authenticated user information
        rate_check: Rate limiting validation

    Returns:
        Generated lesson with English and Lebanese Arabic text

    Raises:
        HTTPException: For validation or generation errors
    """
    try:
        logger.info(f"Story generation request: topic={request.topic}, level={request.level}, seed={request.seed}")

        # Create AI generation request
        ai_request = StoryGenerationRequest(
            topic=request.topic,
            level=request.level,
            seed=request.seed
        )

        # Generate story using AI controller
        story_response = ai_controller.generate_story(ai_request)

        # Get database repository
        repository = db_manager.get_repository()

        # Create lesson data
        lesson_data = LessonCreate(
            topic=request.topic,
            level=request.level,
            en_text=story_response.en_text,
            la_text=story_response.la_text,
            meta=story_response.meta
        )

        # Store in database (with deduplication)
        lesson = repository.create_lesson(lesson_data)

        if not lesson:
            logger.error("Failed to create or retrieve lesson")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to store lesson"
            )

        # Increment rate limit counter
        user_id = user_data.get("sub") or user_data.get("user_id")
        rate_limiter.increment_usage(user_id, "story_generation")

        # Return response
        response = LessonResponse(
            lesson_id=str(lesson.lesson_id),
            en_text=lesson.en_text,
            la_text=lesson.la_text,
            meta=lesson.meta or {}
        )

        logger.info(f"Story generated successfully: lesson_id={response.lesson_id}")
        return response

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Story generation failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during story generation"
        )


@app.post("/api/v1/quiz", response_model=QuizResponse)
async def generate_quiz(
    request: QuizRequest,
    user_data: Dict[str, Any] = Depends(get_current_user),
    rate_check: None = Depends(check_rate_limit)
) -> QuizResponse:
    """
    Generate a quiz based on an existing lesson.

    Args:
        request: Quiz generation parameters with lesson_id
        user_data: Authenticated user information
        rate_check: Rate limiting validation

    Returns:
        Generated quiz with questions and answer key

    Raises:
        HTTPException: For validation or generation errors
    """
    try:
        logger.info(f"Quiz generation request: lesson_id={request.lesson_id}")

        # Get lesson repository
        lesson_repository = db_manager.get_repository()

        # Retrieve lesson by ID
        lesson = lesson_repository.get_lesson_by_id(request.lesson_id)
        if not lesson:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Lesson not found: {request.lesson_id}"
            )

        # Check if lesson has complete translation for quiz generation
        if not lesson.en_text or not lesson.la_text:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Lesson must have both English and Arabic text for quiz generation"
            )

        # Get quiz repository
        quiz_repository = db_manager.get_quiz_repository()

        # Check if quiz already exists for this lesson
        existing_quiz = quiz_repository.get_quiz_by_lesson_id(request.lesson_id)
        if existing_quiz:
            # Return existing quiz
            questions = [
                QuizQuestion(
                    type=q["type"],
                    question=q["question"],
                    answer=q["answer"],
                    choices=q.get("choices"),
                    rationale=q.get("rationale")
                )
                for q in existing_quiz.questions
            ]

            response = QuizResponse(
                quiz_id=str(existing_quiz.quiz_id),
                lesson_id=str(existing_quiz.lesson_id),
                questions=questions,
                meta=existing_quiz.answer_key
            )

            logger.info(f"Returning existing quiz: quiz_id={response.quiz_id}")
            return response

        # Create AI generation request
        ai_request = QuizGenerationRequest(
            lesson_id=request.lesson_id,
            en_text=lesson.en_text,
            la_text=lesson.la_text,
            topic=lesson.topic,
            level=lesson.level
        )

        # Generate quiz using AI controller
        quiz_response = ai_controller.generate_quiz(ai_request)

        # Prepare questions for database storage
        questions_data = [
            {
                "type": q.type,
                "question": q.question,
                "answer": q.answer,
                "choices": q.choices,
                "rationale": q.rationale
            }
            for q in quiz_response.questions
        ]

        # Store quiz in database
        quiz = quiz_repository.create_quiz(
            lesson_id=request.lesson_id,
            questions=questions_data,
            answer_key=quiz_response.answer_key
        )

        # Increment rate limit counter
        user_id = user_data.get("sub") or user_data.get("user_id")
        rate_limiter.increment_usage(user_id, "story_generation")  # Use same rate limit as stories

        # Return response
        response = QuizResponse(
            quiz_id=str(quiz.quiz_id),
            lesson_id=str(quiz.lesson_id),
            questions=quiz_response.questions,
            meta=quiz_response.meta
        )

        logger.info(f"Quiz generated successfully: quiz_id={response.quiz_id}")
        return response

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Quiz generation failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during quiz generation"
        )


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy", "service": "translator-tool-api"}


@app.get("/api/v1/health")
async def api_health_check():
    """API health check with database connectivity."""
    try:
        repository = db_manager.get_repository()
        lesson_count = repository.get_lesson_count()
        return {
            "status": "healthy",
            "database": "connected",
            "total_lessons": lesson_count
        }
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database connection failed"
        )