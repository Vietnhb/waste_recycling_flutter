import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_recycling_flutter/src/controllers/app_controller.dart';
import 'package:waste_recycling_flutter/src/core/api_client.dart';
import 'package:waste_recycling_flutter/src/core/api_exception.dart';
import 'package:waste_recycling_flutter/src/core/json_helpers.dart';
import 'package:waste_recycling_flutter/src/models/models.dart';
import 'package:waste_recycling_flutter/src/services/api_service.dart';
import 'package:waste_recycling_flutter/src/ui/collector/collector_screens.dart';
import 'package:waste_recycling_flutter/src/ui/enterprise/enterprise_screens.dart';
import 'package:waste_recycling_flutter/src/ui/shared/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('collector report workflow', () {
    test('only exposes the legal next state', () {
      expect(collectorNextReportStatus('ASSIGNED'), 'ON_THE_WAY');
      expect(collectorNextReportStatus('ON_THE_WAY'), 'IN_PROGRESS');
      expect(collectorNextReportStatus('IN_PROGRESS'), 'COLLECTED');
      expect(collectorNextReportStatus('COLLECTED'), isNull);
      expect(collectorNextReportStatus('PENDING'), isNull);
    });

    test('queued reports wait while exactly one field trip is running', () {
      final queued = _report(id: 41, status: 'ASSIGNED');
      final anotherQueued = _report(id: 42, status: 'ASSIGNED');
      final running = _report(id: 43, status: 'IN_PROGRESS');

      expect(
        collectorCanAdvanceReport(queued, [queued, anotherQueued]),
        isTrue,
      );
      expect(
        collectorCanAdvanceReport(queued, [queued, anotherQueued, running]),
        isFalse,
      );
      expect(
        collectorCanAdvanceReport(running, [queued, anotherQueued, running]),
        isTrue,
      );
    });

    testWidgets('ASSIGNED starts once and cannot jump to COLLECTED', (
      tester,
    ) async {
      await _configurePhoneViewport(tester);
      final api = _WorkflowApi(collectorReports: [_report(status: 'ASSIGNED')])
        ..updateGate = Completer<void>();
      final controller = _WorkflowController(api);
      addTearDown(controller.dispose);

      await _pumpWorkflow(tester, CollectorReportsView(controller: controller));

      final action = find.byKey(const ValueKey('collector-report-action-42'));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pump();

      expect(find.text('Đi tới điểm #42'), findsOneWidget);
      expect(find.text('Bằng chứng chuyến #42'), findsNothing);
      expect(find.text('Đi tới điểm thu gom'), findsWidgets);

      final submit = find.byKey(const ValueKey('collector-status-submit-42'));
      await tester.tap(submit);
      await tester.tap(submit);
      await tester.pump();

      expect(api.updateCalls, 1);
      expect(api.lastCollectionUpdate?['status'], 'ON_THE_WAY');
      expect(find.text('Đang cập nhật…'), findsOneWidget);
      final disabledSubmit = tester.widget<FilledButton>(submit);
      expect(disabledSubmit.onPressed, isNull);

      api.updateGate!.complete();
      await tester.pump(const Duration(milliseconds: 350));
      expect(api.updateCalls, 1);
    });

    testWidgets('local websocket echo does not duplicate the mutation reload', (
      tester,
    ) async {
      await _configurePhoneViewport(tester);
      final api = _WorkflowApi(collectorReports: [_report(status: 'ASSIGNED')])
        ..updateGate = Completer<void>();
      final controller = _WorkflowController(api);
      addTearDown(controller.dispose);

      await _pumpWorkflow(tester, CollectorReportsView(controller: controller));
      expect(api.collectorProfileRequests, 1);
      expect(api.assignedReportRequests, 1);

      final action = find.byKey(const ValueKey('collector-report-action-42'));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('collector-status-submit-42')),
      );
      await tester.pump();

      controller.realtime.addTestEvent({
        'type': 'REPORT_STATUS_CHANGED',
        'reportId': 42,
        'status': 'ON_THE_WAY',
      });
      await tester.pump(const Duration(milliseconds: 400));
      expect(api.assignedReportRequests, 1);

      api.updateGate!.complete();
      await tester.pumpAndSettle();
      expect(api.collectorProfileRequests, 2);
      expect(api.assignedReportRequests, 2);

      // A late duplicate of the same server echo is still consumed.
      controller.realtime.addTestEvent({
        'type': 'REPORT_STATUS_CHANGED',
        'reportId': 42,
        'status': 'ON_THE_WAY',
      });
      await tester.pump(const Duration(milliseconds: 400));
      expect(api.assignedReportRequests, 2);

      // A different report is not hidden by the local-mutation guard.
      controller.realtime.addTestEvent({
        'type': 'REPORT_STATUS_CHANGED',
        'reportId': 99,
        'status': 'ON_THE_WAY',
      });
      await tester.pump(const Duration(milliseconds: 400));
      expect(api.collectorProfileRequests, 3);
      expect(api.assignedReportRequests, 3);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('ON_THE_WAY must start collection before completion', (
      tester,
    ) async {
      await _configurePhoneViewport(tester);
      final api = _WorkflowApi(
        collectorReports: [_report(status: 'ON_THE_WAY')],
      );
      final controller = _WorkflowController(api);
      addTearDown(controller.dispose);

      await _pumpWorkflow(tester, CollectorReportsView(controller: controller));

      final action = find.byKey(const ValueKey('collector-report-action-42'));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(find.text('Bắt đầu thu gom #42'), findsOneWidget);
      expect(find.text('Đã đến · Bắt đầu thu gom'), findsWidgets);
      expect(
        find.byKey(const ValueKey('collector-completion-weight-42')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey('collector-status-submit-42')),
      );
      await tester.pumpAndSettle();

      expect(api.updateCalls, 1);
      expect(api.lastCollectionUpdate, {'status': 'IN_PROGRESS'});
    });

    testWidgets('IN_PROGRESS completion requires field evidence', (
      tester,
    ) async {
      await _configurePhoneViewport(tester);
      final api = _WorkflowApi(
        collectorReports: [
          _report(status: 'IN_PROGRESS', estimatedWeight: 7.5, weight: 99),
        ],
      );
      final controller = _WorkflowController(api);
      addTearDown(controller.dispose);

      await _pumpWorkflow(tester, CollectorReportsView(controller: controller));

      final action = find.byKey(const ValueKey('collector-report-action-42'));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận hoàn tất chuyến #42'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('collector-completion-weight-42')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('collector-completion-photo-42')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('collector-completion-weight-42')),
            )
            .controller
            ?.text,
        isEmpty,
      );
      expect(find.textContaining('Người dân ước tính 7.5 kg'), findsOneWidget);
      expect(
        tester
            .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
            .selected,
        isEmpty,
      );

      await tester.tap(
        find.byKey(const ValueKey('collector-completion-photo-42')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chụp ảnh tại điểm thu gom'), findsOneWidget);
      expect(find.text('Chọn ảnh từ thư viện'), findsOneWidget);
      Navigator.of(tester.element(find.text('Chọn ảnh từ thư viện'))).pop();
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('collector-status-submit-42')),
      );
      await tester.pump();

      expect(api.updateCalls, 0);
      expect(find.textContaining('Cần ảnh hiện trường'), findsOneWidget);
    });

    testWidgets('active work locks manual shift controls', (tester) async {
      await _configurePhoneViewport(tester);
      final api = _WorkflowApi(
        collectorReports: [_report(status: 'IN_PROGRESS')],
      );
      final controller = _WorkflowController(api);
      addTearDown(controller.dispose);

      await _pumpWorkflow(tester, CollectorReportsView(controller: controller));

      expect(find.text('Kết ca'), findsNothing);
      expect(find.textContaining('Trạng thái được đồng bộ'), findsOneWidget);
      expect(find.text('Đang thu gom'), findsWidgets);
    });

    testWidgets('collector queue supports 320px and 200% text', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _WorkflowApi(
        collectorReports: [_report(status: 'IN_PROGRESS')],
      );
      final controller = _WorkflowController(api);
      addTearDown(controller.dispose);

      await _pumpWorkflow(
        tester,
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: CollectorReportsView(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Việc cần làm hôm nay'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('enterprise release workflow', () {
    test('waiting and tracking timestamps describe the correct context', () {
      final now = DateTime(2026, 7, 18, 12);
      final value = now.subtract(const Duration(minutes: 12));

      expect(enterpriseElapsedLabel(value, now: now), 'Đã chờ 12 phút');
      expect(
        enterpriseElapsedLabel(value, now: now, waiting: false),
        'Cập nhật 12 phút trước',
      );
    });

    testWidgets('reassigns a queued trip only to a different collector', (
      tester,
    ) async {
      await _configurePhoneViewport(tester);
      final api = _WorkflowApi(
        acceptedReports: [
          _report(
            status: 'ASSIGNED',
            collectorId: 11,
            collectorName: 'Trần Minh',
          ),
        ],
        collectors: const [
          Collector(
            id: 11,
            userId: 8,
            userName: 'Trần Minh',
            userEmail: 'minh@example.test',
            enterpriseId: 1,
            enterpriseName: 'Green Operations',
            currentStatus: 'BUSY',
          ),
          Collector(
            id: 12,
            userId: 9,
            userName: 'Lê An',
            userEmail: 'an@example.test',
            enterpriseId: 1,
            enterpriseName: 'Green Operations',
            currentStatus: 'AVAILABLE',
          ),
        ],
      );
      final controller = _WorkflowController(api);
      addTearDown(controller.dispose);

      await _pumpWorkflow(tester, AcceptedReportsView(controller: controller));

      expect(find.text('Điều phối lại chuyến'), findsOneWidget);
      expect(find.byKey(const ValueKey('release-report-42')), findsNothing);

      final collectorPicker = find.byType(DropdownButtonFormField<int>);
      await tester.ensureVisible(collectorPicker);
      await tester.pumpAndSettle();
      await tester.tap(collectorPicker);
      await tester.pumpAndSettle();
      expect(find.textContaining('Trần Minh ·'), findsNothing);
      await tester.tap(find.textContaining('Lê An ·').last);
      await tester.pumpAndSettle();

      final assign = find.byKey(const ValueKey('assign-report-42'));
      await tester.ensureVisible(assign);
      await tester.tap(assign);
      await tester.pumpAndSettle();

      expect(api.assignCalls, 1);
      expect(api.lastAssignedReportId, 42);
      expect(api.lastAssignedCollectorId, 12);
    });

    testWidgets('only releases an accepted, unassigned report once', (
      tester,
    ) async {
      await _configurePhoneViewport(tester);
      final api = _WorkflowApi(acceptedReports: [_report(status: 'ACCEPTED')]);
      final controller = _WorkflowController(api);
      addTearDown(controller.dispose);

      await _pumpWorkflow(tester, AcceptedReportsView(controller: controller));

      final release = find.byKey(const ValueKey('release-report-42'));
      await _scrollOperationalTargetIntoView(
        tester,
        scrollKey: 'enterprise-accepted-reports-scroll',
        target: release,
      );
      await tester.tap(release);
      await tester.pumpAndSettle();

      expect(find.text('Trả yêu cầu #42 về hàng chờ?'), findsOneWidget);
      expect(find.textContaining('doanh nghiệp khác'), findsOneWidget);

      await tester.tap(find.text('Giữ chuyến'));
      await tester.pumpAndSettle();
      expect(api.rejectCalls, 0);

      api.rejectGate = Completer<void>();
      await tester.tap(release);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-release-report-42')));
      await tester.pump(const Duration(milliseconds: 350));

      expect(api.rejectCalls, 1);
      expect(find.text('Đang trả lại…'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(release).onPressed, isNull);

      api.rejectGate!.complete();
      await tester.pump(const Duration(milliseconds: 350));
      expect(api.rejectCalls, 1);
      expect(find.byKey(const ValueKey('release-report-42')), findsNothing);
      expect(find.text('Đã trả yêu cầu #42 về hàng chờ chung'), findsOneWidget);
    });

    testWidgets(
      'pending marketplace does not expose an invalid reject action',
      (tester) async {
        await _configurePhoneViewport(tester);
        final api = _WorkflowApi(pendingReports: [_report(status: 'PENDING')]);
        final controller = _WorkflowController(api);
        addTearDown(controller.dispose);

        await _pumpWorkflow(tester, PendingReportsView(controller: controller));

        expect(find.byKey(const ValueKey('reject-report-42')), findsNothing);
        expect(find.byKey(const ValueKey('accept-report-42')), findsOneWidget);
        expect(find.text('Khu vực chưa cập nhật'), findsOneWidget);
        expect(
          find.textContaining(
            'Người gửi, số điện thoại và vị trí chính xác chỉ mở',
          ),
          findsOneWidget,
        );
        expect(find.text('Chưa có địa chỉ'), findsNothing);
      },
    );
  });

  group('large operational queues', () {
    testWidgets('build the final card only after the user scrolls to it', (
      tester,
    ) async {
      await _configurePhoneViewport(tester);
      final now = DateTime.now();
      final todayAtNoon = DateTime(now.year, now.month, now.day, 12);
      final api = _WorkflowApi(
        collectorReports: List.generate(
          36,
          (index) => _report(id: 1000 + index, status: 'ASSIGNED'),
        ),
        workHistory: List.generate(
          36,
          (index) => WorkHistory(
            reportId: 2000 + index,
            categoryName: 'RECYCLABLE',
            provinceCode: '79',
            wardCode: '26740',
            addressDetail: 'Điểm thu gom ${index + 1}',
            weight: 2.5,
            isCorrectlyClassified: true,
            collectedAt: todayAtNoon.subtract(Duration(minutes: index)),
            citizenName: 'Người gửi ${index + 1}',
            collectedImageUrl: '',
          ),
        ),
        pendingReports: List.generate(
          36,
          (index) => _report(id: 3000 + index, status: 'PENDING'),
        ),
        acceptedReports: List.generate(
          36,
          (index) => _report(id: 4000 + index, status: 'ACCEPTED'),
        ),
      );
      final controller = _WorkflowController(api);
      addTearDown(controller.dispose);

      await _pumpWorkflow(tester, CollectorReportsView(controller: controller));
      await _expectLazyItemAfterScroll(
        tester,
        scrollKey: 'collector-active-reports-scroll',
        itemKey: 1035,
      );

      await _pumpWorkflow(tester, CollectorHistoryView(controller: controller));
      await _expectLazyItemAfterScroll(
        tester,
        scrollKey: 'collector-history-scroll',
        itemKey: 2035,
      );

      await _pumpWorkflow(tester, PendingReportsView(controller: controller));
      await _expectLazyItemAfterScroll(
        tester,
        scrollKey: 'enterprise-pending-reports-scroll',
        itemKey: 3035,
      );

      await _pumpWorkflow(tester, AcceptedReportsView(controller: controller));
      await _expectLazyItemAfterScroll(
        tester,
        scrollKey: 'enterprise-accepted-reports-scroll',
        itemKey: 4035,
      );
    });
  });

  group('enterprise profile contract', () {
    testWidgets('new enterprise is guided to required profile onboarding', (
      tester,
    ) async {
      await _configurePhoneViewport(tester);
      final api = _WorkflowApi(
        enterpriseProfileError: ApiException('Enterprise not found', 404),
      );
      final controller = _WorkflowController(api);
      addTearDown(controller.dispose);
      int? destination;

      await _pumpWorkflow(
        tester,
        EnterpriseHomeView(
          controller: controller,
          onOpenDestination: (value) => destination = value,
        ),
      );

      expect(find.text('Hoàn thiện hồ sơ'), findsOneWidget);
      await tester.tap(find.text('Hoàn thiện hồ sơ'));
      expect(destination, 6);
      expect(find.text('Chưa kết nối được bàn điều hành'), findsNothing);
    });

    testWidgets('migrates display names and persists province code CSV', (
      tester,
    ) async {
      await _configurePhoneViewport(tester);
      final api = _WorkflowApi(
        enterpriseProfile: const Enterprise(
          id: 1,
          userId: 9,
          companyName: 'Green Operations',
          acceptedWasteTypes: 'RECYCLABLE,ORGANIC',
          capacity: 1200,
          serviceArea: 'Thành phố Hồ Chí Minh',
          rating: 4.8,
        ),
        locations: const [
          Province(
            code: '01',
            name: 'Hà Nội',
            nameEn: 'Ha Noi',
            fullName: 'Thành phố Hà Nội',
            fullNameEn: 'Ha Noi City',
            wards: [],
          ),
          Province(
            code: '79',
            name: 'Hồ Chí Minh',
            nameEn: 'Ho Chi Minh',
            fullName: 'Thành phố Hồ Chí Minh',
            fullNameEn: 'Ho Chi Minh City',
            wards: [],
          ),
        ],
      );
      final controller = _WorkflowController(api);
      addTearDown(controller.dispose);

      await _pumpWorkflow(
        tester,
        EnterpriseProfileView(controller: controller),
      );

      expect(find.text('Thành phố Hồ Chí Minh'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('enterprise-service-area')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('enterprise-province-01')));
      await tester.pump();
      await tester.tap(find.text('Áp dụng'));
      await tester.pumpAndSettle();

      final save = find.byKey(const ValueKey('enterprise-profile-save'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pump(const Duration(milliseconds: 200));

      expect(api.lastEnterpriseUpdate?['serviceArea'], 'P:01,P:79');
    });
  });
}

Future<void> _configurePhoneViewport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpWorkflow(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _expectLazyItemAfterScroll(
  WidgetTester tester, {
  required String scrollKey,
  required Object itemKey,
}) async {
  final target = find.byKey(ValueKey(itemKey));
  expect(target, findsNothing);

  await _scrollOperationalTargetIntoView(
    tester,
    scrollKey: scrollKey,
    target: target,
  );
  expect(target, findsOneWidget);
}

Future<void> _scrollOperationalTargetIntoView(
  WidgetTester tester, {
  required String scrollKey,
  required Finder target,
}) async {
  final scrollView = find.byKey(PageStorageKey<String>(scrollKey));
  expect(scrollView, findsOneWidget);
  final scrollable = find
      .descendant(of: scrollView, matching: find.byType(Scrollable))
      .first;
  expect(scrollable, findsOneWidget);

  await tester.scrollUntilVisible(
    target,
    850,
    scrollable: scrollable,
    maxScrolls: 80,
  );
  await tester.pumpAndSettle();
}

WasteReport _report({
  int id = 42,
  required String status,
  double? estimatedWeight,
  double? weight,
  int? collectorId,
  String? collectorName,
}) {
  return WasteReport(
    id: id,
    imageUrl: '',
    description: 'Hai túi chai nhựa đã buộc gọn',
    status: status,
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
    estimatedWeight: estimatedWeight,
    weight: weight,
    collectorId: collectorId,
    collectorName: collectorName,
  );
}

class _WorkflowController extends AppController {
  _WorkflowController(this.workflowApi) {
    booting = false;
    token = 'workflow-test-token';
  }

  final _WorkflowApi workflowApi;

  @override
  ApiService get api => workflowApi;
}

class _WorkflowApi extends ApiService {
  _WorkflowApi({
    List<WasteReport> collectorReports = const [],
    List<WorkHistory> workHistory = const [],
    List<WasteReport> pendingReports = const [],
    List<WasteReport> acceptedReports = const [],
    this.collectors = const [],
    this.enterpriseProfile,
    this.enterpriseProfileError,
    this.locations = const [],
  }) : collectorReports = List.of(collectorReports),
       workHistory = List.of(workHistory),
       pendingReports = List.of(pendingReports),
       acceptedReports = List.of(acceptedReports),
       super(ApiClient(baseUrl: 'https://example.test/api'));

  List<WasteReport> collectorReports;
  List<WorkHistory> workHistory;
  List<WasteReport> pendingReports;
  List<WasteReport> acceptedReports;
  final List<Collector> collectors;
  Enterprise? enterpriseProfile;
  final Object? enterpriseProfileError;
  final List<Province> locations;
  Completer<void>? updateGate;
  Completer<void>? rejectGate;
  int updateCalls = 0;
  int collectorProfileRequests = 0;
  int assignedReportRequests = 0;
  int rejectCalls = 0;
  int assignCalls = 0;
  int? lastAssignedReportId;
  int? lastAssignedCollectorId;
  JsonMap? lastCollectionUpdate;
  JsonMap? lastEnterpriseUpdate;

  @override
  Future<List<Province>> getLocationData() async => locations;

  @override
  Future<List<WasteCategory>> getCategories() async => const [
    WasteCategory(
      id: 1,
      name: 'ORGANIC',
      description: 'Organic',
      isActive: true,
    ),
    WasteCategory(
      id: 2,
      name: 'RECYCLABLE',
      description: 'Recyclable',
      isActive: true,
    ),
    WasteCategory(
      id: 3,
      name: 'HAZARDOUS',
      description: 'Hazardous',
      isActive: true,
    ),
    WasteCategory(id: 4, name: 'OTHER', description: 'Other', isActive: true),
  ];

  @override
  Future<Enterprise> getEnterprise() async {
    final error = enterpriseProfileError;
    if (error != null) throw error;
    return enterpriseProfile!;
  }

  @override
  Future<Enterprise> updateEnterprise(JsonMap data) async {
    lastEnterpriseUpdate = Map<String, dynamic>.of(data);
    final current = enterpriseProfile!;
    final updated = Enterprise(
      id: current.id,
      userId: current.userId,
      companyName: data['companyName'] as String,
      acceptedWasteTypes: data['acceptedWasteTypes'] as String,
      capacity: data['capacity'] as double,
      serviceArea: data['serviceArea'] as String,
      rating: current.rating,
    );
    enterpriseProfile = updated;
    return updated;
  }

  @override
  Future<Collector> getCollectorProfile() async {
    collectorProfileRequests++;
    return const Collector(
      id: 11,
      userId: 8,
      userName: 'Tran Minh',
      userEmail: 'collector@example.test',
      enterpriseId: 1,
      enterpriseName: 'Green Operations',
      currentStatus: 'AVAILABLE',
    );
  }

  @override
  Future<List<WasteReport>> getAssignedReports() async {
    assignedReportRequests++;
    return collectorReports;
  }

  @override
  Future<List<WorkHistory>> getWorkHistory() async => workHistory;

  @override
  Future<WasteReport> updateCollectionStatus(int reportId, JsonMap data) async {
    updateCalls++;
    lastCollectionUpdate = Map<String, dynamic>.of(data);
    final gate = updateGate;
    if (gate != null) await gate.future;
    final updated = _report(status: data['status'] as String);
    collectorReports = [updated];
    return updated;
  }

  @override
  Future<List<WasteReport>> getPendingReports() async => pendingReports;

  @override
  Future<List<WasteReport>> getAcceptedReports() async => acceptedReports;

  @override
  Future<List<Collector>> getCollectors() async => collectors;

  @override
  Future<WasteReport> assignCollector(int reportId, int collectorId) async {
    assignCalls++;
    lastAssignedReportId = reportId;
    lastAssignedCollectorId = collectorId;
    final collector = collectors.singleWhere((item) => item.id == collectorId);
    final updated = _report(
      id: reportId,
      status: 'ASSIGNED',
      collectorId: collector.id,
      collectorName: collector.userName,
    );
    acceptedReports = acceptedReports
        .map((report) => report.id == reportId ? updated : report)
        .toList();
    return updated;
  }

  @override
  Future<List<PointRule>> getPointRules() async => const [];

  @override
  Future<void> rejectReport(int reportId) async {
    rejectCalls++;
    final gate = rejectGate;
    if (gate != null) await gate.future;
    pendingReports = pendingReports
        .where((report) => report.id != reportId)
        .toList();
    acceptedReports = acceptedReports
        .where((report) => report.id != reportId)
        .toList();
  }
}
