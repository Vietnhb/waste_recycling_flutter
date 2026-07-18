part of 'enterprise_screens.dart';

/// Business rules used by the enterprise operations screens.
///
/// Keep status interpretation in one place so the dashboard, dispatch queue
/// and team view cannot silently disagree when the API adds another state.
enum EnterpriseDispatchStage {
  awaitingAssignment,
  assigned,
  onTheWay,
  inProgress,
  completed,
  unknown,
}

String enterpriseNormalizedStatus(String value) => value.trim().toUpperCase();

EnterpriseDispatchStage enterpriseDispatchStage(String status) {
  switch (ReportStage.parse(status)) {
    case ReportStage.accepted:
      return EnterpriseDispatchStage.awaitingAssignment;
    case ReportStage.assigned:
      return EnterpriseDispatchStage.assigned;
    case ReportStage.onTheWay:
      return EnterpriseDispatchStage.onTheWay;
    case ReportStage.inProgress:
      return EnterpriseDispatchStage.inProgress;
    case ReportStage.collected:
      return EnterpriseDispatchStage.completed;
    case ReportStage.pending:
    case ReportStage.unknown:
      return EnterpriseDispatchStage.unknown;
  }
}

bool enterpriseCanAssign(WasteReport report) =>
    enterpriseDispatchStage(report.status) ==
    EnterpriseDispatchStage.awaitingAssignment;

bool enterpriseCanReassign(WasteReport report) =>
    enterpriseDispatchStage(report.status) == EnterpriseDispatchStage.assigned;

bool enterpriseIsActiveDispatch(WasteReport report) {
  final stage = enterpriseDispatchStage(report.status);
  return stage == EnterpriseDispatchStage.awaitingAssignment ||
      stage == EnterpriseDispatchStage.assigned ||
      stage == EnterpriseDispatchStage.onTheWay ||
      stage == EnterpriseDispatchStage.inProgress;
}

bool enterpriseIsRunningDispatch(WasteReport report) {
  final stage = enterpriseDispatchStage(report.status);
  return stage == EnterpriseDispatchStage.assigned ||
      stage == EnterpriseDispatchStage.onTheWay ||
      stage == EnterpriseDispatchStage.inProgress;
}

bool enterpriseCollectorIsAvailable(Collector collector) =>
    CollectorAvailability.parse(collector.currentStatus) ==
    CollectorAvailability.available;

bool enterpriseCollectorCanReceiveAssignment(Collector collector) =>
    CollectorAvailability.parse(collector.currentStatus).canReceiveAssignment;

bool enterpriseCollectorIsBusy(Collector collector) {
  return CollectorAvailability.parse(collector.currentStatus).isWorking;
}

/// The backend score describes capability fit, not urgency:
/// category match = 2 points and province match = 1 point.
int enterpriseCapabilityFit(WasteReport report) =>
    (report.priorityScore ?? 0).clamp(0, 3);

String enterpriseCapabilityFitLabel(WasteReport report) {
  switch (enterpriseCapabilityFit(report)) {
    case 3:
      return 'Khớp vật liệu và khu vực';
    case 2:
      return 'Khớp vật liệu';
    case 1:
      return 'Khớp khu vực';
    default:
      return 'Ngoài cấu hình năng lực';
  }
}

List<WasteReport> enterpriseSortPending(Iterable<WasteReport> source) {
  final reports = source.toList();
  reports.sort((a, b) {
    final fit = enterpriseCapabilityFit(
      b,
    ).compareTo(enterpriseCapabilityFit(a));
    if (fit != 0) return fit;
    final aCreated = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bCreated = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final age = aCreated.compareTo(bCreated);
    if (age != 0) return age;
    return a.id.compareTo(b.id);
  });
  return reports;
}

List<WasteReport> enterpriseSortDispatch(Iterable<WasteReport> source) {
  final reports = source.where(enterpriseIsActiveDispatch).toList();
  int stageOrder(WasteReport report) =>
      switch (enterpriseDispatchStage(report.status)) {
        EnterpriseDispatchStage.awaitingAssignment => 0,
        EnterpriseDispatchStage.assigned => 1,
        EnterpriseDispatchStage.onTheWay => 2,
        EnterpriseDispatchStage.inProgress => 3,
        EnterpriseDispatchStage.completed => 4,
        EnterpriseDispatchStage.unknown => 5,
      };

  reports.sort((a, b) {
    final stage = stageOrder(a).compareTo(stageOrder(b));
    if (stage != 0) return stage;
    final aTime = a.updatedAt ?? a.createdAt ?? DateTime(1970);
    final bTime = b.updatedAt ?? b.createdAt ?? DateTime(1970);
    final age = aTime.compareTo(bTime);
    if (age != 0) return age;
    return a.id.compareTo(b.id);
  });
  return reports;
}

String enterpriseElapsedLabel(DateTime? value, {DateTime? now}) {
  if (value == null) return 'Chưa có thời gian cập nhật';
  final difference = (now ?? DateTime.now()).difference(value);
  if (difference.isNegative || difference.inMinutes < 1) return 'Vừa cập nhật';
  if (difference.inMinutes < 60) {
    return 'Đã chờ ${difference.inMinutes} phút';
  }
  if (difference.inHours < 24) return 'Đã chờ ${difference.inHours} giờ';
  return 'Từ ${DateFormat('dd/MM/yyyy HH:mm').format(value)}';
}

class _EnterpriseDataErrorView extends StatelessWidget {
  const _EnterpriseDataErrorView({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => RefreshIndicator(
        onRefresh: onRetry,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            SizedBox(height: constraints.maxHeight * 0.14),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: AppSurface(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: AppPalette.coral.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                        ),
                        child: const Icon(
                          Icons.cloud_off_rounded,
                          color: AppPalette.coral,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.muted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
