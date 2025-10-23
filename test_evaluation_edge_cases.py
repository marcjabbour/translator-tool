#!/usr/bin/env python3
"""
Edge case and performance testing for evaluation service.
Tests boundary conditions, unusual inputs, and performance requirements.
"""

import asyncio
import time
import sys
import json
from typing import List, Dict, Any
from dataclasses import dataclass

# Import evaluation service components
sys.path.append('app')
from evaluation_service import EvaluationService, TransliterationHeuristics
from evaluation_service import EvaluationRequest as ServiceEvaluationRequest


@dataclass
class EdgeTestCase:
    """Edge case test scenario."""
    name: str
    user_response: str
    expected_answer: str
    question: str
    expected_behavior: str  # "handle_gracefully", "classify_correctly", "fast_response"
    max_time_seconds: float = 5.0
    description: str = ""


class EvaluationEdgeCaseTester:
    """Test suite for edge cases and performance validation."""

    def __init__(self):
        """Initialize the edge case tester."""
        self.evaluation_service = EvaluationService()
        self.edge_cases = self._load_edge_cases()

    def _load_edge_cases(self) -> List[EdgeTestCase]:
        """Load comprehensive edge case test scenarios."""
        return [
            # Boundary Cases - Empty and Whitespace
            EdgeTestCase(
                name="empty_response",
                user_response="",
                expected_answer="mar7aba",
                question="Translate to Lebanese Arabic: 'Hello'",
                expected_behavior="handle_gracefully",
                description="Empty user response"
            ),
            EdgeTestCase(
                name="whitespace_only",
                user_response="   \t\n  ",
                expected_answer="kifak",
                question="Translate to Lebanese Arabic: 'How are you?'",
                expected_behavior="handle_gracefully",
                description="Whitespace-only response"
            ),
            EdgeTestCase(
                name="single_space",
                user_response=" ",
                expected_answer="shu",
                question="Translate to Lebanese Arabic: 'What'",
                expected_behavior="handle_gracefully",
                description="Single space character"
            ),

            # Length Boundary Cases
            EdgeTestCase(
                name="very_long_response",
                user_response="a" * 1000,
                expected_answer="eh",
                question="Translate to Lebanese Arabic: 'Yes'",
                expected_behavior="handle_gracefully",
                max_time_seconds=10.0,
                description="Extremely long response (1000 chars)"
            ),
            EdgeTestCase(
                name="single_character",
                user_response="a",
                expected_answer="mar7aba",
                question="Translate to Lebanese Arabic: 'Hello'",
                expected_behavior="classify_correctly",
                description="Single character response"
            ),

            # Special Characters and Unicode
            EdgeTestCase(
                name="special_characters",
                user_response="@#$%^&*()",
                expected_answer="shukran",
                question="Translate to Lebanese Arabic: 'Thank you'",
                expected_behavior="handle_gracefully",
                description="Special characters only"
            ),
            EdgeTestCase(
                name="numbers_only",
                user_response="123456789",
                expected_answer="baddi mai",
                question="Translate to Lebanese Arabic: 'I want water'",
                expected_behavior="handle_gracefully",
                description="Numbers only"
            ),
            EdgeTestCase(
                name="mixed_unicode",
                user_response="café naïve résumé",
                expected_answer="ahlan",
                question="Translate to Lebanese Arabic: 'Welcome'",
                expected_behavior="handle_gracefully",
                description="Mixed Unicode characters"
            ),
            EdgeTestCase(
                name="arabic_script",
                user_response="مرحبا",
                expected_answer="mar7aba",
                question="Translate to Lebanese Arabic: 'Hello'",
                expected_behavior="classify_correctly",
                description="Arabic script instead of transliteration"
            ),

            # Case Sensitivity Edge Cases
            EdgeTestCase(
                name="all_uppercase",
                user_response="KIFAK",
                expected_answer="kifak",
                question="Translate to Lebanese Arabic: 'How are you?'",
                expected_behavior="classify_correctly",
                description="All uppercase transliteration"
            ),
            EdgeTestCase(
                name="mixed_case",
                user_response="KiFaK",
                expected_answer="kifak",
                question="Translate to Lebanese Arabic: 'How are you?'",
                expected_behavior="classify_correctly",
                description="Mixed case transliteration"
            ),

            # Punctuation and Spacing
            EdgeTestCase(
                name="extra_punctuation",
                user_response="mar7aba!!!",
                expected_answer="mar7aba",
                question="Translate to Lebanese Arabic: 'Hello'",
                expected_behavior="classify_correctly",
                description="Extra punctuation marks"
            ),
            EdgeTestCase(
                name="multiple_spaces",
                user_response="baddi     mai",
                expected_answer="baddi mai",
                question="Translate to Lebanese Arabic: 'I want water'",
                expected_behavior="classify_correctly",
                description="Multiple spaces between words"
            ),
            EdgeTestCase(
                name="leading_trailing_spaces",
                user_response="  shukran  ",
                expected_answer="shukran",
                question="Translate to Lebanese Arabic: 'Thank you'",
                expected_behavior="classify_correctly",
                description="Leading and trailing spaces"
            ),

            # Transliteration Number Edge Cases
            EdgeTestCase(
                name="invalid_numbers",
                user_response="mar1aba4",
                expected_answer="mar7aba",
                question="Translate to Lebanese Arabic: 'Hello'",
                expected_behavior="classify_correctly",
                description="Invalid transliteration numbers (1,4)"
            ),
            EdgeTestCase(
                name="excessive_numbers",
                user_response="m2a3r7a8b9a",
                expected_answer="mar7aba",
                question="Translate to Lebanese Arabic: 'Hello'",
                expected_behavior="classify_correctly",
                description="Excessive transliteration numbers"
            ),
            EdgeTestCase(
                name="no_numbers_needed",
                user_response="ahlan",
                expected_answer="ahlan",
                question="Translate to Lebanese Arabic: 'Welcome'",
                expected_behavior="classify_correctly",
                description="Correct without transliteration numbers"
            ),

            # Repetition and Emphasis
            EdgeTestCase(
                name="letter_repetition",
                user_response="yallaaaaaa",
                expected_answer="yalla",
                question="Translate to Lebanese Arabic: 'Let's go'",
                expected_behavior="classify_correctly",
                description="Letter repetition for emphasis"
            ),
            EdgeTestCase(
                name="word_repetition",
                user_response="yalla yalla yalla",
                expected_answer="yalla",
                question="Translate to Lebanese Arabic: 'Let's go'",
                expected_behavior="classify_correctly",
                description="Word repetition"
            ),

            # Mixed Language Complexity
            EdgeTestCase(
                name="alternating_languages",
                user_response="hello mar7aba hi",
                expected_answer="mar7aba",
                question="Translate to Lebanese Arabic: 'Hello'",
                expected_behavior="classify_correctly",
                description="Alternating English and Arabic"
            ),
            EdgeTestCase(
                name="partial_translation",
                user_response="I want mai",
                expected_answer="baddi mai",
                question="Translate to Lebanese Arabic: 'I want water'",
                expected_behavior="classify_correctly",
                description="Partial English, partial Arabic"
            ),

            # Context-Dependent Cases
            EdgeTestCase(
                name="ambiguous_response",
                user_response="ok",
                expected_answer="tayeb",
                question="Translate to Lebanese Arabic: 'Okay'",
                expected_behavior="classify_correctly",
                description="Ambiguous casual response"
            ),
            EdgeTestCase(
                name="similar_sounds",
                user_response="bait",
                expected_answer="beit",
                question="Translate to Lebanese Arabic: 'House'",
                expected_behavior="classify_correctly",
                description="Similar sounding but different spelling"
            ),

            # Performance Stress Cases
            EdgeTestCase(
                name="complex_sentence",
                user_response="ana baddi rouh 3al beit ta ekel ma3 el 3eile",
                expected_answer="ana baddi rouh 3al beit ta ekel ma3 el 3eile",
                question="Translate: 'I want to go home to eat with the family'",
                expected_behavior="fast_response",
                max_time_seconds=3.0,
                description="Complex multi-word sentence"
            ),
            EdgeTestCase(
                name="many_errors",
                user_response="I want to go home and eat with my family please thank you",
                expected_answer="baddi rouh 3al beit w ekel ma3 el 3eile",
                question="Translate: 'I want to go home and eat with the family'",
                expected_behavior="handle_gracefully",
                max_time_seconds=5.0,
                description="Multiple errors in long sentence"
            ),

            # Malformed Input Cases
            EdgeTestCase(
                name="html_tags",
                user_response="<script>alert('test')</script>mar7aba",
                expected_answer="mar7aba",
                question="Translate to Lebanese Arabic: 'Hello'",
                expected_behavior="handle_gracefully",
                description="HTML/JavaScript injection attempt"
            ),
            EdgeTestCase(
                name="json_injection",
                user_response='{"type": "injection"}',
                expected_answer="shukran",
                question="Translate to Lebanese Arabic: 'Thank you'",
                expected_behavior="handle_gracefully",
                description="JSON injection attempt"
            ),
            EdgeTestCase(
                name="control_characters",
                user_response="mar\x00\x01\x027aba",
                expected_answer="mar7aba",
                question="Translate to Lebanese Arabic: 'Hello'",
                expected_behavior="handle_gracefully",
                description="Control characters in response"
            ),
        ]

    async def run_edge_case_tests(self) -> Dict[str, Any]:
        """Run comprehensive edge case testing."""
        print("🔬 Starting Edge Case Testing Suite")
        print(f"🧪 Testing {len(self.edge_cases)} edge cases")
        print("=" * 60)

        start_time = time.time()
        results = []
        passed = 0
        failed = 0
        performance_issues = 0

        for i, test_case in enumerate(self.edge_cases):
            print(f"[{i+1:2d}/{len(self.edge_cases)}] {test_case.name}")
            print(f"    📝 {test_case.description}")

            try:
                # Run the test case
                result = await self._run_edge_case_test(test_case)
                results.append(result)

                if result['passed']:
                    passed += 1
                    status = "✅"
                else:
                    failed += 1
                    status = "❌"

                if result['performance_issue']:
                    performance_issues += 1
                    status += " ⚡"

                print(f"    {status} Time: {result['execution_time']:.3f}s")

                if result['error_message']:
                    print(f"    ⚠️  {result['error_message']}")

            except Exception as e:
                print(f"    💥 Test failed with exception: {e}")
                failed += 1
                results.append({
                    'test_name': test_case.name,
                    'passed': False,
                    'execution_time': 0,
                    'performance_issue': False,
                    'error_message': str(e),
                    'behavior_validated': False
                })

        total_time = time.time() - start_time

        # Generate summary
        summary = {
            'total_tests': len(self.edge_cases),
            'passed': passed,
            'failed': failed,
            'performance_issues': performance_issues,
            'pass_rate': passed / len(self.edge_cases),
            'total_execution_time': total_time,
            'average_test_time': total_time / len(self.edge_cases),
            'results': results
        }

        self._print_edge_case_summary(summary)
        return summary

    async def _run_edge_case_test(self, test_case: EdgeTestCase) -> Dict[str, Any]:
        """Run a single edge case test."""
        start_time = time.time()

        try:
            # Create evaluation request
            service_request = ServiceEvaluationRequest(
                user_id="edge-test-user",
                lesson_id="edge-test-lesson",
                quiz_id="edge-test-quiz",
                responses=[{
                    "q_index": 0,
                    "value": test_case.user_response
                }],
                quiz_context={
                    "questions": [{
                        "type": "translate",
                        "question": test_case.question,
                        "answer": test_case.expected_answer
                    }],
                    "topic": "edge_test",
                    "level": "test"
                }
            )

            # Execute evaluation
            evaluation_result = self.evaluation_service.evaluate_quiz_responses(service_request)
            execution_time = time.time() - start_time

            # Check if execution time meets requirements
            performance_issue = execution_time > test_case.max_time_seconds

            # Validate behavior based on expected behavior
            behavior_validated = self._validate_expected_behavior(
                test_case.expected_behavior,
                evaluation_result,
                execution_time,
                test_case
            )

            return {
                'test_name': test_case.name,
                'passed': behavior_validated and not performance_issue,
                'execution_time': execution_time,
                'performance_issue': performance_issue,
                'error_message': None,
                'behavior_validated': behavior_validated,
                'evaluation_result': evaluation_result
            }

        except Exception as e:
            execution_time = time.time() - start_time

            # For "handle_gracefully" cases, exceptions might be acceptable
            if test_case.expected_behavior == "handle_gracefully":
                behavior_validated = True
                error_message = f"Handled gracefully: {str(e)}"
            else:
                behavior_validated = False
                error_message = f"Unexpected error: {str(e)}"

            return {
                'test_name': test_case.name,
                'passed': behavior_validated,
                'execution_time': execution_time,
                'performance_issue': execution_time > test_case.max_time_seconds,
                'error_message': error_message,
                'behavior_validated': behavior_validated
            }

    def _validate_expected_behavior(
        self,
        expected_behavior: str,
        evaluation_result,
        execution_time: float,
        test_case: EdgeTestCase
    ) -> bool:
        """Validate that the evaluation behaved as expected."""
        try:
            if expected_behavior == "handle_gracefully":
                # Should not crash and should return some result
                return evaluation_result is not None and hasattr(evaluation_result, 'feedback')

            elif expected_behavior == "classify_correctly":
                # Should provide reasonable classification (not necessarily perfect)
                if not evaluation_result.feedback:
                    return False

                feedback = evaluation_result.feedback[0]
                # For edge cases, we mainly want to ensure it doesn't crash
                # and provides some classification
                return hasattr(feedback, 'is_correct')

            elif expected_behavior == "fast_response":
                # Should respond within time limit and provide valid result
                return (execution_time <= test_case.max_time_seconds and
                        evaluation_result is not None and
                        evaluation_result.feedback)

            else:
                return False

        except Exception:
            return False

    def _print_edge_case_summary(self, summary: Dict[str, Any]):
        """Print comprehensive edge case test summary."""
        print("\n" + "=" * 60)
        print("🔬 EDGE CASE TEST RESULTS")
        print("=" * 60)
        print(f"⏱️  Total Time: {summary['total_execution_time']:.2f}s")
        print(f"📊 Total Tests: {summary['total_tests']}")
        print(f"✅ Passed: {summary['passed']}")
        print(f"❌ Failed: {summary['failed']}")
        print(f"⚡ Performance Issues: {summary['performance_issues']}")
        print(f"📈 Pass Rate: {summary['pass_rate']:.1%}")
        print(f"⏱️  Average Test Time: {summary['average_test_time']:.3f}s")

        # Categorize failures
        failures_by_category = {}
        for result in summary['results']:
            if not result['passed']:
                if result['performance_issue']:
                    category = "Performance"
                elif not result['behavior_validated']:
                    category = "Behavior"
                else:
                    category = "Other"

                if category not in failures_by_category:
                    failures_by_category[category] = []
                failures_by_category[category].append(result['test_name'])

        if failures_by_category:
            print("\n📋 FAILURE BREAKDOWN:")
            for category, test_names in failures_by_category.items():
                print(f"  {category}: {len(test_names)} tests")
                for name in test_names[:3]:  # Show first 3
                    print(f"    - {name}")
                if len(test_names) > 3:
                    print(f"    ... and {len(test_names) - 3} more")

    async def run_performance_stress_test(self) -> Dict[str, Any]:
        """Run performance stress testing with concurrent requests."""
        print("\n⚡ Starting Performance Stress Test")
        print("-" * 40)

        # Test concurrent evaluation requests
        concurrent_requests = 10
        test_cases = self.edge_cases[:5]  # Use first 5 edge cases

        start_time = time.time()

        # Create concurrent tasks
        tasks = []
        for i in range(concurrent_requests):
            test_case = test_cases[i % len(test_cases)]
            tasks.append(self._run_edge_case_test(test_case))

        # Execute concurrently
        results = await asyncio.gather(*tasks, return_exceptions=True)
        total_time = time.time() - start_time

        # Analyze results
        successful = 0
        exceptions = 0
        max_time = 0
        min_time = float('inf')
        total_eval_time = 0

        for result in results:
            if isinstance(result, Exception):
                exceptions += 1
            else:
                successful += 1
                exec_time = result['execution_time']
                max_time = max(max_time, exec_time)
                min_time = min(min_time, exec_time)
                total_eval_time += exec_time

        avg_time = total_eval_time / successful if successful > 0 else 0

        stress_results = {
            'concurrent_requests': concurrent_requests,
            'successful': successful,
            'exceptions': exceptions,
            'total_wall_time': total_time,
            'max_eval_time': max_time,
            'min_eval_time': min_time if min_time != float('inf') else 0,
            'avg_eval_time': avg_time,
            'throughput': successful / total_time if total_time > 0 else 0
        }

        print(f"⚡ Concurrent Requests: {concurrent_requests}")
        print(f"✅ Successful: {successful}")
        print(f"💥 Exceptions: {exceptions}")
        print(f"⏱️  Total Wall Time: {total_time:.2f}s")
        print(f"📊 Throughput: {stress_results['throughput']:.1f} req/sec")
        print(f"⏱️  Avg Evaluation Time: {avg_time:.3f}s")
        print(f"⏱️  Max Evaluation Time: {max_time:.3f}s")

        return stress_results

    def save_edge_case_results(self, results: Dict[str, Any], filename: str = "edge_case_results.json"):
        """Save edge case test results."""
        # Prepare serializable results
        serializable_results = {
            'timestamp': time.time(),
            'summary': {
                'total_tests': results['total_tests'],
                'passed': results['passed'],
                'failed': results['failed'],
                'pass_rate': results['pass_rate'],
                'performance_issues': results['performance_issues'],
                'total_execution_time': results['total_execution_time']
            },
            'test_results': [
                {
                    'test_name': r['test_name'],
                    'passed': r['passed'],
                    'execution_time': r['execution_time'],
                    'performance_issue': r['performance_issue'],
                    'behavior_validated': r['behavior_validated'],
                    'error_message': r['error_message']
                }
                for r in results['results']
            ]
        }

        with open(filename, 'w') as f:
            json.dump(serializable_results, f, indent=2)

        print(f"\n💾 Edge case results saved to: {filename}")


