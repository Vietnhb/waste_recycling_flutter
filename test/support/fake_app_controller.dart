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
  }) : fakeApi = FakeApiService() {
    booting = false;
    token = 'widget-test-token';
    this.user = user;
  }

  final FakeApiService fakeApi;

  @override
  ApiService get api => fakeApi;
}

class FakeApiService extends ApiService {
  FakeApiService() : super(ApiClient(baseUrl: 'https://example.test/api'));

  int addressRequests = 0;
  int categoryRequests = 0;
  int complaintRequests = 0;
  int pointHistoryRequests = 0;
  int rankingRequests = 0;
  int reportRequests = 0;

  int get totalRequests =>
      addressRequests +
      categoryRequests +
      complaintRequests +
      pointHistoryRequests +
      rankingRequests +
      reportRequests;

  @override
  Future<List<UserAddress>> getAddresses() async {
    addressRequests++;
    return const [];
  }

  @override
  Future<List<WasteCategory>> getCategories() async {
    categoryRequests++;
    return const [];
  }

  @override
  Future<List<Complaint>> getMyComplaints() async {
    complaintRequests++;
    return const [];
  }

  @override
  Future<List<PointHistory>> getPointHistory() async {
    pointHistoryRequests++;
    return const [];
  }

  @override
  Future<List<RankingUser>> getRanking(String areaType, String areaCode) async {
    rankingRequests++;
    return const [];
  }

  @override
  Future<List<WasteReport>> getMyReports() async {
    reportRequests++;
    return const [];
  }
}
