"""
Data models for lessons and database integration.
Implements Supabase/PostgreSQL schema with deduplication logic.
"""

import uuid
from datetime import datetime
from typing import Optional, Dict, Any, List
from dataclasses import dataclass
from sqlalchemy import Column, String, Text, DateTime, Integer, Boolean, Float, UniqueConstraint, Index, ForeignKey
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from pydantic import BaseModel, Field

Base = declarative_base()


class Lesson(Base):
    """
    Lessons table model for PostgreSQL/Supabase.

    Schema matches architecture/6-data-model-sql-supabasepostgres.md
    """
    __tablename__ = "lessons"

    lesson_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    topic = Column(Text, nullable=True)
    level = Column(Text, nullable=True)
    en_text = Column(Text, nullable=False)
    la_text = Column(Text, nullable=False, comment="transliterated Lebanese Arabic")
    meta = Column(JSONB, nullable=True, comment="seed, constraints")
    created_at = Column(DateTime(timezone=True), default=func.now())

    # Deduplication constraint
    __table_args__ = (
        UniqueConstraint('topic', 'en_text', name='unique_topic_en_text'),
        Index('idx_lessons_topic_level', 'topic', 'level'),  # Performance index
    )


class Quiz(Base):
    """
    Quizzes table model for PostgreSQL/Supabase.

    Schema matches architecture/6-data-model-sql-supabasepostgres.md
    """
    __tablename__ = "quizzes"

    quiz_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    lesson_id = Column(UUID(as_uuid=True), ForeignKey('lessons.lesson_id', ondelete='CASCADE'), nullable=False)
    questions = Column(JSONB, nullable=False, comment="typed schema (see API)")
    answer_key = Column(JSONB, nullable=False)
    created_at = Column(DateTime(timezone=True), default=func.now())

    # Relationship to lesson
    lesson = relationship("Lesson", backref="quizzes")


class UserProgress(Base):
    """
    User progress tracking table for storing lesson completion and performance data.

    Tracks individual user progress through lessons, quizzes, and overall learning journey.
    """
    __tablename__ = "user_progress"

    progress_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(String, nullable=False, index=True, comment="From JWT token (sub or user_id)")
    lesson_id = Column(UUID(as_uuid=True), ForeignKey('lessons.lesson_id', ondelete='CASCADE'), nullable=False)

    # Progress tracking fields
    status = Column(String, nullable=False, default='not_started',
                   comment="not_started, in_progress, completed")
    completion_date = Column(DateTime(timezone=True), nullable=True)
    time_spent_minutes = Column(Integer, default=0, comment="Total time spent on lesson in minutes")

    # Lesson interaction tracking
    lesson_views = Column(Integer, default=0, comment="Number of times lesson was viewed")
    translation_toggles = Column(Integer, default=0, comment="Number of translation toggle interactions")

    # Quiz performance (if quiz was taken)
    quiz_taken = Column(Boolean, default=False)
    quiz_score = Column(Float, nullable=True, comment="Score as percentage (0.0-1.0)")
    quiz_attempts = Column(Integer, default=0, comment="Number of quiz attempts")
    best_quiz_score = Column(Float, nullable=True, comment="Best quiz score achieved")

    # Metadata
    last_accessed = Column(DateTime(timezone=True), default=func.now())
    created_at = Column(DateTime(timezone=True), default=func.now())
    updated_at = Column(DateTime(timezone=True), default=func.now(), onupdate=func.now())

    # Relationships
    lesson = relationship("Lesson", backref="user_progress")

    # Constraints and indexes
    __table_args__ = (
        UniqueConstraint('user_id', 'lesson_id', name='unique_user_lesson_progress'),
        Index('idx_user_progress_user_id', 'user_id'),
        Index('idx_user_progress_status', 'status'),
        Index('idx_user_progress_completion', 'user_id', 'completion_date'),
    )


class QuizAttempt(Base):
    """
    Individual quiz attempt records for detailed progress tracking.

    Stores each quiz attempt with detailed responses and performance metrics.
    """
    __tablename__ = "quiz_attempts"

    attempt_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(String, nullable=False, index=True, comment="From JWT token")
    quiz_id = Column(UUID(as_uuid=True), ForeignKey('quizzes.quiz_id', ondelete='CASCADE'), nullable=False)

    # Attempt data
    responses = Column(JSONB, nullable=False, comment="User responses to each question")
    score = Column(Float, nullable=False, comment="Score as percentage (0.0-1.0)")
    total_questions = Column(Integer, nullable=False)
    correct_answers = Column(Integer, nullable=False)

    # Timing data
    started_at = Column(DateTime(timezone=True), nullable=False)
    completed_at = Column(DateTime(timezone=True), nullable=False)
    time_taken_seconds = Column(Integer, nullable=False, comment="Total time for quiz completion")

    # Question type performance
    mcq_correct = Column(Integer, default=0)
    mcq_total = Column(Integer, default=0)
    translation_correct = Column(Integer, default=0)
    translation_total = Column(Integer, default=0)
    fill_blank_correct = Column(Integer, default=0)
    fill_blank_total = Column(Integer, default=0)

    # Relationships
    quiz = relationship("Quiz", backref="attempts")

    # Indexes
    __table_args__ = (
        Index('idx_quiz_attempts_user_quiz', 'user_id', 'quiz_id'),
        Index('idx_quiz_attempts_score', 'score'),
        Index('idx_quiz_attempts_completed', 'completed_at'),
    )


class Attempt(Base):
    """
    Attempts table for storing quiz evaluation results.

    Schema matches architecture/6-data-model-sql-supabasepostgres.md
    """
    __tablename__ = "attempts"

    attempt_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(String, nullable=False, index=True, comment="From JWT token")
    lesson_id = Column(UUID(as_uuid=True), ForeignKey('lessons.lesson_id', ondelete='CASCADE'), nullable=False)
    quiz_id = Column(UUID(as_uuid=True), ForeignKey('quizzes.quiz_id', ondelete='CASCADE'), nullable=False)

    # Evaluation data
    responses = Column(JSONB, nullable=False, comment="User responses with evaluation feedback")
    score = Column(Float, nullable=True, comment="Score 0..1")
    eval = Column(JSONB, nullable=True, comment="Model feedback per question")

    created_at = Column(DateTime(timezone=True), default=func.now())

    # Relationships
    lesson = relationship("Lesson", backref="attempts")
    quiz = relationship("Quiz", backref="attempts")

    # Indexes
    __table_args__ = (
        Index('idx_attempts_user_id', 'user_id'),
        Index('idx_attempts_user_quiz', 'user_id', 'quiz_id'),
        Index('idx_attempts_score', 'score'),
    )


