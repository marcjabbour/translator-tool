"""
Caching service for prompt→completion cache optimization.
Supports Redis and in-memory caching strategies.
"""

import json
import hashlib
import logging
import time
from typing import Optional, Dict, Any, Union
from abc import ABC, abstractmethod
from dataclasses import asdict

from .ai_controller import StoryGenerationRequest, StoryGenerationResponse, QuizGenerationRequest, QuizGenerationResponse

logger = logging.getLogger(__name__)


class CacheBackend(ABC):
    """Abstract base class for cache backends."""

    @abstractmethod
    def get(self, key: str) -> Optional[str]:
        """Get value from cache by key."""
        pass

    @abstractmethod
    def set(self, key: str, value: str, ttl: Optional[int] = None) -> bool:
        """Set value in cache with optional TTL."""
        pass

    @abstractmethod
    def delete(self, key: str) -> bool:
        """Delete key from cache."""
        pass

    @abstractmethod
    def exists(self, key: str) -> bool:
        """Check if key exists in cache."""
        pass


class InMemoryCache(CacheBackend):
    """In-memory cache implementation for development."""

    def __init__(self, default_ttl: int = 3600):
        """
        Initialize in-memory cache.

        Args:
            default_ttl: Default time-to-live in seconds
        """
        self.cache: Dict[str, Dict[str, Union[str, float]]] = {}
        self.default_ttl = default_ttl

    def get(self, key: str) -> Optional[str]:
        """Get value from cache, checking expiration."""
        try:
            if key not in self.cache:
                return None

            entry = self.cache[key]
            expiry = entry.get("expiry", 0)

            # Check if expired
            if expiry > 0 and time.time() > expiry:
                del self.cache[key]
                return None

            return entry.get("value")

        except Exception as e:
            logger.error(f"Cache get error: {e}")
            return None

    def set(self, key: str, value: str, ttl: Optional[int] = None) -> bool:
        """Set value in cache with expiration."""
        try:
            ttl = ttl or self.default_ttl
            expiry = time.time() + ttl if ttl > 0 else 0

            self.cache[key] = {
                "value": value,
                "expiry": expiry
            }

            return True

        except Exception as e:
            logger.error(f"Cache set error: {e}")
            return False

    def delete(self, key: str) -> bool:
        """Delete key from cache."""
        try:
            if key in self.cache:
                del self.cache[key]
            return True

        except Exception as e:
            logger.error(f"Cache delete error: {e}")
            return False

    def exists(self, key: str) -> bool:
        """Check if key exists and is not expired."""
        return self.get(key) is not None

    def cleanup_expired(self) -> int:
        """Remove expired entries from cache."""
        try:
            current_time = time.time()
            expired_keys = []

            for key, entry in self.cache.items():
                expiry = entry.get("expiry", 0)
                if expiry > 0 and current_time > expiry:
                    expired_keys.append(key)

            for key in expired_keys:
                del self.cache[key]

            if expired_keys:
                logger.info(f"Cleaned up {len(expired_keys)} expired cache entries")

            return len(expired_keys)

        except Exception as e:
            logger.error(f"Cache cleanup error: {e}")
            return 0


class RedisCache(CacheBackend):
    """Redis cache implementation for production."""

    def __init__(self, redis_client, default_ttl: int = 3600):
        """
        Initialize Redis cache.

        Args:
            redis_client: Redis client instance
            default_ttl: Default time-to-live in seconds
        """
        self.redis = redis_client
        self.default_ttl = default_ttl

    def get(self, key: str) -> Optional[str]:
        """Get value from Redis cache."""
        try:
            value = self.redis.get(key)
            return value.decode('utf-8') if value else None

        except Exception as e:
            logger.error(f"Redis get error: {e}")
            return None

    def set(self, key: str, value: str, ttl: Optional[int] = None) -> bool:
        """Set value in Redis cache with TTL."""
        try:
            ttl = ttl or self.default_ttl
            success = self.redis.setex(key, ttl, value) if ttl > 0 else self.redis.set(key, value)
            return bool(success)

        except Exception as e:
            logger.error(f"Redis set error: {e}")
            return False

    def delete(self, key: str) -> bool:
        """Delete key from Redis cache."""
        try:
            result = self.redis.delete(key)
            return result > 0

        except Exception as e:
            logger.error(f"Redis delete error: {e}")
            return False

    def exists(self, key: str) -> bool:
        """Check if key exists in Redis cache."""
        try:
            return bool(self.redis.exists(key))

        except Exception as e:
            logger.error(f"Redis exists error: {e}")
            return False


