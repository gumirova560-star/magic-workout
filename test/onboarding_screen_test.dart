import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:workout_tracker/data/fairy_phrases.dart';
import 'package:workout_tracker/screens/onboarding_screen.dart';

void main() {
  setUp(() {
    // Чистые SharedPreferences для каждого теста
    SharedPreferences.setMockInitialValues({});
  });

  /// Завершает тест: размонтирует экран, чтобы бесконечная анимация
  /// феи не осталась активной (иначе тест падает с «Ticker was still active»).
  Future<void> stopAnimations(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Показывает первичное исключение, если оно случилось в этом кадре.
  void reportExceptions(WidgetTester tester, String where) {
    final exc = tester.takeException();
    if (exc != null) {
      print('>>> ИССКЛЮЧЕНИЕ в [$where]: $exc');
    }
  }

  testWidgets('Пропустить сразу завершает онбординг', (tester) async {
    int finished = 0;

    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onFinish: () => finished++)),
    );
    await tester.pump();
    reportExceptions(tester, 'старт');

    expect(find.text('Пропустить'), findsOneWidget);

    await tester.tap(find.text('Пропустить'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    reportExceptions(tester, 'тап Пропустить');

    expect(finished, 1);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('fairy_onboarding_done'), isTrue);

    await stopAnimations(tester);
  });

  testWidgets('Пролистывание всех страниц завершает онбординг', (tester) async {
    int finished = 0;

    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onFinish: () => finished++)),
    );
    await tester.pump();
    reportExceptions(tester, 'старт');

    final pageCount = FairyPhrases.onboarding.length;
    print('>>> страниц в онбординге: $pageCount');

    PageController controllerOf() =>
        tester.widget<PageView>(find.byType(PageView)).controller!;

    // Листаем жестами (как реальный пользователь), а не тапами по кнопке:
    // свайп не зависит от разметки кнопки и перекрытий.
    for (int i = 0; i < pageCount - 1; i++) {
      final before = controllerOf().page?.round() ?? 0;

      await tester.fling(
        find.byType(PageView),
        const Offset(-500, 0),
        800,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 500));
      reportExceptions(tester, 'шаг $i');

      final after = controllerOf().page?.round() ?? before;
      print('>>> шаг $i: страница $before -> $after');
      expect(after, greaterThan(before),
          reason: 'Шаг $i: свайп не перелистнул страницу');
    }

    // На последней странице кнопка должна называться «Погнали! 🚀»
    final lastButton = find.widgetWithText(ElevatedButton, 'Погнали! 🚀');
    expect(lastButton, findsOneWidget,
        reason: 'После листания кнопка «Далее» не сменилась на «Погнали!»');

    await tester.tap(lastButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    reportExceptions(tester, 'тап Погнали');

    expect(finished, 1);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('fairy_onboarding_done'), isTrue);

    await stopAnimations(tester);
  });
}
