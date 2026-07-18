import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_recycling_flutter/src/ui/app/waste_app.dart';
import 'package:waste_recycling_flutter/src/ui/citizen/citizen_screens.dart';
import 'package:waste_recycling_flutter/src/models/models.dart';
import 'package:waste_recycling_flutter/src/ui/shared/widgets.dart';

import 'support/fake_app_controller.dart';

const _rankingAddress = UserAddress(
  id: 3,
  receiverName: 'Nguyen An',
  phoneNumber: '0900000000',
  detailAddress: 'Ben Nghe',
  addressNumber: '12 Le Loi',
  latitude: 10.7769,
  longitude: 106.7009,
  isDefault: true,
  provinceCode: '79',
  wardCode: '26740',
);

const _rankingLocations = [
  Province(
    code: '79',
    name: 'Ho Chi Minh',
    nameEn: 'Ho Chi Minh',
    fullName: 'Thanh pho Ho Chi Minh',
    fullNameEn: 'Ho Chi Minh City',
    wards: [
      Ward(
        code: '26740',
        name: 'Ben Nghe',
        nameEn: 'Ben Nghe',
        fullName: 'Phuong Ben Nghe',
        fullNameEn: 'Ben Nghe Ward',
      ),
    ],
  ),
];

const _compactRanking = [
  RankingUser(
    userId: 11,
    userName: 'Mai Linh',
    totalPoints: 1120,
    totalReports: 25,
    rank: 1,
    provinceCode: '79',
    wardCode: '26740',
  ),
  RankingUser(
    userId: 7,
    userName: 'Nguyen An',
    totalPoints: 1040,
    totalReports: 23,
    rank: 2,
    provinceCode: '79',
    wardCode: '26740',
  ),
  RankingUser(
    userId: 13,
    userName: 'Quoc Huy',
    totalPoints: 930,
    totalReports: 20,
    rank: 3,
    provinceCode: '79',
    wardCode: '26740',
  ),
];

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
    expect(find.byType(BottomAppBar), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsWidgets);
    expect(find.byIcon(Icons.map_outlined), findsNothing);
    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(MyReportsView), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);
    expect(controller.fakeApi.complaintRequests, 1);
    expect(controller.fakeApi.reportRequests, 2);
  });

  testWidgets('long report history builds cards lazily while scrolling', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final reports = List.generate(
      80,
      (index) => WasteReport(
        id: index + 1,
        imageUrl: '',
        description: 'Báo cáo ${index + 1}',
        status: 'ASSIGNED',
        citizenId: 7,
        citizenName: 'Nguyen An',
        citizenEmail: 'citizen@example.test',
        addressId: 3,
        addressDetail: 'Phường Bến Nghé',
        addressNumber: '12 Lê Lợi',
        latitude: 10.7769,
        longitude: 106.7009,
        provinceCode: '79',
        wardCode: '26740',
        receiverName: 'Nguyen An',
        phoneNumber: '0900000000',
        categoryId: 2,
        categoryName: 'RECYCLABLE',
      ),
    );
    final controller = FakeAppController.citizen(reports: reports);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CitizenScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(ReportCard).evaluate().length, lessThan(80));
    expect(find.text('Báo cáo 80'), findsNothing);

    final reportScroll = find.descendant(
      of: find.byKey(const PageStorageKey('citizen-my-reports-scroll')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Báo cáo 80'),
      650,
      scrollable: reportScroll,
      maxScrolls: 80,
    );

    expect(find.text('Báo cáo 80'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('realtime refreshes only the visible citizen destination', (
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
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final reportsBefore = controller.fakeApi.reportRequests;
    final complaintsBefore = controller.fakeApi.complaintRequests;

    controller.realtime.addTestEvent({
      'type': 'REPORT_STATUS_CHANGED',
      'reportId': 42,
      'status': 'ON_THE_WAY',
    });
    await tester.pump(const Duration(milliseconds: 360));
    await tester.pump();

    expect(controller.fakeApi.reportRequests, reportsBefore + 1);
    expect(controller.fakeApi.complaintRequests, complaintsBefore);
    expect(find.byType(AppLoadingView), findsNothing);
  });

  testWidgets('Citizen home fills the available scaffold body', (tester) async {
    tester.view.physicalSize = const Size(1920, 932);
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

    final scaffoldBody = tester.getSize(
      find.descendant(
        of: find.byType(Scaffold).first,
        matching: find.byType(AppLazyIndexedStack),
      ),
    );
    final homeSize = tester.getSize(find.byType(CitizenHomeView));

    expect(homeSize, scaffoldBody);
    expect(homeSize.height, greaterThan(800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).destinations,
      hasLength(5),
    );
    expect(find.byType(BottomAppBar), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(
      find.byKey(const ValueKey('citizen-report-rail-action')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.map_outlined), findsNothing);
  });

  testWidgets('citizen composer draft survives an address refresh', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 980);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = FakeAppController.citizen(
      addresses: const [
        UserAddress(
          id: 3,
          receiverName: 'Nguyen An',
          phoneNumber: '0900000000',
          detailAddress: 'Phường Bến Nghé',
          addressNumber: '12 Lê Lợi',
          latitude: 10.7769,
          longitude: 106.7009,
          isDefault: true,
          provinceCode: '79',
          wardCode: '26740',
        ),
      ],
      categories: const [
        WasteCategory(
          id: 2,
          name: 'RECYCLABLE',
          description: 'Vật liệu tái chế',
          isActive: true,
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CitizenScreen(controller: controller),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final descriptionField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Mô tả ngắn tình trạng rác',
      description: 'report description field',
    );
    expect(descriptionField, findsOneWidget);
    await tester.enterText(descriptionField, 'Bản nháp chai nhựa đã buộc gọn');

    await tester.tap(find.byIcon(Icons.location_on_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final addressView = tester.widget<AddressManagementView>(
      find.byType(AddressManagementView),
    );
    addressView.onChanged?.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();

    final restoredField = tester.widget<TextField>(
      find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Mô tả ngắn tình trạng rác',
        description: 'restored report description field',
      ),
    );
    expect(restoredField.controller?.text, 'Bản nháp chai nhựa đã buộc gọn');
  });

  testWidgets('collection journey belongs to its report card', (tester) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = FakeAppController.citizen(
      reports: const [
        WasteReport(
          id: 42,
          imageUrl: '',
          description: 'Túi nhựa tái chế',
          status: 'ASSIGNED',
          citizenId: 7,
          citizenName: 'Nguyen An',
          citizenEmail: 'citizen@example.test',
          addressId: 3,
          addressDetail: 'Phường Bến Nghé',
          addressNumber: '12 Lê Lợi',
          latitude: 10.7769,
          longitude: 106.7009,
          provinceCode: '79',
          wardCode: '26740',
          receiverName: 'Nguyen An',
          phoneNumber: '0900000000',
          categoryId: 2,
          categoryName: 'RECYCLABLE',
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CitizenScreen(controller: controller),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Xem hành trình'), findsNothing);
    expect(find.byKey(const ValueKey('citizen-report-map-42')), findsNothing);
    expect(find.text('Yêu cầu của tôi'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Xem hành trình'), findsOneWidget);
    expect(find.text('Đã gửi'), findsNothing);
    expect(find.byKey(const ValueKey('citizen-report-map-42')), findsNothing);

    await tester.tap(find.text('Xem hành trình'));
    await tester.pump();

    expect(find.text('Thu gọn hành trình'), findsOneWidget);
    expect(find.text('Đã gửi'), findsOneWidget);
    expect(find.byKey(const ValueKey('citizen-report-map-42')), findsOneWidget);
  });

  testWidgets('Citizen ranking tab presents a true top-three leaderboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = FakeAppController.citizen(
      user: const User(
        id: 7,
        email: 'citizen@example.test',
        fullName: 'Nguyen An',
        role: 'CITIZEN',
        points: 860,
      ),
      addresses: const [
        UserAddress(
          id: 3,
          receiverName: 'Nguyen An',
          phoneNumber: '0900000000',
          detailAddress: 'Ben Nghe',
          addressNumber: '12 Le Loi',
          latitude: 10.7769,
          longitude: 106.7009,
          isDefault: true,
          provinceCode: '79',
          wardCode: '26740',
        ),
      ],
      locations: const [
        Province(
          code: '79',
          name: 'Ho Chi Minh',
          nameEn: 'Ho Chi Minh',
          fullName: 'Thanh pho Ho Chi Minh',
          fullNameEn: 'Ho Chi Minh City',
          wards: [
            Ward(
              code: '26740',
              name: 'Ben Nghe',
              nameEn: 'Ben Nghe',
              fullName: 'Phuong Ben Nghe',
              fullNameEn: 'Ben Nghe Ward',
            ),
          ],
        ),
      ],
      pointHistory: const [
        PointHistory(
          id: 1,
          points: 80,
          reportId: 42,
          categoryName: 'RECYCLABLE',
          weight: 4.5,
          isCorrectlyClassified: true,
        ),
      ],
      // Deliberately unsorted: the view must rank by `rank`, not API order.
      ranking: const [
        RankingUser(
          userId: 7,
          userName: 'Nguyen An',
          totalPoints: 860,
          totalReports: 18,
          rank: 4,
          provinceCode: '79',
          wardCode: '26740',
        ),
        RankingUser(
          userId: 12,
          userName: 'Bao Tran',
          totalPoints: 1040,
          totalReports: 23,
          rank: 2,
          provinceCode: '79',
          wardCode: '26740',
        ),
        RankingUser(
          userId: 15,
          userName: 'Thu Ha',
          totalPoints: 790,
          totalReports: 16,
          rank: 5,
          provinceCode: '79',
          wardCode: '26740',
        ),
        RankingUser(
          userId: 11,
          userName: 'Mai Linh',
          totalPoints: 1120,
          totalReports: 25,
          rank: 1,
          provinceCode: '79',
          wardCode: '26740',
        ),
        RankingUser(
          userId: 13,
          userName: 'Quoc Huy',
          totalPoints: 930,
          totalReports: 20,
          rank: 3,
          provinceCode: '79',
          wardCode: '26740',
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CitizenScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    final rankingNavIcon = find.descendant(
      of: find.byType(BottomAppBar),
      matching: find.byIcon(Icons.leaderboard_outlined),
    );
    expect(
      find.descendant(
        of: find.byType(BottomAppBar),
        matching: find.text('Xếp hạng'),
      ),
      findsOneWidget,
    );
    expect(rankingNavIcon, findsOneWidget);

    await tester.tap(rankingNavIcon);
    await tester.pumpAndSettle();

    expect(find.byType(RankingView), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomAppBar),
        matching: find.byIcon(Icons.leaderboard_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('current-user-rank-card')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('current-user-rank-card')),
        matching: find.text('#4'),
      ),
      findsOneWidget,
    );

    final podium = find.byKey(const ValueKey('ranking-podium'));
    expect(podium, findsOneWidget);
    for (final name in ['Mai Linh', 'Bao Tran', 'Quoc Huy']) {
      expect(
        find.descendant(of: podium, matching: find.text(name)),
        findsOneWidget,
      );
    }

    // Podium members must not be repeated as ordinary leaderboard rows.
    for (final userId in [11, 12, 13]) {
      expect(find.byKey(ValueKey('ranking-user-$userId')), findsNothing);
    }
    expect(find.byKey(const ValueKey('ranking-user-7')), findsOneWidget);
    expect(find.byKey(const ValueKey('ranking-user-15')), findsOneWidget);
    expect(controller.fakeApi.pointHistoryRequests, 1);
    expect(controller.fakeApi.rankingRequests, 1);
  });

  testWidgets('ranking scope picker applies one coherent area request', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = FakeAppController.citizen(
      addresses: const [_rankingAddress],
      locations: _rankingLocations,
      ranking: _compactRanking,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CitizenScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await _openRanking(tester);

    expect(controller.fakeApi.rankingCalls, [
      (areaType: 'province', areaCode: '79'),
    ]);

    await tester.tap(find.byKey(const ValueKey('ranking-area-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn sân chơi của bạn'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ranking-scope-ward')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ranking-apply-area')));
    await tester.pumpAndSettle();

    expect(controller.fakeApi.rankingRequests, 2);
    expect(controller.fakeApi.rankingCalls.last, (
      areaType: 'ward',
      areaCode: '26740',
    ));
  });

  testWidgets('returning to ranking refreshes profile and leaderboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = FakeAppController.citizen(
      addresses: const [_rankingAddress],
      locations: _rankingLocations,
      ranking: _compactRanking,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CitizenScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await _openRanking(tester);
    expect(controller.fakeApi.rankingRequests, 1);

    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    await _openRanking(tester);

    expect(controller.profileRefreshes, 1);
    expect(controller.fakeApi.rankingRequests, 2);
  });

  testWidgets('newer ranking scope ignores a late stale response', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final delayedWard = Completer<List<RankingUser>>();
    final controller = FakeAppController.citizen(
      addresses: const [_rankingAddress],
      locations: _rankingLocations,
      rankingLoader: (areaType, areaCode) {
        if (areaType == 'ward') return delayedWard.future;
        return Future.value(_compactRanking);
      },
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CitizenScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await _openRanking(tester);

    await tester.tap(find.byKey(const ValueKey('ranking-area-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ranking-scope-ward')));
    await tester.tap(find.byKey(const ValueKey('ranking-apply-area')));
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(
      find.byKey(const ValueKey('ranking-area-filter')).hitTestable(),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(
      find.byKey(const ValueKey('ranking-scope-province')).hitTestable(),
    );
    await tester.tap(
      find.byKey(const ValueKey('ranking-apply-area')).hitTestable(),
    );
    await tester.pumpAndSettle();

    delayedWard.complete(const [
      RankingUser(
        userId: 99,
        userName: 'Stale User',
        totalPoints: 9999,
        totalReports: 99,
        rank: 1,
        provinceCode: '79',
        wardCode: '26740',
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Stale User'), findsNothing);
    expect(find.text('Mai Linh'), findsOneWidget);
    expect(controller.fakeApi.rankingRequests, 3);
  });

  testWidgets('empty ranking guides the citizen directly to report waste', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = FakeAppController.citizen(
      addresses: const [_rankingAddress],
      locations: _rankingLocations,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CitizenScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await _openRanking(tester);

    expect(
      find.byKey(const ValueKey('current-user-rank-card')),
      findsOneWidget,
    );
    expect(find.text('Bạn có thể là người mở bảng'), findsOneWidget);
    expect(find.text('Báo rác ngay'), findsOneWidget);

    await tester.ensureVisible(find.text('Báo rác ngay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Báo rác ngay'));
    await tester.pumpAndSettle();

    expect(find.byType(ReportWasteView), findsOneWidget);
  });

  testWidgets('ranking error retries inline without losing the page shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = FakeAppController.citizen(
      addresses: const [_rankingAddress],
      locations: _rankingLocations,
      ranking: _compactRanking,
      rankingError: StateError('ranking unavailable'),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CitizenScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await _openRanking(tester);

    expect(find.text('Bảng xếp hạng chưa cập nhật'), findsOneWidget);
    expect(find.text('Chưa mở được bảng xếp hạng'), findsNothing);

    controller.fakeApi.rankingError = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('ranking-podium')), findsOneWidget);
    expect(controller.fakeApi.rankingRequests, 2);
  });

  testWidgets('point history failure does not block the leaderboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = FakeAppController.citizen(
      addresses: const [_rankingAddress],
      locations: _rankingLocations,
      ranking: _compactRanking,
      pointHistoryError: StateError('history unavailable'),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CitizenScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await _openRanking(tester);

    expect(find.byKey(const ValueKey('ranking-podium')), findsOneWidget);
    expect(
      find.text('Lịch sử điểm chưa cập nhật. Kéo xuống để thử lại.'),
      findsOneWidget,
    );
    expect(find.text('Chưa mở được bảng xếp hạng'), findsNothing);
  });

  testWidgets('ranking uses the production desktop rail layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = FakeAppController.citizen(
      addresses: const [_rankingAddress],
      locations: _rankingLocations,
      ranking: _compactRanking,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: CitizenScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.leaderboard_outlined));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(BottomAppBar), findsNothing);
    expect(find.byKey(const ValueKey('ranking-podium')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ranking stays usable at 320px with 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = FakeAppController.citizen(
      addresses: const [_rankingAddress],
      locations: _rankingLocations,
      ranking: _compactRanking,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: CitizenScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await _openRanking(tester);

    expect(find.byKey(const ValueKey('ranking-podium')), findsOneWidget);
    expect(find.text('Mai Linh'), findsOneWidget);
    expect(find.text('Nguyen An · Bạn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _openRanking(WidgetTester tester) async {
  final icon = find.descendant(
    of: find.byType(BottomAppBar),
    matching: find.byIcon(Icons.leaderboard_outlined),
  );
  await tester.tap(icon);
  await tester.pumpAndSettle();
}
