#!/usr/bin/env python3
"""
Integration test for user progress tracking API endpoints
Tests the complete progress tracking workflow from lesson views to dashboard stats
"""

import asyncio
import httpx
import json
import sys
from datetime import datetime
from typing import Dict, Any

# Test configuration
BASE_URL = "http://localhost:8000"
TEST_USER_TOKEN = None  # Will be created during test
TEST_LESSON_ID = "550e8400-e29b-41d4-a716-446655440000"  # Example UUID
TEST_QUIZ_ID = "550e8400-e29b-41d4-a716-446655440001"  # Example UUID

async def test_progress_tracking():
    """Test the complete progress tracking workflow"""
    async with httpx.AsyncClient() as client:
        print("🧪 Starting progress tracking integration test...")

        # Create test token
        global TEST_USER_TOKEN
        TEST_USER_TOKEN = await create_test_token(client)

        headers = {
            "Authorization": f"Bearer {TEST_USER_TOKEN}",
            "Content-Type": "application/json"
        }

        # Test 1: Track lesson view
        print("\n📖 Test 1: Track lesson view")
        try:
            response = await client.post(
                f"{BASE_URL}/api/v1/progress/lesson/{TEST_LESSON_ID}/view",
                headers=headers
            )

            if response.status_code == 200:
                progress_data = response.json()
                print("✅ Lesson view tracked successfully")
                print(f"   Progress ID: {progress_data.get('progress_id')}")
                print(f"   Status: {progress_data.get('status')}")
                print(f"   Lesson views: {progress_data.get('lesson_views')}")

                # Validate progress structure
                validate_progress_structure(progress_data)

            else:
                print(f"❌ Failed to track lesson view: {response.status_code}")
                print(f"   Response: {response.text}")
                return False

        except Exception as e:
            print(f"❌ Error in test 1: {e}")
            return False

        # Test 2: Track translation toggle
        print("\n🔄 Test 2: Track translation toggle")
        try:
            response = await client.post(
                f"{BASE_URL}/api/v1/progress/lesson/{TEST_LESSON_ID}/toggle",
                headers=headers
            )

            if response.status_code == 200:
                progress_data = response.json()
                print("✅ Translation toggle tracked successfully")
                print(f"   Translation toggles: {progress_data.get('translation_toggles')}")

            else:
                print(f"❌ Failed to track translation toggle: {response.status_code}")

        except Exception as e:
            print(f"❌ Error in test 2: {e}")
            return False

        # Test 3: Update lesson progress
        print("\n📝 Test 3: Update lesson progress")
        try:
            update_data = {
                "status": "completed",
                "time_spent_minutes": 25
            }

            response = await client.put(
                f"{BASE_URL}/api/v1/progress/lesson/{TEST_LESSON_ID}",
                headers=headers,
                json=update_data
            )

            if response.status_code == 200:
                progress_data = response.json()
                print("✅ Lesson progress updated successfully")
                print(f"   Status: {progress_data.get('status')}")
                print(f"   Time spent: {progress_data.get('time_spent_minutes')} minutes")

            else:
                print(f"❌ Failed to update lesson progress: {response.status_code}")

        except Exception as e:
            print(f"❌ Error in test 3: {e}")
            return False

        # Test 4: Record quiz attempt
        print("\n🧠 Test 4: Record quiz attempt")
        try:
            quiz_attempt_data = {
                "quiz_id": TEST_QUIZ_ID,
                "responses": [
                    {"type": "mcq", "user_answer": 0, "is_correct": True},
                    {"type": "translate", "user_answer": "marhaba", "is_correct": True},
                    {"type": "fill_blank", "user_answer": ["jaye"], "is_correct": False}
                ],
                "score": 0.67,  # 2/3 correct
                "time_taken_seconds": 120,
                "started_at": "2024-01-01T10:00:00Z",
                "completed_at": "2024-01-01T10:02:00Z"
            }

            response = await client.post(
                f"{BASE_URL}/api/v1/progress/quiz-attempt",
                headers=headers,
                json=quiz_attempt_data
            )

            if response.status_code == 200:
                attempt_data = response.json()
                print("✅ Quiz attempt recorded successfully")
                print(f"   Attempt ID: {attempt_data.get('attempt_id')}")
                print(f"   Score: {attempt_data.get('score')*100:.0f}%")
                print(f"   Correct answers: {attempt_data.get('correct_answers')}/{attempt_data.get('total_questions')}")

                # Validate attempt structure
                validate_quiz_attempt_structure(attempt_data)

            else:
                print(f"❌ Failed to record quiz attempt: {response.status_code}")
                print(f"   Response: {response.text}")

        except Exception as e:
            print(f"❌ Error in test 4: {e}")
            return False

        # Test 5: Get user progress
        print("\n📊 Test 5: Get user progress")
        try:
            response = await client.get(
                f"{BASE_URL}/api/v1/progress/lessons",
                headers=headers
            )

            if response.status_code == 200:
                progress_list = response.json()
                print("✅ User progress retrieved successfully")
                print(f"   Total progress records: {len(progress_list)}")

                if progress_list:
                    first_progress = progress_list[0]
                    print(f"   First record status: {first_progress.get('status')}")

            else:
                print(f"❌ Failed to get user progress: {response.status_code}")

        except Exception as e:
            print(f"❌ Error in test 5: {e}")
            return False

        # Test 6: Get quiz attempts
        print("\n🎯 Test 6: Get quiz attempts")
        try:
            response = await client.get(
                f"{BASE_URL}/api/v1/progress/quiz-attempts",
                headers=headers
            )

            if response.status_code == 200:
                attempts_list = response.json()
                print("✅ Quiz attempts retrieved successfully")
                print(f"   Total attempts: {len(attempts_list)}")

                if attempts_list:
                    first_attempt = attempts_list[0]
                    print(f"   First attempt score: {first_attempt.get('score')*100:.0f}%")

            else:
                print(f"❌ Failed to get quiz attempts: {response.status_code}")

        except Exception as e:
            print(f"❌ Error in test 6: {e}")
            return False

        # Test 7: Get user profile
        print("\n👤 Test 7: Get user profile")
        try:
            response = await client.get(
                f"{BASE_URL}/api/v1/profile",
                headers=headers
            )

            if response.status_code == 200:
                profile_data = response.json()
                print("✅ User profile retrieved successfully")
                print(f"   User ID: {profile_data.get('user_id')}")
                print(f"   Lessons completed: {profile_data.get('total_lessons_completed')}")
                print(f"   Quizzes completed: {profile_data.get('total_quizzes_completed')}")
                print(f"   Current streak: {profile_data.get('current_streak_days')} days")

                # Validate profile structure
                validate_profile_structure(profile_data)

            else:
                print(f"❌ Failed to get user profile: {response.status_code}")

        except Exception as e:
            print(f"❌ Error in test 7: {e}")
            return False

        # Test 8: Get dashboard stats
        print("\n📈 Test 8: Get dashboard stats")
        try:
            response = await client.get(
                f"{BASE_URL}/api/v1/dashboard",
                headers=headers
            )

            if response.status_code == 200:
                dashboard_data = response.json()
                print("✅ Dashboard stats retrieved successfully")
                print(f"   Lessons completed: {dashboard_data.get('total_lessons_completed')}")
                print(f"   Lessons this week: {dashboard_data.get('lessons_this_week')}")
                print(f"   Recent activity items: {len(dashboard_data.get('recent_activity', []))}")

                # Validate dashboard structure
                validate_dashboard_structure(dashboard_data)

            else:
                print(f"❌ Failed to get dashboard stats: {response.status_code}")

        except Exception as e:
            print(f"❌ Error in test 8: {e}")
            return False

        # Test 9: Get learning analytics
        print("\n🔍 Test 9: Get learning analytics")
        try:
            response = await client.get(
                f"{BASE_URL}/api/v1/analytics?days=30",
                headers=headers
            )

            if response.status_code == 200:
                analytics_data = response.json()
                print("✅ Learning analytics retrieved successfully")
                print(f"   Period: {analytics_data.get('period_days')} days")
                print(f"   Lessons accessed: {analytics_data.get('lessons_accessed')}")
                print(f"   Learning velocity: {analytics_data.get('learning_velocity'):.2f} lessons/day")

                # Validate analytics structure
                validate_analytics_structure(analytics_data)

            else:
                print(f"❌ Failed to get learning analytics: {response.status_code}")

        except Exception as e:
            print(f"❌ Error in test 9: {e}")
            return False

        print("\n🎉 All progress tracking tests passed!")
        return True

