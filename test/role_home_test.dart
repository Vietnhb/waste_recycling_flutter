import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_recycling_flutter/src/models/models.dart';
import 'package:waste_recycling_flutter/src/ui/admin/admin_screens.dart';
import 'package:waste_recycling_flutter/src/ui/citizen/citizen_screens.dart';
import 'package:waste_recycling_flutter/src/ui/collector/collector_screens.dart';
import 'package:waste_recycling_flutter/src/ui/enterprise/enterprise_screens.dart';
import 'package:waste_recycling_flutter/src/ui/home/home_screen.dart';
import 'package:waste_recycling_flutter/src/ui/shared/widgets.dart';

import 'support/fake_app_controller.dart';

void main() {
  Future<void> pumpRoleHome(
    WidgetTester tester, {
    required Widget home,
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: home));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
  }

  testWidgets(
    'unknown server role fails closed instead of opening Citizen UI',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = FakeAppController.citizen(
        user: const User(
          id: 99,
          email: 'unknown@example.test',
          fullName: 'Unknown Role',
          role: 'LEGACY_ROLE',
        ),
      );
      addTearDown(controller.dispose);

      await pumpRoleHome(
        tester,
        home: HomeScreen(controller: controller),
        size: const Size(390, 844),
      );

      expect(find.text('Chưa thể mở không gian làm việc'), findsOneWidget);
      expect(find.byType(CitizenScreen), findsNothing);
      expect(find.text('Đăng xuất an toàn'), findsOneWidget);
    },
  );

  testWidgets('temporary network failure preserves the local session', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = FakeAppController.citizen();
    controller.user = null;
    controller.sessionRestoreError = const SocketException('offline');
    addTearDown(controller.dispose);

    await pumpRoleHome(
      tester,
      home: HomeScreen(controller: controller),
      size: const Size(390, 844),
    );

    expect(find.text('Chưa thể xác minh phiên đăng nhập'), findsOneWidget);
    expect(find.text('Thử kết nối lại'), findsOneWidget);
    expect(find.text('Đăng nhập'), findsNothing);
    expect(controller.token, isNotNull);
  });

  testWidgets('Citizen opens a task-first home without a map', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = FakeAppController.citizen();
    addTearDown(controller.dispose);

    await pumpRoleHome(
      tester,
      home: CitizenScreen(controller: controller),
      size: const Size(390, 844),
    );

    expect(find.byType(CitizenHomeView), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Báo rác ngay'), findsOneWidget);
    expect(find.text('Thao tác nhanh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Collector opens Home and keeps Trips at the next tab', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = FakeAppController.collector();
    addTearDown(controller.dispose);

    await pumpRoleHome(
      tester,
      home: CollectorScreen(controller: controller),
      size: const Size(430, 932),
    );

    expect(find.byType(CollectorHomeView), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Trang chủ'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Chuyến đi').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(CollectorReportsView), findsOneWidget);
  });

  testWidgets('Enterprise opens Home and keeps Pending at the next tab', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = FakeAppController.enterprise();
    addTearDown(controller.dispose);

    await pumpRoleHome(
      tester,
      home: EnterpriseScreen(controller: controller),
      size: const Size(430, 932),
    );

    expect(find.byType(EnterpriseHomeView), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Trang chủ'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Yêu cầu').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(PendingReportsView), findsOneWidget);
  });

  testWidgets('Enterprise More sheet scrolls on a short landscape viewport', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = FakeAppController.enterprise();
    addTearDown(controller.dispose);

    await pumpRoleHome(
      tester,
      home: EnterpriseScreen(controller: controller),
      size: const Size(598, 480),
    );

    await tester.tap(find.text('Thêm').last);
    await tester.pumpAndSettle();

    expect(find.text('Không gian doanh nghiệp'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).last, const Offset(0, -280));
    await tester.pumpAndSettle();
    expect(find.text('Lịch sử hoàn tất'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Admin opens Home and keeps Accounts at the next tab', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = FakeAppController.admin();
    addTearDown(controller.dispose);

    await pumpRoleHome(
      tester,
      home: AdminScreen(controller: controller),
      size: const Size(430, 932),
    );

    expect(find.byType(AdminHomeView), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Trang chủ'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Tài khoản').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(AdminUsersView), findsOneWidget);
  });

  testWidgets('all role dashboards render at a desktop breakpoint', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controllers = [
      FakeAppController.citizen(),
      FakeAppController.collector(),
      FakeAppController.enterprise(),
      FakeAppController.admin(),
    ];
    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
    });
    final homes = <Widget>[
      CitizenScreen(controller: controllers[0]),
      CollectorScreen(controller: controllers[1]),
      EnterpriseScreen(controller: controllers[2]),
      AdminScreen(controller: controllers[3]),
    ];

    for (final home in homes) {
      await pumpRoleHome(tester, home: home, size: const Size(1440, 1000));
      expect(find.byType(FlutterMap), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('system back returns every role shell to Home first', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;

    final controllers = [
      FakeAppController.citizen(),
      FakeAppController.collector(),
      FakeAppController.enterprise(),
      FakeAppController.admin(),
    ];
    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
    });

    final cases =
        <({Widget shell, String destination, Type homeType, Type detailType})>[
          (
            shell: CitizenScreen(controller: controllers[0]),
            destination: 'Báo cáo',
            homeType: CitizenHomeView,
            detailType: MyReportsView,
          ),
          (
            shell: CollectorScreen(controller: controllers[1]),
            destination: 'Chuyến đi',
            homeType: CollectorHomeView,
            detailType: CollectorReportsView,
          ),
          (
            shell: EnterpriseScreen(controller: controllers[2]),
            destination: 'Yêu cầu',
            homeType: EnterpriseHomeView,
            detailType: PendingReportsView,
          ),
          (
            shell: AdminScreen(controller: controllers[3]),
            destination: 'Tài khoản',
            homeType: AdminHomeView,
            detailType: AdminUsersView,
          ),
        ];

    for (final testCase in cases) {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: testCase.shell),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      await tester.tap(find.text(testCase.destination).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byType(testCase.detailType), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(find.byType(testCase.homeType), findsOneWidget);
      expect(find.byType(testCase.detailType), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