class Error(Base):
    """
    Errors table for normalized error logging.

    Schema matches architecture/6-data-model-sql-supabasepostgres.md
    """
    __tablename__ = "errors"

    error_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id = Column(String, nullable=False, index=True, comment="From JWT token")
    lesson_id = Column(UUID(as_uuid=True), nullable=True, comment="Associated lesson")
    quiz_id = Column(UUID(as_uuid=True), nullable=True, comment="Associated quiz")
    q_index = Column(Integer, nullable=True, comment="Question index in quiz")

    # Error classification
    error_type = Column(String, nullable=False, comment="Error taxonomy (EN_IN_AR, SPELL_T, etc.)")
    token = Column(String, nullable=True, comment="Offending token/word")
    details = Column(JSONB, nullable=True, comment="Additional error metadata")

    created_at = Column(DateTime(timezone=True), default=func.now())

    # Indexes
    __table_args__ = (
        Index('idx_errors_user_id', 'user_id'),
        Index('idx_errors_type', 'error_type'),
        Index('idx_errors_user_lesson', 'user_id', 'lesson_id'),
    )


class Progress(Base):
    """
    Progress table for storing daily/weekly progress metrics.

    Schema matches architecture/6-data-model-sql-supabasepostgres.md
    """
    __tablename__ = "progress"

    user_id = Column(String, nullable=False, primary_key=True, comment="From JWT token")
    period = Column(Date, nullable=False, primary_key=True, comment="Date for this progress snapshot")

    # Progress metrics stored as JSONB
    metrics = Column(JSONB, nullable=False, comment="accuracy, time_spent, error_breakdown")

    created_at = Column(DateTime(timezone=True), default=func.now())
    updated_at = Column(DateTime(timezone=True), default=func.now(), onupdate=func.now())

    # Indexes
    __table_args__ = (
        Index('idx_progress_user_period', 'user_id', 'period'),
        Index('idx_progress_period', 'period'),
    )


class UserProfile(Base):
    """
    User profile and aggregate statistics table.

    Stores user-level aggregated data and preferences.
    """
    __tablename__ = "user_profiles"

    user_id = Column(String, primary_key=True, comment="From JWT token (sub or user_id)")

    # Profile information
    display_name = Column(String, nullable=True)
    preferred_level = Column(String, nullable=True, comment="beginner, intermediate, advanced")

    # Aggregate statistics
    total_lessons_completed = Column(Integer, default=0)
    total_quizzes_completed = Column(Integer, default=0)
    total_time_spent_minutes = Column(Integer, default=0)
    average_quiz_score = Column(Float, nullable=True)

    # Learning streak tracking
    current_streak_days = Column(Integer, default=0)
    longest_streak_days = Column(Integer, default=0)
    last_activity_date = Column(DateTime(timezone=True), nullable=True)

    # Topic preferences and performance
    favorite_topics = Column(JSONB, default=list, comment="Array of topics user prefers")
    topic_performance = Column(JSONB, default=dict, comment="Performance stats by topic")

    # Settings and preferences
    settings = Column(JSONB, default=dict, comment="User preferences and settings")

    # Timestamps
    created_at = Column(DateTime(timezone=True), default=func.now())
    updated_at = Column(DateTime(timezone=True), default=func.now(), onupdate=func.now())

    # Indexes
    __table_args__ = (
        Index('idx_user_profiles_activity', 'last_activity_date'),
        Index('idx_user_profiles_level', 'preferred_level'),
    )


@dataclass
class LessonCreate:
    """Data class for creating new lessons."""
    topic: str
    level: str
    en_text: str
    la_text: str
    meta: Optional[Dict[str, Any]] = None


class LessonResponse(BaseModel):
    """Pydantic model for API responses."""
    lesson_id: str = Field(..., description="Unique lesson identifier")
    en_text: str = Field(..., description="English text")
    la_text: str = Field(..., description="Lebanese Arabic transliteration")
    meta: Dict[str, Any] = Field(default_factory=dict, description="Lesson metadata")

    class Config:
        from_attributes = True


class LessonRequest(BaseModel):
    """Pydantic model for API requests."""
    topic: str = Field(..., description="Story topic (e.g., coffee_chat)", example="coffee_chat")
    level: str = Field(..., description="Difficulty level", example="beginner")
    seed: Optional[int] = Field(None, description="Seed for consistent generation", example=42)


class QuizQuestion(BaseModel):
    """Pydantic model for quiz questions."""
    type: str = Field(..., description="Question type", example="mcq")
    question: str = Field(..., description="Question text", example="What does 'ahwe' mean?")
    answer: Any = Field(..., description="Correct answer (type varies by question type)")
    choices: Optional[List[str]] = Field(None, description="Multiple choice options")
    rationale: Optional[str] = Field(None, description="Explanation of correct answer")

    class Config:
        from_attributes = True


class QuizRequest(BaseModel):
    """Pydantic model for quiz generation requests."""
    lesson_id: str = Field(..., description="Lesson UUID to generate quiz for", example="550e8400-e29b-41d4-a716-446655440000")


class QuizResponse(BaseModel):
    """Pydantic model for quiz API responses."""
    quiz_id: str = Field(..., description="Unique quiz identifier")
    lesson_id: str = Field(..., description="Associated lesson identifier")
    questions: List[QuizQuestion] = Field(..., description="Quiz questions array")
    meta: Dict[str, Any] = Field(default_factory=dict, description="Quiz metadata")

    class Config:
        from_attributes = True


# User Progress Models
class UserProgressUpdate(BaseModel):
    """Pydantic model for updating user progress."""
    status: Optional[str] = Field(None, description="Progress status", example="completed")
    time_spent_minutes: Optional[int] = Field(None, description="Time spent on lesson", example=15)
    lesson_views: Optional[int] = Field(None, description="Number of lesson views", example=3)
    translation_toggles: Optional[int] = Field(None, description="Number of translation toggles", example=5)

    class Config:
        from_attributes = True


class UserProgressResponse(BaseModel):
    """Pydantic model for user progress API responses."""
    progress_id: str = Field(..., description="Progress record identifier")
    user_id: str = Field(..., description="User identifier")
    lesson_id: str = Field(..., description="Lesson identifier")
    status: str = Field(..., description="Progress status")
    completion_date: Optional[datetime] = Field(None, description="Completion timestamp")
    time_spent_minutes: int = Field(..., description="Total time spent")
    lesson_views: int = Field(..., description="Number of lesson views")
    translation_toggles: int = Field(..., description="Number of translation toggles")
    quiz_taken: bool = Field(..., description="Whether quiz was taken")
    quiz_score: Optional[float] = Field(None, description="Quiz score percentage")
    quiz_attempts: int = Field(..., description="Number of quiz attempts")
    best_quiz_score: Optional[float] = Field(None, description="Best quiz score")
    last_accessed: datetime = Field(..., description="Last access timestamp")

    class Config:
        from_attributes = True


class QuizAttemptCreate(BaseModel):
    """Pydantic model for creating quiz attempts."""
    quiz_id: str = Field(..., description="Quiz identifier")
    responses: List[Dict[str, Any]] = Field(..., description="User responses to questions")
    score: float = Field(..., description="Score percentage", ge=0.0, le=1.0)
    time_taken_seconds: int = Field(..., description="Time taken to complete quiz")
    started_at: datetime = Field(..., description="Quiz start time")
    completed_at: datetime = Field(..., description="Quiz completion time")

    class Config:
        from_attributes = True