async def create_test_token(client: httpx.AsyncClient) -> str:
    """Create a test JWT token for authentication"""
    try:
        # Assuming the auth controller has a test token creation endpoint
        # In a real scenario, this would use proper authentication
        test_user_id = "test-user-123"

        # For testing, we'll create a simple token
        # In production, this should use proper JWT creation with the auth service
        import jwt
        import time

        payload = {
            "sub": test_user_id,
            "user_id": test_user_id,
            "exp": int(time.time()) + 3600,  # 1 hour
            "iat": int(time.time()),
            "iss": "translator-tool-test"
        }

        # Use the same secret as the server (for testing only)
        token = jwt.encode(payload, "your-jwt-secret-key", algorithm="HS256")
        print(f"✅ Created test token for user: {test_user_id}")
        return token

    except Exception as e:
        print(f"❌ Failed to create test token: {e}")
        sys.exit(1)

def validate_progress_structure(progress_data: Dict[str, Any]) -> bool:
    """Validate that the progress record has the correct structure"""
    required_fields = [
        'progress_id', 'user_id', 'lesson_id', 'status',
        'time_spent_minutes', 'lesson_views', 'translation_toggles',
        'quiz_taken', 'quiz_attempts', 'last_accessed'
    ]

    for field in required_fields:
        if field not in progress_data:
            print(f"❌ Missing required field in progress: {field}")
            return False

    # Validate status values
    valid_statuses = ['not_started', 'in_progress', 'completed']
    if progress_data['status'] not in valid_statuses:
        print(f"❌ Invalid status: {progress_data['status']}")
        return False

    print("✅ Progress structure validation passed")
    return True

