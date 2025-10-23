"""
FastAPI application for story generation service.
Implements POST /api/v1/story endpoint with authentication and rate limiting.
"""

import os
import logging
from typing import Dict, Any, List
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from .models import (
    LessonRequest, LessonResponse, LessonCreate, QuizRequest, QuizResponse, QuizQuestion,
    UserProgressUpdate, UserProgressResponse, QuizAttemptCreate, QuizAttemptResponse,
    UserProfileResponse, DashboardStats, DatabaseManager, EvaluationRequest, EvaluationResponse,
    AttemptCreate, ErrorCreate, ProgressRequest, ProgressResponse,
    UserRegistrationRequest, UserLoginRequest, TokenRefreshRequest, AuthResponse, TokenResponse,
    UserProfileUpdate, AuthUserProfileResponse, SyncRequest, SyncResponse, SyncStatus, SyncItemRequest
)
from .ai_controller import AIController, StoryGenerationRequest, QuizGenerationRequest
from .auth_controller import AuthController
from .rate_limiter import RateLimiter
from .cache_service import create_cache_service
from .progress_controller import ProgressController
from .evaluation_service import EvaluationService
from .progress_service import ProgressService
from .sync_service import SyncService, SyncItem, SyncResult

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global instances
db_manager: DatabaseManager = None
ai_controller: AIController = None
auth_controller: AuthController = None
rate_limiter: RateLimiter = None
cache_service = None
evaluation_service: EvaluationService = None
progress_service: ProgressService = None
sync_service: SyncService = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager."""
    global db_manager, ai_controller, auth_controller, rate_limiter, cache_service, evaluation_service, progress_service, sync_service

    # Initialize services
    database_url = os.getenv("DATABASE_URL", "postgresql://localhost/translator_tool")
    db_manager = DatabaseManager(database_url)
    db_manager.create_tables()

    # Initialize cache service (use Redis if available, otherwise in-memory)
    use_redis = os.getenv("REDIS_URL") is not None
    cache_service = create_cache_service(use_redis=use_redis)

    # Initialize AI controller with cache service
    ai_controller = AIController(cache_service=cache_service)
    auth_controller = AuthController(db_manager=db_manager, cache_service=cache_service)
    rate_limiter = RateLimiter()

    # Initialize evaluation service
    evaluation_service = EvaluationService(cache_service=cache_service)

    # Initialize progress service
    progress_service = ProgressService(db_manager=db_manager)

    # Initialize sync service
    sync_service = SyncService(db_manager=db_manager, cache_service=cache_service)

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


# User Progress Tracking Endpoints

@app.post("/api/v1/progress/lesson/{lesson_id}/view")
async def track_lesson_view(
    lesson_id: str,
    user_data: Dict[str, Any] = Depends(get_current_user)
) -> UserProgressResponse:
    """Track when a user views a lesson."""
    try:
        user_id = user_data.get("sub") or user_data.get("user_id")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user token"
            )

        progress_repo = db_manager.get_progress_repository()
        profile_repo = db_manager.get_profile_repository()
        controller = ProgressController(progress_repo, profile_repo)

        return controller.track_lesson_view(user_id, lesson_id)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to track lesson view: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to track lesson view"
        )


@app.post("/api/v1/progress/lesson/{lesson_id}/toggle")
async def track_translation_toggle(
    lesson_id: str,
    user_data: Dict[str, Any] = Depends(get_current_user)
) -> UserProgressResponse:
    """Track when a user toggles translation view."""
    try:
        user_id = user_data.get("sub") or user_data.get("user_id")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user token"
            )

        progress_repo = db_manager.get_progress_repository()
        profile_repo = db_manager.get_profile_repository()
        controller = ProgressController(progress_repo, profile_repo)

        return controller.track_translation_toggle(user_id, lesson_id)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to track translation toggle: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to track translation toggle"
        )


@app.put("/api/v1/progress/lesson/{lesson_id}")
async def update_lesson_progress(
    lesson_id: str,
    update_data: UserProgressUpdate,
    user_data: Dict[str, Any] = Depends(get_current_user)
) -> UserProgressResponse:
    """Update lesson progress with custom data."""
    try:
        user_id = user_data.get("sub") or user_data.get("user_id")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user token"
            )

        progress_repo = db_manager.get_progress_repository()
        profile_repo = db_manager.get_profile_repository()
        controller = ProgressController(progress_repo, profile_repo)

        return controller.update_lesson_progress(user_id, lesson_id, update_data)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to update lesson progress: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to update lesson progress"
        )


@app.post("/api/v1/progress/quiz-attempt")
async def record_quiz_attempt(
    attempt_data: QuizAttemptCreate,
    user_data: Dict[str, Any] = Depends(get_current_user)
) -> QuizAttemptResponse:
    """Record a quiz attempt and update related progress."""
    try:
        user_id = user_data.get("sub") or user_data.get("user_id")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user token"
            )

        progress_repo = db_manager.get_progress_repository()
        profile_repo = db_manager.get_profile_repository()
        controller = ProgressController(progress_repo, profile_repo)

        return controller.record_quiz_attempt(user_id, attempt_data)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to record quiz attempt: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to record quiz attempt"
        )


@app.get("/api/v1/progress/lessons")
async def get_user_progress(
    lesson_id: str = None,
    user_data: Dict[str, Any] = Depends(get_current_user)
) -> List[UserProgressResponse]:
    """Get progress records for a user."""
    try:
        user_id = user_data.get("sub") or user_data.get("user_id")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user token"
            )

        progress_repo = db_manager.get_progress_repository()
        profile_repo = db_manager.get_profile_repository()
        controller = ProgressController(progress_repo, profile_repo)

        return controller.get_user_progress(user_id, lesson_id)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get user progress: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get user progress"
        )


@app.get("/api/v1/progress/quiz-attempts")
async def get_quiz_attempts(
    quiz_id: str = None,
    user_data: Dict[str, Any] = Depends(get_current_user)
) -> List[QuizAttemptResponse]:
    """Get quiz attempts for a user."""
    try:
        user_id = user_data.get("sub") or user_data.get("user_id")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user token"
            )

        progress_repo = db_manager.get_progress_repository()
        profile_repo = db_manager.get_profile_repository()
        controller = ProgressController(progress_repo, profile_repo)

        return controller.get_quiz_attempts(user_id, quiz_id)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get quiz attempts: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get quiz attempts"
        )


@app.get("/api/v1/profile")
async def get_user_profile(
    user_data: Dict[str, Any] = Depends(get_current_user)
) -> UserProfileResponse:
    """Get or create user profile with aggregated stats."""
    try:
        user_id = user_data.get("sub") or user_data.get("user_id")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user token"
            )

        progress_repo = db_manager.get_progress_repository()
        profile_repo = db_manager.get_profile_repository()
        controller = ProgressController(progress_repo, profile_repo)

        return controller.get_user_profile(user_id)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get user profile: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get user profile"
        )


@app.get("/api/v1/dashboard")
async def get_dashboard_stats(
    user_data: Dict[str, Any] = Depends(get_current_user)
) -> DashboardStats:
    """Get comprehensive dashboard statistics."""
    try:
        user_id = user_data.get("sub") or user_data.get("user_id")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user token"
            )

        progress_repo = db_manager.get_progress_repository()
        profile_repo = db_manager.get_profile_repository()
        controller = ProgressController(progress_repo, profile_repo)

        return controller.get_dashboard_stats(user_id)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get dashboard stats: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get dashboard stats"
        )


@app.get("/api/v1/analytics")
async def get_learning_analytics(
    days: int = 30,
    user_data: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """Get detailed learning analytics for a user."""
    try:
        user_id = user_data.get("sub") or user_data.get("user_id")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user token"
            )

        if days < 1 or days > 365:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Days parameter must be between 1 and 365"
            )

        progress_repo = db_manager.get_progress_repository()
        profile_repo = db_manager.get_profile_repository()
        controller = ProgressController(progress_repo, profile_repo)

        return controller.get_learning_analytics(user_id, days)

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get learning analytics: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to get learning analytics"
        )


# Evaluation Endpoint

@app.post("/api/v1/evaluate", response_model=EvaluationResponse)
async def evaluate_quiz_responses(
    request: EvaluationRequest,
    user_data: Dict[str, Any] = Depends(get_current_user)
) -> EvaluationResponse:
    """
    Evaluate quiz responses using hybrid error detection approach.

    Args:
        request: Evaluation request with user responses and quiz context
        user_data: Authenticated user information

    Returns:
        Evaluation response with attempt ID, score, and detailed feedback

    Raises:
        HTTPException: For validation or evaluation errors
    """
    try:
        # Validate user authentication
        authenticated_user_id = user_data.get("sub") or user_data.get("user_id")
        if not authenticated_user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user token"
            )

        # Ensure the user ID in request matches authenticated user
        if request.user_id != authenticated_user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="User ID mismatch"
            )

        logger.info(f"Evaluation request for user {request.user_id}, quiz {request.quiz_id}")

        # Get quiz repository to fetch quiz context
        quiz_repository = db_manager.get_quiz_repository()
        quiz = quiz_repository.get_quiz_by_id(request.quiz_id)

        if not quiz:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Quiz not found: {request.quiz_id}"
            )

        # Get lesson for additional context
        lesson_repository = db_manager.get_repository()
        lesson = lesson_repository.get_lesson_by_id(request.lesson_id)

        if not lesson:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Lesson not found: {request.lesson_id}"
            )

        # Prepare evaluation request for service
        from .evaluation_service import EvaluationRequest as ServiceEvaluationRequest

        service_request = ServiceEvaluationRequest(
            user_id=request.user_id,
            lesson_id=request.lesson_id,
            quiz_id=request.quiz_id,
            responses=request.responses,
            quiz_context={
                "questions": quiz.questions,
                "answer_key": quiz.answer_key,
                "topic": lesson.topic,
                "level": lesson.level
            }
        )

        # Perform evaluation using service
        evaluation_result = evaluation_service.evaluate_quiz_responses(service_request)

        # Store attempt in database
        attempt_repo = db_manager.get_attempt_repository()
        error_repo = db_manager.get_error_repository()

        # Prepare evaluation data for database storage
        eval_data = {
            "feedback": [
                {
                    "q_index": feedback.q_index,
                    "is_correct": feedback.is_correct,
                    "errors": [
                        {
                            "type": error.type,
                            "token": error.token,
                            "hint": error.hint,
                            "severity": error.severity
                        }
                        for error in feedback.errors
                    ],
                    "suggestion": feedback.suggestion,
                    "confidence": feedback.confidence
                }
                for feedback in evaluation_result.feedback
            ],
            "overall_feedback": evaluation_result.overall_feedback
        }

        # Store attempt record
        attempt_data = AttemptCreate(
            user_id=request.user_id,
            lesson_id=request.lesson_id,
            quiz_id=request.quiz_id,
            responses=request.responses,
            score=evaluation_result.score,
            eval=eval_data
        )

        attempt = attempt_repo.create_attempt(attempt_data)

        # Store individual errors for analytics
        error_records = []
        for feedback in evaluation_result.feedback:
            for error in feedback.errors:
                error_records.append(ErrorCreate(
                    user_id=request.user_id,
                    lesson_id=request.lesson_id,
                    quiz_id=request.quiz_id,
                    q_index=feedback.q_index,
                    error_type=error.type,
                    token=error.token,
                    details={
                        "hint": error.hint,
                        "severity": error.severity,
                        "position": error.position
                    }
                ))

        if error_records:
            error_repo.create_errors_batch(error_records)

        # Prepare response using the actual attempt_id from database
        from .models import QuestionFeedback as ResponseQuestionFeedback, ErrorFeedback

        response_feedback = []
        for feedback in evaluation_result.feedback:
            response_errors = [
                ErrorFeedback(
                    type=error.type,
                    token=error.token,
                    hint=error.hint
                )
                for error in feedback.errors
            ]

            response_feedback.append(ResponseQuestionFeedback(
                q_index=feedback.q_index,
                ok=feedback.is_correct,
                errors=response_errors,
                suggestion=feedback.suggestion
            ))

        response = EvaluationResponse(
            attempt_id=str(attempt.attempt_id),
            score=evaluation_result.score,
            feedback=response_feedback
        )

        logger.info(f"Evaluation completed for user {request.user_id}: score={evaluation_result.score:.2f}, attempt_id={response.attempt_id}")
        return response

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Evaluation failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during evaluation"
        )


@app.get("/api/v1/progress", response_model=ProgressResponse)
async def get_user_progress(
    user_id: str,
    days_back: int = 30,
    user_data: Dict[str, Any] = Depends(get_current_user)
) -> ProgressResponse:
    """
    Get user progress analytics including trends and improvement areas.

    Args:
        user_id: User identifier (must match authenticated user)
        days_back: Number of days to look back for trends (1-365)
        user_data: Authenticated user data

    Returns:
        Progress analytics with weekly metrics, trends, and improvement areas

    Raises:
        HTTPException: If user is not authorized or service error occurs
    """
    try:
        # Validate user authorization
        authenticated_user_id = user_data.get("sub") or user_data.get("user_id")
        if not authenticated_user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user data in token"
            )

        # Check if user is requesting their own data
        if user_id != authenticated_user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied: can only view your own progress"
            )

        # Validate days_back parameter
        if not (1 <= days_back <= 365):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="days_back must be between 1 and 365"
            )

        logger.info(f"Fetching progress for user {user_id}, days_back={days_back}")

        # Get progress summary from service
        progress_summary = progress_service.get_user_progress_summary(user_id, days_back)

        # Convert to API response format
        from .models import ProgressMetrics, TrendPoint

        weekly_metrics = ProgressMetrics(
            accuracy=progress_summary.weekly.accuracy,
            time_minutes=progress_summary.weekly.time_minutes,
            error_breakdown=progress_summary.weekly.error_breakdown,
            lessons_completed=progress_summary.weekly.lessons_completed,
            streak_days=progress_summary.weekly.streak_days,
            improvement_rate=progress_summary.weekly.improvement_rate
        )

        trend_points = [
            TrendPoint(
                date=point.date.strftime("%Y-%m-%d"),
                accuracy=point.accuracy,
                time_minutes=point.time_minutes
            )
            for point in progress_summary.trends
        ]

        response = ProgressResponse(
            weekly=weekly_metrics,
            trends=trend_points,
            improvement_areas=progress_summary.improvement_areas
        )

        logger.info(f"Progress retrieved for user {user_id}: accuracy={weekly_metrics.accuracy:.2f}, trends={len(trend_points)} points")
        return response

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Progress retrieval failed for user {user_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error while retrieving progress data"
        )


# Authentication Endpoints

@app.post("/api/v1/auth/register", response_model=AuthResponse)
async def register_user(request: UserRegistrationRequest) -> AuthResponse:
    """
    Register a new user account.

    Args:
        request: User registration data

    Returns:
        Authentication response with tokens and user data

    Raises:
        HTTPException: If registration fails
    """
    try:
        logger.info(f"User registration attempt: {request.email}")

        # Prepare profile data
        profile_data = {
            "dialect": request.dialect,
            "difficulty": request.difficulty,
            "translit_style": request.translit_style or {}
        }

        # Register user through auth controller
        result = auth_controller.register_user(
            email=request.email,
            password=request.password,
            profile_data=profile_data
        )

        # Prepare response
        response = AuthResponse(
            user_id=result["user_id"],
            email=result["email"],
            access_token=result["access_token"],
            refresh_token=result["refresh_token"],
            expires_in=86400,  # 24 hours
            profile=result["profile"]
        )

        logger.info(f"User registered successfully: {request.email}")
        return response

    except ValueError as e:
        logger.warning(f"User registration validation failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )
    except Exception as e:
        logger.error(f"User registration failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during registration"
        )


@app.post("/api/v1/auth/login", response_model=AuthResponse)
async def login_user(request: UserLoginRequest) -> AuthResponse:
    """
    Authenticate user with email and password.

    Args:
        request: User login credentials

    Returns:
        Authentication response with tokens and user data

    Raises:
        HTTPException: If authentication fails
    """
    try:
        logger.info(f"User login attempt: {request.email}")

        # Authenticate user through auth controller
        result = auth_controller.authenticate_user(
            email=request.email,
            password=request.password
        )

        # Prepare response
        response = AuthResponse(
            user_id=result["user_id"],
            email=result["email"],
            access_token=result["access_token"],
            refresh_token=result["refresh_token"],
            expires_in=86400,  # 24 hours
            profile=result["profile"]
        )

        logger.info(f"User authenticated successfully: {request.email}")
        return response

    except ValueError as e:
        logger.warning(f"User authentication failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials"
        )
    except Exception as e:
        logger.error(f"User authentication error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during authentication"
        )


@app.post("/api/v1/auth/refresh", response_model=TokenResponse)
async def refresh_token(request: TokenRefreshRequest) -> TokenResponse:
    """
    Refresh access token using refresh token.

    Args:
        request: Token refresh request

    Returns:
        New tokens

    Raises:
        HTTPException: If token refresh fails
    """
    try:
        logger.info("Token refresh attempt")

        # Refresh tokens through auth controller
        result = auth_controller.refresh_tokens(request.refresh_token)

        # Prepare response
        response = TokenResponse(
            access_token=result["access_token"],
            refresh_token=result["refresh_token"],
            expires_in=86400  # 24 hours
        )

        logger.info("Token refreshed successfully")
        return response

    except ValueError as e:
        logger.warning(f"Token refresh failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token"
        )
    except Exception as e:
        logger.error(f"Token refresh error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during token refresh"
        )


@app.post("/api/v1/auth/logout")
async def logout_user(user_data: Dict[str, Any] = Depends(get_current_user)):
    """
    Logout user by invalidating session.

    Args:
        user_data: Authenticated user data

    Returns:
        Success message

    Raises:
        HTTPException: If logout fails
    """
    try:
        user_id = user_data.get("sub") or user_data.get("user_id")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user data"
            )

        logger.info(f"User logout attempt: {user_id}")

        # Logout user through auth controller
        success = auth_controller.logout_user(user_id)

        if success:
            logger.info(f"User logged out successfully: {user_id}")
            return {"message": "Logged out successfully"}
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Logout failed"
            )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Logout error: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error during logout"
        )


@app.get("/api/v1/auth/profile", response_model=AuthUserProfileResponse)
async def get_user_profile_auth(user_data: Dict[str, Any] = Depends(get_current_user)) -> AuthUserProfileResponse:
    """
    Get current user's profile data.

    Args:
        user_data: Authenticated user data

    Returns:
        User profile data

    Raises:
        HTTPException: If profile retrieval fails
    """
    try:
        user_id = user_data.get("sub") or user_data.get("user_id")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user data"
            )

        logger.info(f"Profile retrieval for user: {user_id}")

        # Get profile through auth controller
        profile = auth_controller.get_user_profile(user_id)

        # Prepare response
        response = AuthUserProfileResponse(
            user_id=user_id,
            email=user_data.get("email", ""),
            display_name=profile.get("settings", {}).get("display_name"),
            dialect=profile.get("dialect", "lebanese"),
            difficulty=profile.get("difficulty", "beginner"),
            translit_style=profile.get("translit_style", {}),
            settings=profile.get("settings", {}),
            last_login=profile.get("settings", {}).get("last_login")
        )

        logger.info(f"Profile retrieved successfully for user: {user_id}")
        return response

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Profile retrieval failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error while retrieving profile"
        )


@app.put("/api/v1/auth/profile", response_model=AuthUserProfileResponse)
async def update_user_profile_auth(
    request: UserProfileUpdate,
    user_data: Dict[str, Any] = Depends(get_current_user)
) -> AuthUserProfileResponse:
    """
    Update current user's profile data.

    Args:
        request: Profile update data
        user_data: Authenticated user data

    Returns:
        Updated user profile data

    Raises:
        HTTPException: If profile update fails
    """
    try:
        user_id = user_data.get("sub") or user_data.get("user_id")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user data"
            )

        logger.info(f"Profile update for user: {user_id}")

        # Prepare update data
        update_data = {}
        if request.display_name is not None:
            update_data["display_name"] = request.display_name
        if request.dialect is not None:
            update_data["preferred_level"] = request.dialect  # Map to existing field
        if request.difficulty is not None:
            update_data["preferred_level"] = request.difficulty
        if request.settings is not None:
            update_data["settings"] = request.settings
        if request.translit_style is not None:
            if "settings" not in update_data:
                update_data["settings"] = {}
            update_data["settings"]["translit_style"] = request.translit_style

        # Update profile through auth controller
        success = auth_controller.update_user_profile(user_id, update_data)

        if not success:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Profile update failed"
            )

        # Get updated profile
        profile = auth_controller.get_user_profile(user_id)

        # Prepare response
        response = AuthUserProfileResponse(
            user_id=user_id,
            email=user_data.get("email", ""),
            display_name=profile.get("settings", {}).get("display_name"),
            dialect=profile.get("dialect", "lebanese"),
            difficulty=profile.get("difficulty", "beginner"),
            translit_style=profile.get("translit_style", {}),
            settings=profile.get("settings", {})
        )

        logger.info(f"Profile updated successfully for user: {user_id}")
        return response

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Profile update failed: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Internal server error while updating profile"
        )


# Synchronization Endpoints

@app.post("/api/v1/sync", response_model=SyncResponse)
async def sync_user_data(
    request: SyncRequest,
    user_data: Dict[str, Any] = Depends(get_current_user)
) -> SyncResponse:
    """
    Synchronize user data between client and server.

    Args:
        request: Sync request with client data and timestamp
        user_data: Authenticated user information

    Returns:
        Sync response with server changes and conflicts

    Raises:
        HTTPException: For sync errors
    """
    try:
        user_id = user_data.get("sub") or user_data.get("user_id")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user data in token"
            )

        logger.info(f"Sync request for user: {user_id}")

        # Convert SyncItemRequest to SyncItem
        client_sync_items = []
        for item in request.client_data:
            sync_item = SyncItem(
                table_name=item.table_name,
                item_id=item.item_id,
                user_id=user_id,
                data=item.data,
                updated_at=item.updated_at,
                operation=item.operation
            )
            client_sync_items.append(sync_item)

        # Perform synchronization
        sync_result = sync_service.sync_user_data(
            user_id=user_id,
            client_data=client_sync_items,
            last_sync=request.last_sync
        )

        # Prepare response
        response = SyncResponse(
            result=sync_result,
            user_id=user_id,
            sync_timestamp=sync_result.last_sync
        )

        logger.info(f"Sync completed for user {user_id}: {sync_result.synced_count} items synced, {sync_result.conflict_count} conflicts")
        return response

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Sync failed for user {user_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Sync operation failed: {str(e)}"
        )


@app.get("/api/v1/sync/status", response_model=SyncStatus)
async def get_sync_status(
    user_data: Dict[str, Any] = Depends(get_current_user)
) -> SyncStatus:
    """
    Get synchronization status for the user.

    Args:
        user_data: Authenticated user information

    Returns:
        Current sync status

    Raises:
        HTTPException: For status retrieval errors
    """
    try:
        user_id = user_data.get("sub") or user_data.get("user_id")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user data in token"
            )

        # Get sync status
        status_info = sync_service.get_sync_status(user_id)

        return SyncStatus(
            is_syncing=status_info.get("is_syncing", False),
            last_sync=status_info.get("last_sync"),
            pending_items=status_info.get("pending_items", 0),
            last_error=status_info.get("last_error"),
            sync_enabled=status_info.get("sync_enabled", True)
        )

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to get sync status for user {user_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to retrieve sync status"
        )


@app.post("/api/v1/sync/queue")
async def add_to_sync_queue(
    item: SyncItemRequest,
    user_data: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, str]:
    """
    Add item to offline sync queue.

    Args:
        item: Sync item to queue
        user_data: Authenticated user information

    Returns:
        Queue confirmation

    Raises:
        HTTPException: For queue errors
    """
    try:
        user_id = user_data.get("sub") or user_data.get("user_id")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user data in token"
            )

        # Convert to SyncItem and add to queue
        sync_item = SyncItem(
            table_name=item.table_name,
            item_id=item.item_id,
            user_id=user_id,
            data=item.data,
            updated_at=item.updated_at,
            operation=item.operation
        )

        queue_id = sync_service.queue_offline_action(sync_item)

        logger.info(f"Added item to sync queue for user {user_id}: {queue_id}")
        return {"status": "queued", "queue_id": queue_id}

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to queue sync item for user {user_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to queue sync item"
        )


@app.post("/api/v1/sync/process-queue")
async def process_sync_queue(
    user_data: Dict[str, Any] = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Process all queued sync items for the user.

    Args:
        user_data: Authenticated user information

    Returns:
        Processing results

    Raises:
        HTTPException: For processing errors
    """
    try:
        user_id = user_data.get("sub") or user_data.get("user_id")
        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid user data in token"
            )

        # Process offline queue
        result = sync_service.process_offline_queue(user_id)

        logger.info(f"Processed sync queue for user {user_id}: {result}")
        return result

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Failed to process sync queue for user {user_id}: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to process sync queue"
        )