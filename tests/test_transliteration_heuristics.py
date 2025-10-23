"""
Heuristic tests for transliteration validation.
Tests validate no Arabic script and allowed alphabet constraints.
"""

import pytest
from app.ai_controller import TransliterationValidator


class TestTransliterationHeuristics:
    """Test transliteration validation heuristics."""

    def setup_method(self):
        """Set up test instance."""
        self.validator = TransliterationValidator()

    def test_valid_transliteration_basic(self):
        """Test basic valid transliteration text."""
        valid_texts = [
            "ahlan wa sahlan",
            "keef 7aalak?",
            "shou akhbaarak",
            "yalla nrou7",
            "3a2bal el jame3a",
            "bteshrab ahwe?",
            "la2, shukran",
            "mni7 kteer"
        ]

        for text in valid_texts:
            assert self.validator.validate(text), f"Should be valid: {text}"

    def test_valid_transliteration_with_numbers(self):
        """Test valid transliteration with transliteration numbers."""
        valid_texts = [
            "7abibi",  # 7 for ح
            "3arabi",  # 3 for ع
            "2alam",   # 2 for ء
            "5alas",   # 5 for خ
            "8ali",    # 8 for غ
            "9ahwe"    # 9 for ق
        ]

        for text in valid_texts:
            assert self.validator.validate(text), f"Should be valid: {text}"

    def test_valid_transliteration_punctuation(self):
        """Test valid transliteration with punctuation."""
        valid_texts = [
            "ahlan, keef 7aalak?",
            "la2! ma baddak?",
            "yalla... nrou7",
            "shou el-akhbaar?",
            "ana mni7, w inta?",
            "'allo, meen?"
        ]

        for text in valid_texts:
            assert self.validator.validate(text), f"Should be valid: {text}"

    def test_invalid_transliteration_arabic_script(self):
        """Test rejection of Arabic script characters."""
        invalid_texts = [
            "أهلا وسهلا",      # Arabic script
            "كيف حالك؟",       # Arabic script
            "شو أخبارك",       # Arabic script
            "يلا نروح",        # Arabic script
            "ahlan أهلا",      # Mixed script
            "7abibi حبيبي",     # Mixed script
        ]

        for text in invalid_texts:
            assert not self.validator.validate(text), f"Should be invalid: {text}"
            assert self.validator.contains_arabic_script(text), f"Should contain Arabic script: {text}"

    def test_invalid_transliteration_forbidden_chars(self):
        """Test rejection of forbidden characters."""
        invalid_texts = [
            "ahlan@wa sahlan",  # @ symbol
            "keef#7aalak",      # # symbol
            "shou$akhbaarak",   # $ symbol
            "yalla%nrou7",      # % symbol
            "7abibi&wallah",    # & symbol
            "ma3*salama",       # * symbol
            "ahlan+wa",         # + symbol
            "keef=7aalak",      # = symbol
        ]

        for text in invalid_texts:
            assert not self.validator.validate(text), f"Should be invalid: {text}"

    def test_contains_arabic_script_detection(self):
        """Test Arabic script detection method."""
        # Should detect Arabic
        arabic_texts = [
            "أهلا",
            "حبيبي",
            "شكرا",
            "mixed ahlan أهلا",
            "7abibi حالك"
        ]

        for text in arabic_texts:
            assert self.validator.contains_arabic_script(text), f"Should detect Arabic in: {text}"

        # Should not detect Arabic
        latin_texts = [
            "ahlan",
            "7abibi",
            "keef 7aalak",
            "shou akhbaarak"
        ]

        for text in latin_texts:
            assert not self.validator.contains_arabic_script(text), f"Should not detect Arabic in: {text}"

    def test_allowed_characters_comprehensive(self):
        """Test comprehensive set of allowed characters."""
        # All allowed characters
        allowed_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,!?'\"-"
        transliteration_chars = "73258"  # Common transliteration numbers

        all_allowed = allowed_chars + transliteration_chars
        assert self.validator.validate(all_allowed), "All allowed characters should be valid"

    def test_edge_cases_empty_and_whitespace(self):
        """Test edge cases with empty strings and whitespace."""
        # Empty string should be valid
        assert self.validator.validate(""), "Empty string should be valid"

        # Whitespace only should be valid
        assert self.validator.validate("   "), "Whitespace should be valid"
        assert self.validator.validate("\t"), "Tab should be valid"

        # Mixed whitespace
        assert self.validator.validate(" \t "), "Mixed whitespace should be valid"

    def test_case_sensitivity(self):
        """Test that validation is case-insensitive for letters."""
        mixed_case_texts = [
            "Ahlan Wa Sahlan",
            "KEEF 7AALAK",
            "sHoU aKhBaArAk",
            "YaLlA nRoU7"
        ]

        for text in mixed_case_texts:
            assert self.validator.validate(text), f"Mixed case should be valid: {text}"

    def test_numbers_in_context(self):
        """Test transliteration numbers in realistic contexts."""
        realistic_examples = [
            "mar7aba",     # مرحبا
            "3a2balik",    # عقبالك
            "ma3 salama",  # مع سلامة
            "2inshallah",  # إنشالله
            "5alas",       # خلاص
            "ma38oul",     # معقول
            "9addeesh"     # قديش
        ]

        for text in realistic_examples:
            assert self.validator.validate(text), f"Realistic example should be valid: {text}"

    @pytest.mark.parametrize("char", "73259068")
    def test_individual_transliteration_numbers(self, char):
        """Test each transliteration number individually."""
        text = f"test{char}text"
        assert self.validator.validate(text), f"Transliteration number {char} should be allowed"

    @pytest.mark.parametrize("forbidden_char", "@#$%&*+=<>[]{}|\\~`^")
    def test_individual_forbidden_characters(self, forbidden_char):
        """Test that each forbidden character is rejected."""
        text = f"test{forbidden_char}text"
        assert not self.validator.validate(text), f"Character {forbidden_char} should be forbidden"

    def test_realistic_conversation_examples(self):
        """Test realistic conversational examples."""
        conversations = [
            "ahlan, keef 7aalak?",
            "mni7, al7amdella. w inta?",
            "kello mni7. shou 3am ta3mol?",
            "3am beshte8el. baddak tiji ma3na?",
            "la2, ana mash88oul. 3a2bal el marra jay.",
            "ma3 salama!"
        ]

        for conv in conversations:
            assert self.validator.validate(conv), f"Conversation should be valid: {conv}"

    def test_boundary_conditions(self):
        """Test boundary conditions and special cases."""
        # Single characters
        assert self.validator.validate("a"), "Single letter should be valid"
        assert self.validator.validate("7"), "Single transliteration number should be valid"
        assert self.validator.validate("."), "Single punctuation should be valid"

        # Very long text
        long_text = "ahlan " * 1000
        assert self.validator.validate(long_text), "Long valid text should be valid"

        # Text with only numbers
        assert self.validator.validate("123456789"), "Regular numbers should be valid"
        assert self.validator.validate("73259"), "Transliteration numbers should be valid"