class QuizAttemptResponse(BaseModel):
    """Pydantic model for quiz attempt API responses."""
    attempt_id: str = Field(..., description="Attempt identifier")
    user_id: str = Field(..., description="User identifier")
    quiz_id: str = Field(..., description="Quiz identifier")
    score: float = Field(..., description="Score percentage")
    total_questions: int = Field(..., description="Total number of questions")
    correct_answers: int = Field(..., description="Number of correct answers")
    time_taken_seconds: int = Field(..., description="Time taken in seconds")
    started_at: datetime = Field(..., description="Quiz start time")
    completed_at: datetime = Field(..., description="Quiz completion time")
    mcq_correct: int = Field(..., description="MCQ questions correct")
    mcq_total: int = Field(..., description="Total MCQ questions")
    translation_correct: int = Field(..., description="Translation questions correct")
    translation_total: int = Field(..., description="Total translation questions")
    fill_blank_correct: int = Field(..., description="Fill blank questions correct")
    fill_blank_total: int = Field(..., description="Total fill blank questions")

    class Config:
        from_attributes = True


class UserProfileUpdate(BaseModel):
    """Pydantic model for updating user profiles."""
    display_name: Optional[str] = Field(None, description="User display name")
    preferred_level: Optional[str] = Field(None, description="Preferred difficulty level")
    settings: Optional[Dict[str, Any]] = Field(None, description="User preferences")

    class Config:
        from_attributes = True


class UserProfileResponse(BaseModel):
    """Pydantic model for user profile API responses."""
    user_id: str = Field(..., description="User identifier")
    display_name: Optional[str] = Field(None, description="Display name")
    preferred_level: Optional[str] = Field(None, description="Preferred level")
    total_lessons_completed: int = Field(..., description="Total lessons completed")
    total_quizzes_completed: int = Field(..., description="Total quizzes completed")
    total_time_spent_minutes: int = Field(..., description="Total time spent learning")
    average_quiz_score: Optional[float] = Field(None, description="Average quiz score")
    current_streak_days: int = Field(..., description="Current learning streak")
    longest_streak_days: int = Field(..., description="Longest learning streak")
    last_activity_date: Optional[datetime] = Field(None, description="Last activity")
    favorite_topics: List[str] = Field(default_factory=list, description="Favorite topics")
    topic_performance: Dict[str, Any] = Field(default_factory=dict, description="Performance by topic")
    settings: Dict[str, Any] = Field(default_factory=dict, description="User settings")

    class Config:
        from_attributes = True


class DashboardStats(BaseModel):
    """Pydantic model for dashboard statistics."""
    total_lessons_completed: int = Field(..., description="Total lessons completed")
    total_quizzes_completed: int = Field(..., description="Total quizzes completed")
    total_time_spent_minutes: int = Field(..., description="Total learning time")
    average_quiz_score: Optional[float] = Field(None, description="Average quiz score")
    current_streak_days: int = Field(..., description="Current learning streak")
    lessons_this_week: int = Field(..., description="Lessons completed this week")
    recent_activity: List[Dict[str, Any]] = Field(default_factory=list, description="Recent learning activity")
    topic_progress: Dict[str, Any] = Field(default_factory=dict, description="Progress by topic")

    class Config:
        from_attributes = True


from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError
import logging

logger = logging.getLogger(__name__)


class LessonRepository:
    """Repository for lesson data operations with deduplication logic."""

    def __init__(self, db_session: Session):
        """
        Initialize repository with database session.

        Args:
            db_session: SQLAlchemy database session
        """
        self.db = db_session

    def create_lesson(self, lesson_data: LessonCreate) -> Optional[Lesson]:
        """
        Create a new lesson with deduplication logic.

        Args:
            lesson_data: Lesson creation data

        Returns:
            Created lesson or None if duplicate exists

        Raises:
            Exception: For database errors other than duplicates
        """
        try:
            lesson = Lesson(
                topic=lesson_data.topic,
                level=lesson_data.level,
                en_text=lesson_data.en_text,
                la_text=lesson_data.la_text,
                meta=lesson_data.meta or {}
            )

            self.db.add(lesson)
            self.db.commit()
            self.db.refresh(lesson)

            logger.info(f"Created new lesson: {lesson.lesson_id}")
            return lesson

        except IntegrityError as e:
            self.db.rollback()
            if "unique_topic_en_text" in str(e.orig):
                logger.info(f"Duplicate lesson found for topic '{lesson_data.topic}' and text '{lesson_data.en_text[:30]}...'")
                return self.get_existing_lesson(lesson_data.topic, lesson_data.en_text)
            else:
                logger.error(f"Database integrity error: {e}")
                raise

        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed to create lesson: {e}")
            raise

    def get_existing_lesson(self, topic: str, en_text: str) -> Optional[Lesson]:
        """
        Retrieve existing lesson by topic and English text.

        Args:
            topic: Lesson topic
            en_text: English text content

        Returns:
            Existing lesson or None if not found
        """
        try:
            lesson = self.db.query(Lesson).filter(
                Lesson.topic == topic,
                Lesson.en_text == en_text
            ).first()

            if lesson:
                logger.info(f"Retrieved existing lesson: {lesson.lesson_id}")

            return lesson

        except Exception as e:
            logger.error(f"Failed to retrieve lesson: {e}")
            raise

    def get_lesson_by_id(self, lesson_id: str) -> Optional[Lesson]:
        """
        Retrieve lesson by ID.

        Args:
            lesson_id: Lesson UUID

        Returns:
            Lesson or None if not found
        """
        try:
            lesson = self.db.query(Lesson).filter(
                Lesson.lesson_id == lesson_id
            ).first()

            return lesson

        except Exception as e:
            logger.error(f"Failed to retrieve lesson by ID: {e}")
            raise

    def get_lessons_by_topic_level(self, topic: str, level: str, limit: int = 20) -> List[Lesson]:
        """
        Retrieve lessons by topic and level with proper indexing.

        Args:
            topic: Lesson topic
            level: Difficulty level
            limit: Maximum number of lessons to return

        Returns:
            List of matching lessons
        """
        try:
            lessons = self.db.query(Lesson).filter(
                Lesson.topic == topic,
                Lesson.level == level
            ).order_by(Lesson.created_at.desc()).limit(limit).all()

            logger.info(f"Retrieved {len(lessons)} lessons for topic '{topic}', level '{level}'")
            return lessons

        except Exception as e:
            logger.error(f"Failed to retrieve lessons by topic/level: {e}")
            raise

    def get_lesson_count(self) -> int:
        """
        Get total number of lessons in database.

        Returns:
            Total lesson count
        """
        try:
            count = self.db.query(Lesson).count()
            return count

        except Exception as e:
            logger.error(f"Failed to get lesson count: {e}")
            raise


