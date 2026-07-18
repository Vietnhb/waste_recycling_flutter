import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/json_helpers.dart';
import '../core/platform_config.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/realtime_service.dart';

class AppController extends ChangeNotifier {
  String baseUrl = defaultApiBaseUrl();
  String? token;
  User? user;
  Object? sessionRestoreError;
  bool booting = true;
  final realtime = RealtimeService();

  SharedPreferences? _prefs;

  ApiService get api => ApiService(ApiClient(baseUrl: baseUrl, token: token));

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      baseUrl = kDebugMode
          ? normalizeApiBaseUrl(
              _prefs?.getString('baseUrl') ?? defaultApiBaseUrl(),
            )
          : defaultApiBaseUrl();
      token = _prefs?.getString('token');
      if (token != null) {
        await _restoreSession();
      }
    } catch (error) {
      // A storage failure must not trap the app on its launch screen. The user
      // can still enter as a guest and retry authenticated actions later.
      token = null;
      user = null;
      sessionRestoreError = error;
    } finally {
      booting = false;
      notifyListeners();
    }
  }

  Future<void> setBaseUrl(String value) async {
    if (!kDebugMode) return;
    final normalized = normalizeApiBaseUrl(value);
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
    sessionRestoreError = null;
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
    sessionRestoreError = null;
    notifyListeners();
  }

  Future<void> signup(String email, String fullName, String password) =>
      api.signup(email, fullName, password);

  Future<void> refreshMe() async {
    if (token == null) return;
    user = await api.getMe();
    notifyListeners();
  }

  Future<void> retrySessionRestore() async {
    if (token == null || booting) return;
    booting = true;
    sessionRestoreError = null;
    notifyListeners();
    await _restoreSession();
    booting = false;
    notifyListeners();
  }

  Future<void> updateMe(String fullName, String email) async {
    user = await api.updateMe(fullName, email);
    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    user = null;
    sessionRestoreError = null;
    realtime.disconnect();
    await _prefs?.remove('token');
    notifyListeners();
  }

  Future<void> _restoreSession() async {
    try {
      user = await api.getMe();
      sessionRestoreError = null;
      realtime.connect(baseUrl: baseUrl, token: token!);
    } catch (error) {
      user = null;
      final unauthorized =
          error is ApiException &&
          (error.statusCode == 401 || error.statusCode == 403);
      if (unauthorized) {
        token = null;
        sessionRestoreError = null;
        await _prefs?.remove('token');
      } else {
        sessionRestoreError = error;
      }
    }
  }

  @override
  void dispose() {
    realtime.dispose();
    super.dispose();
  }
}
