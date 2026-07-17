import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_recycling_flutter/src/ui/app/waste_app.dart';
import 'package:waste_recycling_flutter/src/ui/auth/auth_screens.dart';
import 'package:waste_recycling_flutter/src/ui/citizen/citizen_screens.dart';
import 'package:waste_recycling_flutter/src/ui/home/home_screen.dart';

import 'support/fake_app_controller.dart';

void main() {
  testWidgets('guest landing opens login without contacting the API', (
    tester,
  ) async {
    final controller = FakeAppController.guest();
    addTearDown(controller.dispose);

    await tester.pumpWidget(WasteApp(controller: controller));
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(CitizenScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
    expect(controller.fakeApi.totalRequests, 0);

    final loginAction = find.widgetWithText(FilledButton, 'Đăng nhập');
    expect(loginAction, findsOneWidget);

    await tester.tap(loginAction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(controller.fakeApi.totalRequests, 0);
  });
}