class QuizRepository:
    """Repository for quiz data operations."""

    def __init__(self, db_session: Session):
        """
        Initialize repository with database session.

        Args:
            db_session: SQLAlchemy database session
        """
        self.db = db_session

    def create_quiz(self, lesson_id: str, questions: List[Dict[str, Any]], answer_key: Dict[str, Any]) -> Quiz:
        """
        Create a new quiz for a lesson.

        Args:
            lesson_id: UUID of the associated lesson
            questions: List of question dictionaries
            answer_key: Answer key and metadata

        Returns:
            Created quiz

        Raises:
            Exception: For database errors
        """
        try:
            quiz = Quiz(
                lesson_id=lesson_id,
                questions=questions,
                answer_key=answer_key
            )

            self.db.add(quiz)
            self.db.commit()
            self.db.refresh(quiz)

            logger.info(f"Created quiz: {quiz.quiz_id} for lesson: {lesson_id}")
            return quiz

        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed to create quiz: {e}")
            raise

    def get_quiz_by_id(self, quiz_id: str) -> Optional[Quiz]:
        """
        Retrieve quiz by ID.

        Args:
            quiz_id: Quiz UUID

        Returns:
            Quiz or None if not found
        """
        try:
            quiz = self.db.query(Quiz).filter(
                Quiz.quiz_id == quiz_id
            ).first()

            return quiz

        except Exception as e:
            logger.error(f"Failed to retrieve quiz by ID: {e}")
            raise

    def get_quiz_by_lesson_id(self, lesson_id: str) -> Optional[Quiz]:
        """
        Retrieve quiz by lesson ID.

        Args:
            lesson_id: Lesson UUID

        Returns:
            Quiz or None if not found
        """
        try:
            quiz = self.db.query(Quiz).filter(
                Quiz.lesson_id == lesson_id
            ).first()

            return quiz

        except Exception as e:
            logger.error(f"Failed to retrieve quiz by lesson ID: {e}")
            raise

    def get_quizzes_by_lesson_ids(self, lesson_ids: List[str]) -> List[Quiz]:
        """
        Retrieve quizzes for multiple lessons.

        Args:
            lesson_ids: List of lesson UUIDs

        Returns:
            List of quizzes
        """
        try:
            quizzes = self.db.query(Quiz).filter(
                Quiz.lesson_id.in_(lesson_ids)
            ).all()

            logger.info(f"Retrieved {len(quizzes)} quizzes for {len(lesson_ids)} lessons")
            return quizzes

        except Exception as e:
            logger.error(f"Failed to retrieve quizzes by lesson IDs: {e}")
            raise

    def delete_quiz(self, quiz_id: str) -> bool:
        """
        Delete quiz by ID.

        Args:
            quiz_id: Quiz UUID

        Returns:
            True if deleted, False if not found
        """
        try:
            quiz = self.db.query(Quiz).filter(
                Quiz.quiz_id == quiz_id
            ).first()

            if quiz:
                self.db.delete(quiz)
                self.db.commit()
                logger.info(f"Deleted quiz: {quiz_id}")
                return True
            else:
                logger.warning(f"Quiz not found for deletion: {quiz_id}")
                return False

        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed to delete quiz: {e}")
            raise

    def get_quiz_count(self) -> int:
        """
        Get total number of quizzes in database.

        Returns:
            Total quiz count
        """
        try:
            count = self.db.query(Quiz).count()
            return count

        except Exception as e:
            logger.error(f"Failed to get quiz count: {e}")
            raise


class DatabaseManager:
    """Manages database connections and session lifecycle."""

    def __init__(self, database_url: str):
        """
        Initialize database manager.

        Args:
            database_url: PostgreSQL/Supabase connection URL
        """
        from sqlalchemy import create_engine
        from sqlalchemy.orm import sessionmaker

        self.engine = create_engine(database_url)
        self.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)

    def create_tables(self):
        """Create all tables if they don't exist."""
        Base.metadata.create_all(bind=self.engine)
        logger.info("Database tables created/verified")

    def get_session(self) -> Session:
        """Get database session for operations."""
        return self.SessionLocal()

    def get_repository(self) -> LessonRepository:
        """Get lesson repository with session."""
        session = self.get_session()
        return LessonRepository(session)

    def get_quiz_repository(self) -> QuizRepository:
        """Get quiz repository with session."""
        session = self.get_session()
        return QuizRepository(session)

    def get_progress_repository(self) -> 'UserProgressRepository':
        """Get user progress repository with session."""
        session = self.get_session()
        return UserProgressRepository(session)

    def get_profile_repository(self) -> 'UserProfileRepository':
        """Get user profile repository with session."""
        session = self.get_session()
        return UserProfileRepository(session)

    def get_attempt_repository(self) -> 'AttemptRepository':
        """Get attempt repository with session."""
        session = self.get_session()
        return AttemptRepository(session)

    def get_error_repository(self) -> 'ErrorRepository':
        """Get error repository with session."""
        session = self.get_session()
        return ErrorRepository(session)

    def get_progress_analytics_repository(self) -> 'ProgressRepository':
        """Get progress repository with session."""
        session = self.get_session()
        return ProgressRepository(session)


