import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:the_city_property/core/utils/system_insets.dart';

void main() {
  testWidgets('adds the navigation bar inset to the bottom padding',
      (tester) async {
    late EdgeInsets padded;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(bottom: 34)),
        child: Builder(
          builder: (context) {
            padded =
                withSystemBottomInset(context, const EdgeInsets.all(16));
            return const SizedBox();
          },
        ),
      ),
    );

    expect(padded, const EdgeInsets.fromLTRB(16, 16, 16, 50));
  });

  testWidgets('falls back to viewPadding when a SafeArea consumed the padding',
      (tester) async {
    late EdgeInsets padded;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          viewPadding: EdgeInsets.only(bottom: 34),
        ),
        child: SafeArea(
          child: Builder(
            builder: (context) {
              padded =
                  withSystemBottomInset(context, const EdgeInsets.all(16));
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(padded, const EdgeInsets.fromLTRB(16, 16, 16, 50));
  });

  testWidgets('ignores the inset while the keyboard is open', (tester) async {
    late EdgeInsets padded;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          padding: EdgeInsets.only(bottom: 34),
          viewInsets: EdgeInsets.only(bottom: 320),
        ),
        child: Builder(
          builder: (context) {
            padded =
                withSystemBottomInset(context, const EdgeInsets.all(16));
            return const SizedBox();
          },
        ),
      ),
    );

    expect(padded, const EdgeInsets.all(16));
  });

  testWidgets('keeps the padding untouched when no inset is reported',
      (tester) async {
    late EdgeInsets padded;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Builder(
          builder: (context) {
            padded =
                withSystemBottomInset(context, const EdgeInsets.all(16));
            return const SizedBox();
          },
        ),
      ),
    );

    expect(padded, const EdgeInsets.all(16));
  });
}
