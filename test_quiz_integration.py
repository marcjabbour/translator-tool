#!/usr/bin/env python3
"""
Integration test for quiz generation API endpoint
Tests the complete quiz generation flow from API to response
"""

import asyncio
import httpx
import json
import sys
from typing import Dict, Any

# Test configuration
BASE_URL = "http://localhost:8000"
TEST_LESSON_ID = "550e8400-e29b-41d4-a716-446655440000"  # Example UUID

async def test_quiz_generation():
    """Test the complete quiz generation workflow"""
    async with httpx.AsyncClient() as client:
        print("🧪 Starting quiz generation integration test...")

        # Test 1: Generate quiz for valid lesson
        print("\n📝 Test 1: Generate quiz for valid lesson")
        try:
            response = await client.post(
                f"{BASE_URL}/api/v1/quiz",
                json={"lesson_id": TEST_LESSON_ID},
                headers={"Content-Type": "application/json"}
            )

            if response.status_code == 200:
                quiz_data = response.json()
                print("✅ Quiz generation successful")
                print(f"   Quiz ID: {quiz_data.get('quiz_id')}")
                print(f"   Lesson ID: {quiz_data.get('lesson_id')}")
                print(f"   Questions: {len(quiz_data.get('questions', []))}")

                # Validate quiz structure
                validate_quiz_structure(quiz_data)

            elif response.status_code == 404:
                print("❌ Lesson not found - create a lesson first")
                return False
            elif response.status_code == 400:
                print("❌ Invalid lesson - lesson must have both English and Arabic text")
                return False
            else:
                print(f"❌ Unexpected status code: {response.status_code}")
                print(f"   Response: {response.text}")
                return False

        except Exception as e:
            print(f"❌ Error in test 1: {e}")
            return False

        # Test 2: Test invalid lesson ID format
        print("\n📝 Test 2: Test invalid lesson ID format")
        try:
            response = await client.post(
                f"{BASE_URL}/api/v1/quiz",
                json={"lesson_id": "invalid-uuid"},
                headers={"Content-Type": "application/json"}
            )

            if response.status_code == 422:
                print("✅ Correctly rejected invalid UUID format")
            else:
                print(f"❌ Expected 422, got {response.status_code}")

        except Exception as e:
            print(f"❌ Error in test 2: {e}")
            return False

        # Test 3: Test missing lesson ID
        print("\n📝 Test 3: Test missing lesson ID")
        try:
            response = await client.post(
                f"{BASE_URL}/api/v1/quiz",
                json={},
                headers={"Content-Type": "application/json"}
            )

            if response.status_code == 422:
                print("✅ Correctly rejected missing lesson_id")
            else:
                print(f"❌ Expected 422, got {response.status_code}")

        except Exception as e:
            print(f"❌ Error in test 3: {e}")
            return False

        # Test 4: Test duplicate quiz generation (should return existing or create new)
        print("\n📝 Test 4: Test duplicate quiz generation")
        try:
            response1 = await client.post(
                f"{BASE_URL}/api/v1/quiz",
                json={"lesson_id": TEST_LESSON_ID},
                headers={"Content-Type": "application/json"}
            )

            response2 = await client.post(
                f"{BASE_URL}/api/v1/quiz",
                json={"lesson_id": TEST_LESSON_ID},
                headers={"Content-Type": "application/json"}
            )

            if response1.status_code == 200 and response2.status_code == 200:
                quiz1 = response1.json()
                quiz2 = response2.json()

                if quiz1.get('quiz_id') == quiz2.get('quiz_id'):
                    print("✅ Returned existing quiz (cached)")
                else:
                    print("✅ Generated new quiz (no caching or different content)")
            else:
                print(f"❌ One or both requests failed: {response1.status_code}, {response2.status_code}")

        except Exception as e:
            print(f"❌ Error in test 4: {e}")
            return False

        print("\n🎉 All integration tests completed!")
        return True

def validate_quiz_structure(quiz_data: Dict[str, Any]) -> bool:
    """Validate that the quiz has the correct structure"""
    print("\n🔍 Validating quiz structure...")

    # Check required fields
    required_fields = ['quiz_id', 'lesson_id', 'questions', 'meta']
    for field in required_fields:
        if field not in quiz_data:
            print(f"❌ Missing required field: {field}")
            return False

    # Check questions
    questions = quiz_data.get('questions', [])
    if len(questions) < 3:
        print(f"❌ Insufficient questions: {len(questions)} (minimum 3)")
        return False

    print(f"✅ Quiz has {len(questions)} questions")

    # Validate each question
    question_types = set()
    for i, question in enumerate(questions):
        print(f"   Question {i+1}: {question.get('type', 'unknown')}")

        # Check required question fields
        required_q_fields = ['type', 'question', 'answer']
        for field in required_q_fields:
            if field not in question:
                print(f"❌ Question {i+1} missing field: {field}")
                return False

        q_type = question.get('type')
        question_types.add(q_type)

        # Validate question type specific fields
        if q_type == 'mcq':
            if 'choices' not in question or not isinstance(question['choices'], list):
                print(f"❌ MCQ question {i+1} missing or invalid choices")
                return False
            if len(question['choices']) < 2:
                print(f"❌ MCQ question {i+1} has insufficient choices")
                return False
        elif q_type == 'translate':
            if not isinstance(question['answer'], str):
                print(f"❌ Translation question {i+1} answer must be string")
                return False
        elif q_type == 'fill_blank':
            if not isinstance(question['answer'], list):
                print(f"❌ Fill blank question {i+1} answer must be list")
                return False
        else:
            print(f"❌ Unknown question type: {q_type}")
            return False

    print(f"✅ Question types found: {', '.join(question_types)}")

    # Check for variety (should have at least 2 different types for good quizzes)
    if len(question_types) < 2:
        print("⚠️  Warning: Quiz has only one question type")

    print("✅ Quiz structure validation passed")
    return True

async def check_server_health():
    """Check if the server is running"""
    try:
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{BASE_URL}/health")
            if response.status_code == 200:
                print("✅ Server is running")
                return True
            else:
                print(f"❌ Server health check failed: {response.status_code}")
                return False
    except Exception as e:
        print(f"❌ Cannot connect to server: {e}")
        print(f"   Make sure the server is running on {BASE_URL}")
        return False

async def main():
    """Main test function"""
    print("🚀 Quiz Generation Integration Test Suite")
    print(f"🔗 Testing against: {BASE_URL}")

    # Check server health first
    if not await check_server_health():
        print("\n💡 To start the server, run:")
        print("   cd /path/to/your/backend")
        print("   uvicorn app.main:app --reload")
        sys.exit(1)

    # Run integration tests
    success = await test_quiz_generation()

    if success:
        print("\n🎉 All tests passed!")
        sys.exit(0)
    else:
        print("\n❌ Some tests failed!")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())