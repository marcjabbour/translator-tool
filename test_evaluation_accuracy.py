#!/usr/bin/env python3
"""
Comprehensive accuracy testing for error detection evaluation service.
Tests the hybrid approach (heuristics + LLM) to validate ≥80% classification accuracy.
"""

import asyncio
import json
import sys
import time
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass
from pathlib import Path

# Import evaluation service components
sys.path.append('app')
from evaluation_service import EvaluationService, TransliterationHeuristics, LLMEvaluationJudge
from evaluation_service import EvaluationRequest as ServiceEvaluationRequest


@dataclass
class TestCase:
    """Individual test case with expected results."""
    question: str
    expected_answer: str
    user_response: str
    expected_errors: List[Dict[str, str]]  # [{"type": "EN_IN_AR", "token": "hello", "severity": "high"}]
    expected_correct: bool
    category: str  # "basic", "intermediate", "advanced", "edge_case"
    description: str


@dataclass
class AccuracyResult:
    """Results from accuracy testing."""
    total_cases: int
    correct_classifications: int
    false_positives: int  # Predicted error when none expected
    false_negatives: int  # Missed expected error
    precision: float
    recall: float
    f1_score: float
    accuracy: float
    category_results: Dict[str, Dict[str, Any]]


class EvaluationAccuracyTester:
    """Test suite for evaluation service accuracy validation."""

    def __init__(self):
        """Initialize the tester with evaluation service."""
        self.evaluation_service = EvaluationService()
        self.heuristics = TransliterationHeuristics()
        self.test_cases = self._load_test_cases()

    def _load_test_cases(self) -> List[TestCase]:
        """Load comprehensive test cases for accuracy validation."""
        return [
            # Category: Basic Transliteration Errors
            TestCase(
                question="Translate to Lebanese Arabic: 'Hello'",
                expected_answer="mar7aba",
                user_response="hello",
                expected_errors=[{"type": "EN_IN_AR", "token": "hello", "severity": "high"}],
                expected_correct=False,
                category="basic",
                description="English word instead of Arabic transliteration"
            ),
            TestCase(
                question="Translate to Lebanese Arabic: 'How are you?'",
                expected_answer="kifak",
                user_response="kifak",
                expected_errors=[],
                expected_correct=True,
                category="basic",
                description="Correct transliteration"
            ),
            TestCase(
                question="Translate to Lebanese Arabic: 'What'",
                expected_answer="shu",
                user_response="shou",
                expected_errors=[{"type": "SPELL_T", "token": "shou", "severity": "medium"}],
                expected_correct=False,
                category="basic",
                description="Common spelling variation"
            ),

            # Category: Intermediate Mixed Errors
            TestCase(
                question="Translate to Lebanese Arabic: 'Thank you very much'",
                expected_answer="shukran ktir",
                user_response="thank you ktir",
                expected_errors=[
                    {"type": "EN_IN_AR", "token": "thank", "severity": "high"},
                    {"type": "EN_IN_AR", "token": "you", "severity": "high"}
                ],
                expected_correct=False,
                category="intermediate",
                description="Partial English, partial transliteration"
            ),
            TestCase(
                question="Translate to Lebanese Arabic: 'Good morning'",
                expected_answer="sabah el kheir",
                user_response="saba7 el kheir",
                expected_errors=[],
                expected_correct=True,
                category="intermediate",
                description="Correct with transliteration numbers"
            ),
            TestCase(
                question="Translate to Lebanese Arabic: 'I want coffee'",
                expected_answer="baddi ahwe",
                user_response="baddeh ahweh",
                expected_errors=[{"type": "SPELL_T", "token": "baddeh", "severity": "medium"}],
                expected_correct=False,
                category="intermediate",
                description="Minor spelling variation"
            ),

            # Category: Advanced Grammar and Vocabulary
            TestCase(
                question="Translate to Lebanese Arabic: 'Where is the bathroom?'",
                expected_answer="wen el hammam",
                user_response="where hammam",
                expected_errors=[
                    {"type": "EN_IN_AR", "token": "where", "severity": "high"},
                    {"type": "OMISSION", "token": "el", "severity": "medium"}
                ],
                expected_correct=False,
                category="advanced",
                description="Mixed language with missing article"
            ),
            TestCase(
                question="Translate to Lebanese Arabic: 'Let's go'",
                expected_answer="yalla",
                user_response="yalla yalla",
                expected_errors=[{"type": "EXTRA", "token": "yalla", "severity": "low"}],
                expected_correct=False,
                category="advanced",
                description="Extra word repetition"
            ),
            TestCase(
                question="Translate to Lebanese Arabic: 'Beautiful girl'",
                expected_answer="bint 7elwe",
                user_response="bint helwe",
                expected_errors=[{"type": "SPELL_T", "token": "helwe", "severity": "medium"}],
                expected_correct=False,
                category="advanced",
                description="Missing transliteration number"
            ),

            # Category: Edge Cases
            TestCase(
                question="Translate to Lebanese Arabic: 'Yes'",
                expected_answer="eh",
                user_response="",
                expected_errors=[{"type": "OMISSION", "token": "", "severity": "high"}],
                expected_correct=False,
                category="edge_case",
                description="Empty response"
            ),
            TestCase(
                question="Translate to Lebanese Arabic: 'No'",
                expected_answer="la2",
                user_response="la",
                expected_errors=[{"type": "SPELL_T", "token": "la", "severity": "medium"}],
                expected_correct=False,
                category="edge_case",
                description="Missing transliteration number"
            ),
            TestCase(
                question="Translate to Lebanese Arabic: 'Peace'",
                expected_answer="salam",
                user_response="salammmm",
                expected_errors=[{"type": "SPELL_T", "token": "salammmm", "severity": "low"}],
                expected_correct=False,
                category="edge_case",
                description="Extra letters for emphasis"
            ),
            TestCase(
                question="Translate to Lebanese Arabic: 'Excuse me'",
                expected_answer="3afu",
                user_response="3afu please",
                expected_errors=[{"type": "EN_IN_AR", "token": "please", "severity": "medium"}],
                expected_correct=False,
                category="edge_case",
                description="Correct with English addition"
            ),

            # Category: Complex Contextual Cases
            TestCase(
                question="Complete: 'Good ___' (morning greeting)",
                expected_answer="sabah",
                user_response="morning",
                expected_errors=[{"type": "EN_IN_AR", "token": "morning", "severity": "high"}],
                expected_correct=False,
                category="advanced",
                description="Context-dependent English error"
            ),
            TestCase(
                question="Translate to Lebanese Arabic: 'My name is'",
                expected_answer="ismi",
                user_response="ismi",
                expected_errors=[],
                expected_correct=True,
                category="basic",
                description="Correct possessive form"
            ),
            TestCase(
                question="Translate to Lebanese Arabic: 'Water please'",
                expected_answer="mai 3aishek",
                user_response="water 3aishek",
                expected_errors=[{"type": "EN_IN_AR", "token": "water", "severity": "high"}],
                expected_correct=False,
                category="intermediate",
                description="Mixed language in request"
            ),

            # Category: Subtle Vocabulary Errors
            TestCase(
                question="Translate to Lebanese Arabic: 'House'",
                expected_answer="beit",
                user_response="dar",
                expected_errors=[{"type": "VOCAB", "token": "dar", "severity": "medium"}],
                expected_correct=False,
                category="advanced",
                description="Different valid Arabic word"
            ),
            TestCase(
                question="Translate to Lebanese Arabic: 'Money'",
                expected_answer="masari",
                user_response="flus",
                expected_errors=[{"type": "VOCAB", "token": "flus", "severity": "low"}],
                expected_correct=True,  # Both are valid in Lebanese Arabic
                category="advanced",
                description="Alternative valid vocabulary"
            ),

            # Category: Grammar Structure Tests
            TestCase(
                question="Translate to Lebanese Arabic: 'I am eating'",
                expected_answer="ana bekol",
                user_response="bekol ana",
                expected_errors=[{"type": "GRAMMAR", "token": "bekol ana", "severity": "medium"}],
                expected_correct=False,
                category="advanced",
                description="Incorrect word order"
            ),
            TestCase(
                question="Translate to Lebanese Arabic: 'This is good'",
                expected_answer="heda mnee7",
                user_response="heda mni7",
                expected_errors=[],
                expected_correct=True,
                category="intermediate",
                description="Correct with number substitution"
            ),

            # Category: Multiple Error Types
            TestCase(
                question="Translate to Lebanese Arabic: 'Good evening everyone'",
                expected_answer="masa el kheir kel wa7ad",
                user_response="good evening kel wa7ad",
                expected_errors=[
                    {"type": "EN_IN_AR", "token": "good", "severity": "high"},
                    {"type": "EN_IN_AR", "token": "evening", "severity": "high"}
                ],
                expected_correct=False,
                category="advanced",
                description="Multiple English words in Arabic context"
            ),
            TestCase(
                question="Translate to Lebanese Arabic: 'See you later'",
                expected_answer="nshufak ba3den",
                user_response="see you ba3den",
                expected_errors=[
                    {"type": "EN_IN_AR", "token": "see", "severity": "high"},
                    {"type": "EN_IN_AR", "token": "you", "severity": "high"}
                ],
                expected_correct=False,
                category="intermediate",
                description="Partial translation mixing"
            ),

            # Category: Borderline Cases for ≥80% Challenge
            TestCase(
                question="Translate to Lebanese Arabic: 'Maybe'",
                expected_answer="yimken",
                user_response="maybe",
                expected_errors=[{"type": "EN_IN_AR", "token": "maybe", "severity": "high"}],
                expected_correct=False,
                category="basic",
                description="Common untranslated word"
            ),
            TestCase(
                question="Translate to Lebanese Arabic: 'Okay'",
                expected_answer="tayeb",
                user_response="ok",
                expected_errors=[{"type": "EN_IN_AR", "token": "ok", "severity": "medium"}],
                expected_correct=False,
                category="basic",
                description="Casual English abbreviation"
            ),
        ]

    async def run_accuracy_test(self) -> AccuracyResult:
        """Run comprehensive accuracy test on all test cases."""
        print("🧪 Starting Error Detection Accuracy Test")
        print(f"📊 Testing {len(self.test_cases)} cases across categories")
        print("=" * 60)

        start_time = time.time()
        results = []
        category_stats = {}

        for i, test_case in enumerate(self.test_cases):
            print(f"[{i+1:2d}/{len(self.test_cases)}] {test_case.category.upper()}: {test_case.description}")

            # Run evaluation
            result = await self._evaluate_test_case(test_case)
            results.append(result)

            # Track category stats
            if test_case.category not in category_stats:
                category_stats[test_case.category] = {
                    'total': 0, 'correct': 0, 'false_pos': 0, 'false_neg': 0
                }

            category_stats[test_case.category]['total'] += 1
            if result['correct_classification']:
                category_stats[test_case.category]['correct'] += 1
            if result['false_positive']:
                category_stats[test_case.category]['false_pos'] += 1
            if result['false_negative']:
                category_stats[test_case.category]['false_neg'] += 1

            # Show result
            status = "✅" if result['correct_classification'] else "❌"
            print(f"    {status} Expected: {test_case.expected_correct}, Got: {result['actual_correct']}")

            if result['error_details']:
                print(f"    📝 {result['error_details']}")

        elapsed_time = time.time() - start_time

        # Calculate overall metrics
        accuracy_result = self._calculate_accuracy_metrics(results, category_stats)

        print("\n" + "=" * 60)
        print("📈 ACCURACY TEST RESULTS")
        print("=" * 60)
        print(f"⏱️  Total Time: {elapsed_time:.2f}s")
        print(f"📊 Total Cases: {accuracy_result.total_cases}")
        print(f"✅ Correct Classifications: {accuracy_result.correct_classifications}")
        print(f"❌ False Positives: {accuracy_result.false_positives}")
        print(f"⚠️  False Negatives: {accuracy_result.false_negatives}")
        print(f"🎯 Accuracy: {accuracy_result.accuracy:.1%}")
        print(f"🔍 Precision: {accuracy_result.precision:.1%}")
        print(f"📡 Recall: {accuracy_result.recall:.1%}")
        print(f"⚖️  F1 Score: {accuracy_result.f1_score:.1%}")

        print("\n📂 CATEGORY BREAKDOWN:")
        for category, stats in accuracy_result.category_results.items():
            print(f"  {category.upper()}: {stats['accuracy']:.1%} ({stats['correct']}/{stats['total']})")

        # Validate ≥80% requirement
        meets_requirement = accuracy_result.accuracy >= 0.8
        print(f"\n🎖️  REQUIREMENT CHECK: ≥80% Classification Accuracy")
        print(f"   Result: {'✅ PASSED' if meets_requirement else '❌ FAILED'} ({accuracy_result.accuracy:.1%})")

        return accuracy_result

    async def _evaluate_test_case(self, test_case: TestCase) -> Dict[str, Any]:
        """Evaluate a single test case and compare with expected results."""
        try:
            # Create evaluation request
            service_request = ServiceEvaluationRequest(
                user_id="test-user",
                lesson_id="test-lesson",
                quiz_id="test-quiz",
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
                    "topic": "test",
                    "level": "beginner"
                }
            )

            # Run evaluation
            evaluation_result = self.evaluation_service.evaluate_quiz_responses(service_request)

            if not evaluation_result.feedback:
                return {
                    'correct_classification': False,
                    'actual_correct': False,
                    'false_positive': False,
                    'false_negative': True,
                    'error_details': 'No feedback generated'
                }

            feedback = evaluation_result.feedback[0]
            actual_correct = feedback.is_correct
            actual_errors = feedback.errors

            # Check classification accuracy
            classification_correct = (actual_correct == test_case.expected_correct)

            # Check error detection accuracy
            false_positive = False
            false_negative = False

            if test_case.expected_errors:
                # Should have found errors
                if not actual_errors:
                    false_negative = True
                else:
                    # Check if we found the expected error types
                    expected_types = {err['type'] for err in test_case.expected_errors}
                    actual_types = {err.type for err in actual_errors}
                    if not expected_types.intersection(actual_types):
                        false_negative = True
            else:
                # Should not have found errors
                if actual_errors:
                    false_positive = True

            error_details = ""
            if actual_errors:
                error_details = f"Found {len(actual_errors)} errors: {[e.type for e in actual_errors]}"
            if test_case.expected_errors:
                expected_types = [e['type'] for e in test_case.expected_errors]
                error_details += f" | Expected: {expected_types}"

            return {
                'correct_classification': classification_correct,
                'actual_correct': actual_correct,
                'false_positive': false_positive,
                'false_negative': false_negative,
                'error_details': error_details
            }

        except Exception as e:
            print(f"    ⚠️  Evaluation failed: {e}")
            return {
                'correct_classification': False,
                'actual_correct': False,
                'false_positive': False,
                'false_negative': True,
                'error_details': f'Exception: {str(e)}'
            }

    def _calculate_accuracy_metrics(
        self,
        results: List[Dict[str, Any]],
        category_stats: Dict[str, Dict[str, int]]
    ) -> AccuracyResult:
        """Calculate comprehensive accuracy metrics."""
        total_cases = len(results)
        correct_classifications = sum(1 for r in results if r['correct_classification'])
        false_positives = sum(1 for r in results if r['false_positive'])
        false_negatives = sum(1 for r in results if r['false_negative'])

        accuracy = correct_classifications / total_cases if total_cases > 0 else 0.0

        # Calculate precision and recall for error detection
        true_positives = sum(1 for r in results if not r['false_positive'] and not r['false_negative'])
        precision = true_positives / (true_positives + false_positives) if (true_positives + false_positives) > 0 else 0.0
        recall = true_positives / (true_positives + false_negatives) if (true_positives + false_negatives) > 0 else 0.0
        f1_score = 2 * (precision * recall) / (precision + recall) if (precision + recall) > 0 else 0.0

        # Calculate category results
        category_results = {}
        for category, stats in category_stats.items():
            category_accuracy = stats['correct'] / stats['total'] if stats['total'] > 0 else 0.0
            category_results[category] = {
                'total': stats['total'],
                'correct': stats['correct'],
                'accuracy': category_accuracy,
                'false_positives': stats['false_pos'],
                'false_negatives': stats['false_neg']
            }

        return AccuracyResult(
            total_cases=total_cases,
            correct_classifications=correct_classifications,
            false_positives=false_positives,
            false_negatives=false_negatives,
            precision=precision,
            recall=recall,
            f1_score=f1_score,
            accuracy=accuracy,
            category_results=category_results
        )

    async def run_heuristics_only_test(self) -> Dict[str, Any]:
        """Test heuristics-only accuracy for comparison."""
        print("\n🔧 Running Heuristics-Only Test (for comparison)")
        print("-" * 40)

        correct = 0
        total = len(self.test_cases)

        for test_case in self.test_cases:
            # Run only heuristic checks
            heuristic_errors = []
            heuristic_errors.extend(self.heuristics.detect_english_in_arabic(test_case.user_response))
            heuristic_errors.extend(self.heuristics.detect_spelling_errors(test_case.user_response))
            heuristic_errors.extend(self.heuristics.detect_missing_transliteration(
                test_case.user_response, test_case.expected_answer
            ))

            # Simple heuristic: if any critical errors found, mark as incorrect
            critical_errors = [e for e in heuristic_errors if e.severity == "high"]
            heuristic_correct = len(critical_errors) == 0

            if heuristic_correct == test_case.expected_correct:
                correct += 1

        heuristics_accuracy = correct / total
        print(f"🔧 Heuristics-Only Accuracy: {heuristics_accuracy:.1%} ({correct}/{total})")

        return {
            'accuracy': heuristics_accuracy,
            'correct': correct,
            'total': total
        }

    def save_results(self, accuracy_result: AccuracyResult, filename: str = "evaluation_accuracy_results.json"):
        """Save test results to JSON file for analysis."""
        results_data = {
            'timestamp': time.time(),
            'total_cases': accuracy_result.total_cases,
            'accuracy': accuracy_result.accuracy,
            'precision': accuracy_result.precision,
            'recall': accuracy_result.recall,
            'f1_score': accuracy_result.f1_score,
            'meets_80_percent_requirement': accuracy_result.accuracy >= 0.8,
            'category_results': accuracy_result.category_results,
            'false_positives': accuracy_result.false_positives,
            'false_negatives': accuracy_result.false_negatives
        }

        with open(filename, 'w') as f:
            json.dump(results_data, f, indent=2)

        print(f"\n💾 Results saved to: {filename}")


