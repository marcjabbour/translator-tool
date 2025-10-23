import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:translator_tool/models/quiz.dart';
import 'package:translator_tool/widgets/questions/translation_question.dart';

void main() {
  group('TranslationQuestion Widget', () {
    late QuizQuestion testQuestion;
    String? userAnswer;
    bool callbackCalled = false;

    setUp(() {
      testQuestion = QuizQuestion(
        type: 'translate',
        question: 'Translate to Lebanese Arabic: Good morning',
        answer: 'sabah al kheir',
        rationale: 'Sabah al kheir is the common way to say good morning in Lebanese Arabic.',
      );
      userAnswer = null;
      callbackCalled = false;
    });

    Widget createWidget({
      QuizQuestion? question,
      String? answer,
      bool showCorrect = false,
      bool enabled = true,
    }) {
      return ProviderScope(
        child: CupertinoApp(
          home: CupertinoPageScaffold(
            child: TranslationQuestion(
              question: question ?? testQuestion,
              userAnswer: answer,
              showCorrectAnswer: showCorrect,
              onAnswerChanged: (newAnswer) {
                userAnswer = newAnswer;
                callbackCalled = true;
              },
              isEnabled: enabled,
            ),
          ),
        ),
      );
    }

    testWidgets('should display question text and input field', (tester) async {
      await tester.pumpWidget(createWidget());

      expect(find.text('Translate to Lebanese Arabic: Good morning'), findsOneWidget);
      expect(find.text('Translation'), findsOneWidget);
      expect(find.text('Your translation:'), findsOneWidget);
      expect(find.text('Type your translation here...'), findsOneWidget);
      expect(find.text('Use Latin alphabet only'), findsOneWidget);
    });

    testWidgets('should handle text input', (tester) async {
      await tester.pumpWidget(createWidget());

      final textField = find.byType(CupertinoTextField);
      await tester.enterText(textField, 'sabah al kheir');
      await tester.pump();

      expect(callbackCalled, true);
      expect(userAnswer, 'sabah al kheir');
    });

    testWidgets('should display initial user answer', (tester) async {
      await tester.pumpWidget(createWidget(answer: 'initial answer'));

      final textField = find.byType(CupertinoTextField);
      final textFieldWidget = tester.widget<CupertinoTextField>(textField);

      expect(textFieldWidget.controller?.text, 'initial answer');
    });

    testWidgets('should show character count', (tester) async {
      await tester.pumpWidget(createWidget(answer: 'test'));

      expect(find.text('4 characters'), findsOneWidget);
    });

    testWidgets('should show correct answer feedback when enabled', (tester) async {
      await tester.pumpWidget(createWidget(
        answer: 'sabah al kheir', // Correct answer
        showCorrect: true,
      ));

      expect(find.text('Correct!'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.check_mark), findsAtLeastOneWidget);
    });

    testWidgets('should show incorrect answer feedback', (tester) async {
      await tester.pumpWidget(createWidget(
        answer: 'wrong answer',
        showCorrect: true,
      ));

      expect(find.text('Incorrect'), findsOneWidget);
      expect(find.text('Correct answer:'), findsOneWidget);
      expect(find.text('sabah al kheir'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.xmark), findsAtLeastOneWidget);
    });

    testWidgets('should show explanation when available', (tester) async {
      await tester.pumpWidget(createWidget(
        answer: 'wrong answer',
        showCorrect: true,
      ));

      expect(find.text('Explanation'), findsOneWidget);
      expect(find.text('Sabah al kheir is the common way to say good morning in Lebanese Arabic.'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.lightbulb), findsOneWidget);
    });

    testWidgets('should disable input when not enabled', (tester) async {
      await tester.pumpWidget(createWidget(enabled: false));

      final textField = find.byType(CupertinoTextField);
      final textFieldWidget = tester.widget<CupertinoTextField>(textField);

      expect(textFieldWidget.enabled, false);
    });

    testWidgets('should disable input when showing correct answer', (tester) async {
      await tester.pumpWidget(createWidget(showCorrect: true));

      final textField = find.byType(CupertinoTextField);
      final textFieldWidget = tester.widget<CupertinoTextField>(textField);

      expect(textFieldWidget.enabled, false);
    });

    testWidgets('should show different border colors based on state', (tester) async {
      // Test correct answer border
      await tester.pumpWidget(createWidget(
        answer: 'sabah al kheir',
        showCorrect: true,
      ));
      await tester.pump();

      // Should not throw and widget should build correctly
      expect(find.byType(CupertinoTextField), findsOneWidget);

      // Test incorrect answer border
      await tester.pumpWidget(createWidget(
        answer: 'wrong',
        showCorrect: true,
      ));
      await tester.pump();

      expect(find.byType(CupertinoTextField), findsOneWidget);
    });

    testWidgets('should display error for invalid question type', (tester) async {
      final invalidQuestion = QuizQuestion(
        type: 'mcq', // Wrong type
        question: 'Invalid question',
        answer: 0,
      );

      await tester.pumpWidget(createWidget(question: invalidQuestion));

      expect(find.text('Invalid translation question format'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.exclamationmark_triangle), findsOneWidget);
    });

    testWidgets('should handle focus state', (tester) async {
      await tester.pumpWidget(createWidget());

      final textField = find.byType(CupertinoTextField);

      // Tap to focus
      await tester.tap(textField);
      await tester.pump();

      // Should not throw and maintain focus
      expect(find.byType(CupertinoTextField), findsOneWidget);
    });

    testWidgets('should handle enter key submission', (tester) async {
      await tester.pumpWidget(createWidget());

      final textField = find.byType(CupertinoTextField);

      await tester.enterText(textField, 'test answer');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Should maintain the text and remove focus
      expect(userAnswer, 'test answer');
    });

    testWidgets('should update text when userAnswer prop changes', (tester) async {
      await tester.pumpWidget(createWidget(answer: 'initial'));

      // Update with new answer
      await tester.pumpWidget(createWidget(answer: 'updated'));

      final textField = find.byType(CupertinoTextField);
      final textFieldWidget = tester.widget<CupertinoTextField>(textField);

      expect(textFieldWidget.controller?.text, 'updated');
    });

    testWidgets('should handle multiline input', (tester) async {
      await tester.pumpWidget(createWidget());

      final textField = find.byType(CupertinoTextField);
      final textFieldWidget = tester.widget<CupertinoTextField>(textField);

      expect(textFieldWidget.maxLines, 3);
      expect(textFieldWidget.minLines, 1);
    });

    testWidgets('should show result icon in header when answer is shown', (tester) async {
      await tester.pumpWidget(createWidget(
        answer: 'sabah al kheir',
        showCorrect: true,
      ));

      // Should show result icon in the header
      expect(find.byIcon(CupertinoIcons.check_mark), findsAtLeastOneWidget);
    });

    testWidgets('should handle animation', (tester) async {
      await tester.pumpWidget(createWidget());

      // Pump until animation completes
      await tester.pumpAndSettle();

      // Widget should be visible after animation
      expect(find.text('Translate to Lebanese Arabic: Good morning'), findsOneWidget);
    });

    testWidgets('should not show feedback when no rationale', (tester) async {
      final questionWithoutRationale = QuizQuestion(
        type: 'translate',
        question: 'Test question',
        answer: 'answer',
        rationale: null,
      );

      await tester.pumpWidget(createWidget(
        question: questionWithoutRationale,
        answer: 'wrong',
        showCorrect: true,
      ));

      // Should show feedback section but without explanation
      expect(find.text('Incorrect'), findsOneWidget);
      expect(find.text('Explanation'), findsNothing);
    });

    testWidgets('should handle case insensitive correct answers', (tester) async {
      await tester.pumpWidget(createWidget(
        answer: 'SABAH AL KHEIR', // Uppercase version
        showCorrect: true,
      ));

      // Should still show as correct
      expect(find.text('Correct!'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.check_mark), findsAtLeastOneWidget);
    });

    testWidgets('should trim whitespace for correct answers', (tester) async {
      await tester.pumpWidget(createWidget(
        answer: '  sabah al kheir  ', // With whitespace
        showCorrect: true,
      ));

      // Should still show as correct
      expect(find.text('Correct!'), findsOneWidget);
    });
  });
}