def validate_quiz_attempt_structure(attempt_data: Dict[str, Any]) -> bool:
    """Validate that the quiz attempt has the correct structure"""
    required_fields = [
        'attempt_id', 'user_id', 'quiz_id', 'score',
        'total_questions', 'correct_answers', 'time_taken_seconds',
        'started_at', 'completed_at'
    ]

    for field in required_fields:
        if field not in attempt_data:
            print(f"❌ Missing required field in quiz attempt: {field}")
            return False

    # Validate score range
    score = attempt_data['score']
    if not (0.0 <= score <= 1.0):
        print(f"❌ Invalid score range: {score}")
        return False

    print("✅ Quiz attempt structure validation passed")
    return True

def validate_profile_structure(profile_data: Dict[str, Any]) -> bool:
    """Validate that the user profile has the correct structure"""
    required_fields = [
        'user_id', 'total_lessons_completed', 'total_quizzes_completed',
        'total_time_spent_minutes', 'current_streak_days',
        'longest_streak_days'
    ]

    for field in required_fields:
        if field not in profile_data:
            print(f"❌ Missing required field in profile: {field}")
            return False

    print("✅ Profile structure validation passed")
    return True

def validate_dashboard_structure(dashboard_data: Dict[str, Any]) -> bool:
    """Validate that the dashboard stats have the correct structure"""
    required_fields = [
        'total_lessons_completed', 'total_quizzes_completed',
        'total_time_spent_minutes', 'current_streak_days',
        'lessons_this_week', 'recent_activity', 'topic_progress'
    ]

    for field in required_fields:
        if field not in dashboard_data:
            print(f"❌ Missing required field in dashboard: {field}")
            return False

    # Validate that arrays are actually arrays
    if not isinstance(dashboard_data['recent_activity'], list):
        print("❌ recent_activity should be a list")
        return False

    if not isinstance(dashboard_data['topic_progress'], dict):
        print("❌ topic_progress should be a dict")
        return False

    print("✅ Dashboard structure validation passed")
    return True

def validate_analytics_structure(analytics_data: Dict[str, Any]) -> bool:
    """Validate that the analytics data has the correct structure"""
    required_fields = [
        'period_days', 'lessons_accessed', 'lessons_completed',
        'total_study_time', 'quiz_attempts', 'learning_velocity',
        'engagement_metrics', 'daily_activity'
    ]

    for field in required_fields:
        if field not in analytics_data:
            print(f"❌ Missing required field in analytics: {field}")
            return False

    # Validate nested structures
    if not isinstance(analytics_data['engagement_metrics'], dict):
        print("❌ engagement_metrics should be a dict")
        return False

    if not isinstance(analytics_data['daily_activity'], list):
        print("❌ daily_activity should be a list")
        return False

    print("✅ Analytics structure validation passed")
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
    print("🚀 Progress Tracking Integration Test Suite")
    print(f"🔗 Testing against: {BASE_URL}")

    # Check server health first
    if not await check_server_health():
        print("\n💡 To start the server, run:")
        print("   cd /path/to/your/backend")
        print("   uvicorn app.main:app --reload")
        sys.exit(1)

    # Run integration tests
    success = await test_progress_tracking()

    if success:
        print("\n🎉 All tests passed!")
        sys.exit(0)
    else:
        print("\n❌ Some tests failed!")
        sys.exit(1)

if __name__ == "__main__":
    asyncio.run(main())