import '../core/api_client.dart';
import '../core/json_helpers.dart';
import '../models/models.dart';

class ApiService {
  ApiService(this.client);

  final ApiClient client;

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

  Future<Enterprise> getEnterprise() async => Enterprise.fromJson(
    Map<String, dynamic>.from(await client.get('/enterprise/profile')),
  );

  Future<Enterprise> registerEnterprise(JsonMap data) async =>
      Enterprise.fromJson(
        Map<String, dynamic>.from(
          await client.post('/enterprise/register', data),
        ),
      );

  Future<Enterprise> updateEnterprise(JsonMap data) async =>
      Enterprise.fromJson(
        Map<String, dynamic>.from(
          await client.put('/enterprise/profile', data),
        ),
      );

  Future<List<WasteReport>> getPendingReports() async => parseList(
    await client.get('/enterprise/reports/pending'),
    WasteReport.fromJson,
  );

  Future<WasteReport> acceptReport(int reportId, int ruleId) async {
    return WasteReport.fromJson(
      Map<String, dynamic>.from(
        await client.post(
          '/enterprise/reports/$reportId/accept?ruleId=$ruleId',
        ),
      ),
    );
  }

  Future<void> rejectReport(int reportId) =>
      client.post('/enterprise/reports/$reportId/reject');

  Future<List<WasteReport>> getAcceptedReports() async => parseList(
    await client.get('/enterprise/reports/accepted'),
    WasteReport.fromJson,
  );

  Future<WasteReport> assignCollector(int reportId, int collectorId) async {
    return WasteReport.fromJson(
      Map<String, dynamic>.from(
        await client.post('/enterprise/reports/assign', {
          'reportId': reportId,
          'collectorId': collectorId,
        }),
      ),
    );
  }

  Future<List<Collector>> getCollectors() async =>
      parseList(await client.get('/enterprise/collectors'), Collector.fromJson);

  Future<Collector> createCollector(JsonMap data) async => Collector.fromJson(
    Map<String, dynamic>.from(
      await client.post('/enterprise/collectors', data),
    ),
  );

  Future<void> deleteCollector(int id) =>
      client.delete('/enterprise/collectors/$id');

  Future<List<PointRule>> getPointRules() async =>
      parseList(await client.get('/points/rules/my-rules'), PointRule.fromJson);

  Future<PointRule> createPointRule(JsonMap data) async => PointRule.fromJson(
    Map<String, dynamic>.from(await client.post('/points/rules', data)),
  );

  Future<PointRule> updatePointRule(int id, JsonMap data) async =>
      PointRule.fromJson(
        Map<String, dynamic>.from(await client.put('/points/rules/$id', data)),
      );

  Future<PointRule> togglePointRule(int id) async => PointRule.fromJson(
    Map<String, dynamic>.from(await client.put('/points/rules/$id/toggle')),
  );

  Future<void> deletePointRule(int id) => client.delete('/points/rules/$id');

  Future<List<WasteStatistics>> getWasteStatistics({
    int? categoryId,
    String? provinceCode,
    String? wardCode,
    String? startDate,
    String? endDate,
  }) async {
    return parseList(
      await client.get('/enterprise/statistics', {
        'categoryId': categoryId?.toString(),
        'provinceCode': provinceCode,
        'wardCode': wardCode,
        'startDate': startDate,
        'endDate': endDate,
      }),
      WasteStatistics.fromJson,
    );
  }

  Future<Collector> getCollectorProfile() async => Collector.fromJson(
    Map<String, dynamic>.from(await client.get('/collector/profile')),
  );

  Future<List<WasteReport>> getAssignedReports() async =>
      parseList(await client.get('/collector/reports'), WasteReport.fromJson);

  Future<WasteReport> updateCollectionStatus(int reportId, JsonMap data) async {
    return WasteReport.fromJson(
      Map<String, dynamic>.from(
        await client.put('/collector/reports/$reportId/status', data),
      ),
    );
  }

  Future<Collector> updateCollectorStatus(String status) async {
    return Collector.fromJson(
      Map<String, dynamic>.from(
        await client.put('/collector/status', null, {'status': status}),
      ),
    );
  }

  Future<List<WorkHistory>> getWorkHistory() async => parseList(
    await client.get('/collector/work-history'),
    WorkHistory.fromJson,
  );

  Future<WorkStatistics> getWorkStatistics() async => WorkStatistics.fromJson(
    Map<String, dynamic>.from(await client.get('/collector/work-statistics')),
  );
}