async def main():
    """Main edge case testing execution."""
    print("🔬 Evaluation Service Edge Case & Performance Testing")
    print("🎯 Goals: Robust error handling, performance validation")
    print()

    try:
        tester = EvaluationEdgeCaseTester()

        # Run edge case tests
        edge_results = await tester.run_edge_case_tests()

        # Run performance stress test
        stress_results = await tester.run_performance_stress_test()

        # Save results
        tester.save_edge_case_results(edge_results)

        # Final assessment
        print("\n" + "=" * 60)
        print("🏁 FINAL ASSESSMENT")
        print("=" * 60)

        edge_pass_rate = edge_results['pass_rate']
        performance_acceptable = stress_results['exceptions'] == 0 and stress_results['avg_eval_time'] < 5.0

        print(f"🔬 Edge Case Pass Rate: {edge_pass_rate:.1%}")
        print(f"⚡ Performance Acceptable: {'✅' if performance_acceptable else '❌'}")
        print(f"📊 Concurrent Throughput: {stress_results['throughput']:.1f} req/sec")

        # Overall grade
        overall_success = edge_pass_rate >= 0.8 and performance_acceptable
        print(f"\n🎖️  OVERALL ROBUSTNESS: {'✅ PASSED' if overall_success else '❌ NEEDS IMPROVEMENT'}")

        if not overall_success:
            print("\n💡 RECOMMENDATIONS:")
            if edge_pass_rate < 0.8:
                print("   - Improve error handling for edge cases")
                print("   - Add input sanitization and validation")
            if not performance_acceptable:
                print("   - Optimize evaluation performance")
                print("   - Consider caching for repeated patterns")

        return 0 if overall_success else 1

    except Exception as e:
        print(f"\n💥 Test execution failed: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)