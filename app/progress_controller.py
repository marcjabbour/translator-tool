"""
User progress tracking controller for dashboard and analytics.
Handles lesson completion, quiz attempts, and user statistics.
"""

import logging
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from fastapi import HTTPException, status

from .models import (
    UserProgressRepository, UserProfileRepository,
    UserProgressUpdate, QuizAttemptCreate,
    UserProgressResponse, QuizAttemptResponse,
    UserProfileResponse, DashboardStats
)

logger = logging.getLogger(__name__)


class ProgressController:
    """Controller for user progress tracking and analytics."""

    def __init__(self, progress_repo: UserProgressRepository, profile_repo: UserProfileRepository):
        """
        Initialize progress controller with repositories.

        Args:
            progress_repo: User progress repository
            profile_repo: User profile repository
        """
        self.progress_repo = progress_repo
        self.profile_repo = profile_repo

    def track_lesson_view(self, user_id: str, lesson_id: str) -> UserProgressResponse:
        """
        Track when a user views a lesson.

        Args:
            user_id: User identifier
            lesson_id: Lesson identifier

        Returns:
            Updated progress record

        Raises:
            HTTPException: For database errors
        """
        try:
            # Get or create progress record
            progress = self.progress_repo.get_or_create_progress(user_id, lesson_id)

            # Increment view count and update access time
            update_data = {
                'lesson_views': progress.lesson_views + 1,
                'status': 'in_progress' if progress.status == 'not_started' else progress.status
            }

            updated_progress = self.progress_repo.update_progress(user_id, lesson_id, update_data)

            logger.info(f"Tracked lesson view for user {user_id}, lesson {lesson_id}")
            return self._convert_to_response(updated_progress)

        except Exception as e:
            logger.error(f"Failed to track lesson view: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to track lesson view"
            )

    def track_translation_toggle(self, user_id: str, lesson_id: str) -> UserProgressResponse:
        """
        Track when a user toggles translation view.

        Args:
            user_id: User identifier
            lesson_id: Lesson identifier

        Returns:
            Updated progress record
        """
        try:
            progress = self.progress_repo.get_or_create_progress(user_id, lesson_id)

            update_data = {
                'translation_toggles': progress.translation_toggles + 1
            }

            updated_progress = self.progress_repo.update_progress(user_id, lesson_id, update_data)

            logger.info(f"Tracked translation toggle for user {user_id}, lesson {lesson_id}")
            return self._convert_to_response(updated_progress)

        except Exception as e:
            logger.error(f"Failed to track translation toggle: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to track translation toggle"
            )

    def update_lesson_progress(
        self,
        user_id: str,
        lesson_id: str,
        update_data: UserProgressUpdate
    ) -> UserProgressResponse:
        """
        Update lesson progress with custom data.

        Args:
            user_id: User identifier
            lesson_id: Lesson identifier
            update_data: Progress update data

        Returns:
            Updated progress record
        """
        try:
            # Convert Pydantic model to dict, excluding None values
            update_dict = update_data.dict(exclude_none=True)

            updated_progress = self.progress_repo.update_progress(user_id, lesson_id, update_dict)

            # Update aggregated stats if lesson was completed
            if update_dict.get('status') == 'completed':
                self.profile_repo.update_aggregated_stats(user_id)

            logger.info(f"Updated lesson progress for user {user_id}, lesson {lesson_id}")
            return self._convert_to_response(updated_progress)

        except Exception as e:
            logger.error(f"Failed to update lesson progress: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to update lesson progress"
            )

    def record_quiz_attempt(
        self,
        user_id: str,
        attempt_data: QuizAttemptCreate
    ) -> QuizAttemptResponse:
        """
        Record a quiz attempt and update related progress.

        Args:
            user_id: User identifier
            attempt_data: Quiz attempt data

        Returns:
            Created quiz attempt record
        """
        try:
            # Create quiz attempt record
            attempt = self.progress_repo.create_quiz_attempt(user_id, attempt_data)

            # Get quiz to find associated lesson
            from .models import Quiz
            quiz = self.progress_repo.db.query(Quiz).filter(
                Quiz.quiz_id == attempt_data.quiz_id
            ).first()

            if quiz:
                # Update lesson progress with quiz results
                progress = self.progress_repo.get_or_create_progress(user_id, str(quiz.lesson_id))

                # Update quiz-related fields
                quiz_update = {
                    'quiz_taken': True,
                    'quiz_attempts': progress.quiz_attempts + 1,
                    'quiz_score': attempt_data.score,
                    'best_quiz_score': max(
                        progress.best_quiz_score or 0,
                        attempt_data.score
                    )
                }

                # Mark lesson as completed if quiz score is good enough
                if attempt_data.score >= 0.7:  # 70% threshold
                    quiz_update['status'] = 'completed'

                self.progress_repo.update_progress(user_id, str(quiz.lesson_id), quiz_update)

                # Update aggregated profile stats
                self.profile_repo.update_aggregated_stats(user_id)

            logger.info(f"Recorded quiz attempt for user {user_id}, quiz {attempt_data.quiz_id}")
            return self._convert_attempt_to_response(attempt)

        except Exception as e:
            logger.error(f"Failed to record quiz attempt: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to record quiz attempt"
            )

    def get_user_progress(
        self,
        user_id: str,
        lesson_id: Optional[str] = None
    ) -> List[UserProgressResponse]:
        """
        Get progress records for a user.

        Args:
            user_id: User identifier
            lesson_id: Optional lesson filter

        Returns:
            List of progress records
        """
        try:
            progress_records = self.progress_repo.get_user_progress(user_id, lesson_id)
            return [self._convert_to_response(p) for p in progress_records]

        except Exception as e:
            logger.error(f"Failed to get user progress: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to get user progress"
            )

    def get_quiz_attempts(
        self,
        user_id: str,
        quiz_id: Optional[str] = None
    ) -> List[QuizAttemptResponse]:
        """
        Get quiz attempts for a user.

        Args:
            user_id: User identifier
            quiz_id: Optional quiz filter

        Returns:
            List of quiz attempts
        """
        try:
            attempts = self.progress_repo.get_quiz_attempts(user_id, quiz_id)
            return [self._convert_attempt_to_response(a) for a in attempts]

        except Exception as e:
            logger.error(f"Failed to get quiz attempts: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to get quiz attempts"
            )

    def get_user_profile(self, user_id: str) -> UserProfileResponse:
        """
        Get or create user profile with aggregated stats.

        Args:
            user_id: User identifier

        Returns:
            User profile data
        """
        try:
            # Update aggregated stats first
            profile = self.profile_repo.update_aggregated_stats(user_id)

            return UserProfileResponse(
                user_id=profile.user_id,
                display_name=profile.display_name,
                preferred_level=profile.preferred_level,
                total_lessons_completed=profile.total_lessons_completed,
                total_quizzes_completed=profile.total_quizzes_completed,
                total_time_spent_minutes=profile.total_time_spent_minutes,
                average_quiz_score=profile.average_quiz_score,
                current_streak_days=profile.current_streak_days,
                longest_streak_days=profile.longest_streak_days,
                last_activity_date=profile.last_activity_date,
                favorite_topics=profile.favorite_topics or [],
                topic_performance=profile.topic_performance or {},
                settings=profile.settings or {}
            )

        except Exception as e:
            logger.error(f"Failed to get user profile: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to get user profile"
            )

    def get_dashboard_stats(self, user_id: str) -> DashboardStats:
        """
        Get comprehensive dashboard statistics.

        Args:
            user_id: User identifier

        Returns:
            Dashboard statistics
        """
        try:
            stats_data = self.profile_repo.get_dashboard_stats(user_id)

            return DashboardStats(
                total_lessons_completed=stats_data['total_lessons_completed'],
                total_quizzes_completed=stats_data['total_quizzes_completed'],
                total_time_spent_minutes=stats_data['total_time_spent_minutes'],
                average_quiz_score=stats_data['average_quiz_score'],
                current_streak_days=stats_data['current_streak_days'],
                lessons_this_week=stats_data['lessons_this_week'],
                recent_activity=stats_data['recent_activity'],
                topic_progress=stats_data['topic_progress']
            )

        except Exception as e:
            logger.error(f"Failed to get dashboard stats: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to get dashboard stats"
            )

    def get_learning_analytics(self, user_id: str, days: int = 30) -> Dict[str, Any]:
        """
        Get detailed learning analytics for a user.

        Args:
            user_id: User identifier
            days: Number of days to analyze

        Returns:
            Analytics data
        """
        try:
            cutoff_date = datetime.now() - timedelta(days=days)

            # Get recent progress
            from .models import UserProgress
            recent_progress = self.progress_repo.db.query(UserProgress).filter(
                UserProgress.user_id == user_id,
                UserProgress.last_accessed >= cutoff_date
            ).all()

            # Get recent quiz attempts
            recent_attempts = self.progress_repo.get_quiz_attempts(user_id)
            recent_attempts = [a for a in recent_attempts if a.completed_at >= cutoff_date]

            # Calculate analytics
            analytics = {
                'period_days': days,
                'lessons_accessed': len(recent_progress),
                'lessons_completed': len([p for p in recent_progress if p.status == 'completed']),
                'total_study_time': sum(p.time_spent_minutes for p in recent_progress),
                'quiz_attempts': len(recent_attempts),
                'average_quiz_score': (
                    sum(a.score for a in recent_attempts) / len(recent_attempts)
                    if recent_attempts else None
                ),
                'learning_velocity': len([p for p in recent_progress if p.status == 'completed']) / days,
                'engagement_metrics': {
                    'avg_lesson_views': (
                        sum(p.lesson_views for p in recent_progress) / len(recent_progress)
                        if recent_progress else 0
                    ),
                    'avg_translation_toggles': (
                        sum(p.translation_toggles for p in recent_progress) / len(recent_progress)
                        if recent_progress else 0
                    )
                },
                'performance_by_question_type': self._calculate_question_type_performance(recent_attempts),
                'daily_activity': self._calculate_daily_activity(recent_progress, days)
            }

            return analytics

        except Exception as e:
            logger.error(f"Failed to get learning analytics: {e}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to get learning analytics"
            )

    def _convert_to_response(self, progress) -> UserProgressResponse:
        """Convert progress model to response."""
        return UserProgressResponse(
            progress_id=str(progress.progress_id),
            user_id=progress.user_id,
            lesson_id=str(progress.lesson_id),
            status=progress.status,
            completion_date=progress.completion_date,
            time_spent_minutes=progress.time_spent_minutes,
            lesson_views=progress.lesson_views,
            translation_toggles=progress.translation_toggles,
            quiz_taken=progress.quiz_taken,
            quiz_score=progress.quiz_score,
            quiz_attempts=progress.quiz_attempts,
            best_quiz_score=progress.best_quiz_score,
            last_accessed=progress.last_accessed
        )

    def _convert_attempt_to_response(self, attempt) -> QuizAttemptResponse:
        """Convert quiz attempt model to response."""
        return QuizAttemptResponse(
            attempt_id=str(attempt.attempt_id),
            user_id=attempt.user_id,
            quiz_id=str(attempt.quiz_id),
            score=attempt.score,
            total_questions=attempt.total_questions,
            correct_answers=attempt.correct_answers,
            time_taken_seconds=attempt.time_taken_seconds,
            started_at=attempt.started_at,
            completed_at=attempt.completed_at,
            mcq_correct=attempt.mcq_correct,
            mcq_total=attempt.mcq_total,
            translation_correct=attempt.translation_correct,
            translation_total=attempt.translation_total,
            fill_blank_correct=attempt.fill_blank_correct,
            fill_blank_total=attempt.fill_blank_total
        )

    def _calculate_question_type_performance(self, attempts) -> Dict[str, Dict[str, float]]:
        """Calculate performance by question type."""
        performance = {}

        if not attempts:
            return performance

        # Aggregate by question type
        mcq_correct = mcq_total = 0
        translation_correct = translation_total = 0
        fill_blank_correct = fill_blank_total = 0

        for attempt in attempts:
            mcq_correct += attempt.mcq_correct
            mcq_total += attempt.mcq_total
            translation_correct += attempt.translation_correct
            translation_total += attempt.translation_total
            fill_blank_correct += attempt.fill_blank_correct
            fill_blank_total += attempt.fill_blank_total

        if mcq_total > 0:
            performance['mcq'] = {
                'accuracy': mcq_correct / mcq_total,
                'total_questions': mcq_total
            }

        if translation_total > 0:
            performance['translate'] = {
                'accuracy': translation_correct / translation_total,
                'total_questions': translation_total
            }

        if fill_blank_total > 0:
            performance['fill_blank'] = {
                'accuracy': fill_blank_correct / fill_blank_total,
                'total_questions': fill_blank_total
            }

        return performance

    def _calculate_daily_activity(self, progress_records, days: int) -> List[Dict[str, Any]]:
        """Calculate daily activity for the specified period."""
        from collections import defaultdict
        from datetime import date

        daily_stats = defaultdict(lambda: {
            'date': None,
            'lessons_accessed': 0,
            'lessons_completed': 0,
            'time_spent': 0
        })

        # Group by date
        for progress in progress_records:
            activity_date = progress.last_accessed.date()
            daily_stats[activity_date]['date'] = activity_date
            daily_stats[activity_date]['lessons_accessed'] += 1
            daily_stats[activity_date]['time_spent'] += progress.time_spent_minutes

            if progress.status == 'completed':
                daily_stats[activity_date]['lessons_completed'] += 1

        # Fill in missing days with zero activity
        today = date.today()
        result = []

        for i in range(days):
            check_date = today - timedelta(days=i)
            day_stats = daily_stats.get(check_date, {
                'date': check_date,
                'lessons_accessed': 0,
                'lessons_completed': 0,
                'time_spent': 0
            })
            result.append(day_stats)

        return sorted(result, key=lambda x: x['date'])