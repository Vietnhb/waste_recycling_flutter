import 'package:flutter_test/flutter_test.dart';
import 'package:waste_recycling_flutter/src/features/operations/domain/operation_workflow.dart';

void main() {
  test('collector workflow only permits the next physical step', () {
    expect(
      ReportStage.assigned.canCollectorTransitionTo(ReportStage.onTheWay),
      isTrue,
    );
    expect(
      ReportStage.onTheWay.canCollectorTransitionTo(ReportStage.inProgress),
      isTrue,
    );
    expect(
      ReportStage.inProgress.canCollectorTransitionTo(ReportStage.collected),
      isTrue,
    );

    expect(
      ReportStage.assigned.canCollectorTransitionTo(ReportStage.collected),
      isFalse,
    );
    expect(
      ReportStage.collected.canCollectorTransitionTo(ReportStage.inProgress),
      isFalse,
    );
  });

  test('dispatch and availability semantics do not count completed work', () {
    expect(ReportStage.accepted.isDispatchActive, isTrue);
    expect(ReportStage.inProgress.occupiesCollector, isTrue);
    expect(ReportStage.collected.isDispatchActive, isFalse);
    expect(CollectorAvailability.available.canReceiveAssignment, isTrue);
    expect(CollectorAvailability.busy.canReceiveAssignment, isTrue);
    expect(CollectorAvailability.onTheWay.canReceiveAssignment, isTrue);
    expect(CollectorAvailability.offline.canReceiveAssignment, isFalse);
  });

  test('API values are normalized defensively', () {
    expect(ReportStage.parse(' in_progress '), ReportStage.inProgress);
    expect(ReportStage.parse('future_status'), ReportStage.unknown);
    expect(
      CollectorAvailability.parse('available'),
      CollectorAvailability.available,
    );
  });
}