class UserProgressRepository:
    """Repository for user progress data operations."""

    def __init__(self, db_session: Session):
        """Initialize repository with database session."""
        self.db = db_session

    def get_or_create_progress(self, user_id: str, lesson_id: str) -> UserProgress:
        """Get existing progress or create new record."""
        try:
            progress = self.db.query(UserProgress).filter(
                UserProgress.user_id == user_id,
                UserProgress.lesson_id == lesson_id
            ).first()

            if not progress:
                progress = UserProgress(
                    user_id=user_id,
                    lesson_id=lesson_id,
                    status='not_started'
                )
                self.db.add(progress)
                self.db.commit()
                self.db.refresh(progress)
                logger.info(f"Created new progress record for user {user_id}, lesson {lesson_id}")

            return progress

        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed to get/create progress: {e}")
            raise

    def update_progress(self, user_id: str, lesson_id: str, update_data: Dict[str, Any]) -> UserProgress:
        """Update user progress for a lesson."""
        try:
            progress = self.get_or_create_progress(user_id, lesson_id)

            # Update fields
            for field, value in update_data.items():
                if hasattr(progress, field) and value is not None:
                    setattr(progress, field, value)

            # Update timestamps
            progress.last_accessed = func.now()
            if update_data.get('status') == 'completed' and not progress.completion_date:
                progress.completion_date = func.now()

            self.db.commit()
            self.db.refresh(progress)
            logger.info(f"Updated progress for user {user_id}, lesson {lesson_id}")

            return progress

        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed to update progress: {e}")
            raise

    def get_user_progress(self, user_id: str, lesson_id: Optional[str] = None) -> List[UserProgress]:
        """Get progress records for a user."""
        try:
            query = self.db.query(UserProgress).filter(UserProgress.user_id == user_id)

            if lesson_id:
                query = query.filter(UserProgress.lesson_id == lesson_id)

            progress_records = query.order_by(UserProgress.last_accessed.desc()).all()
            return progress_records

        except Exception as e:
            logger.error(f"Failed to get user progress: {e}")
            raise

    def get_completed_lessons(self, user_id: str, limit: int = 50) -> List[UserProgress]:
        """Get completed lessons for a user."""
        try:
            completed = self.db.query(UserProgress).filter(
                UserProgress.user_id == user_id,
                UserProgress.status == 'completed'
            ).order_by(UserProgress.completion_date.desc()).limit(limit).all()

            return completed

        except Exception as e:
            logger.error(f"Failed to get completed lessons: {e}")
            raise

    def create_quiz_attempt(self, user_id: str, attempt_data: QuizAttemptCreate) -> QuizAttempt:
        """Record a quiz attempt."""
        try:
            # Calculate question type performance
            responses = attempt_data.responses
            mcq_correct = mcq_total = 0
            translation_correct = translation_total = 0
            fill_blank_correct = fill_blank_total = 0

            for response in responses:
                q_type = response.get('type', '')
                is_correct = response.get('is_correct', False)

                if q_type == 'mcq':
                    mcq_total += 1
                    if is_correct:
                        mcq_correct += 1
                elif q_type == 'translate':
                    translation_total += 1
                    if is_correct:
                        translation_correct += 1
                elif q_type == 'fill_blank':
                    fill_blank_total += 1
                    if is_correct:
                        fill_blank_correct += 1

            attempt = QuizAttempt(
                user_id=user_id,
                quiz_id=attempt_data.quiz_id,
                responses=responses,
                score=attempt_data.score,
                total_questions=len(responses),
                correct_answers=sum(1 for r in responses if r.get('is_correct', False)),
                started_at=attempt_data.started_at,
                completed_at=attempt_data.completed_at,
                time_taken_seconds=attempt_data.time_taken_seconds,
                mcq_correct=mcq_correct,
                mcq_total=mcq_total,
                translation_correct=translation_correct,
                translation_total=translation_total,
                fill_blank_correct=fill_blank_correct,
                fill_blank_total=fill_blank_total
            )

            self.db.add(attempt)
            self.db.commit()
            self.db.refresh(attempt)
            logger.info(f"Created quiz attempt for user {user_id}, quiz {attempt_data.quiz_id}")

            return attempt

        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed to create quiz attempt: {e}")
            raise

    def get_quiz_attempts(self, user_id: str, quiz_id: Optional[str] = None) -> List[QuizAttempt]:
        """Get quiz attempts for a user."""
        try:
            query = self.db.query(QuizAttempt).filter(QuizAttempt.user_id == user_id)

            if quiz_id:
                query = query.filter(QuizAttempt.quiz_id == quiz_id)

            attempts = query.order_by(QuizAttempt.completed_at.desc()).all()
            return attempts

        except Exception as e:
            logger.error(f"Failed to get quiz attempts: {e}")
            raise


class UserProfileRepository:
    """Repository for user profile data operations."""

    def __init__(self, db_session: Session):
        """Initialize repository with database session."""
        self.db = db_session

    def get_or_create_profile(self, user_id: str) -> UserProfile:
        """Get existing profile or create new one."""
        try:
            profile = self.db.query(UserProfile).filter(
                UserProfile.user_id == user_id
            ).first()

            if not profile:
                profile = UserProfile(user_id=user_id)
                self.db.add(profile)
                self.db.commit()
                self.db.refresh(profile)
                logger.info(f"Created new profile for user {user_id}")

            return profile

        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed to get/create profile: {e}")
            raise

    def update_profile(self, user_id: str, update_data: Dict[str, Any]) -> UserProfile:
        """Update user profile."""
        try:
            profile = self.get_or_create_profile(user_id)

            for field, value in update_data.items():
                if hasattr(profile, field) and value is not None:
                    setattr(profile, field, value)

            self.db.commit()
            self.db.refresh(profile)
            logger.info(f"Updated profile for user {user_id}")

            return profile

        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed to update profile: {e}")
            raise

    def update_aggregated_stats(self, user_id: str) -> UserProfile:
        """Update aggregated statistics for a user."""
        try:
            profile = self.get_or_create_profile(user_id)

            # Get aggregated stats from progress records
            progress_stats = self.db.query(
                func.count(UserProgress.progress_id).label('total_lessons'),
                func.sum(UserProgress.time_spent_minutes).label('total_time'),
                func.count().filter(UserProgress.quiz_taken == True).label('total_quizzes'),
                func.avg(UserProgress.quiz_score).label('avg_score')
            ).filter(
                UserProgress.user_id == user_id,
                UserProgress.status == 'completed'
            ).first()

            if progress_stats:
                profile.total_lessons_completed = progress_stats.total_lessons or 0
                profile.total_time_spent_minutes = progress_stats.total_time or 0
                profile.total_quizzes_completed = progress_stats.total_quizzes or 0
                profile.average_quiz_score = progress_stats.avg_score

            # Update streak calculation
            self._update_learning_streak(profile)

            self.db.commit()
            self.db.refresh(profile)
            logger.info(f"Updated aggregated stats for user {user_id}")

            return profile

        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed to update aggregated stats: {e}")
            raise

    def _update_learning_streak(self, profile: UserProfile):
        """Update learning streak for a user."""
        try:
            from datetime import date, timedelta

            # Get recent completion dates
            recent_completions = self.db.query(
                func.date(UserProgress.completion_date).label('completion_date')
            ).filter(
                UserProgress.user_id == profile.user_id,
                UserProgress.status == 'completed',
                UserProgress.completion_date.isnot(None)
            ).distinct().order_by(func.date(UserProgress.completion_date).desc()).limit(30).all()

            if not recent_completions:
                profile.current_streak_days = 0
                return

            dates = [comp.completion_date for comp in recent_completions]
            today = date.today()
            current_streak = 0
            longest_streak = 0
            temp_streak = 0

            # Calculate current streak
            for i, completion_date in enumerate(dates):
                if i == 0:
                    # Check if today or yesterday
                    days_diff = (today - completion_date).days
                    if days_diff <= 1:
                        current_streak = 1
                        temp_streak = 1
                    else:
                        break
                else:
                    # Check if consecutive days
                    prev_date = dates[i-1]
                    days_diff = (prev_date - completion_date).days
                    if days_diff == 1:
                        current_streak += 1
                        temp_streak += 1
                    else:
                        temp_streak = 1

                longest_streak = max(longest_streak, temp_streak)

            profile.current_streak_days = current_streak
            profile.longest_streak_days = max(profile.longest_streak_days, longest_streak)
            profile.last_activity_date = dates[0] if dates else None

        except Exception as e:
            logger.error(f"Failed to update learning streak: {e}")

    def get_dashboard_stats(self, user_id: str) -> Dict[str, Any]:
        """Get comprehensive dashboard statistics for a user."""
        try:
            profile = self.get_or_create_profile(user_id)

            # Get recent activity (last 7 days)
            from datetime import datetime, timedelta
            week_ago = datetime.now() - timedelta(days=7)

            recent_progress = self.db.query(UserProgress).filter(
                UserProgress.user_id == user_id,
                UserProgress.last_accessed >= week_ago
            ).order_by(UserProgress.last_accessed.desc()).limit(10).all()

            recent_activity = []
            for progress in recent_progress:
                recent_activity.append({
                    'lesson_id': str(progress.lesson_id),
                    'status': progress.status,
                    'timestamp': progress.last_accessed,
                    'time_spent': progress.time_spent_minutes
                })

            # Get topic performance
            topic_stats = self.db.query(
                Lesson.topic,
                func.count(UserProgress.progress_id).label('total'),
                func.count().filter(UserProgress.status == 'completed').label('completed'),
                func.avg(UserProgress.quiz_score).label('avg_score')
            ).join(UserProgress, Lesson.lesson_id == UserProgress.lesson_id).filter(
                UserProgress.user_id == user_id
            ).group_by(Lesson.topic).all()

            topic_progress = {}
            for stat in topic_stats:
                topic_progress[stat.topic] = {
                    'total': stat.total,
                    'completed': stat.completed,
                    'completion_rate': stat.completed / stat.total if stat.total > 0 else 0,
                    'average_score': stat.avg_score
                }

            # Count lessons this week
            lessons_this_week = self.db.query(UserProgress).filter(
                UserProgress.user_id == user_id,
                UserProgress.status == 'completed',
                UserProgress.completion_date >= week_ago
            ).count()

            return {
                'total_lessons_completed': profile.total_lessons_completed,
                'total_quizzes_completed': profile.total_quizzes_completed,
                'total_time_spent_minutes': profile.total_time_spent_minutes,
                'average_quiz_score': profile.average_quiz_score,
                'current_streak_days': profile.current_streak_days,
                'lessons_this_week': lessons_this_week,
                'recent_activity': recent_activity,
                'topic_progress': topic_progress
            }

        except Exception as e:
            logger.error(f"Failed to get dashboard stats: {e}")
            raise


