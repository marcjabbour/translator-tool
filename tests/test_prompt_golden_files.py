"""
Prompt tests with golden files for LLM constraints.
Tests validate prompt generation and LLM output consistency.
"""

import pytest
import json
import os
from unittest.mock import Mock, patch
from app.ai_controller import AIController, StoryGenerationRequest, StoryGenerationResponse


class TestPromptGoldenFiles:
    """Test LLM prompts with golden file validation."""

    def setup_method(self):
        """Set up test instances."""
        # Mock Anthropic client to avoid actual API calls
        self.mock_anthropic = Mock()
        self.ai_controller = AIController(anthropic_client=self.mock_anthropic)

    def test_prompt_generation_coffee_chat_beginner(self):
        """Test prompt generation for coffee chat scenario."""
        request = StoryGenerationRequest(
            topic="coffee_chat",
            level="beginner",
            seed=42
        )

        prompt = self.ai_controller._create_story_prompt(request)

        # Validate prompt contains required elements
        assert "coffee_chat" in prompt
        assert "beginner" in prompt
        assert "seed" in prompt or "42" in prompt
        assert "simple vocabulary" in prompt.lower()
        assert "5-10 words" in prompt
        assert "JSON format" in prompt
        assert "en_text" in prompt
        assert "la_text" in prompt

        # Validate transliteration rules are included
        assert "7=ح" in prompt or "7 for ح" in prompt
        assert "3=ع" in prompt or "3 for ع" in prompt
        assert "Latin" in prompt

    def test_prompt_generation_restaurant_intermediate(self):
        """Test prompt generation for restaurant scenario."""
        request = StoryGenerationRequest(
            topic="restaurant",
            level="intermediate",
            seed=123
        )

        prompt = self.ai_controller._create_story_prompt(request)

        # Validate level-specific constraints
        assert "restaurant" in prompt
        assert "intermediate" in prompt
        assert "moderate vocabulary" in prompt.lower()
        assert "10-15 words" in prompt
        assert "123" in prompt

    def test_prompt_generation_shopping_advanced(self):
        """Test prompt generation for shopping scenario."""
        request = StoryGenerationRequest(
            topic="shopping",
            level="advanced",
            seed=None
        )

        prompt = self.ai_controller._create_story_prompt(request)

        # Validate advanced constraints
        assert "shopping" in prompt
        assert "advanced" in prompt
        assert "rich vocabulary" in prompt.lower()
        assert "varied sentence" in prompt.lower()

    def test_system_prompt_consistency(self):
        """Test system prompt contains all required elements."""
        system_prompt = self.ai_controller._get_system_prompt()

        # Validate core requirements
        assert "Lebanese Arabic" in system_prompt
        assert "transliteration" in system_prompt
        assert "NEVER use Arabic script" in system_prompt
        assert "Latin alphabet" in system_prompt

        # Validate number mappings
        assert "7 for ح" in system_prompt
        assert "3 for ع" in system_prompt
        assert "2 for ء" in system_prompt
        assert "5 for خ" in system_prompt
        assert "8 for غ" in system_prompt
        assert "9 for ق" in system_prompt

        # Validate cultural context
        assert "Lebanese" in system_prompt
        assert "dialect" in system_prompt

    @patch('app.ai_controller.Anthropic')
    def test_llm_output_parsing_valid_json(self, mock_anthropic_class):
        """Test parsing valid LLM JSON output."""
        # Mock response
        mock_response = Mock()
        mock_response.content = [Mock()]
        mock_response.content[0].text = '''
        Here's the story:
        {
            "en_text": "Hey, want to grab coffee?",
            "la_text": "ahlan, baddak nrou7 neeshrab ahwe?"
        }
        '''

        mock_client = Mock()
        mock_client.messages.create.return_value = mock_response
        mock_anthropic_class.return_value = mock_client

        ai_controller = AIController()
        parsed = ai_controller._parse_story_response(mock_response.content[0].text)

        assert parsed["en_text"] == "Hey, want to grab coffee?"
        assert parsed["la_text"] == "ahlan, baddak nrou7 neeshrab ahwe?"

    def test_llm_output_parsing_invalid_json(self):
        """Test parsing invalid LLM output."""
        invalid_responses = [
            "This is not JSON",
            "{ invalid json }",
            '{"en_text": "missing la_text"}',
            '{"la_text": "missing en_text"}',
            "",
            "Some text without JSON at all"
        ]

        for invalid_response in invalid_responses:
            with pytest.raises(ValueError):
                self.ai_controller._parse_story_response(invalid_response)

    def test_prompt_constraints_length_validation(self):
        """Test prompt specifies correct length constraints."""
        test_cases = [
            ("beginner", "5-10 words"),
            ("intermediate", "10-15 words"),
            ("advanced", "varied sentence")
        ]

        for level, expected_constraint in test_cases:
            request = StoryGenerationRequest(
                topic="test",
                level=level,
                seed=42
            )
            prompt = self.ai_controller._create_story_prompt(request)
            assert expected_constraint in prompt

    def test_prompt_register_specification(self):
        """Test prompt specifies informal/casual register."""
        request = StoryGenerationRequest(
            topic="greeting",
            level="beginner"
        )

        prompt = self.ai_controller._create_story_prompt(request)
        assert "informal" in prompt.lower() or "casual" in prompt.lower()

    def test_prompt_cultural_relevance(self):
        """Test prompt includes cultural relevance requirements."""
        request = StoryGenerationRequest(
            topic="family",
            level="beginner"
        )

        prompt = self.ai_controller._create_story_prompt(request)
        assert "culturally relevant" in prompt
        assert "appropriate" in prompt

    def test_prompt_golden_file_consistency(self):
        """Test prompt generation matches golden file examples."""
        # Golden examples for consistent prompt testing
        golden_examples = [
            {
                "topic": "coffee_chat",
                "level": "beginner",
                "seed": 42,
                "expected_elements": [
                    "coffee_chat",
                    "beginner",
                    "simple vocabulary",
                    "5-10 words",
                    "JSON format",
                    "transliteration"
                ]
            },
            {
                "topic": "restaurant",
                "level": "intermediate",
                "seed": 123,
                "expected_elements": [
                    "restaurant",
                    "intermediate",
                    "moderate vocabulary",
                    "10-15 words",
                    "JSON format"
                ]
            }
        ]

        for example in golden_examples:
            request = StoryGenerationRequest(
                topic=example["topic"],
                level=example["level"],
                seed=example["seed"]
            )

            prompt = self.ai_controller._create_story_prompt(request)

            for element in example["expected_elements"]:
                assert element in prompt, f"Missing element '{element}' in prompt for {example['topic']}/{example['level']}"

    def test_prompt_transliteration_rules_complete(self):
        """Test prompt includes complete transliteration rules."""
        request = StoryGenerationRequest(topic="test", level="beginner")
        prompt = self.ai_controller._create_story_prompt(request)

        # Check all required transliteration mappings
        required_mappings = ["7=ح", "3=ع", "2=ء", "5=خ", "8=غ", "9=ق"]

        for mapping in required_mappings:
            assert mapping in prompt, f"Missing transliteration mapping: {mapping}"

    def test_prompt_output_format_specification(self):
        """Test prompt specifies exact output format."""
        request = StoryGenerationRequest(topic="test", level="beginner")
        prompt = self.ai_controller._create_story_prompt(request)

        # Should specify exact JSON format
        assert '"en_text":' in prompt
        assert '"la_text":' in prompt
        assert "exact JSON format" in prompt or "this exact JSON format" in prompt

    @pytest.mark.parametrize("topic,level", [
        ("coffee_chat", "beginner"),
        ("restaurant", "intermediate"),
        ("shopping", "advanced"),
        ("greeting", "beginner"),
        ("family", "intermediate")
    ])
    def test_prompt_generation_consistency(self, topic, level):
        """Test prompt generation is consistent across different inputs."""
        request = StoryGenerationRequest(topic=topic, level=level, seed=42)

        # Generate prompt multiple times
        prompt1 = self.ai_controller._create_story_prompt(request)
        prompt2 = self.ai_controller._create_story_prompt(request)

        # Should be identical for same inputs
        assert prompt1 == prompt2, "Prompts should be consistent for same inputs"

        # Should contain core elements
        assert topic in prompt1
        assert level in prompt1
        assert "JSON" in prompt1
        assert "transliteration" in prompt1.lower()