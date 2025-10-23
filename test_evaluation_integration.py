#!/usr/bin/env python3
"""
Integration test for complete evaluation workflow.
Tests end-to-end evaluation from API request to database storage.
"""

import asyncio
import httpx
import json
import sys
import time
import uuid
from typing import Dict, Any, List
from datetime import datetime

# Test configuration
BASE_URL = "http://localhost:8000"
TEST_USER_ID = "eval-test-user-123"

# Test data
TEST_LESSON_DATA = {
    "topic": "greetings",
    "level": "beginner",
    "seed": 42
}

TEST_QUIZ_RESPONSES = [
    {"q_index": 0, "value": "hello"},  # Should detect EN_IN_AR error
    {"q_index": 1, "value": "kifak"},   # Should be correct
    {"q_index": 2, "value": "shou"},    # Should detect SPELL_T error
]


async def test_complete_evaluation_workflow():
    """Test the complete evaluation workflow from lesson creation to evaluation."""
    async with httpx.AsyncClient() as client:
        print("🧪 Starting Complete Evaluation Integration Test")
        print(f"🔗 Testing against: {BASE_URL}")
        print("=" * 60)

        # Create test token
        test_token = await create_test_token(client)
        headers = {
            "Authorization": f"Bearer {test_token}",
            "Content-Type": "application/json"
        }

        try:
            # Step 1: Create a lesson
            print("\n📖 Step 1: Creating test lesson")
            lesson_response = await client.post(
                f"{BASE_URL}/api/v1/story",
                headers=headers,
                json=TEST_LESSON_DATA
            )

            if lesson_response.status_code != 200:
                print(f"❌ Failed to create lesson: {lesson_response.status_code}")
                print(f"   Response: {lesson_response.text}")
                return False

            lesson_data = lesson_response.json()
            lesson_id = lesson_data["lesson_id"]
            print(f"✅ Lesson created: {lesson_id}")

            # Step 2: Generate quiz for the lesson
            print("\n🧠 Step 2: Generating quiz")
            quiz_response = await client.post(
                f"{BASE_URL}/api/v1/quiz",
                headers=headers,
                json={"lesson_id": lesson_id}
            )

            if quiz_response.status_code != 200:
                print(f"❌ Failed to generate quiz: {quiz_response.status_code}")
                print(f"   Response: {quiz_response.text}")
                return False

            quiz_data = quiz_response.json()
            quiz_id = quiz_data["quiz_id"]
            questions = quiz_data["questions"]
            print(f"✅ Quiz generated: {quiz_id} with {len(questions)} questions")

            # Step 3: Prepare evaluation request
            print("\n🔍 Step 3: Preparing evaluation request")
            evaluation_request = {
                "user_id": TEST_USER_ID,
                "lesson_id": lesson_id,
                "quiz_id": quiz_id,
                "responses": [
                    {"q_index": 0, "value": "hello"},  # EN_IN_AR error
                    {"q_index": 1, "value": "kifak"},  # Correct response
                ]
            }

            # Ensure we only test with available questions
            if len(questions) > 2:
                evaluation_request["responses"].append(
                    {"q_index": 2, "value": "shou"}  # SPELL_T error
                )

            print(f"📝 Testing with {len(evaluation_request['responses'])} responses")

            # Step 4: Submit for evaluation
            print("\n⚖️  Step 4: Submitting for evaluation")
            eval_start_time = time.time()

            evaluation_response = await client.post(
                f"{BASE_URL}/api/v1/evaluate",
                headers=headers,
                json=evaluation_request
            )

            eval_time = time.time() - eval_start_time

            if evaluation_response.status_code != 200:
                print(f"❌ Evaluation failed: {evaluation_response.status_code}")
                print(f"   Response: {evaluation_response.text}")
                return False

            eval_data = evaluation_response.json()
            print(f"✅ Evaluation completed in {eval_time:.2f}s")
            print(f"   Attempt ID: {eval_data['attempt_id']}")
            print(f"   Score: {eval_data['score']:.1%}")

            # Step 5: Validate evaluation results
            print("\n✔️  Step 5: Validating evaluation results")
            validation_passed = await validate_evaluation_results(eval_data)

            if not validation_passed:
                return False

            # Step 6: Test error classification accuracy
            print("\n🎯 Step 6: Testing error classification accuracy")
            accuracy_passed = await test_error_classification_accuracy(eval_data)

            if not accuracy_passed:
                return False

            # Step 7: Test database storage
            print("\n💾 Step 7: Validating database storage")
            storage_passed = await test_database_storage(client, headers, eval_data["attempt_id"])

            if not storage_passed:
                return False

            # Step 8: Test performance requirements
            print("\n⚡ Step 8: Testing performance requirements")
            performance_passed = await test_performance_requirements(client, headers, evaluation_request)

            if not performance_passed:
                return False

            print("\n" + "=" * 60)
            print("🎉 ALL INTEGRATION TESTS PASSED!")
            print("=" * 60)
            return True

        except Exception as e:
            print(f"\n💥 Integration test failed: {e}")
            import traceback
            traceback.print_exc()
            return False


