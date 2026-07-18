import 'dart:math';
import 'dart:typed_data';

import '../core/api_client.dart';
import '../core/json_helpers.dart';
import '../features/collector/data/collector_api.dart';
import '../features/enterprise/data/enterprise_api.dart';
import '../models/models.dart';

class ApiService {
  ApiService(this.client)
    : collector = CollectorApi(client),
      enterprise = EnterpriseApi(client);

  final ApiClient client;
  final CollectorApi collector;
  final EnterpriseApi enterprise;

  Future<User> login(String email, String password) async {
    final data = await client.post('/auth/login', {
      'email': email,
      'password': password,
    });
    return User.fromJson(Map<String, dynamic>.from(data['user']));
  }

  Future<String> loginToken(String email, String password) async {
    final data = await client.post('/auth/login', {
      'email': email,
      'password': password,
    });
    return asString(data['token']);
  }

  Future<void> signup(String email, String fullName, String password) async {
    await client.post('/auth/signup', {
      'email': email,
      'fullName': fullName,
      'password': password,
    });
  }

  Future<User> getMe() async =>
      User.fromJson(Map<String, dynamic>.from(await client.get('/user/me')));

  Future<User> updateMe(String fullName, String email) async {
    final data = await client.put('/user/me', {
      'fullName': fullName,
      'email': email,
    });
    return User.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<User>> getUsers() async =>
      parseList(await client.get('/admin/all'), User.fromJson);

  Future<void> createUser(JsonMap data) => client.post('/admin/account', data);

  Future<User> updateUser(int id, JsonMap data) async => User.fromJson(
    Map<String, dynamic>.from(await client.put('/admin/user/$id', data)),
  );

  Future<void> deleteUser(int id) => client.delete('/admin/user/$id');

  Future<List<UserAddress>> getAddresses() async =>
      parseList(await client.get('/user/addresses'), UserAddress.fromJson);

  Future<List<Province>> getLocationData() async =>
      parseList(await client.get('/locations/data'), Province.fromJson);

  Future<UserAddress> addAddress(JsonMap data) async => UserAddress.fromJson(
    Map<String, dynamic>.from(await client.post('/user/address', data)),
  );

  Future<UserAddress> updateAddress(int id, JsonMap data) async =>
      UserAddress.fromJson(
        Map<String, dynamic>.from(await client.put('/user/address/$id', data)),
      );

  Future<void> deleteAddress(int id) => client.delete('/user/address/$id');

  Future<List<WasteCategory>> getCategories() async =>
      parseList(await client.get('/category/list'), WasteCategory.fromJson);

  Future<WasteClassification> classifyWasteImage(
    Uint8List bytes, {
    required String filename,
    String locale = 'vi-VN',
  }) async {
    final data = await client
        .postImage(
          '/report/classifications',
          bytes: bytes,
          filename: filename,
          fields: {'locale': locale},
          headers: {'Idempotency-Key': _uuidV4()},
        )
        .timeout(const Duration(seconds: 20));
    return WasteClassification.fromJson(Map<String, dynamic>.from(data));
  }

  Future<WasteReport> createReport(JsonMap data) async => WasteReport.fromJson(
    Map<String, dynamic>.from(await client.post('/report/create', data)),
  );

  Future<List<WasteReport>> getMyReports() async =>
      parseList(await client.get('/report/my-reports'), WasteReport.fromJson);

  Future<List<PointHistory>> getPointHistory() async =>
      parseList(await client.get('/user/point-history'), PointHistory.fromJson);

  Future<List<RankingUser>> getRanking(String areaType, String areaCode) async {
    return parseList(
      await client.get('/user/ranking', {
        'areaType': areaType,
        'areaCode': areaCode,
      }),
      RankingUser.fromJson,
    );
  }

  Future<List<Complaint>> getMyComplaints() async => parseList(
    await client.get('/complaint/my-complaints'),
    Complaint.fromJson,
  );

  Future<Complaint> createComplaint(int reportId, String description) async {
    return Complaint.fromJson(
      Map<String, dynamic>.from(
        await client.post('/complaint/create', {
          'reportId': reportId,
          'description': description,
        }),
      ),
    );
  }

  Future<List<Complaint>> getAllComplaints() async =>
      parseList(await client.get('/complaint/all'), Complaint.fromJson);

  Future<Complaint> resolveComplaint(
    int id,
    String status,
    String adminNote,
  ) async {
    return Complaint.fromJson(
      Map<String, dynamic>.from(
        await client.put('/complaint/$id/resolve', {
          'status': status,
          'adminNote': adminNote,
        }),
      ),
    );
  }

  Future<Enterprise> getEnterprise() => enterprise.getProfile();

  Future<Enterprise> registerEnterprise(JsonMap data) =>
      enterprise.register(data);

  Future<Enterprise> updateEnterprise(JsonMap data) =>
      enterprise.updateProfile(data);

  Future<List<WasteReport>> getPendingReports() =>
      enterprise.getPendingReports();

  Future<WasteReport> acceptReport(int reportId, int ruleId) =>
      enterprise.acceptReport(reportId, ruleId);

  Future<void> rejectReport(int reportId) => enterprise.releaseReport(reportId);

  Future<List<WasteReport>> getAcceptedReports() =>
      enterprise.getDispatchReports();

  Future<List<WasteReport>> getEnterpriseReportHistory() =>
      enterprise.getReportHistory();

  Future<WasteReport> assignCollector(int reportId, int collectorId) =>
      enterprise.assignCollector(reportId, collectorId);

  Future<List<Collector>> getCollectors() async => enterprise.getCollectors();

  Future<Collector> createCollector(JsonMap data) =>
      enterprise.createCollector(data);

  Future<void> deleteCollector(int id) => enterprise.deleteCollector(id);

  Future<List<PointRule>> getPointRules() async => enterprise.getPointRules();

  Future<PointRule> createPointRule(JsonMap data) =>
      enterprise.createPointRule(data);

  Future<PointRule> updatePointRule(int id, JsonMap data) =>
      enterprise.updatePointRule(id, data);

  Future<PointRule> togglePointRule(int id) => enterprise.togglePointRule(id);

  Future<void> deletePointRule(int id) => enterprise.deletePointRule(id);

  Future<List<WasteStatistics>> getWasteStatistics({
    int? categoryId,
    String? provinceCode,
    String? wardCode,
    String? startDate,
    String? endDate,
  }) async {
    return enterprise.getWasteStatistics(
      categoryId: categoryId,
      provinceCode: provinceCode,
      wardCode: wardCode,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<Collector> getCollectorProfile() => collector.getProfile();

  Future<List<WasteReport>> getAssignedReports() async =>
      collector.getAssignedReports();

  Future<WasteReport> updateCollectionStatus(int reportId, JsonMap data) =>
      collector.updateCollectionStatus(reportId, data);

  Future<Collector> updateCollectorStatus(String status) =>
      collector.updateAvailability(status);

  Future<List<WorkHistory>> getWorkHistory() => collector.getWorkHistory();

  Future<WorkStatistics> getWorkStatistics() => collector.getWorkStatistics();
}

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int value) => value.toRadixString(16).padLeft(2, '0');
  final value = bytes.map(hex).join();
  return '${value.substring(0, 8)}-'
      '${value.substring(8, 12)}-'
      '${value.substring(12, 16)}-'
      '${value.substring(16, 20)}-'
      '${value.substring(20)}';
}
