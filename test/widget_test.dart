import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:noctros/presentation/features/home/home_screen.dart';

void main() {
  testWidgets('Noctros home renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HomeScreen(),
      ),
    );

    expect(find.text('Noctros'), findsOneWidget);
    expect(find.text('Your second brain.'), findsOneWidget);
  });
}