class CacheService:
    """
    Cache service for story generation with prompt→completion caching.
    Implements cache key strategy based on topic, level, and seed.
    """

    def __init__(self, backend: CacheBackend, cache_ttl: int = 24 * 3600):
        """
        Initialize cache service.

        Args:
            backend: Cache backend implementation
            cache_ttl: Cache time-to-live in seconds (default: 24 hours)
        """
        self.backend = backend
        self.cache_ttl = cache_ttl
        self.cache_prefix = "story_gen:"

    def generate_cache_key(self, request: StoryGenerationRequest) -> str:
        """
        Generate cache key based on topic, level, and seed.

        Args:
            request: Story generation request

        Returns:
            Cache key string
        """
        # Create consistent cache key from request parameters
        key_data = {
            "topic": request.topic,
            "level": request.level,
            "seed": request.seed
        }

        # Sort keys for consistency
        key_string = json.dumps(key_data, sort_keys=True)

        # Create hash for compact key
        key_hash = hashlib.md5(key_string.encode()).hexdigest()

        return f"{self.cache_prefix}{key_hash}"

    def generate_quiz_cache_key(self, request: QuizGenerationRequest) -> str:
        """
        Generate cache key for quiz generation based on lesson content.

        Args:
            request: Quiz generation request

        Returns:
            Cache key string
        """
        # Create cache key from lesson content and parameters
        key_data = {
            "lesson_id": request.lesson_id,
            "en_text_hash": hashlib.md5(request.en_text.encode()).hexdigest()[:8],
            "la_text_hash": hashlib.md5(request.la_text.encode()).hexdigest()[:8],
            "topic": request.topic,
            "level": request.level
        }

        # Sort keys for consistency
        key_string = json.dumps(key_data, sort_keys=True)

        # Create hash for compact key
        key_hash = hashlib.md5(key_string.encode()).hexdigest()

        return f"quiz:{key_hash}"

    def get_cached_story(self, request: StoryGenerationRequest) -> Optional[StoryGenerationResponse]:
        """
        Retrieve cached story generation result.

        Args:
            request: Story generation request

        Returns:
            Cached story response or None if not found
        """
        try:
            cache_key = self.generate_cache_key(request)
            cached_data = self.backend.get(cache_key)

            if not cached_data:
                logger.debug(f"Cache miss for key: {cache_key}")
                return None

            # Parse cached JSON
            story_data = json.loads(cached_data)

            response = StoryGenerationResponse(
                en_text=story_data["en_text"],
                la_text=story_data["la_text"],
                meta=story_data["meta"]
            )

            logger.info(f"Cache hit for key: {cache_key}")
            return response

        except Exception as e:
            logger.error(f"Failed to retrieve cached story: {e}")
            return None

    def cache_story(self, request: StoryGenerationRequest, response: StoryGenerationResponse) -> bool:
        """
        Cache story generation result.

        Args:
            request: Story generation request
            response: Story generation response

        Returns:
            True if successfully cached, False otherwise
        """
        try:
            cache_key = self.generate_cache_key(request)

            # Serialize response data
            cache_data = {
                "en_text": response.en_text,
                "la_text": response.la_text,
                "meta": response.meta,
                "cached_at": time.time()
            }

            cached_json = json.dumps(cache_data)

            # Store in cache
            success = self.backend.set(cache_key, cached_json, self.cache_ttl)

            if success:
                logger.info(f"Story cached with key: {cache_key}")
            else:
                logger.warning(f"Failed to cache story with key: {cache_key}")

            return success

        except Exception as e:
            logger.error(f"Failed to cache story: {e}")
            return False

    def get_cached_quiz(self, request: QuizGenerationRequest) -> Optional[QuizGenerationResponse]:
        """
        Retrieve cached quiz generation result.

        Args:
            request: Quiz generation request

        Returns:
            Cached quiz response or None if not found
        """
        try:
            cache_key = self.generate_quiz_cache_key(request)
            cached_data = self.backend.get(cache_key)

            if not cached_data:
                logger.debug(f"Quiz cache miss for key: {cache_key}")
                return None

            # Parse cached JSON
            quiz_data = json.loads(cached_data)

            # Reconstruct QuizQuestion objects
            questions = []
            for q_data in quiz_data["questions"]:
                question = QuizQuestion(
                    type=q_data["type"],
                    question=q_data["question"],
                    answer=q_data["answer"],
                    choices=q_data.get("choices"),
                    rationale=q_data.get("rationale")
                )
                questions.append(question)

            response = QuizGenerationResponse(
                questions=questions,
                answer_key=quiz_data["answer_key"],
                meta=quiz_data["meta"]
            )

            logger.info(f"Quiz cache hit for key: {cache_key}")
            return response

        except Exception as e:
            logger.error(f"Failed to retrieve cached quiz: {e}")
            return None

    def cache_quiz(self, request: QuizGenerationRequest, response: QuizGenerationResponse) -> bool:
        """
        Cache quiz generation result.

        Args:
            request: Quiz generation request
            response: Quiz generation response

        Returns:
            True if successfully cached, False otherwise
        """
        try:
            cache_key = self.generate_quiz_cache_key(request)

            # Serialize response data
            cache_data = {
                "questions": [
                    {
                        "type": q.type,
                        "question": q.question,
                        "answer": q.answer,
                        "choices": q.choices,
                        "rationale": q.rationale
                    }
                    for q in response.questions
                ],
                "answer_key": response.answer_key,
                "meta": response.meta,
                "cached_at": time.time()
            }

            cached_json = json.dumps(cache_data)

            # Store in cache
            success = self.backend.set(cache_key, cached_json, self.cache_ttl)

            if success:
                logger.info(f"Quiz cached with key: {cache_key}")
            else:
                logger.warning(f"Failed to cache quiz with key: {cache_key}")

            return success

        except Exception as e:
            logger.error(f"Failed to cache quiz: {e}")
            return False

    def invalidate_cache(self, request: StoryGenerationRequest) -> bool:
        """
        Invalidate cached story for specific request.

        Args:
            request: Story generation request

        Returns:
            True if successfully invalidated, False otherwise
        """
        try:
            cache_key = self.generate_cache_key(request)
            success = self.backend.delete(cache_key)

            if success:
                logger.info(f"Cache invalidated for key: {cache_key}")

            return success

        except Exception as e:
            logger.error(f"Failed to invalidate cache: {e}")
            return False

    def get_cache_stats(self) -> Dict[str, Any]:
        """
        Get cache statistics (implementation depends on backend).

        Returns:
            Dictionary with cache statistics
        """
        stats = {
            "backend_type": type(self.backend).__name__,
            "cache_ttl": self.cache_ttl,
            "cache_prefix": self.cache_prefix
        }

        # Additional stats for in-memory cache
        if isinstance(self.backend, InMemoryCache):
            stats["entries_count"] = len(self.backend.cache)

        return stats

    def clear_all_cache(self) -> bool:
        """
        Clear all cached stories (use with caution).

        Returns:
            True if successful (implementation depends on backend)
        """
        try:
            # For in-memory cache, clear all entries
            if isinstance(self.backend, InMemoryCache):
                self.backend.cache.clear()
                logger.info("All cache entries cleared")
                return True

            # For Redis, would need to scan and delete by prefix
            logger.warning("Clear all cache not implemented for this backend")
            return False

        except Exception as e:
            logger.error(f"Failed to clear cache: {e}")
            return False


def create_cache_service(use_redis: bool = False, redis_client=None) -> CacheService:
    """
    Factory function to create cache service with appropriate backend.

    Args:
        use_redis: Whether to use Redis backend
        redis_client: Redis client instance (required if use_redis=True)

    Returns:
        Configured cache service instance
    """
    if use_redis and redis_client:
        backend = RedisCache(redis_client)
        logger.info("Cache service created with Redis backend")
    else:
        backend = InMemoryCache()
        logger.info("Cache service created with in-memory backend")

    return CacheService(backend)