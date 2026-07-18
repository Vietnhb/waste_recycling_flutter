import '../../../models/models.dart';

/// Defensive client-side ordering keeps the audit timeline deterministic even
/// when an older server does not yet honor the newest-first contract.
List<WasteReport> sortEnterpriseHistory(Iterable<WasteReport> reports) {
  final sorted = reports
      .where((report) => report.status == 'COLLECTED')
      .toList();
  sorted.sort((left, right) {
    final leftAt = left.collectedAt ?? left.updatedAt ?? left.createdAt;
    final rightAt = right.collectedAt ?? right.updatedAt ?? right.createdAt;
    if (leftAt == null) {
      return rightAt == null ? right.id.compareTo(left.id) : 1;
    }
    if (rightAt == null) return -1;
    final timeOrder = rightAt.compareTo(leftAt);
    return timeOrder == 0 ? right.id.compareTo(left.id) : timeOrder;
  });
  return sorted;
}

double enterpriseHistoryWeight(Iterable<WasteReport> reports) =>
    reports.fold(0, (total, report) => total + (report.weight ?? 0));

double enterpriseHistoryClassificationRate(Iterable<WasteReport> reports) {
  final verified = reports
      .where((report) => report.isCorrectlyClassified != null)
      .toList();
  if (verified.isEmpty) return 0;
  final correct = verified
      .where((report) => report.isCorrectlyClassified == true)
      .length;
  return correct * 100 / verified.length;
}
