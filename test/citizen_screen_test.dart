import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_recycling_flutter/src/ui/app/waste_app.dart';
import 'package:waste_recycling_flutter/src/ui/citizen/citizen_screens.dart';
import 'package:waste_recycling_flutter/src/ui/shared/widgets.dart';

import 'support/fake_app_controller.dart';

void main() {
  testWidgets('authenticated citizen is routed directly to CitizenScreen', (
    tester,
  ) async {
    final controller = FakeAppController.citizen();
    addTearDown(controller.dispose);

    await tester.pumpWidget(WasteApp(controller: controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(CitizenScreen), findsOneWidget);
    expect(find.byType(CitizenHomeView), findsOneWidget);
    expect(controller.fakeApi.addressRequests, 1);
    expect(controller.fakeApi.reportRequests, 1);
  });

  testWidgets('Citizen bottom navigation lazily opens the reports tab', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = FakeAppController.citizen();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CitizenScreen(controller: controller),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(CitizenHomeView), findsOneWidget);
    expect(find.byType(MyReportsView), findsNothing);
    expect(controller.fakeApi.complaintRequests, 0);
    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(MyReportsView), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);
    expect(controller.fakeApi.complaintRequests, 1);
    expect(controller.fakeApi.reportRequests, 2);
  });
}
