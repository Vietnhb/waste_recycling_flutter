import '../../../core/api_client.dart';
import '../../../core/json_helpers.dart';
import '../../../models/models.dart';

/// Network boundary for the collector feature.
///
/// Keeping role-specific endpoints here prevents collector workflow changes
/// from growing the application-wide [ApiService] facade indefinitely.
class CollectorApi {
  const CollectorApi(this._client);

  final ApiClient _client;

  Future<Collector> getProfile() async => Collector.fromJson(
    Map<String, dynamic>.from(await _client.get('/collector/profile')),
  );

  Future<List<WasteReport>> getAssignedReports() async =>
      parseList(await _client.get('/collector/reports'), WasteReport.fromJson);

  Future<WasteReport> updateCollectionStatus(int reportId, JsonMap data) async {
    return WasteReport.fromJson(
      Map<String, dynamic>.from(
        await _client.put('/collector/reports/$reportId/status', data),
      ),
    );
  }

  Future<Collector> updateAvailability(String status) async {
    return Collector.fromJson(
      Map<String, dynamic>.from(
        await _client.put('/collector/status', null, {'status': status}),
      ),
    );
  }

  Future<List<WorkHistory>> getWorkHistory() async => parseList(
    await _client.get('/collector/work-history'),
    WorkHistory.fromJson,
  );

  Future<WorkStatistics> getWorkStatistics() async => WorkStatistics.fromJson(
    Map<String, dynamic>.from(await _client.get('/collector/work-statistics')),
  );
}
