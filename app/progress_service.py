"""
Progress Service for analytics aggregation and progress tracking.
Aggregates data from attempts and errors tables to provide learning insights.
"""

import logging
from datetime import datetime, timedelta, date
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass
from sqlalchemy.orm import Session
from sqlalchemy import func, and_, or_, text
from collections import defaultdict

from .models import Attempt, Error, Lesson

logger = logging.getLogger(__name__)


@dataclass
class ProgressMetrics:
    """Progress metrics for a specific time period."""
    accuracy: float
    time_minutes: int
    lessons_completed: int
    quizzes_taken: int
    total_attempts: int
    errors_by_type: Dict[str, int]
    improvement_areas: List[str]
    streak_days: int


@dataclass
class TrendPoint:
    """Single point in progress trend."""
    date: date
    accuracy: float
    lessons_completed: int
    time_spent: int
    errors_count: int


@dataclass
class ProgressSummary:
    """Complete progress summary with trends and metrics."""
    current_metrics: ProgressMetrics
    weekly_metrics: ProgressMetrics
    monthly_metrics: ProgressMetrics
    trend_points: List[TrendPoint]
    total_study_time: int
    lessons_completed_total: int
    most_common_errors: List[Tuple[str, int]]
    improvement_rate: float  # Progress trend slope


