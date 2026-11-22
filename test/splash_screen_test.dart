import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:the_city_property/core/theme/app_theme.dart';
import 'package:the_city_property/features/auth/splash_screen.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('Tajawal');
  for (final weight in ['Regular', 'Bold', 'ExtraBold']) {
    final data = await rootBundle.load('assets/fonts/Tajawal-$weight.ttf');
    loader.addFont(Future.value(data));
  }
  await loader.load();
}

void main() {
  testWidgets('branded splash renders', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const SplashScreen(),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        const AssetImage('assets/images/logo.png'),
        tester.element(find.byType(SplashScreen)),
      );
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 1200));

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(SplashScreen),
      matchesGoldenFile('goldens/splash.png'),
    );
  });
}
