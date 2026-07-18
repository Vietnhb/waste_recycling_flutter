import '../../../core/api_client.dart';
import '../../../core/json_helpers.dart';
import '../../../models/models.dart';

/// Network boundary for enterprise operations and dispatch.
class EnterpriseApi {
  const EnterpriseApi(this._client);

  final ApiClient _client;

  Future<Enterprise> getProfile() async => Enterprise.fromJson(
    Map<String, dynamic>.from(await _client.get('/enterprise/profile')),
  );

  Future<Enterprise> register(JsonMap data) async => Enterprise.fromJson(
    Map<String, dynamic>.from(await _client.post('/enterprise/register', data)),
  );

  Future<Enterprise> updateProfile(JsonMap data) async => Enterprise.fromJson(
    Map<String, dynamic>.from(await _client.put('/enterprise/profile', data)),
  );

  Future<List<WasteReport>> getPendingReports() async => parseList(
    await _client.get('/enterprise/reports/pending'),
    WasteReport.fromJson,
  );

  Future<WasteReport> acceptReport(int reportId, int ruleId) async {
    return WasteReport.fromJson(
      Map<String, dynamic>.from(
        await _client.post(
          '/enterprise/reports/$reportId/accept?ruleId=$ruleId',
        ),
      ),
    );
  }

  Future<void> releaseReport(int reportId) =>
      _client.post('/enterprise/reports/$reportId/reject');

  Future<List<WasteReport>> getDispatchReports() async => parseList(
    await _client.get('/enterprise/reports/accepted'),
    WasteReport.fromJson,
  );

  Future<List<WasteReport>> getReportHistory() async => parseList(
    await _client.get('/enterprise/reports/history'),
    WasteReport.fromJson,
  );

  Future<WasteReport> assignCollector(int reportId, int collectorId) async {
    return WasteReport.fromJson(
      Map<String, dynamic>.from(
        await _client.post('/enterprise/reports/assign', {
          'reportId': reportId,
          'collectorId': collectorId,
        }),
      ),
    );
  }

  Future<List<Collector>> getCollectors() async => parseList(
    await _client.get('/enterprise/collectors'),
    Collector.fromJson,
  );

  Future<Collector> createCollector(JsonMap data) async => Collector.fromJson(
    Map<String, dynamic>.from(
      await _client.post('/enterprise/collectors', data),
    ),
  );

  Future<void> deleteCollector(int id) =>
      _client.delete('/enterprise/collectors/$id');

  Future<List<PointRule>> getPointRules() async => parseList(
    await _client.get('/points/rules/my-rules'),
    PointRule.fromJson,
  );

  Future<PointRule> createPointRule(JsonMap data) async => PointRule.fromJson(
    Map<String, dynamic>.from(await _client.post('/points/rules', data)),
  );

  Future<PointRule> updatePointRule(int id, JsonMap data) async =>
      PointRule.fromJson(
        Map<String, dynamic>.from(await _client.put('/points/rules/$id', data)),
      );

  Future<PointRule> togglePointRule(int id) async => PointRule.fromJson(
    Map<String, dynamic>.from(await _client.put('/points/rules/$id/toggle')),
  );

  Future<void> deletePointRule(int id) => _client.delete('/points/rules/$id');

  Future<List<WasteStatistics>> getWasteStatistics({
    int? categoryId,
    String? provinceCode,
    String? wardCode,
    String? startDate,
    String? endDate,
  }) async {
    return parseList(
      await _client.get('/enterprise/statistics', {
        'categoryId': categoryId?.toString(),
        'provinceCode': provinceCode,
        'wardCode': wardCode,
        'startDate': startDate,
        'endDate': endDate,
      }),
      WasteStatistics.fromJson,
    );
  }
}
