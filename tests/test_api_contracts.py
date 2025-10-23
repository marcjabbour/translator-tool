"""
Contract tests for API JSON schemas using Pydantic + pytest.
Validates POST /api/v1/story endpoint request/response schemas.
"""

import pytest
from pydantic import ValidationError
from app.models import LessonRequest, LessonResponse


class TestAPIContracts:
    """Test API contract validation using Pydantic schemas."""

    def test_lesson_request_valid_schema(self):
        """Test valid lesson request schema."""
        valid_request = {
            "topic": "coffee_chat",
            "level": "beginner",
            "seed": 42
        }

        # Should not raise ValidationError
        lesson_request = LessonRequest(**valid_request)
        assert lesson_request.topic == "coffee_chat"
        assert lesson_request.level == "beginner"
        assert lesson_request.seed == 42

    def test_lesson_request_required_fields(self):
        """Test lesson request requires topic and level."""
        # Missing topic should fail
        with pytest.raises(ValidationError) as exc_info:
            LessonRequest(level="beginner")
        assert "topic" in str(exc_info.value)

        # Missing level should fail
        with pytest.raises(ValidationError) as exc_info:
            LessonRequest(topic="coffee_chat")
        assert "level" in str(exc_info.value)

    def test_lesson_request_optional_seed(self):
        """Test lesson request with optional seed parameter."""
        # Seed is optional
        lesson_request = LessonRequest(topic="greeting", level="intermediate")
        assert lesson_request.topic == "greeting"
        assert lesson_request.level == "intermediate"
        assert lesson_request.seed is None

    def test_lesson_request_field_types(self):
        """Test lesson request field type validation."""
        # Topic must be string
        with pytest.raises(ValidationError):
            LessonRequest(topic=123, level="beginner")

        # Level must be string
        with pytest.raises(ValidationError):
            LessonRequest(topic="coffee_chat", level=456)

        # Seed must be int if provided
        with pytest.raises(ValidationError):
            LessonRequest(topic="coffee_chat", level="beginner", seed="not_int")

    def test_lesson_response_valid_schema(self):
        """Test valid lesson response schema."""
        valid_response = {
            "lesson_id": "550e8400-e29b-41d4-a716-446655440000",
            "en_text": "Hey, want to grab coffee?",
            "la_text": "ahlan, baddak nrou7 neeshrab ahwe?",
            "meta": {"topic": "coffee_chat", "level": "beginner"}
        }

        # Should not raise ValidationError
        lesson_response = LessonResponse(**valid_response)
        assert lesson_response.lesson_id == "550e8400-e29b-41d4-a716-446655440000"
        assert lesson_response.en_text == "Hey, want to grab coffee?"
        assert lesson_response.la_text == "ahlan, baddak nrou7 neeshrab ahwe?"
        assert lesson_response.meta == {"topic": "coffee_chat", "level": "beginner"}

    def test_lesson_response_required_fields(self):
        """Test lesson response requires all fields except meta."""
        # Missing lesson_id
        with pytest.raises(ValidationError) as exc_info:
            LessonResponse(
                en_text="Hello",
                la_text="ahlan"
            )
        assert "lesson_id" in str(exc_info.value)

        # Missing en_text
        with pytest.raises(ValidationError) as exc_info:
            LessonResponse(
                lesson_id="550e8400-e29b-41d4-a716-446655440000",
                la_text="ahlan"
            )
        assert "en_text" in str(exc_info.value)

        # Missing la_text
        with pytest.raises(ValidationError) as exc_info:
            LessonResponse(
                lesson_id="550e8400-e29b-41d4-a716-446655440000",
                en_text="Hello"
            )
        assert "la_text" in str(exc_info.value)

    def test_lesson_response_meta_default(self):
        """Test lesson response meta field defaults to empty dict."""
        lesson_response = LessonResponse(
            lesson_id="550e8400-e29b-41d4-a716-446655440000",
            en_text="Hello",
            la_text="ahlan"
        )
        assert lesson_response.meta == {}

    def test_lesson_response_field_types(self):
        """Test lesson response field type validation."""
        base_data = {
            "lesson_id": "550e8400-e29b-41d4-a716-446655440000",
            "en_text": "Hello",
            "la_text": "ahlan"
        }

        # lesson_id must be string
        with pytest.raises(ValidationError):
            LessonResponse(**{**base_data, "lesson_id": 123})

        # en_text must be string
        with pytest.raises(ValidationError):
            LessonResponse(**{**base_data, "en_text": 456})

        # la_text must be string
        with pytest.raises(ValidationError):
            LessonResponse(**{**base_data, "la_text": 789})

        # meta must be dict
        with pytest.raises(ValidationError):
            LessonResponse(**{**base_data, "meta": "not_dict"})

    def test_api_contract_json_serialization(self):
        """Test API contract models can be serialized to/from JSON."""
        # Test request serialization
        request = LessonRequest(topic="coffee_chat", level="beginner", seed=42)
        request_json = request.model_dump()
        assert request_json == {
            "topic": "coffee_chat",
            "level": "beginner",
            "seed": 42
        }

        # Test response serialization
        response = LessonResponse(
            lesson_id="550e8400-e29b-41d4-a716-446655440000",
            en_text="Hello",
            la_text="ahlan",
            meta={"key": "value"}
        )
        response_json = response.model_dump()
        assert response_json == {
            "lesson_id": "550e8400-e29b-41d4-a716-446655440000",
            "en_text": "Hello",
            "la_text": "ahlan",
            "meta": {"key": "value"}
        }

    @pytest.mark.parametrize("topic,level,seed", [
        ("coffee_chat", "beginner", 42),
        ("restaurant", "intermediate", None),
        ("shopping", "advanced", 123),
        ("greeting", "beginner", 0),
    ])
    def test_lesson_request_valid_combinations(self, topic, level, seed):
        """Test various valid topic/level/seed combinations."""
        if seed is not None:
            request = LessonRequest(topic=topic, level=level, seed=seed)
            assert request.seed == seed
        else:
            request = LessonRequest(topic=topic, level=level)
            assert request.seed is None

        assert request.topic == topic
        assert request.level == level

    def test_api_contract_backward_compatibility(self):
        """Test API contracts maintain backward compatibility."""
        # Ensure adding new optional fields doesn't break existing clients
        old_request_data = {
            "topic": "coffee_chat",
            "level": "beginner"
        }

        request = LessonRequest(**old_request_data)
        assert request.topic == "coffee_chat"
        assert request.level == "beginner"
        assert request.seed is None

        # Response should work with minimal required fields
        minimal_response_data = {
            "lesson_id": "550e8400-e29b-41d4-a716-446655440000",
            "en_text": "Hello",
            "la_text": "ahlan"
        }

        response = LessonResponse(**minimal_response_data)
        assert response.meta == {}  # Default empty dict