class ProgressAnalytics:
    """Analytics service for calculating progress metrics and trends."""

    def __init__(self, db_session: Session):
        """Initialize with database session."""
        self.db = db_session

    def get_user_progress_summary(
        self,
        user_id: str,
        days_back: int = 30
    ) -> ProgressSummary:
        """
        Get comprehensive progress summary for a user.

        Args:
            user_id: User identifier
            days_back: Number of days to look back for trends

        Returns:
            Complete progress summary with metrics and trends
        """
        try:
            logger.info(f"Calculating progress summary for user {user_id}")

            # Calculate different time period metrics
            current_metrics = self._calculate_period_metrics(user_id, days=1)
            weekly_metrics = self._calculate_period_metrics(user_id, days=7)
            monthly_metrics = self._calculate_period_metrics(user_id, days=30)

            # Generate trend data
            trend_points = self._calculate_trend_points(user_id, days_back)

            # Calculate overall statistics
            total_study_time = self._calculate_total_study_time(user_id)
            lessons_completed_total = self._calculate_total_lessons_completed(user_id)
            most_common_errors = self._get_most_common_errors(user_id, limit=5)
            improvement_rate = self._calculate_improvement_rate(trend_points)

            return ProgressSummary(
                current_metrics=current_metrics,
                weekly_metrics=weekly_metrics,
                monthly_metrics=monthly_metrics,
                trend_points=trend_points,
                total_study_time=total_study_time,
                lessons_completed_total=lessons_completed_total,
                most_common_errors=most_common_errors,
                improvement_rate=improvement_rate
            )

        except Exception as e:
            logger.error(f"Failed to calculate progress summary: {e}")
            # Return empty metrics rather than failing
            return self._create_empty_progress_summary()

    def _calculate_period_metrics(self, user_id: str, days: int) -> ProgressMetrics:
        """Calculate metrics for a specific time period."""
        try:
            cutoff_date = datetime.now() - timedelta(days=days)

            # Get attempts for the period
            attempts = self.db.query(Attempt).filter(
                and_(
                    Attempt.user_id == user_id,
                    Attempt.created_at >= cutoff_date
                )
            ).all()

            if not attempts:
                return self._create_empty_metrics()

            # Calculate accuracy
            total_attempts = len(attempts)
            total_score = sum(attempt.score or 0 for attempt in attempts)
            accuracy = total_score / total_attempts if total_attempts > 0 else 0.0

            # Get lesson completion data
            lesson_ids = set(attempt.lesson_id for attempt in attempts)
            lessons_completed = len(lesson_ids)

            # Estimate time spent (rough calculation based on attempt count)
            # In a real system, you'd track actual time spent
            estimated_time = total_attempts * 5  # Assume 5 minutes per attempt average

            # Get errors for the period
            errors = self.db.query(Error).filter(
                and_(
                    Error.user_id == user_id,
                    Error.created_at >= cutoff_date
                )
            ).all()

            # Count errors by type
            errors_by_type = defaultdict(int)
            for error in errors:
                errors_by_type[error.error_type] += 1

            # Identify improvement areas (error types with >2 occurrences)
            improvement_areas = [
                error_type for error_type, count in errors_by_type.items()
                if count > 2
            ]

            # Calculate learning streak (simplified)
            streak_days = self._calculate_streak_days(user_id)

            return ProgressMetrics(
                accuracy=accuracy,
                time_minutes=estimated_time,
                lessons_completed=lessons_completed,
                quizzes_taken=total_attempts,
                total_attempts=total_attempts,
                errors_by_type=dict(errors_by_type),
                improvement_areas=improvement_areas,
                streak_days=streak_days
            )

        except Exception as e:
            logger.error(f"Failed to calculate period metrics: {e}")
            return self._create_empty_metrics()

    def _calculate_trend_points(self, user_id: str, days_back: int) -> List[TrendPoint]:
        """Calculate daily trend points for the specified period."""
        try:
            trend_points = []
            cutoff_date = datetime.now() - timedelta(days=days_back)

            # Group attempts by date
            attempts_by_date = self.db.query(
                func.date(Attempt.created_at).label('date'),
                func.count(Attempt.attempt_id).label('attempt_count'),
                func.avg(Attempt.score).label('avg_score')
            ).filter(
                and_(
                    Attempt.user_id == user_id,
                    Attempt.created_at >= cutoff_date
                )
            ).group_by(func.date(Attempt.created_at)).all()

            # Get lessons by date
            lessons_by_date = self.db.query(
                func.date(Attempt.created_at).label('date'),
                func.count(func.distinct(Attempt.lesson_id)).label('lesson_count')
            ).filter(
                and_(
                    Attempt.user_id == user_id,
                    Attempt.created_at >= cutoff_date
                )
            ).group_by(func.date(Attempt.created_at)).all()

            # Get errors by date
            errors_by_date = self.db.query(
                func.date(Error.created_at).label('date'),
                func.count(Error.error_id).label('error_count')
            ).filter(
                and_(
                    Error.user_id == user_id,
                    Error.created_at >= cutoff_date
                )
            ).group_by(func.date(Error.created_at)).all()

            # Convert to dictionaries for easy lookup
            attempts_dict = {row.date: (row.attempt_count, row.avg_score or 0) for row in attempts_by_date}
            lessons_dict = {row.date: row.lesson_count for row in lessons_by_date}
            errors_dict = {row.date: row.error_count for row in errors_by_date}

            # Create trend points for each day
            for i in range(days_back):
                current_date = (datetime.now() - timedelta(days=i)).date()

                attempt_count, avg_score = attempts_dict.get(current_date, (0, 0))
                lesson_count = lessons_dict.get(current_date, 0)
                error_count = errors_dict.get(current_date, 0)

                # Estimate time spent
                time_spent = attempt_count * 5  # 5 minutes per attempt

                trend_points.append(TrendPoint(
                    date=current_date,
                    accuracy=avg_score,
                    lessons_completed=lesson_count,
                    time_spent=time_spent,
                    errors_count=error_count
                ))

            # Sort by date (oldest first for trend analysis)
            trend_points.sort(key=lambda x: x.date)
            return trend_points

        except Exception as e:
            logger.error(f"Failed to calculate trend points: {e}")
            return []

    def _calculate_total_study_time(self, user_id: str) -> int:
        """Calculate total study time for user (estimated)."""
        try:
            total_attempts = self.db.query(func.count(Attempt.attempt_id)).filter(
                Attempt.user_id == user_id
            ).scalar() or 0

            # Estimate 5 minutes per attempt
            return total_attempts * 5

        except Exception as e:
            logger.error(f"Failed to calculate total study time: {e}")
            return 0

    def _calculate_total_lessons_completed(self, user_id: str) -> int:
        """Calculate total unique lessons completed by user."""
        try:
            unique_lessons = self.db.query(func.count(func.distinct(Attempt.lesson_id))).filter(
                Attempt.user_id == user_id
            ).scalar() or 0

            return unique_lessons

        except Exception as e:
            logger.error(f"Failed to calculate total lessons completed: {e}")
            return 0

    def _get_most_common_errors(self, user_id: str, limit: int = 5) -> List[Tuple[str, int]]:
        """Get most common error types for user."""
        try:
            error_stats = self.db.query(
                Error.error_type,
                func.count(Error.error_id).label('count')
            ).filter(
                Error.user_id == user_id
            ).group_by(Error.error_type).order_by(
                func.count(Error.error_id).desc()
            ).limit(limit).all()

            return [(row.error_type, row.count) for row in error_stats]

        except Exception as e:
            logger.error(f"Failed to get most common errors: {e}")
            return []

    def _calculate_improvement_rate(self, trend_points: List[TrendPoint]) -> float:
        """Calculate improvement rate from trend points."""
        try:
            if len(trend_points) < 2:
                return 0.0

            # Simple linear regression to calculate improvement slope
            valid_points = [p for p in trend_points if p.accuracy > 0]
            if len(valid_points) < 2:
                return 0.0

            # Calculate slope of accuracy over time
            n = len(valid_points)
            sum_x = sum(i for i in range(n))
            sum_y = sum(p.accuracy for p in valid_points)
            sum_xy = sum(i * p.accuracy for i, p in enumerate(valid_points))
            sum_x_squared = sum(i * i for i in range(n))

            # Slope formula: (n*sum_xy - sum_x*sum_y) / (n*sum_x_squared - sum_x*sum_x)
            denominator = n * sum_x_squared - sum_x * sum_x
            if denominator == 0:
                return 0.0

            slope = (n * sum_xy - sum_x * sum_y) / denominator
            return slope

        except Exception as e:
            logger.error(f"Failed to calculate improvement rate: {e}")
            return 0.0

    def _calculate_streak_days(self, user_id: str) -> int:
        """Calculate current learning streak in days."""
        try:
            # Get dates when user had attempts
            attempt_dates = self.db.query(
                func.date(Attempt.created_at).label('date')
            ).filter(
                Attempt.user_id == user_id
            ).distinct().order_by(
                func.date(Attempt.created_at).desc()
            ).limit(30).all()  # Look back 30 days max

            if not attempt_dates:
                return 0

            dates = [row.date for row in attempt_dates]
            today = datetime.now().date()
            streak = 0

            # Check consecutive days working backwards from today
            current_date = today
            for attempt_date in dates:
                if attempt_date == current_date:
                    streak += 1
                    current_date = current_date - timedelta(days=1)
                elif attempt_date == current_date - timedelta(days=1):
                    # Allow for gaps of 1 day
                    current_date = attempt_date - timedelta(days=1)
                else:
                    break

            return streak

        except Exception as e:
            logger.error(f"Failed to calculate streak days: {e}")
            return 0

    def _create_empty_metrics(self) -> ProgressMetrics:
        """Create empty metrics for when no data is available."""
        return ProgressMetrics(
            accuracy=0.0,
            time_minutes=0,
            lessons_completed=0,
            quizzes_taken=0,
            total_attempts=0,
            errors_by_type={},
            improvement_areas=[],
            streak_days=0
        )

    def _create_empty_progress_summary(self) -> ProgressSummary:
        """Create empty progress summary for error cases."""
        empty_metrics = self._create_empty_metrics()
        return ProgressSummary(
            current_metrics=empty_metrics,
            weekly_metrics=empty_metrics,
            monthly_metrics=empty_metrics,
            trend_points=[],
            total_study_time=0,
            lessons_completed_total=0,
            most_common_errors=[],
            improvement_rate=0.0
        )

    def get_weekly_progress_data(self, user_id: str) -> Dict[str, Any]:
        """Get formatted weekly progress data for API response."""
        try:
            weekly_metrics = self._calculate_period_metrics(user_id, days=7)

            return {
                "accuracy": round(weekly_metrics.accuracy, 3),
                "time_minutes": weekly_metrics.time_minutes,
                "lessons_completed": weekly_metrics.lessons_completed,
                "quizzes_taken": weekly_metrics.quizzes_taken,
                "errors_by_type": weekly_metrics.errors_by_type,
                "improvement_areas": weekly_metrics.improvement_areas,
                "streak_days": weekly_metrics.streak_days
            }

        except Exception as e:
            logger.error(f"Failed to get weekly progress data: {e}")
            return {
                "accuracy": 0.0,
                "time_minutes": 0,
                "lessons_completed": 0,
                "quizzes_taken": 0,
                "errors_by_type": {},
                "improvement_areas": [],
                "streak_days": 0
            }

    def get_progress_trends(self, user_id: str, days: int = 14) -> List[Dict[str, Any]]:
        """Get progress trend data for charts."""
        try:
            trend_points = self._calculate_trend_points(user_id, days)

            return [
                {
                    "date": point.date.isoformat(),
                    "accuracy": round(point.accuracy, 3),
                    "lessons_completed": point.lessons_completed,
                    "time_spent": point.time_spent,
                    "errors_count": point.errors_count
                }
                for point in trend_points
            ]

        except Exception as e:
            logger.error(f"Failed to get progress trends: {e}")
            return []