# Evaluation API Models
class EvaluationRequest(BaseModel):
    """Pydantic model for evaluation API requests."""
    user_id: str = Field(..., description="User identifier")
    lesson_id: str = Field(..., description="Lesson UUID")
    quiz_id: str = Field(..., description="Quiz UUID")
    responses: List[Dict[str, Any]] = Field(..., description="User responses array")

    class Config:
        from_attributes = True


class ErrorFeedback(BaseModel):
    """Pydantic model for individual error feedback."""
    type: str = Field(..., description="Error type from taxonomy")
    token: str = Field(..., description="Problematic token/word")
    hint: Optional[str] = Field(None, description="Correction suggestion")

    class Config:
        from_attributes = True


class QuestionFeedback(BaseModel):
    """Pydantic model for question-level feedback."""
    q_index: int = Field(..., description="Question index")
    ok: bool = Field(..., description="Whether response is correct")
    errors: List[ErrorFeedback] = Field(default_factory=list, description="List of errors found")
    suggestion: Optional[str] = Field(None, description="Overall improvement suggestion")

    class Config:
        from_attributes = True


class EvaluationResponse(BaseModel):
    """Pydantic model for evaluation API responses."""
    attempt_id: str = Field(..., description="Unique attempt identifier")
    score: float = Field(..., description="Overall score 0..1", ge=0.0, le=1.0)
    feedback: List[QuestionFeedback] = Field(..., description="Per-question feedback")

    class Config:
        from_attributes = True


class AttemptCreate(BaseModel):
    """Pydantic model for creating attempt records."""
    user_id: str = Field(..., description="User identifier")
    lesson_id: str = Field(..., description="Lesson UUID")
    quiz_id: str = Field(..., description="Quiz UUID")
    responses: List[Dict[str, Any]] = Field(..., description="User responses with evaluation")
    score: float = Field(..., description="Score 0..1", ge=0.0, le=1.0)
    eval: Dict[str, Any] = Field(..., description="Model feedback per question")

    class Config:
        from_attributes = True


class AttemptResponse(BaseModel):
    """Pydantic model for attempt API responses."""
    attempt_id: str = Field(..., description="Attempt identifier")
    user_id: str = Field(..., description="User identifier")
    lesson_id: str = Field(..., description="Lesson identifier")
    quiz_id: str = Field(..., description="Quiz identifier")
    score: float = Field(..., description="Score 0..1")
    created_at: datetime = Field(..., description="Creation timestamp")

    class Config:
        from_attributes = True


class ErrorCreate(BaseModel):
    """Pydantic model for creating error records."""
    user_id: str = Field(..., description="User identifier")
    lesson_id: Optional[str] = Field(None, description="Lesson UUID")
    quiz_id: Optional[str] = Field(None, description="Quiz UUID")
    q_index: Optional[int] = Field(None, description="Question index")
    error_type: str = Field(..., description="Error taxonomy type")
    token: Optional[str] = Field(None, description="Problematic token")
    details: Optional[Dict[str, Any]] = Field(None, description="Additional error metadata")

    class Config:
        from_attributes = True


class ErrorResponse(BaseModel):
    """Pydantic model for error API responses."""
    error_id: str = Field(..., description="Error identifier")
    user_id: str = Field(..., description="User identifier")
    error_type: str = Field(..., description="Error type")
    token: Optional[str] = Field(None, description="Problematic token")
    details: Optional[Dict[str, Any]] = Field(None, description="Error metadata")
    created_at: datetime = Field(..., description="Creation timestamp")

    class Config:
        from_attributes = True


# Repository classes for new models
class AttemptRepository:
    """Repository for attempt data operations."""

    def __init__(self, db_session: Session):
        """Initialize repository with database session."""
        self.db = db_session

    def create_attempt(self, attempt_data: AttemptCreate) -> Attempt:
        """Create a new evaluation attempt."""
        try:
            attempt = Attempt(
                user_id=attempt_data.user_id,
                lesson_id=attempt_data.lesson_id,
                quiz_id=attempt_data.quiz_id,
                responses=attempt_data.responses,
                score=attempt_data.score,
                eval=attempt_data.eval
            )

            self.db.add(attempt)
            self.db.commit()
            self.db.refresh(attempt)
            logger.info(f"Created attempt {attempt.attempt_id} for user {attempt_data.user_id}")

            return attempt

        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed to create attempt: {e}")
            raise

    def get_attempts_by_user(self, user_id: str, limit: int = 50) -> List[Attempt]:
        """Get attempts for a user."""
        try:
            attempts = self.db.query(Attempt).filter(
                Attempt.user_id == user_id
            ).order_by(Attempt.created_at.desc()).limit(limit).all()

            return attempts

        except Exception as e:
            logger.error(f"Failed to get attempts: {e}")
            raise

    def get_attempt_by_id(self, attempt_id: str) -> Optional[Attempt]:
        """Get attempt by ID."""
        try:
            attempt = self.db.query(Attempt).filter(
                Attempt.attempt_id == attempt_id
            ).first()

            return attempt

        except Exception as e:
            logger.error(f"Failed to get attempt by ID: {e}")
            raise


