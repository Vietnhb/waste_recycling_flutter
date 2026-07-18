import 'package:flutter_test/flutter_test.dart';
import 'package:waste_recycling_flutter/src/models/models.dart';
import 'package:waste_recycling_flutter/src/ui/enterprise/enterprise_screens.dart';

void main() {
  test('capability score is treated as fit, never as urgency', () {
    expect(
      enterpriseCapabilityFitLabel(_report(id: 1, fit: 3)),
      'Khớp vật liệu và khu vực',
    );
    expect(
      enterpriseCapabilityFitLabel(_report(id: 2, fit: 2)),
      'Khớp vật liệu',
    );
    expect(
      enterpriseCapabilityFitLabel(_report(id: 3, fit: 1)),
      'Khớp khu vực',
    );
  });

  test('pending queue sorts by fit then oldest waiting report', () {
    final now = DateTime(2026, 7, 17, 10);
    final sorted = enterpriseSortPending([
      _report(id: 1, fit: 2, createdAt: now),
      _report(
        id: 2,
        fit: 3,
        createdAt: now.subtract(const Duration(minutes: 5)),
      ),
      _report(
        id: 3,
        fit: 3,
        createdAt: now.subtract(const Duration(minutes: 20)),
      ),
    ]);

    expect(sorted.map((report) => report.id), [3, 2, 1]);
  });

  test(
    'dispatch lifecycle includes active collection and excludes completed',
    () {
      final sorted = enterpriseSortDispatch([
        _report(id: 5, status: 'COLLECTED'),
        _report(id: 4, status: 'IN_PROGRESS'),
        _report(id: 3, status: 'ON_THE_WAY'),
        _report(id: 2, status: 'ASSIGNED'),
        _report(id: 1, status: 'ACCEPTED'),
      ]);

      expect(sorted.map((report) => report.id), [1, 2, 3, 4]);
      expect(
        enterpriseDispatchStage('in_progress'),
        EnterpriseDispatchStage.inProgress,
      );
    },
  );

  test('collector availability is normalized and active statuses are busy', () {
    expect(
      enterpriseCollectorIsAvailable(_collector(status: ' available ')),
      isTrue,
    );
    expect(enterpriseCollectorIsAvailable(_collector(status: 'BUSY')), isFalse);
    expect(
      enterpriseCollectorCanReceiveAssignment(_collector(status: 'BUSY')),
      isTrue,
    );
    expect(
      enterpriseCollectorCanReceiveAssignment(_collector(status: 'ON_THE_WAY')),
      isTrue,
    );
    expect(
      enterpriseCollectorCanReceiveAssignment(_collector(status: 'OFFLINE')),
      isFalse,
    );
    expect(enterpriseCollectorIsBusy(_collector(status: 'ON_THE_WAY')), isTrue);
    expect(enterpriseCollectorIsBusy(_collector(status: 'OFFLINE')), isFalse);
  });
}

WasteReport _report({
  required int id,
  String status = 'PENDING',
  int fit = 0,
  DateTime? createdAt,
}) {
  return WasteReport(
    id: id,
    imageUrl: '',
    description: '',
    status: status,
    createdAt: createdAt,
    citizenId: 1,
    citizenName: 'Citizen',
    citizenEmail: 'citizen@example.test',
    addressId: 1,
    addressDetail: 'Phường Bến Nghé',
    addressNumber: '12 Lê Lợi',
    latitude: 10.77,
    longitude: 106.7,
    provinceCode: '79',
    wardCode: '26740',
    receiverName: 'Citizen',
    phoneNumber: '0900000000',
    categoryId: 1,
    categoryName: 'RECYCLABLE',
    priorityScore: fit,
  );
}

Collector _collector({required String status}) => Collector(
  id: 1,
  userId: 1,
  userName: 'Collector',
  userEmail: 'collector@example.test',
  enterpriseId: 1,
  enterpriseName: 'Enterprise',
  currentStatus: status,
);