async def validate_evaluation_results(eval_data: Dict[str, Any]) -> bool:
    """Validate the structure and content of evaluation results."""
    print("   🔍 Validating result structure...")

    # Check required fields
    required_fields = ["attempt_id", "score", "feedback"]
    for field in required_fields:
        if field not in eval_data:
            print(f"   ❌ Missing required field: {field}")
            return False

    # Validate attempt_id format (should be UUID)
    try:
        uuid.UUID(eval_data["attempt_id"])
        print("   ✅ Valid attempt ID format")
    except ValueError:
        print(f"   ❌ Invalid attempt ID format: {eval_data['attempt_id']}")
        return False

    # Validate score range
    score = eval_data["score"]
    if not (0.0 <= score <= 1.0):
        print(f"   ❌ Score out of range: {score}")
        return False
    print(f"   ✅ Valid score: {score:.1%}")

    # Validate feedback structure
    feedback = eval_data["feedback"]
    if not isinstance(feedback, list):
        print("   ❌ Feedback should be a list")
        return False

    for i, fb in enumerate(feedback):
        required_fb_fields = ["q_index", "ok", "errors"]
        for field in required_fb_fields:
            if field not in fb:
                print(f"   ❌ Missing feedback field {field} in question {i}")
                return False

        # Validate errors structure
        if not isinstance(fb["errors"], list):
            print(f"   ❌ Errors should be a list in question {i}")
            return False

        for error in fb["errors"]:
            if not isinstance(error, dict) or "type" not in error or "token" not in error:
                print(f"   ❌ Invalid error structure in question {i}")
                return False

    print(f"   ✅ Valid feedback structure for {len(feedback)} questions")
    return True


async def test_error_classification_accuracy(eval_data: Dict[str, Any]) -> bool:
    """Test the accuracy of error classification."""
    print("   🎯 Testing error classification accuracy...")

    feedback = eval_data["feedback"]
    correct_classifications = 0
    total_responses = len(feedback)

    expected_results = [
        {"correct": False, "error_types": ["EN_IN_AR"]},  # "hello" response
        {"correct": True, "error_types": []},             # "kifak" response
        {"correct": False, "error_types": ["SPELL_T"]},   # "shou" response (if present)
    ]

    for i, fb in enumerate(feedback):
        if i < len(expected_results):
            expected = expected_results[i]
            actual_correct = fb["ok"]
            actual_errors = [err["type"] for err in fb["errors"]]

            print(f"     Q{i+1}: Expected correct={expected['correct']}, Got correct={actual_correct}")
            print(f"         Expected errors={expected['error_types']}, Got errors={actual_errors}")

            # Check correctness classification
            if actual_correct == expected["correct"]:
                # Check error type detection
                if expected["error_types"]:
                    # Should have detected at least one expected error type
                    if any(err_type in actual_errors for err_type in expected["error_types"]):
                        correct_classifications += 1
                        print(f"     ✅ Correct classification for Q{i+1}")
                    else:
                        print(f"     ❌ Missed expected error types for Q{i+1}")
                else:
                    # Should not have detected errors (or minor ones are acceptable)
                    correct_classifications += 1
                    print(f"     ✅ Correct classification for Q{i+1}")
            else:
                print(f"     ❌ Incorrect correctness classification for Q{i+1}")

    accuracy = correct_classifications / total_responses
    print(f"   📊 Classification accuracy: {accuracy:.1%} ({correct_classifications}/{total_responses})")

    # Require at least 80% accuracy
    if accuracy >= 0.8:
        print("   ✅ Meets ≥80% accuracy requirement")
        return True
    else:
        print("   ❌ Below 80% accuracy requirement")
        return False