async def main():
    """Main test execution function."""
    print("🚀 Error Detection Accuracy Testing Suite")
    print("🎯 Target: ≥80% Classification Accuracy")
    print("🔧 Testing Hybrid Approach (Heuristics + LLM Judge)")
    print()

    try:
        tester = EvaluationAccuracyTester()

        # Run main accuracy test
        accuracy_result = await tester.run_accuracy_test()

        # Run heuristics comparison
        heuristics_result = await tester.run_heuristics_only_test()

        # Save results
        tester.save_results(accuracy_result)

        # Final summary
        print("\n" + "=" * 60)
        print("🏁 FINAL SUMMARY")
        print("=" * 60)
        print(f"📊 Hybrid Approach: {accuracy_result.accuracy:.1%}")
        print(f"🔧 Heuristics Only: {heuristics_result['accuracy']:.1%}")
        print(f"📈 Improvement: {(accuracy_result.accuracy - heuristics_result['accuracy']):.1%}")

        requirement_met = accuracy_result.accuracy >= 0.8
        print(f"\n🎖️  ≥80% REQUIREMENT: {'✅ PASSED' if requirement_met else '❌ FAILED'}")

        if not requirement_met:
            print("\n💡 IMPROVEMENT SUGGESTIONS:")
            print("   - Review false negative cases for pattern improvement")
            print("   - Enhance LLM prompting for edge cases")
            print("   - Add more sophisticated heuristic rules")
            print("   - Consider context-aware error detection")

        return 0 if requirement_met else 1

    except Exception as e:
        print(f"\n💥 Test execution failed: {e}")
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)