import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:noctros/app/noctros_app.dart';

void main() {
  testWidgets('Noctros home renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: NoctrosApp(),
      ),
    );

    expect(find.text('Noctros'), findsOneWidget);
  });
}