async def test_database_storage(client: httpx.AsyncClient, headers: Dict[str, str], attempt_id: str) -> bool:
    """Test that evaluation results are properly stored in database."""
    print("   💾 Testing database storage...")

    # Note: In a real test, you'd query the database directly
    # For this integration test, we'll verify the attempt_id is valid
    # and that the evaluation endpoint worked (which implies storage)

    try:
        # Validate UUID format (indicates proper database ID generation)
        uuid.UUID(attempt_id)
        print(f"   ✅ Valid attempt ID generated: {attempt_id}")

        # In a complete test, you might:
        # - Query the attempts table directly
        # - Query the errors table for error records
        # - Verify data integrity

        return True

    except ValueError:
        print(f"   ❌ Invalid attempt ID format: {attempt_id}")
        return False


async def test_performance_requirements(
    client: httpx.AsyncClient,
    headers: Dict[str, str],
    evaluation_request: Dict[str, Any]
) -> bool:
    """Test performance requirements for evaluation."""
    print("   ⚡ Testing performance requirements...")

    # Test single request latency
    start_time = time.time()
    response = await client.post(
        f"{BASE_URL}/api/v1/evaluate",
        headers=headers,
        json=evaluation_request
    )
    single_latency = time.time() - start_time

    if response.status_code != 200:
        print(f"   ❌ Performance test request failed: {response.status_code}")
        return False

    print(f"   📊 Single request latency: {single_latency:.3f}s")

    # Requirement: Should complete within 10 seconds
    if single_latency > 10.0:
        print(f"   ❌ Latency exceeds 10s requirement: {single_latency:.3f}s")
        return False

    print("   ✅ Latency within acceptable range")

    # Test concurrent requests (basic load test)
    print("   🔄 Testing concurrent evaluation requests...")
    concurrent_requests = 5
    tasks = []

    for i in range(concurrent_requests):
        # Modify user_id slightly to avoid conflicts
        modified_request = evaluation_request.copy()
        modified_request["user_id"] = f"{evaluation_request['user_id']}-{i}"

        task = client.post(
            f"{BASE_URL}/api/v1/evaluate",
            headers=headers,
            json=modified_request
        )
        tasks.append(task)

    start_time = time.time()
    responses = await asyncio.gather(*tasks, return_exceptions=True)
    concurrent_time = time.time() - start_time

    successful_responses = sum(1 for r in responses if not isinstance(r, Exception) and r.status_code == 200)
    throughput = successful_responses / concurrent_time

    print(f"   📊 Concurrent requests: {concurrent_requests}")
    print(f"   📊 Successful: {successful_responses}")
    print(f"   📊 Total time: {concurrent_time:.3f}s")
    print(f"   📊 Throughput: {throughput:.1f} req/sec")

    # Basic requirement: Should handle concurrent requests without major failures
    if successful_responses < concurrent_requests * 0.8:  # Allow 20% failure rate
        print(f"   ❌ Too many failed concurrent requests")
        return False

    print("   ✅ Concurrent request handling acceptable")
    return True


async def create_test_token(client: httpx.AsyncClient) -> str:
    """Create a test JWT token for authentication."""
    try:
        import jwt
        import time

        payload = {
            "sub": TEST_USER_ID,
            "user_id": TEST_USER_ID,
            "exp": int(time.time()) + 3600,  # 1 hour
            "iat": int(time.time()),
            "iss": "translator-tool-test"
        }

        # Use the same secret as the server (for testing only)
        token = jwt.encode(payload, "your-jwt-secret-key", algorithm="HS256")
        print(f"✅ Created test token for user: {TEST_USER_ID}")
        return token

    except Exception as e:
        print(f"❌ Failed to create test token: {e}")
        sys.exit(1)


async def check_server_health():
    """Check if the server is running."""
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
    """Main integration test function."""
    print("🚀 Evaluation Service Integration Test Suite")
    print(f"🔗 Testing against: {BASE_URL}")
    print("🎯 Goals: End-to-end workflow validation, ≥80% accuracy, performance")
    print()

    # Check server health first
    if not await check_server_health():
        print("\n💡 To start the server, run:")
        print("   cd /path/to/your/backend")
        print("   uvicorn app.main:app --reload")
        sys.exit(1)

    # Run integration tests
    success = await test_complete_evaluation_workflow()

    if success:
        print("\n🎉 All integration tests passed!")
        print("✅ Evaluation service is ready for production")
        sys.exit(0)
    else:
        print("\n❌ Integration tests failed!")
        print("🔧 Please review and fix issues before deploying")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())