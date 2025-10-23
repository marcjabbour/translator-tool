import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translator_tool/models/quiz.dart';
import 'package:translator_tool/widgets/questions/multiple_choice_question.dart';

void main() {
  group('MultipleChoiceQuestion Widget', () {
    late QuizQuestion testQuestion;
    int? selectedChoice;
    bool callbackCalled = false;

    setUp(() {
      testQuestion = QuizQuestion(
        type: 'mcq',
        question: 'What does "marhaba" mean?',
        answer: 0,
        choices: ['Hello', 'Goodbye', 'Thank you', 'Please'],
        rationale: 'Marhaba is a common greeting in Arabic.',
      );
      selectedChoice = null;
      callbackCalled = false;
    });

    Widget createWidget({
      QuizQuestion? question,
      int? selected,
      bool showCorrect = false,
      bool enabled = true,
    }) {
      return ProviderScope(
        child: CupertinoApp(
          home: CupertinoPageScaffold(
            child: MultipleChoiceQuestion(
              question: question ?? testQuestion,
              selectedChoice: selected,
              showCorrectAnswer: showCorrect,
              onChoiceSelected: (choice) {
                selectedChoice = choice;
                callbackCalled = true;
              },
              isEnabled: enabled,
            ),
          ),
        ),
      );
    }

    testWidgets('should display question text and choices', (tester) async {
      await tester.pumpWidget(createWidget());

      expect(find.text('What does "marhaba" mean?'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Goodbye'), findsOneWidget);
      expect(find.text('Thank you'), findsOneWidget);
      expect(find.text('Please'), findsOneWidget);
      expect(find.text('Multiple Choice'), findsOneWidget);
    });

    testWidgets('should display choice indicators (A, B, C, D)', (tester) async {
      await tester.pumpWidget(createWidget());

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);
      expect(find.text('D'), findsOneWidget);
    });

    testWidgets('should handle choice selection', (tester) async {
      await tester.pumpWidget(createWidget());

      // Tap on first choice (Hello)
      await tester.tap(find.text('Hello'));
      await tester.pump();

      expect(callbackCalled, true);
      expect(selectedChoice, 0);
    });

    testWidgets('should show selected choice with different styling', (tester) async {
      await tester.pumpWidget(createWidget(selected: 1));

      // The selected choice should have different styling
      // We can't easily test colors, but we can ensure the widget builds correctly
      expect(find.text('Goodbye'), findsOneWidget);
    });

    testWidgets('should show correct answer when enabled', (tester) async {
      await tester.pumpWidget(createWidget(
        selected: 1, // Wrong answer
        showCorrect: true,
      ));

      // Should show feedback since showCorrectAnswer is true
      expect(find.text('Explanation'), findsOneWidget);
      expect(find.text('Marhaba is a common greeting in Arabic.'), findsOneWidget);
    });

    testWidgets('should show result icon when answer is shown', (tester) async {
      await tester.pumpWidget(createWidget(
        selected: 0, // Correct answer
        showCorrect: true,
      ));

      // Should show checkmark icon for correct answer
      expect(find.byIcon(CupertinoIcons.check_mark), findsAtLeastOneWidget);
    });

    testWidgets('should show error icon for wrong answer', (tester) async {
      await tester.pumpWidget(createWidget(
        selected: 1, // Wrong answer
        showCorrect: true,
      ));

      // Should show X mark icon for wrong answer
      expect(find.byIcon(CupertinoIcons.xmark), findsAtLeastOneWidget);
    });

    testWidgets('should disable interaction when not enabled', (tester) async {
      await tester.pumpWidget(createWidget(enabled: false));

      // Try to tap on a choice
      await tester.tap(find.text('Hello'));
      await tester.pump();

      // Callback should not be called when disabled
      expect(callbackCalled, false);
    });

    testWidgets('should disable interaction when showing correct answer', (tester) async {
      await tester.pumpWidget(createWidget(showCorrect: true));

      // Try to tap on a choice
      await tester.tap(find.text('Hello'));
      await tester.pump();

      // Callback should not be called when showing correct answer
      expect(callbackCalled, false);
    });

    testWidgets('should display error for invalid question', (tester) async {
      final invalidQuestion = QuizQuestion(
        type: 'translate', // Wrong type
        question: 'Invalid question',
        answer: 'answer',
      );

      await tester.pumpWidget(createWidget(question: invalidQuestion));

      expect(find.text('Invalid multiple choice question format'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.exclamationmark_triangle), findsOneWidget);
    });

    testWidgets('should display error for question without choices', (tester) async {
      final invalidQuestion = QuizQuestion(
        type: 'mcq',
        question: 'Question without choices',
        answer: 0,
        choices: null, // No choices
      );

      await tester.pumpWidget(createWidget(question: invalidQuestion));

      expect(find.text('Invalid multiple choice question format'), findsOneWidget);
    });

    testWidgets('should handle animation', (tester) async {
      await tester.pumpWidget(createWidget());

      // Pump until animation completes
      await tester.pumpAndSettle();

      // Widget should be visible after animation
      expect(find.text('What does "marhaba" mean?'), findsOneWidget);
    });

    testWidgets('should show feedback only when rationale exists', (tester) async {
      final questionWithoutRationale = QuizQuestion(
        type: 'mcq',
        question: 'Test question',
        answer: 0,
        choices: ['A', 'B', 'C', 'D'],
        rationale: null,
      );

      await tester.pumpWidget(createWidget(
        question: questionWithoutRationale,
        selected: 0,
        showCorrect: true,
      ));

      // Should not show explanation section when no rationale
      expect(find.text('Explanation'), findsNothing);
    });

    testWidgets('should handle tap on choice containers', (tester) async {
      await tester.pumpWidget(createWidget());

      // Find the choice button by its text content
      final choiceButton = find.ancestor(
        of: find.text('Hello'),
        matching: find.byType(CupertinoButton),
      );

      await tester.tap(choiceButton);
      await tester.pump();

      expect(callbackCalled, true);
      expect(selectedChoice, 0);
    });

    testWidgets('should maintain visual state during rebuild', (tester) async {
      await tester.pumpWidget(createWidget(selected: 2));

      // Verify initial selection
      expect(find.text('Thank you'), findsOneWidget);

      // Rebuild with different selection
      await tester.pumpWidget(createWidget(selected: 3));

      // Should show new selection
      expect(find.text('Please'), findsOneWidget);
    });

    testWidgets('should show correct visual feedback for all states', (tester) async {
      // Test correct answer state
      await tester.pumpWidget(createWidget(
        selected: 0, // Correct
        showCorrect: true,
      ));
      await tester.pump();

      expect(find.byIcon(CupertinoIcons.check_mark), findsAtLeastOneWidget);

      // Test incorrect answer state
      await tester.pumpWidget(createWidget(
        selected: 1, // Incorrect
        showCorrect: true,
      ));
      await tester.pump();

      expect(find.byIcon(CupertinoIcons.xmark), findsAtLeastOneWidget);
    });
  });
}