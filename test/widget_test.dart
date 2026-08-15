import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noctros/app/bootstrap/noctros_bootstrap.dart';
import 'package:noctros/app/noctros_app.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _settleAsyncUi(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await NoctrosBootstrap.initialize();
  });

  testWidgets('Messages inbox renders seeded conversations', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: NoctrosApp(),
      ),
    );
    await _settleAsyncUi(tester);

    expect(find.text('Noctros'), findsWidgets);
    expect(find.text('Messages'), findsWidgets);
    expect(find.text('Maya Chen'), findsWidgets);
  });

  testWidgets('Bottom navigation reaches Contacts', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: NoctrosApp(),
      ),
    );
    await _settleAsyncUi(tester);

    await tester.tap(find.text('Contacts').last);
    await _settleAsyncUi(tester);

    expect(find.text('All contacts'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('Assistant opens the Hive of connected agents', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: NoctrosApp(),
      ),
    );
    await _settleAsyncUi(tester);

    await tester.tap(find.text('Assistant').last);
    await _settleAsyncUi(tester);

    expect(find.text('Open the Hive'), findsOneWidget);

    await tester.tap(find.text('Open the Hive'));
    await _settleAsyncUi(tester);

    expect(find.text('One autonomous system'), findsOneWidget);
    expect(find.text('Conductor'), findsWidgets);
    expect(find.text('Coder'), findsWidgets);
  });
}