class ErrorRepository:
    """Repository for error data operations."""

    def __init__(self, db_session: Session):
        """Initialize repository with database session."""
        self.db = db_session

    def create_error(self, error_data: ErrorCreate) -> Error:
        """Create a new error record."""
        try:
            error = Error(
                user_id=error_data.user_id,
                lesson_id=error_data.lesson_id,
                quiz_id=error_data.quiz_id,
                q_index=error_data.q_index,
                error_type=error_data.error_type,
                token=error_data.token,
                details=error_data.details or {}
            )

            self.db.add(error)
            self.db.commit()
            self.db.refresh(error)
            logger.info(f"Created error {error.error_id} for user {error_data.user_id}")

            return error

        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed to create error: {e}")
            raise

    def create_errors_batch(self, errors_data: List[ErrorCreate]) -> List[Error]:
        """Create multiple error records in batch."""
        try:
            errors = []
            for error_data in errors_data:
                error = Error(
                    user_id=error_data.user_id,
                    lesson_id=error_data.lesson_id,
                    quiz_id=error_data.quiz_id,
                    q_index=error_data.q_index,
                    error_type=error_data.error_type,
                    token=error_data.token,
                    details=error_data.details or {}
                )
                errors.append(error)

            self.db.add_all(errors)
            self.db.commit()

            for error in errors:
                self.db.refresh(error)

            logger.info(f"Created {len(errors)} error records")
            return errors

        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed to create errors batch: {e}")
            raise

    def get_errors_by_user(self, user_id: str, error_type: Optional[str] = None, limit: int = 100) -> List[Error]:
        """Get errors for a user, optionally filtered by type."""
        try:
            query = self.db.query(Error).filter(Error.user_id == user_id)

            if error_type:
                query = query.filter(Error.error_type == error_type)

            errors = query.order_by(Error.created_at.desc()).limit(limit).all()
            return errors

        except Exception as e:
            logger.error(f"Failed to get errors: {e}")
            raise

    def get_error_stats(self, user_id: str) -> Dict[str, int]:
        """Get error statistics for a user."""
        try:
            stats = self.db.query(
                Error.error_type,
                func.count(Error.error_id).label('count')
            ).filter(
                Error.user_id == user_id
            ).group_by(Error.error_type).all()

            return {stat.error_type: stat.count for stat in stats}

        except Exception as e:
            logger.error(f"Failed to get error stats: {e}")
            raise


# Progress API Models
class ProgressRequest(BaseModel):
    """Pydantic model for progress API requests."""
    user_id: str = Field(..., description="User identifier")
    days_back: Optional[int] = Field(30, description="Number of days to look back for trends", ge=1, le=365)

    class Config:
        from_attributes = True


class ProgressMetrics(BaseModel):
    """Pydantic model for progress metrics."""
    accuracy: float = Field(..., description="Average accuracy rate 0..1", ge=0.0, le=1.0)
    time_minutes: int = Field(..., description="Total time spent in minutes", ge=0)
    error_breakdown: Dict[str, int] = Field(default_factory=dict, description="Error counts by type")
    lessons_completed: int = Field(..., description="Number of lessons completed", ge=0)
    streak_days: int = Field(..., description="Current learning streak in days", ge=0)
    improvement_rate: float = Field(..., description="Rate of improvement over period", ge=-1.0, le=1.0)

    class Config:
        from_attributes = True


class TrendPoint(BaseModel):
    """Pydantic model for trend data points."""
    date: str = Field(..., description="Date in YYYY-MM-DD format")
    accuracy: float = Field(..., description="Accuracy for this date", ge=0.0, le=1.0)
    time_minutes: int = Field(..., description="Time spent on this date", ge=0)

    class Config:
        from_attributes = True


class ProgressSummary(BaseModel):
    """Pydantic model for comprehensive progress summary."""
    current: ProgressMetrics = Field(..., description="Current period metrics")
    weekly: ProgressMetrics = Field(..., description="Weekly metrics")
    monthly: ProgressMetrics = Field(..., description="Monthly metrics")
    trends: List[TrendPoint] = Field(default_factory=list, description="Trend data points")
    improvement_areas: List[str] = Field(default_factory=list, description="Areas needing improvement")

    class Config:
        from_attributes = True


class ProgressResponse(BaseModel):
    """Pydantic model for progress API responses."""
    weekly: ProgressMetrics = Field(..., description="Weekly progress metrics")
    trends: List[TrendPoint] = Field(default_factory=list, description="Progress trend points")
    improvement_areas: List[str] = Field(default_factory=list, description="Recommended focus areas")

    class Config:
        from_attributes = True


class ProgressCreate(BaseModel):
    """Pydantic model for creating progress records."""
    user_id: str = Field(..., description="User identifier")
    period: str = Field(..., description="Date period in YYYY-MM-DD format")
    metrics: Dict[str, Any] = Field(..., description="Progress metrics as JSON")

    class Config:
        from_attributes = True


# Progress Repository
class ProgressRepository:
    """Repository for progress data operations."""

    def __init__(self, db_session: Session):
        """Initialize repository with database session."""
        self.db = db_session

    def create_or_update_progress(self, progress_data: ProgressCreate) -> Progress:
        """Create or update progress record for a user and period."""
        try:
            from datetime import datetime
            period_date = datetime.strptime(progress_data.period, "%Y-%m-%d").date()

            # Check if record exists
            existing = self.db.query(Progress).filter(
                Progress.user_id == progress_data.user_id,
                Progress.period == period_date
            ).first()

            if existing:
                # Update existing record
                existing.metrics = progress_data.metrics
                existing.updated_at = func.now()
                self.db.commit()
                self.db.refresh(existing)
                logger.info(f"Updated progress for user {progress_data.user_id}, period {progress_data.period}")
                return existing
            else:
                # Create new record
                progress = Progress(
                    user_id=progress_data.user_id,
                    period=period_date,
                    metrics=progress_data.metrics
                )
                self.db.add(progress)
                self.db.commit()
                self.db.refresh(progress)
                logger.info(f"Created progress for user {progress_data.user_id}, period {progress_data.period}")
                return progress

        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed to create/update progress: {e}")
            raise

    def get_user_progress(self, user_id: str, days_back: int = 30) -> List[Progress]:
        """Get progress records for a user within specified days."""
        try:
            from datetime import date, timedelta
            start_date = date.today() - timedelta(days=days_back)

            progress_records = self.db.query(Progress).filter(
                Progress.user_id == user_id,
                Progress.period >= start_date
            ).order_by(Progress.period.desc()).all()

            return progress_records

        except Exception as e:
            logger.error(f"Failed to get user progress: {e}")
            raise

    def get_progress_by_period(self, user_id: str, start_date: str, end_date: str) -> List[Progress]:
        """Get progress records for a user within a date range."""
        try:
            from datetime import datetime
            start = datetime.strptime(start_date, "%Y-%m-%d").date()
            end = datetime.strptime(end_date, "%Y-%m-%d").date()

            progress_records = self.db.query(Progress).filter(
                Progress.user_id == user_id,
                Progress.period >= start,
                Progress.period <= end
            ).order_by(Progress.period.asc()).all()

            return progress_records

        except Exception as e:
            logger.error(f"Failed to get progress by period: {e}")
            raise

    def delete_old_progress(self, days_to_keep: int = 365) -> int:
        """Delete progress records older than specified days."""
        try:
            from datetime import date, timedelta
            cutoff_date = date.today() - timedelta(days=days_to_keep)

            deleted_count = self.db.query(Progress).filter(
                Progress.period < cutoff_date
            ).delete()

            self.db.commit()
            logger.info(f"Deleted {deleted_count} old progress records")
            return deleted_count

        except Exception as e:
            self.db.rollback()
            logger.error(f"Failed to delete old progress: {e}")
            raise

    def get_latest_progress(self, user_id: str) -> Optional[Progress]:
        """Get the most recent progress record for a user."""
        try:
            latest = self.db.query(Progress).filter(
                Progress.user_id == user_id
            ).order_by(Progress.period.desc()).first()

            return latest

        except Exception as e:
            logger.error(f"Failed to get latest progress: {e}")
            raise


