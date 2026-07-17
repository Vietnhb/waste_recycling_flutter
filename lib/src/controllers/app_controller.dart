import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/json_helpers.dart';
import '../core/platform_config.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';

class AppController extends ChangeNotifier {
  String baseUrl = defaultApiBaseUrl();
  String? token;
  User? user;
  bool booting = true;
  final realtime = RealtimeService();

  SharedPreferences? _prefs;

  ApiService get api => ApiService(ApiClient(baseUrl: baseUrl, token: token));

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    baseUrl = _prefs?.getString('baseUrl') ?? defaultApiBaseUrl();
    token = _prefs?.getString('token');
    if (token != null) {
      try {
        user = await api.getMe();
        realtime.connect(baseUrl: baseUrl, token: token!);
      } catch (_) {
        token = null;
        await _prefs?.remove('token');
      }
    }
    booting = false;
    notifyListeners();
  }

  Future<void> setBaseUrl(String value) async {
    final normalized = value.trim().replaceAll(RegExp(r'/+$'), '');
    if (normalized.isEmpty) return;
    baseUrl = normalized;
    await _prefs?.setString('baseUrl', baseUrl);
    if (token != null) realtime.connect(baseUrl: baseUrl, token: token!);
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final client = ApiClient(baseUrl: baseUrl);
    final data = await client.post('/auth/login', {
      'email': email,
      'password': password,
    });
    token = asString(data['token']);
    user = User.fromJson(Map<String, dynamic>.from(data['user']));
    await _prefs?.setString('token', token!);
    realtime.connect(baseUrl: baseUrl, token: token!);
    notifyListeners();
  }

  Future<void> devLogin(String role) async {
    token = 'dev_dummy_token';
    user = User(
      id: 999,
      email: 'test@$role.com',
      fullName: 'Dev $role',
      role: role,
      points: 100,
    );
    notifyListeners();
  }

  Future<void> signup(String email, String fullName, String password) =>
      api.signup(email, fullName, password);

  Future<void> refreshMe() async {
    if (token == null) return;
    user = await api.getMe();
    notifyListeners();
  }

  Future<void> updateMe(String fullName, String email) async {
    user = await api.updateMe(fullName, email);
    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    user = null;
    realtime.disconnect();
    await _prefs?.remove('token');
    notifyListeners();
  }

  @override
  void dispose() {
    realtime.dispose();
    super.dispose();
  }
}
