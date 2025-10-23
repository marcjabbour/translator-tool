"""
Latency budget tests for performance monitoring.
Tests validate story generation P50 < 1.5s (cached) requirement.
"""

import pytest
import time
import statistics
from unittest.mock import Mock, patch
from app.ai_controller import AIController, StoryGenerationRequest
from app.cache_service import CacheService, InMemoryCache


class TestLatencyBudgets:
    """Test latency budget requirements for story generation."""

    def setup_method(self):
        """Set up test instances with caching."""
        # Create cache service for performance testing
        cache_backend = InMemoryCache()
        self.cache_service = CacheService(cache_backend)

        # Mock Anthropic client
        self.mock_anthropic = Mock()
        self.ai_controller = AIController(
            anthropic_client=self.mock_anthropic,
            cache_service=self.cache_service
        )

        # Mock LLM response
        self._setup_mock_llm_response()

    def _setup_mock_llm_response(self):
        """Set up mock LLM response for consistent testing."""
        mock_response = Mock()
        mock_response.content = [Mock()]
        mock_response.content[0].text = '''
        {
            "en_text": "Hey, want to grab coffee?",
            "la_text": "ahlan, baddak nrou7 neeshrab ahwe?"
        }
        '''
        self.mock_anthropic.messages.create.return_value = mock_response

    def test_cached_story_generation_latency(self):
        """Test cached story generation meets P50 < 1.5s requirement."""
        request = StoryGenerationRequest(
            topic="coffee_chat",
            level="beginner",
            seed=42
        )

        # First generation (cache miss) - populate cache
        start_time = time.time()
        response1 = self.ai_controller.generate_story(request)
        first_gen_time = time.time() - start_time

        # Verify response is valid
        assert response1.en_text == "Hey, want to grab coffee?"
        assert response1.la_text == "ahlan, baddak nrou7 neeshrab ahwe?"

        # Multiple cached requests to test P50
        cached_times = []
        for _ in range(10):
            start_time = time.time()
            response = self.ai_controller.generate_story(request)
            elapsed_time = time.time() - start_time
            cached_times.append(elapsed_time)

            # Verify consistent response from cache
            assert response.en_text == response1.en_text
            assert response.la_text == response1.la_text

        # Calculate P50 (median)
        p50_latency = statistics.median(cached_times)

        # Verify P50 < 1.5s requirement
        assert p50_latency < 1.5, f"P50 latency {p50_latency:.3f}s exceeds 1.5s budget"

        # Cached requests should be significantly faster than first generation
        assert p50_latency < first_gen_time, "Cached requests should be faster than initial generation"

        print(f"First generation: {first_gen_time:.3f}s")
        print(f"P50 cached latency: {p50_latency:.3f}s")
        print(f"All cached times: {[f'{t:.3f}' for t in cached_times]}")

    def test_cache_performance_improvement(self):
        """Test cache provides significant performance improvement."""
        request = StoryGenerationRequest(
            topic="restaurant",
            level="intermediate",
            seed=123
        )

        # Measure uncached generation time
        self.ai_controller.cache_service = None  # Disable cache
        start_time = time.time()
        response1 = self.ai_controller.generate_story(request)
        uncached_time = time.time() - start_time

        # Re-enable cache and measure cached time
        self.ai_controller.cache_service = self.cache_service
        start_time = time.time()
        response2 = self.ai_controller.generate_story(request)
        cached_time = time.time() - start_time

        # Cache should provide significant speedup
        speedup_ratio = uncached_time / cached_time
        assert speedup_ratio > 2, f"Cache speedup {speedup_ratio:.1f}x is insufficient"

        print(f"Uncached time: {uncached_time:.3f}s")
        print(f"Cached time: {cached_time:.3f}s")
        print(f"Speedup ratio: {speedup_ratio:.1f}x")

    def test_latency_consistency_across_topics(self):
        """Test latency is consistent across different topics."""
        topics = ["coffee_chat", "restaurant", "shopping", "greeting", "family"]
        latencies = []

        for topic in topics:
            request = StoryGenerationRequest(
                topic=topic,
                level="beginner",
                seed=42
            )

            # First request to populate cache
            self.ai_controller.generate_story(request)

            # Measure cached request
            start_time = time.time()
            self.ai_controller.generate_story(request)
            latency = time.time() - start_time
            latencies.append(latency)

        # All latencies should meet budget
        for i, latency in enumerate(latencies):
            assert latency < 1.5, f"Topic '{topics[i]}' latency {latency:.3f}s exceeds budget"

        # Latencies should be reasonably consistent
        max_latency = max(latencies)
        min_latency = min(latencies)
        assert max_latency / min_latency < 5, "Latency variance too high across topics"

        print(f"Topic latencies: {dict(zip(topics, [f'{l:.3f}s' for l in latencies]))}")

    def test_latency_under_load(self):
        """Test latency remains acceptable under concurrent load."""
        request = StoryGenerationRequest(
            topic="coffee_chat",
            level="beginner",
            seed=42
        )

        # Populate cache
        self.ai_controller.generate_story(request)

        # Simulate concurrent requests
        latencies = []
        for _ in range(50):  # Simulate 50 concurrent-ish requests
            start_time = time.time()
            self.ai_controller.generate_story(request)
            latency = time.time() - start_time
            latencies.append(latency)

        # Calculate percentiles
        p50 = statistics.median(latencies)
        p95 = statistics.quantiles(latencies, n=20)[18]  # 95th percentile
        p99 = statistics.quantiles(latencies, n=100)[98]  # 99th percentile

        # Verify latency budgets
        assert p50 < 1.5, f"P50 under load {p50:.3f}s exceeds budget"
        assert p95 < 3.0, f"P95 under load {p95:.3f}s is too high"
        assert p99 < 5.0, f"P99 under load {p99:.3f}s is too high"

        print(f"Load test - P50: {p50:.3f}s, P95: {p95:.3f}s, P99: {p99:.3f}s")

    def test_cache_hit_rate_performance(self):
        """Test cache hit rate affects performance as expected."""
        requests = [
            StoryGenerationRequest(topic="coffee_chat", level="beginner", seed=i)
            for i in range(5)
        ]

        # Measure cache miss performance (first requests)
        miss_times = []
        for request in requests:
            start_time = time.time()
            self.ai_controller.generate_story(request)
            miss_time = time.time() - start_time
            miss_times.append(miss_time)

        # Measure cache hit performance (repeat requests)
        hit_times = []
        for request in requests:
            start_time = time.time()
            self.ai_controller.generate_story(request)
            hit_time = time.time() - start_time
            hit_times.append(hit_time)

        # Cache hits should be consistently faster
        avg_miss_time = statistics.mean(miss_times)
        avg_hit_time = statistics.mean(hit_times)

        assert avg_hit_time < avg_miss_time, "Cache hits should be faster than misses"
        assert avg_hit_time < 1.5, f"Average cache hit time {avg_hit_time:.3f}s exceeds budget"

        print(f"Average cache miss time: {avg_miss_time:.3f}s")
        print(f"Average cache hit time: {avg_hit_time:.3f}s")

    def test_latency_with_different_cache_backends(self):
        """Test latency with different cache backend implementations."""
        request = StoryGenerationRequest(
            topic="coffee_chat",
            level="beginner",
            seed=42
        )

        # Test in-memory cache
        memory_cache = CacheService(InMemoryCache())
        ai_controller_memory = AIController(
            anthropic_client=self.mock_anthropic,
            cache_service=memory_cache
        )

        # Populate cache
        ai_controller_memory.generate_story(request)

        # Measure in-memory cache performance
        start_time = time.time()
        ai_controller_memory.generate_story(request)
        memory_latency = time.time() - start_time

        assert memory_latency < 1.5, f"In-memory cache latency {memory_latency:.3f}s exceeds budget"

        print(f"In-memory cache latency: {memory_latency:.3f}s")

    @pytest.mark.performance
    def test_latency_regression_baseline(self):
        """Test latency doesn't regress from baseline performance."""
        # This test establishes baseline for future regression testing
        request = StoryGenerationRequest(
            topic="coffee_chat",
            level="beginner",
            seed=42
        )

        # Populate cache
        self.ai_controller.generate_story(request)

        # Measure baseline performance
        baseline_times = []
        for _ in range(20):
            start_time = time.time()
            self.ai_controller.generate_story(request)
            latency = time.time() - start_time
            baseline_times.append(latency)

        p50_baseline = statistics.median(baseline_times)
        p95_baseline = statistics.quantiles(baseline_times, n=20)[18]

        # Store baseline for comparison (in real testing, this would be stored)
        print(f"Baseline P50: {p50_baseline:.3f}s")
        print(f"Baseline P95: {p95_baseline:.3f}s")

        # Verify meets current requirements
        assert p50_baseline < 1.5, f"Baseline P50 {p50_baseline:.3f}s exceeds budget"
        assert p95_baseline < 3.0, f"Baseline P95 {p95_baseline:.3f}s is too high"

    def test_timeout_handling(self):
        """Test handling of requests that exceed reasonable timeouts."""
        # Simulate slow LLM response
        def slow_llm_call(*args, **kwargs):
            time.sleep(0.1)  # Simulate network delay
            return self.mock_anthropic.messages.create.return_value

        self.mock_anthropic.messages.create.side_effect = slow_llm_call

        request = StoryGenerationRequest(
            topic="coffee_chat",
            level="beginner",
            seed=42
        )

        # First request (cache miss) - should handle slow LLM
        start_time = time.time()
        response = self.ai_controller.generate_story(request)
        first_time = time.time() - start_time

        assert response is not None, "Should handle slow LLM gracefully"

        # Cached request should still be fast
        start_time = time.time()
        cached_response = self.ai_controller.generate_story(request)
        cached_time = time.time() - start_time

        assert cached_time < 1.5, f"Cached request {cached_time:.3f}s should meet budget despite slow LLM"

        print(f"Slow LLM time: {first_time:.3f}s")
        print(f"Cached time after slow LLM: {cached_time:.3f}s")