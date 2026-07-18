import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_recycling_flutter/src/controllers/app_controller.dart';
import 'package:waste_recycling_flutter/src/ui/app/waste_app.dart';
import 'package:waste_recycling_flutter/src/ui/auth/auth_screens.dart';
import 'package:waste_recycling_flutter/src/ui/citizen/citizen_screens.dart';
import 'package:waste_recycling_flutter/src/ui/home/home_screen.dart';
import 'package:waste_recycling_flutter/src/ui/shared/widgets.dart';

import 'support/fake_app_controller.dart';

void main() {
  testWidgets('startup paints a branded loading state before session restore', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(WasteApp(controller: controller));
    await tester.pump();

    expect(find.byType(AppLoadingView), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

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

  testWidgets('authentication screens support narrow devices and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = FakeAppController.guest();
    addTearDown(controller.dispose);

    Widget screen(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2),
        ),
        child: child,
      ),
    );

    await tester.pumpWidget(screen(LoginScreen(controller: controller)));
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(screen(SignupScreen(controller: controller)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
