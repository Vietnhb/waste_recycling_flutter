import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waste_recycling_flutter/src/controllers/app_controller.dart';
import 'package:waste_recycling_flutter/src/core/api_client.dart';
import 'package:waste_recycling_flutter/src/models/models.dart';
import 'package:waste_recycling_flutter/src/services/api_service.dart';
import 'package:waste_recycling_flutter/src/ui/admin/admin_screens.dart';
import 'package:waste_recycling_flutter/src/ui/citizen/citizen_screens.dart';
import 'package:waste_recycling_flutter/src/ui/collector/collector_screens.dart';
import 'package:waste_recycling_flutter/src/ui/shared/widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('citizen complaint echo causes exactly one mutation reload', (
    tester,
  ) async {
    await _configurePhone(tester);
    final api = _ComplaintEchoApi(reports: [_collectedReport()])
      ..createGate = Completer<void>();
    final controller = _ComplaintEchoController(api);
    addTearDown(controller.dispose);

    await _pump(tester, MyReportsView(controller: controller));
    expect(api.myComplaintRequests, 1);

    final open = find.byKey(const ValueKey('citizen-open-complaint-42'));
    await tester.ensureVisible(open);
    await tester.pumpAndSettle();
    await tester.tap(open);
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('citizen-complaint-input')),
      'Chuyến thu gom còn để sót rác trước cửa nhà.',
    );
    final submit = find.byKey(const ValueKey('citizen-complaint-submit'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump();
    expect(api.createCalls, 1);

    controller.realtime.addTestEvent({
      'type': 'COMPLAINT_CREATED',
      'reportId': 42,
      'status': 'PENDING',
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.myComplaintRequests, 1);

    api.createGate!.complete();
    await tester.pumpAndSettle();
    expect(api.myComplaintRequests, 2);

    controller.realtime.addTestEvent({
      'type': 'COMPLAINT_CREATED',
      'reportId': 42,
      'status': 'PENDING',
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.myComplaintRequests, 2);

    controller.realtime.addTestEvent({
      'type': 'COMPLAINT_CREATED',
      'reportId': 99,
      'status': 'PENDING',
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.myComplaintRequests, 3);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('admin resolution echo causes exactly one mutation reload', (
    tester,
  ) async {
    await _configurePhone(tester);
    final api = _ComplaintEchoApi(complaints: [_pendingComplaint()])
      ..resolveGate = Completer<void>();
    final controller = _ComplaintEchoController(api);
    addTearDown(controller.dispose);

    await _pump(tester, AdminComplaintsView(controller: controller));
    expect(api.allComplaintRequests, 1);

    final resolve = find.byKey(const ValueKey('admin-resolve-complaint-7'));
    await tester.ensureVisible(resolve);
    await tester.pumpAndSettle();
    await tester.tap(resolve);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'Đã kiểm tra hiện trường.',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Gửi'));
    await tester.pump();
    expect(api.resolveCalls, 1);

    controller.realtime.addTestEvent({
      'type': 'COMPLAINT_RESOLVED',
      'reportId': 42,
      'status': 'RESOLVED',
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.allComplaintRequests, 1);

    api.resolveGate!.complete();
    await tester.pumpAndSettle();
    expect(api.allComplaintRequests, 2);

    controller.realtime.addTestEvent({
      'type': 'COMPLAINT_RESOLVED',
      'reportId': 42,
      'status': 'RESOLVED',
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.allComplaintRequests, 2);

    controller.realtime.addTestEvent({
      'type': 'COMPLAINT_RESOLVED',
      'reportId': 99,
      'status': 'RESOLVED',
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.allComplaintRequests, 3);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('collector status echo does not reload the whole dashboard', (
    tester,
  ) async {
    await _configurePhone(tester);
    final api = _ComplaintEchoApi()..collectorStatusGate = Completer<void>();
    final controller = _ComplaintEchoController(api);
    addTearDown(controller.dispose);

    await _pump(
      tester,
      CollectorHomeView(
        controller: controller,
        onOpenTrips: () {},
        onOpenHistory: () {},
      ),
    );
    expect(api.collectorProfileRequests, 1);
    expect(api.assignedReportRequests, 1);

    final endShift = find.byKey(
      const ValueKey('collector-home-status-OFFLINE'),
    );
    await tester.ensureVisible(endShift);
    await tester.tap(endShift);
    await tester.pump();
    expect(api.collectorStatusCalls, 1);

    controller.realtime.addTestEvent({
      'type': 'COLLECTOR_STATUS_CHANGED',
      'reportId': null,
      'status': 'OFFLINE',
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.collectorProfileRequests, 1);

    api.collectorStatusGate!.complete();
    await tester.pumpAndSettle();
    expect(api.collectorProfileRequests, 1);
    expect(api.assignedReportRequests, 1);
    expect(api.workHistoryRequests, 1);
    expect(api.workStatisticsRequests, 1);

    controller.realtime.addTestEvent({
      'type': 'COLLECTOR_STATUS_CHANGED',
      'reportId': null,
      'status': 'OFFLINE',
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.collectorProfileRequests, 1);

    controller.realtime.addTestEvent({
      'type': 'COLLECTOR_STATUS_CHANGED',
      'reportId': null,
      'status': 'AVAILABLE',
    });
    await tester.pump(const Duration(milliseconds: 400));
    expect(api.collectorProfileRequests, 2);
    expect(api.assignedReportRequests, 2);
    expect(api.workHistoryRequests, 2);
    expect(api.workStatisticsRequests, 2);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

Future<void> _configurePhone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

class _ComplaintEchoController extends AppController {
  _ComplaintEchoController(this.echoApi) {
    booting = false;
    token = 'echo-test-token';
  }

  final _ComplaintEchoApi echoApi;

  @override
  ApiService get api => echoApi;
}

class _ComplaintEchoApi extends ApiService {
  _ComplaintEchoApi({
    List<WasteReport> reports = const [],
    List<Complaint> complaints = const [],
  }) : reports = List.of(reports),
       complaints = List.of(complaints),
       super(ApiClient(baseUrl: 'https://example.test/api'));

  final List<WasteReport> reports;
  List<Complaint> complaints;
  Completer<void>? createGate;
  Completer<void>? resolveGate;
  Completer<void>? collectorStatusGate;
  int reportRequests = 0;
  int myComplaintRequests = 0;
  int allComplaintRequests = 0;
  int createCalls = 0;
  int resolveCalls = 0;
  int collectorProfileRequests = 0;
  int assignedReportRequests = 0;
  int workHistoryRequests = 0;
  int workStatisticsRequests = 0;
  int collectorStatusCalls = 0;
  String collectorStatus = 'AVAILABLE';

  @override
  Future<List<WasteReport>> getMyReports() async {
    reportRequests++;
    return reports;
  }

  @override
  Future<List<Complaint>> getMyComplaints() async {
    myComplaintRequests++;
    return complaints;
  }

  @override
  Future<List<Complaint>> getAllComplaints() async {
    allComplaintRequests++;
    return complaints;
  }

  @override
  Future<Complaint> createComplaint(int reportId, String description) async {
    createCalls++;
    final gate = createGate;
    if (gate != null) await gate.future;
    final complaint = Complaint(
      id: 7,
      reportId: reportId,
      userId: 3,
      userName: 'Nguyễn An',
      description: description,
      status: 'PENDING',
    );
    complaints = [complaint];
    return complaint;
  }

  @override
  Future<Complaint> resolveComplaint(
    int id,
    String status,
    String adminNote,
  ) async {
    resolveCalls++;
    final gate = resolveGate;
    if (gate != null) await gate.future;
    final current = complaints.singleWhere((item) => item.id == id);
    final resolved = Complaint(
      id: current.id,
      reportId: current.reportId,
      userId: current.userId,
      userName: current.userName,
      description: current.description,
      status: status,
      adminNote: adminNote,
      adminId: 1,
      adminName: 'Quản trị viên',
      createdAt: current.createdAt,
      resolvedAt: DateTime(2026, 7, 18, 12),
    );
    complaints = [resolved];
    return resolved;
  }

  @override
  Future<Collector> getCollectorProfile() async {
    collectorProfileRequests++;
    return Collector(
      id: 11,
      userId: 8,
      userName: 'Trần Minh',
      userEmail: 'collector@example.test',
      enterpriseId: 1,
      enterpriseName: 'Green Operations',
      currentStatus: collectorStatus,
    );
  }

  @override
  Future<List<WasteReport>> getAssignedReports() async {
    assignedReportRequests++;
    return const [];
  }

  @override
  Future<List<WorkHistory>> getWorkHistory() async {
    workHistoryRequests++;
    return const [];
  }

  @override
  Future<WorkStatistics> getWorkStatistics() async {
    workStatisticsRequests++;
    return const WorkStatistics(
      totalCompletedReports: 0,
      totalWeight: 0,
      correctlyClassifiedCount: 0,
    );
  }

  @override
  Future<Collector> updateCollectorStatus(String status) async {
    collectorStatusCalls++;
    final gate = collectorStatusGate;
    if (gate != null) await gate.future;
    collectorStatus = status;
    return Collector(
      id: 11,
      userId: 8,
      userName: 'Trần Minh',
      userEmail: 'collector@example.test',
      enterpriseId: 1,
      enterpriseName: 'Green Operations',
      currentStatus: collectorStatus,
    );
  }
}

WasteReport _collectedReport() => const WasteReport(
  id: 42,
  imageUrl: '',
  description: 'Hai túi chai nhựa',
  status: 'COLLECTED',
  citizenId: 3,
  citizenName: 'Nguyễn An',
  citizenEmail: 'citizen@example.test',
  addressId: 5,
  addressDetail: 'Phường Bến Nghé',
  addressNumber: '12 Lê Lợi',
  latitude: 10.7769,
  longitude: 106.7009,
  provinceCode: '79',
  wardCode: '26740',
  receiverName: 'Nguyễn An',
  phoneNumber: '0900000000',
  categoryId: 2,
  categoryName: 'RECYCLABLE',
);

Complaint _pendingComplaint() => const Complaint(
  id: 7,
  reportId: 42,
  userId: 3,
  userName: 'Nguyễn An',
  description: 'Chuyến thu gom còn để sót rác trước cửa nhà.',
  status: 'PENDING',
);
