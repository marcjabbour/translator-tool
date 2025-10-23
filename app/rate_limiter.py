"""
Rate limiting implementation for API endpoints.
Implements 100 requests per day per user for story generation.
"""

import time
import logging
from typing import Dict, Optional
from datetime import datetime, timedelta
from collections import defaultdict

logger = logging.getLogger(__name__)


class RateLimiter:
    """In-memory rate limiter for development. Use Redis for production."""

    def __init__(self):
        """Initialize rate limiter with default limits."""
        # Rate limits per endpoint type
        self.limits = {
            "story_generation": 100  # 100 requests per day per user
        }

        # In-memory storage: {user_id: {endpoint: [(timestamp, count)]}}
        self.usage_data: Dict[str, Dict[str, list]] = defaultdict(lambda: defaultdict(list))

        # Window duration (24 hours for daily limits)
        self.window_duration = 24 * 60 * 60  # 24 hours in seconds

        logger.info("Rate limiter initialized")

    def check_limit(self, user_id: str, endpoint_type: str) -> bool:
        """
        Check if user is within rate limit for endpoint.

        Args:
            user_id: User identifier
            endpoint_type: Type of endpoint (e.g., 'story_generation')

        Returns:
            True if within limit, False if limit exceeded
        """
        try:
            limit = self.limits.get(endpoint_type, 100)
            current_usage = self.get_current_usage(user_id, endpoint_type)

            within_limit = current_usage < limit
            logger.info(f"Rate limit check for {user_id}/{endpoint_type}: {current_usage}/{limit} - {'OK' if within_limit else 'EXCEEDED'}")

            return within_limit

        except Exception as e:
            logger.error(f"Rate limit check failed: {e}")
            # Fail open - allow request if rate limiting fails
            return True

    def increment_usage(self, user_id: str, endpoint_type: str) -> None:
        """
        Increment usage counter for user and endpoint.

        Args:
            user_id: User identifier
            endpoint_type: Type of endpoint
        """
        try:
            current_time = time.time()
            self.usage_data[user_id][endpoint_type].append(current_time)

            # Clean up old entries
            self._cleanup_old_entries(user_id, endpoint_type)

            current_usage = len(self.usage_data[user_id][endpoint_type])
            logger.info(f"Usage incremented for {user_id}/{endpoint_type}: {current_usage}")

        except Exception as e:
            logger.error(f"Failed to increment usage: {e}")

    def get_current_usage(self, user_id: str, endpoint_type: str) -> int:
        """
        Get current usage count for user and endpoint within time window.

        Args:
            user_id: User identifier
            endpoint_type: Type of endpoint

        Returns:
            Current usage count
        """
        try:
            # Clean up old entries first
            self._cleanup_old_entries(user_id, endpoint_type)

            # Return current count
            return len(self.usage_data[user_id][endpoint_type])

        except Exception as e:
            logger.error(f"Failed to get current usage: {e}")
            return 0

    def get_remaining_requests(self, user_id: str, endpoint_type: str) -> int:
        """
        Get remaining requests for user and endpoint.

        Args:
            user_id: User identifier
            endpoint_type: Type of endpoint

        Returns:
            Number of remaining requests
        """
        try:
            limit = self.limits.get(endpoint_type, 100)
            current_usage = self.get_current_usage(user_id, endpoint_type)
            remaining = max(0, limit - current_usage)

            return remaining

        except Exception as e:
            logger.error(f"Failed to get remaining requests: {e}")
            return 0

    def get_reset_time(self) -> int:
        """
        Get time until rate limit resets (in seconds).

        Returns:
            Seconds until next reset (daily reset at midnight UTC)
        """
        try:
            now = datetime.utcnow()
            # Calculate next midnight UTC
            next_reset = (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
            reset_seconds = int((next_reset - now).total_seconds())

            return reset_seconds

        except Exception as e:
            logger.error(f"Failed to calculate reset time: {e}")
            return 3600  # Default to 1 hour

    def _cleanup_old_entries(self, user_id: str, endpoint_type: str) -> None:
        """
        Remove usage entries older than the time window.

        Args:
            user_id: User identifier
            endpoint_type: Type of endpoint
        """
        try:
            current_time = time.time()
            cutoff_time = current_time - self.window_duration

            # Remove entries older than cutoff
            old_entries = self.usage_data[user_id][endpoint_type]
            new_entries = [timestamp for timestamp in old_entries if timestamp > cutoff_time]
            self.usage_data[user_id][endpoint_type] = new_entries

            removed_count = len(old_entries) - len(new_entries)
            if removed_count > 0:
                logger.debug(f"Cleaned up {removed_count} old entries for {user_id}/{endpoint_type}")

        except Exception as e:
            logger.error(f"Failed to cleanup old entries: {e}")

    def reset_user_limits(self, user_id: str) -> None:
        """
        Reset all limits for a specific user.

        Args:
            user_id: User identifier to reset
        """
        try:
            if user_id in self.usage_data:
                del self.usage_data[user_id]
                logger.info(f"Reset rate limits for user: {user_id}")

        except Exception as e:
            logger.error(f"Failed to reset user limits: {e}")

    def get_usage_stats(self, user_id: str) -> Dict[str, Dict[str, int]]:
        """
        Get usage statistics for a user.

        Args:
            user_id: User identifier

        Returns:
            Dictionary with usage stats per endpoint
        """
        try:
            stats = {}
            for endpoint_type in self.limits.keys():
                current_usage = self.get_current_usage(user_id, endpoint_type)
                limit = self.limits[endpoint_type]
                remaining = self.get_remaining_requests(user_id, endpoint_type)

                stats[endpoint_type] = {
                    "current_usage": current_usage,
                    "limit": limit,
                    "remaining": remaining
                }

            return stats

        except Exception as e:
            logger.error(f"Failed to get usage stats: {e}")
            return {}


# Production Redis-based rate limiter (placeholder)
class RedisRateLimiter(RateLimiter):
    """Redis-based rate limiter for production use."""

    def __init__(self, redis_client=None):
        """
        Initialize Redis rate limiter.

        Args:
            redis_client: Redis client instance
        """
        super().__init__()
        self.redis = redis_client
        logger.info("Redis rate limiter initialized")

    # Implement Redis-based methods here for production use
    # This would replace the in-memory storage with Redis operations