# Authentication API Models
class UserRegistrationRequest(BaseModel):
    """Pydantic model for user registration requests."""
    email: str = Field(..., description="User email address", example="user@example.com")
    password: str = Field(..., description="User password", min_length=8)
    dialect: Optional[str] = Field("lebanese", description="Preferred dialect")
    difficulty: Optional[str] = Field("beginner", description="Difficulty level")
    translit_style: Optional[Dict[str, str]] = Field(default_factory=dict, description="Transliteration preferences")

    class Config:
        from_attributes = True


class UserLoginRequest(BaseModel):
    """Pydantic model for user login requests."""
    email: str = Field(..., description="User email address", example="user@example.com")
    password: str = Field(..., description="User password")

    class Config:
        from_attributes = True


class TokenRefreshRequest(BaseModel):
    """Pydantic model for token refresh requests."""
    refresh_token: str = Field(..., description="Valid refresh token")

    class Config:
        from_attributes = True


class AuthResponse(BaseModel):
    """Pydantic model for authentication responses."""
    user_id: str = Field(..., description="User identifier")
    email: str = Field(..., description="User email")
    access_token: str = Field(..., description="JWT access token")
    refresh_token: str = Field(..., description="JWT refresh token")
    expires_in: int = Field(..., description="Token expiration in seconds")
    profile: Dict[str, Any] = Field(default_factory=dict, description="User profile data")

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    """Pydantic model for token refresh responses."""
    access_token: str = Field(..., description="New JWT access token")
    refresh_token: str = Field(..., description="New JWT refresh token")
    expires_in: int = Field(..., description="Token expiration in seconds")

    class Config:
        from_attributes = True


class UserProfileUpdate(BaseModel):
    """Pydantic model for user profile updates."""
    display_name: Optional[str] = Field(None, description="User display name")
    dialect: Optional[str] = Field(None, description="Preferred dialect")
    difficulty: Optional[str] = Field(None, description="Difficulty level")
    translit_style: Optional[Dict[str, str]] = Field(None, description="Transliteration preferences")
    settings: Optional[Dict[str, Any]] = Field(None, description="Additional user settings")

    class Config:
        from_attributes = True


class AuthUserProfileResponse(BaseModel):
    """Pydantic model for auth user profile responses."""
    user_id: str = Field(..., description="User identifier")
    email: str = Field(..., description="User email")
    display_name: Optional[str] = Field(None, description="User display name")
    dialect: str = Field(..., description="Preferred dialect")
    difficulty: str = Field(..., description="Difficulty level")
    translit_style: Dict[str, str] = Field(default_factory=dict, description="Transliteration preferences")
    settings: Dict[str, Any] = Field(default_factory=dict, description="User settings")
    created_at: Optional[datetime] = Field(None, description="Account creation date")
    last_login: Optional[datetime] = Field(None, description="Last login timestamp")

    class Config:
        from_attributes = True


# Synchronization API Models
class SyncItemRequest(BaseModel):
    """Pydantic model for sync item requests."""
    table_name: str = Field(..., description="Database table name")
    item_id: str = Field(..., description="Item identifier")
    data: Dict[str, Any] = Field(..., description="Item data")
    updated_at: datetime = Field(..., description="Last update timestamp")
    operation: str = Field("update", description="Operation type: create, update, delete")

    class Config:
        from_attributes = True


class SyncRequest(BaseModel):
    """Pydantic model for synchronization requests."""
    last_sync: Optional[datetime] = Field(None, description="Last sync timestamp")
    client_data: List[SyncItemRequest] = Field(default_factory=list, description="Client data to sync")
    conflict_resolution: str = Field("timestamp", description="Conflict resolution strategy")

    class Config:
        from_attributes = True


class SyncConflict(BaseModel):
    """Pydantic model for sync conflicts."""
    table_name: str = Field(..., description="Table with conflict")
    item_id: str = Field(..., description="Conflicting item ID")
    server_data: Dict[str, Any] = Field(..., description="Server version")
    client_data: Dict[str, Any] = Field(..., description="Client version")
    server_updated: datetime = Field(..., description="Server update time")
    client_updated: datetime = Field(..., description="Client update time")

    class Config:
        from_attributes = True


class SyncResult(BaseModel):
    """Pydantic model for sync results."""
    success: bool = Field(..., description="Sync success status")
    server_changes: List[SyncItemRequest] = Field(default_factory=list, description="Changes from server")
    conflicts: List[SyncConflict] = Field(default_factory=list, description="Sync conflicts")
    last_sync: datetime = Field(..., description="New sync timestamp")
    synced_count: int = Field(0, description="Number of items synced")
    conflict_count: int = Field(0, description="Number of conflicts")

    class Config:
        from_attributes = True


class SyncResponse(BaseModel):
    """Pydantic model for sync API responses."""
    result: SyncResult = Field(..., description="Sync operation result")
    user_id: str = Field(..., description="User identifier")
    sync_timestamp: datetime = Field(..., description="Sync completion timestamp")

    class Config:
        from_attributes = True


class SyncQueueItem(BaseModel):
    """Pydantic model for offline sync queue items."""
    queue_id: str = Field(..., description="Queue item identifier")
    user_id: str = Field(..., description="User identifier")
    table_name: str = Field(..., description="Target table")
    item_id: str = Field(..., description="Item identifier")
    operation: str = Field(..., description="Operation: create, update, delete")
    data: Dict[str, Any] = Field(..., description="Item data")
    created_at: datetime = Field(..., description="Queue creation time")
    retry_count: int = Field(0, description="Number of retry attempts")

    class Config:
        from_attributes = True


class SyncStatus(BaseModel):
    """Pydantic model for sync status responses."""
    is_syncing: bool = Field(..., description="Whether sync is in progress")
    last_sync: Optional[datetime] = Field(None, description="Last successful sync")
    pending_items: int = Field(0, description="Number of pending sync items")
    last_error: Optional[str] = Field(None, description="Last sync error message")
    sync_enabled: bool = Field(True, description="Whether sync is enabled")

    class Config:
        from_attributes = True