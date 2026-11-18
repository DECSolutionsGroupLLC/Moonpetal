import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';

import 'package:moonpetal/app.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets(
    'the empty state fits a phone-sized portrait viewport',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpEmptyState(tester);

      final headline = tester.getRect(find.text('Welcome to Moonpetal'));
      final body = tester.getRect(find.textContaining('Start by marking today'));

      expect(tester.takeException(), isNull);
      expect(body.left, greaterThanOrEqualTo(0));
      expect(body.right, lessThanOrEqualTo(390));
      expect(headline.top, greaterThanOrEqualTo(0));
      expect(body.bottom, lessThanOrEqualTo(844));
    },
  );

  testWidgets(
    'a wide desktop window keeps the content in a phone-width column',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpEmptyState(tester);

      final body = tester.getRect(find.textContaining('Start by marking today'));

      expect(tester.takeException(), isNull);
      expect(body.center.dx, closeTo(640, 1));
      expect(body.left, greaterThanOrEqualTo(460));
      expect(body.right, lessThanOrEqualTo(820));
    },
  );
}

Future<void> _pumpEmptyState(WidgetTester tester) async {
  await tester.pumpWidget(
    MoonpetalApp(
      clock: FixedClock(DateTime(2026, 11, 18, 9)),
      store: InMemoryAppStore(),
    ),
  );
  await tester.pumpAndSettle();
}