class ProgressService:
    """High-level progress service for API endpoints."""

    def __init__(self, db_session: Session):
        """Initialize progress service with database session."""
        self.analytics = ProgressAnalytics(db_session)

    def get_user_progress(self, user_id: str) -> Dict[str, Any]:
        """
        Get comprehensive user progress data for API response.

        Args:
            user_id: User identifier

        Returns:
            Formatted progress data matching API specification
        """
        try:
            # Get weekly data as specified in API contract
            weekly_data = self.analytics.get_weekly_progress_data(user_id)

            # Get trend data for charts
            trends = self.analytics.get_progress_trends(user_id, days=14)

            # Get full summary for additional metrics
            summary = self.analytics.get_user_progress_summary(user_id)

            return {
                "weekly": weekly_data,
                "trends": trends,
                "summary": {
                    "total_study_time": summary.total_study_time,
                    "total_lessons": summary.lessons_completed_total,
                    "most_common_errors": [
                        {"type": error_type, "count": count}
                        for error_type, count in summary.most_common_errors
                    ],
                    "improvement_rate": round(summary.improvement_rate, 3),
                    "current_streak": summary.weekly_metrics.streak_days
                },
                "monthly": {
                    "accuracy": round(summary.monthly_metrics.accuracy, 3),
                    "time_minutes": summary.monthly_metrics.time_minutes,
                    "lessons_completed": summary.monthly_metrics.lessons_completed,
                    "errors_by_type": summary.monthly_metrics.errors_by_type
                }
            }

        except Exception as e:
            logger.error(f"Failed to get user progress: {e}")
            # Return empty progress data rather than failing
            return {
                "weekly": {
                    "accuracy": 0.0,
                    "time_minutes": 0,
                    "lessons_completed": 0,
                    "quizzes_taken": 0,
                    "errors_by_type": {},
                    "improvement_areas": [],
                    "streak_days": 0
                },
                "trends": [],
                "summary": {
                    "total_study_time": 0,
                    "total_lessons": 0,
                    "most_common_errors": [],
                    "improvement_rate": 0.0,
                    "current_streak": 0
                },
                "monthly": {
                    "accuracy": 0.0,
                    "time_minutes": 0,
                    "lessons_completed": 0,
                    "errors_by_type": {}
                }
            }

    def get_improvement_recommendations(self, user_id: str) -> List[Dict[str, Any]]:
        """Get personalized improvement recommendations based on error patterns."""
        try:
            summary = self.analytics.get_user_progress_summary(user_id)

            recommendations = []

            # Analyze most common errors
            for error_type, count in summary.most_common_errors[:3]:
                recommendation = self._get_error_recommendation(error_type, count)
                if recommendation:
                    recommendations.append(recommendation)

            # Analyze accuracy trends
            if summary.improvement_rate < 0:
                recommendations.append({
                    "type": "accuracy_trend",
                    "title": "Focus on Fundamentals",
                    "description": "Your accuracy has been declining. Consider reviewing basic transliteration rules.",
                    "priority": "high",
                    "action": "Review lesson basics"
                })

            # Analyze study consistency
            if summary.weekly_metrics.streak_days < 3:
                recommendations.append({
                    "type": "consistency",
                    "title": "Build Study Consistency",
                    "description": "Regular practice leads to better retention. Try to study a little each day.",
                    "priority": "medium",
                    "action": "Set daily reminders"
                })

            return recommendations

        except Exception as e:
            logger.error(f"Failed to get improvement recommendations: {e}")
            return []

    def _get_error_recommendation(self, error_type: str, count: int) -> Optional[Dict[str, Any]]:
        """Get recommendation for specific error type."""
        error_recommendations = {
            "EN_IN_AR": {
                "title": "Practice Arabic Transliteration",
                "description": f"You've used English words {count} times. Focus on learning Arabic equivalents.",
                "action": "Review transliteration lessons"
            },
            "SPELL_T": {
                "title": "Improve Transliteration Spelling",
                "description": f"You have {count} spelling errors. Practice number substitutions (2,3,5,7,8,9).",
                "action": "Study transliteration rules"
            },
            "GRAMMAR": {
                "title": "Work on Grammar Structure",
                "description": f"You have {count} grammar issues. Review Lebanese Arabic sentence patterns.",
                "action": "Practice sentence structure"
            },
            "VOCAB": {
                "title": "Expand Your Vocabulary",
                "description": f"You have {count} vocabulary mistakes. Learn more Lebanese Arabic words.",
                "action": "Study vocabulary lists"
            }
        }

        if error_type in error_recommendations:
            rec = error_recommendations[error_type].copy()
            rec["type"] = error_type.lower()
            rec["priority"] = "high" if count > 5 else "medium"
            return rec

        return None