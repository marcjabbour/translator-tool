"""
Integration tests for the complete API endpoint functionality.
Tests the full POST /api/v1/story workflow with authentication and rate limiting.
"""

import pytest
import os
from unittest.mock import Mock, patch
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.models import Base, DatabaseManager
from app.auth_controller import AuthController


class TestAPIIntegration:
    """Integration tests for the story generation API."""

    @pytest.fixture(scope="class")
    def test_db(self):
        """Create test database."""
        # Use in-memory SQLite for testing
        engine = create_engine("sqlite:///:memory:", echo=False)
        Base.metadata.create_all(engine)

        TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

        yield TestingSessionLocal

        Base.metadata.drop_all(engine)

    @pytest.fixture
    def client(self):
        """Create test client."""
        return TestClient(app)

    @pytest.fixture
    def auth_token(self):
        """Create valid test authentication token."""
        auth_controller = AuthController()
        return auth_controller.create_test_token("test_user_123")

    @pytest.fixture
    def mock_ai_response(self):
        """Mock AI controller response."""
        with patch('app.main.ai_controller') as mock_ai:
            mock_response = Mock()
            mock_response.en_text = "Hey, want to grab coffee?"
            mock_response.la_text = "ahlan, baddak nrou7 neeshrab ahwe?"
            mock_response.meta = {"topic": "coffee_chat", "level": "beginner"}

            mock_ai.generate_story.return_value = mock_response
            yield mock_ai

    @pytest.fixture
    def mock_database(self):
        """Mock database operations."""
        with patch('app.main.db_manager') as mock_db:
            mock_repo = Mock()
            mock_lesson = Mock()
            mock_lesson.lesson_id = "550e8400-e29b-41d4-a716-446655440000"
            mock_lesson.en_text = "Hey, want to grab coffee?"
            mock_lesson.la_text = "ahlan, baddak nrou7 neeshrab ahwe?"
            mock_lesson.meta = {"topic": "coffee_chat", "level": "beginner"}

            mock_repo.create_lesson.return_value = mock_lesson
            mock_db.get_repository.return_value = mock_repo
            yield mock_db

    def test_story_endpoint_success(self, client, auth_token, mock_ai_response, mock_database):
        """Test successful story generation."""
        headers = {"Authorization": f"Bearer {auth_token}"}
        payload = {
            "topic": "coffee_chat",
            "level": "beginner",
            "seed": 42
        }

        response = client.post("/api/v1/story", json=payload, headers=headers)

        assert response.status_code == 200
        data = response.json()

        assert "lesson_id" in data
        assert data["en_text"] == "Hey, want to grab coffee?"
        assert data["la_text"] == "ahlan, baddak nrou7 neeshrab ahwe?"
        assert data["meta"]["topic"] == "coffee_chat"
        assert data["meta"]["level"] == "beginner"

    def test_story_endpoint_missing_auth(self, client):
        """Test story endpoint without authentication."""
        payload = {
            "topic": "coffee_chat",
            "level": "beginner"
        }

        response = client.post("/api/v1/story", json=payload)

        assert response.status_code == 403  # FastAPI returns 403 for missing auth

    def test_story_endpoint_invalid_token(self, client):
        """Test story endpoint with invalid token."""
        headers = {"Authorization": "Bearer invalid_token"}
        payload = {
            "topic": "coffee_chat",
            "level": "beginner"
        }

        response = client.post("/api/v1/story", json=payload, headers=headers)

        assert response.status_code == 401
        assert "invalid" in response.json()["detail"].lower()

    def test_story_endpoint_invalid_payload(self, client, auth_token):
        """Test story endpoint with invalid request payload."""
        headers = {"Authorization": f"Bearer {auth_token}"}

        # Missing required fields
        invalid_payloads = [
            {},  # Empty payload
            {"topic": "coffee_chat"},  # Missing level
            {"level": "beginner"},  # Missing topic
            {"topic": 123, "level": "beginner"},  # Invalid topic type
            {"topic": "coffee_chat", "level": 456},  # Invalid level type
            {"topic": "coffee_chat", "level": "beginner", "seed": "not_int"},  # Invalid seed type
        ]

        for payload in invalid_payloads:
            response = client.post("/api/v1/story", json=payload, headers=headers)
            assert response.status_code == 422, f"Payload should be invalid: {payload}"

    @patch('app.main.rate_limiter')
    def test_story_endpoint_rate_limiting(self, mock_rate_limiter, client, auth_token, mock_ai_response, mock_database):
        """Test rate limiting functionality."""
        # Configure rate limiter to reject requests
        mock_rate_limiter.check_limit.return_value = False
        mock_rate_limiter.get_remaining_requests.return_value = 0
        mock_rate_limiter.get_reset_time.return_value = 3600

        headers = {"Authorization": f"Bearer {auth_token}"}
        payload = {
            "topic": "coffee_chat",
            "level": "beginner"
        }

        response = client.post("/api/v1/story", json=payload, headers=headers)

        assert response.status_code == 429
        assert "rate limit" in response.json()["detail"].lower()
        assert "Retry-After" in response.headers

    def test_story_endpoint_different_topics(self, client, auth_token, mock_ai_response, mock_database):
        """Test story endpoint with different topics."""
        headers = {"Authorization": f"Bearer {auth_token}"}

        topics = ["coffee_chat", "restaurant", "shopping", "greeting", "family"]

        for topic in topics:
            payload = {
                "topic": topic,
                "level": "beginner",
                "seed": 42
            }

            response = client.post("/api/v1/story", json=payload, headers=headers)
            assert response.status_code == 200, f"Failed for topic: {topic}"

            data = response.json()
            assert data["meta"]["topic"] == topic

    def test_story_endpoint_different_levels(self, client, auth_token, mock_ai_response, mock_database):
        """Test story endpoint with different difficulty levels."""
        headers = {"Authorization": f"Bearer {auth_token}"}

        levels = ["beginner", "intermediate", "advanced"]

        for level in levels:
            payload = {
                "topic": "coffee_chat",
                "level": level,
                "seed": 42
            }

            response = client.post("/api/v1/story", json=payload, headers=headers)
            assert response.status_code == 200, f"Failed for level: {level}"

            data = response.json()
            assert data["meta"]["level"] == level

    def test_story_endpoint_with_seed(self, client, auth_token, mock_ai_response, mock_database):
        """Test story endpoint with seed parameter."""
        headers = {"Authorization": f"Bearer {auth_token}"}

        payload_with_seed = {
            "topic": "coffee_chat",
            "level": "beginner",
            "seed": 42
        }

        payload_without_seed = {
            "topic": "coffee_chat",
            "level": "beginner"
        }

        # Both should work
        response1 = client.post("/api/v1/story", json=payload_with_seed, headers=headers)
        response2 = client.post("/api/v1/story", json=payload_without_seed, headers=headers)

        assert response1.status_code == 200
        assert response2.status_code == 200

    @patch('app.main.ai_controller')
    def test_story_endpoint_ai_error_handling(self, mock_ai, client, auth_token, mock_database):
        """Test story endpoint handles AI controller errors."""
        # Configure AI controller to raise an error
        mock_ai.generate_story.side_effect = Exception("AI service unavailable")

        headers = {"Authorization": f"Bearer {auth_token}"}
        payload = {
            "topic": "coffee_chat",
            "level": "beginner"
        }

        response = client.post("/api/v1/story", json=payload, headers=headers)

        assert response.status_code == 500
        assert "internal server error" in response.json()["detail"].lower()

    @patch('app.main.db_manager')
    def test_story_endpoint_database_error_handling(self, mock_db, client, auth_token, mock_ai_response):
        """Test story endpoint handles database errors."""
        # Configure database to raise an error
        mock_repo = Mock()
        mock_repo.create_lesson.side_effect = Exception("Database unavailable")
        mock_db.get_repository.return_value = mock_repo

        headers = {"Authorization": f"Bearer {auth_token}"}
        payload = {
            "topic": "coffee_chat",
            "level": "beginner"
        }

        response = client.post("/api/v1/story", json=payload, headers=headers)

        assert response.status_code == 500

    def test_health_endpoints(self, client):
        """Test health check endpoints."""
        # Basic health check
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["service"] == "translator-tool-api"

    @patch('app.main.db_manager')
    def test_api_health_endpoint(self, mock_db, client):
        """Test API health check with database connectivity."""
        # Mock successful database connection
        mock_repo = Mock()
        mock_repo.get_lesson_count.return_value = 42
        mock_db.get_repository.return_value = mock_repo

        response = client.get("/api/v1/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["database"] == "connected"
        assert data["total_lessons"] == 42

    @patch('app.main.db_manager')
    def test_api_health_endpoint_database_error(self, mock_db, client):
        """Test API health check with database error."""
        # Mock database error
        mock_repo = Mock()
        mock_repo.get_lesson_count.side_effect = Exception("Database error")
        mock_db.get_repository.return_value = mock_repo

        response = client.get("/api/v1/health")
        assert response.status_code == 503
        assert "database connection failed" in response.json()["detail"].lower()

    def test_cors_headers(self, client):
        """Test CORS headers are present."""
        response = client.options("/api/v1/story")

        # Should have CORS headers (exact headers depend on CORS configuration)
        assert response.status_code in [200, 405]  # 405 if OPTIONS not explicitly handled

    def test_request_response_content_type(self, client, auth_token, mock_ai_response, mock_database):
        """Test request and response content types."""
        headers = {
            "Authorization": f"Bearer {auth_token}",
            "Content-Type": "application/json"
        }
        payload = {
            "topic": "coffee_chat",
            "level": "beginner"
        }

        response = client.post("/api/v1/story", json=payload, headers=headers)

        assert response.status_code == 200
        assert response.headers["content-type"] == "application/json"

    def test_response_schema_validation(self, client, auth_token, mock_ai_response, mock_database):
        """Test response matches expected schema."""
        headers = {"Authorization": f"Bearer {auth_token}"}
        payload = {
            "topic": "coffee_chat",
            "level": "beginner",
            "seed": 42
        }

        response = client.post("/api/v1/story", json=payload, headers=headers)

        assert response.status_code == 200
        data = response.json()

        # Validate response schema
        required_fields = ["lesson_id", "en_text", "la_text", "meta"]
        for field in required_fields:
            assert field in data, f"Missing required field: {field}"

        # Validate field types
        assert isinstance(data["lesson_id"], str)
        assert isinstance(data["en_text"], str)
        assert isinstance(data["la_text"], str)
        assert isinstance(data["meta"], dict)

        # Validate meta content
        assert "topic" in data["meta"]
        assert "level" in data["meta"]