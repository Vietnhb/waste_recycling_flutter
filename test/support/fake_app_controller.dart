import 'package:waste_recycling_flutter/src/controllers/app_controller.dart';
import 'package:waste_recycling_flutter/src/core/api_client.dart';
import 'package:waste_recycling_flutter/src/models/models.dart';
import 'package:waste_recycling_flutter/src/services/api_service.dart';

class FakeAppController extends AppController {
  FakeAppController.guest() : fakeApi = FakeApiService() {
    booting = false;
  }

  FakeAppController.citizen({
    User user = const User(
      id: 7,
      email: 'citizen@example.test',
      fullName: 'Nguyen An',
      role: 'CITIZEN',
      points: 120,
    ),
    List<WasteReport> reports = const [],
    List<UserAddress> addresses = const [],
    List<WasteCategory> categories = const [],
    List<PointHistory> pointHistory = const [],
    List<RankingUser> ranking = const [],
    List<Province>? locations,
    Object? pointHistoryError,
    Object? rankingError,
    Future<List<RankingUser>> Function(String areaType, String areaCode)?
    rankingLoader,
  }) : fakeApi = FakeApiService(
         reports: reports,
         addresses: addresses,
         categories: categories,
         pointHistory: pointHistory,
         ranking: ranking,
         locations: locations,
         pointHistoryError: pointHistoryError,
         rankingError: rankingError,
         rankingLoader: rankingLoader,
       ) {
    booting = false;
    token = 'widget-test-token';
    this.user = user;
  }

  FakeAppController.collector({
    User user = const User(
      id: 8,
      email: 'collector@example.test',
      fullName: 'Tran Minh',
      role: 'COLLECTOR',
    ),
  }) : fakeApi = FakeApiService() {
    booting = false;
    token = 'widget-test-token';
    this.user = user;
  }

  FakeAppController.enterprise({
    User user = const User(
      id: 9,
      email: 'enterprise@example.test',
      fullName: 'Green Operations',
      role: 'ENTERPRISE',
    ),
    List<WasteReport> enterpriseHistory = const [],
    Object? enterpriseHistoryError,
  }) : fakeApi = FakeApiService(
         enterpriseHistory: enterpriseHistory,
         enterpriseHistoryError: enterpriseHistoryError,
       ) {
    booting = false;
    token = 'widget-test-token';
    this.user = user;
  }

  FakeAppController.admin({
    User user = const User(
      id: 1,
      email: 'admin@example.test',
      fullName: 'System Admin',
      role: 'ADMIN',
    ),
    List<User> users = const [],
    List<Complaint> complaints = const [],
  }) : fakeApi = FakeApiService(users: users, complaints: complaints) {
    booting = false;
    token = 'widget-test-token';
    this.user = user;
  }

  final FakeApiService fakeApi;
  int profileRefreshes = 0;

  @override
  ApiService get api => fakeApi;

  @override
  Future<void> refreshMe() async {
    profileRefreshes++;
  }
}

class FakeApiService extends ApiService {
  FakeApiService({
    this.reports = const [],
    this.addresses = const [],
    this.categories = const [],
    this.pointHistory = const [],
    this.ranking = const [],
    this.locations,
    this.pointHistoryError,
    this.rankingError,
    this.rankingLoader,
    this.enterpriseHistory = const [],
    this.enterpriseHistoryError,
    this.users = const [],
    this.complaints = const [],
  }) : super(ApiClient(baseUrl: 'https://example.test/api'));

  final List<WasteReport> reports;
  final List<UserAddress> addresses;
  final List<WasteCategory> categories;
  final List<PointHistory> pointHistory;
  final List<RankingUser> ranking;
  final List<Province>? locations;
  Object? pointHistoryError;
  Object? rankingError;
  final Future<List<RankingUser>> Function(String areaType, String areaCode)?
  rankingLoader;
  final List<WasteReport> enterpriseHistory;
  final Object? enterpriseHistoryError;
  final List<User> users;
  final List<Complaint> complaints;

  int addressRequests = 0;
  int categoryRequests = 0;
  int complaintRequests = 0;
  int pointHistoryRequests = 0;
  int rankingRequests = 0;
  int reportRequests = 0;
  int enterpriseHistoryRequests = 0;
  int userRequests = 0;
  int allComplaintRequests = 0;
  int enterpriseRequests = 0;
  int pendingReportRequests = 0;
  int acceptedReportRequests = 0;
  int collectorRequests = 0;
  int collectorProfileRequests = 0;
  int assignedReportRequests = 0;
  int workHistoryRequests = 0;
  int workStatisticsRequests = 0;
  final List<({String areaType, String areaCode})> rankingCalls = [];

  int get totalRequests =>
      addressRequests +
      categoryRequests +
      complaintRequests +
      pointHistoryRequests +
      rankingRequests +
      reportRequests +
      enterpriseHistoryRequests;

  @override
  Future<List<UserAddress>> getAddresses() async {
    addressRequests++;
    return addresses;
  }

  @override
  Future<List<WasteCategory>> getCategories() async {
    categoryRequests++;
    return categories;
  }

  @override
  Future<List<Province>> getLocationData() async {
    final fixture = locations;
    if (fixture != null) return fixture;
    return super.getLocationData();
  }

  @override
  Future<List<Complaint>> getMyComplaints() async {
    complaintRequests++;
    return const [];
  }

  @override
  Future<List<PointHistory>> getPointHistory() async {
    pointHistoryRequests++;
    final error = pointHistoryError;
    if (error != null) throw error;
    return pointHistory;
  }

  @override
  Future<List<RankingUser>> getRanking(String areaType, String areaCode) async {
    rankingRequests++;
    rankingCalls.add((areaType: areaType, areaCode: areaCode));
    final error = rankingError;
    if (error != null) throw error;
    final loader = rankingLoader;
    if (loader != null) return loader(areaType, areaCode);
    return ranking;
  }

  @override
  Future<List<WasteReport>> getMyReports() async {
    reportRequests++;
    return reports;
  }

  @override
  Future<List<User>> getUsers() async {
    userRequests++;
    return users;
  }

  @override
  Future<List<Complaint>> getAllComplaints() async {
    allComplaintRequests++;
    return complaints;
  }

  @override
  Future<Enterprise> getEnterprise() async {
    enterpriseRequests++;
    return const Enterprise(
      id: 1,
      userId: 9,
      companyName: 'Green Operations',
      acceptedWasteTypes: 'RECYCLABLE,ORGANIC',
      capacity: 1500,
      serviceArea: 'Ho Chi Minh City',
      rating: 4.8,
    );
  }

  @override
  Future<List<WasteReport>> getPendingReports() async {
    pendingReportRequests++;
    return const [];
  }

  @override
  Future<List<WasteReport>> getAcceptedReports() async {
    acceptedReportRequests++;
    return const [];
  }

  @override
  Future<List<WasteReport>> getEnterpriseReportHistory() async {
    enterpriseHistoryRequests++;
    final error = enterpriseHistoryError;
    if (error != null) throw error;
    return enterpriseHistory;
  }

  @override
  Future<List<Collector>> getCollectors() async {
    collectorRequests++;
    return const [];
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
  Future<Collector> updateCollectorStatus(String status) async => Collector(
    id: 11,
    userId: 8,
    userName: 'Tran Minh',
    userEmail: 'collector@example.test',
    enterpriseId: 1,
    enterpriseName: 'Green Operations',
    currentStatus: status,
  );
}
