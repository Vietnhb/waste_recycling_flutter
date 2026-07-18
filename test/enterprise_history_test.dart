import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_recycling_flutter/src/features/enterprise/domain/enterprise_history.dart';
import 'package:waste_recycling_flutter/src/features/enterprise/presentation/enterprise_history_view.dart';
import 'package:waste_recycling_flutter/src/models/models.dart';
import 'package:waste_recycling_flutter/src/ui/shared/widgets.dart';

import 'support/fake_app_controller.dart';

void main() {
  test('WasteReport parses the completion timestamp used by audit history', () {
    final report = WasteReport.fromJson({
      'id': 9,
      'status': 'COLLECTED',
      'collectedAt': '2026-07-17T14:30:00',
    });

    expect(report.collectedAt, DateTime(2026, 7, 17, 14, 30));
  });

  test(
    'history keeps collected records newest first and summarizes evidence',
    () {
      final older = _report(
        id: 1,
        collectedAt: DateTime(2026, 7, 16, 8),
        weight: 4.5,
        correctlyClassified: false,
      );
      final newer = _report(
        id: 2,
        collectedAt: DateTime(2026, 7, 17, 9),
        weight: 8,
        correctlyClassified: true,
      );
      final active = _report(
        id: 3,
        status: 'IN_PROGRESS',
        collectedAt: DateTime(2026, 7, 18, 10),
      );

      final history = sortEnterpriseHistory([older, active, newer]);

      expect(history.map((report) => report.id), [2, 1]);
      expect(enterpriseHistoryWeight(history), 12.5);
      expect(enterpriseHistoryClassificationRate(history), 50);
    },
  );

  testWidgets('enterprise history renders operational audit evidence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = FakeAppController.enterprise(
      enterpriseHistory: [
        _report(
          id: 72,
          collectedAt: DateTime(2026, 7, 17, 14, 30),
          weight: 12.5,
          correctlyClassified: true,
        ),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: EnterpriseHistoryView(controller: controller)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('Hồ sơ thu gom đã hoàn tất'), findsOneWidget);
    expect(find.text('Hồ sơ #72'), findsOneWidget);
    expect(find.text('Collector Linh'), findsOneWidget);
    expect(find.text('Citizen An'), findsOneWidget);
    expect(find.text('12,5 kg'), findsWidgets);
    expect(find.text('Đúng loại'), findsOneWidget);
    expect(controller.fakeApi.enterpriseHistoryRequests, 1);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1200, 900);
    await tester.pump();
    expect(find.text('Hồ sơ #72'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

WasteReport _report({
  required int id,
  String status = 'COLLECTED',
  DateTime? collectedAt,
  double? weight,
  bool? correctlyClassified,
}) {
  return WasteReport(
    id: id,
    imageUrl: '',
    description: 'Bao bì đã phân loại',
    status: status,
    createdAt: DateTime(2026, 7, 15),
    updatedAt: collectedAt,
    collectedAt: collectedAt,
    citizenId: 7,
    citizenName: 'Citizen An',
    citizenEmail: 'citizen@example.test',
    addressId: 1,
    addressDetail: 'Lê Lợi',
    addressNumber: '12',
    latitude: 10.77,
    longitude: 106.7,
    provinceCode: '79',
    wardCode: '26740',
    receiverName: 'Citizen An',
    phoneNumber: '0900000000',
    categoryId: 1,
    categoryName: 'RECYCLABLE',
    weight: weight,
    isCorrectlyClassified: correctlyClassified,
    collectedImageUrl: '',
    enterpriseId: 1,
    collectorId: 11,
    collectorName: 'Collector Linh',
  );
}
