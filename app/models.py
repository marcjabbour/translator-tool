"""
Data models for lessons and database integration.
Implements Supabase/PostgreSQL schema with deduplication logic.
"""

import uuid
from datetime import datetime
from typing import Optional, Dict, Any, List
from dataclasses import dataclass
from sqlalchemy import Column, String, Text, DateTime, UniqueConstraint, Index, ForeignKey
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