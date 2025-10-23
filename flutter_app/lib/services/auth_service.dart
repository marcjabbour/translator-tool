import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Service for handling authentication state and tokens
class AuthService {
  static SharedPreferences? _prefs;

  /// Initialize the auth service
  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Get the current authentication token
  static Future<String?> getToken() async {
    await initialize();
    return _prefs?.getString(ApiConfig.tokenStorageKey);
  }

  /// Set the authentication token
  static Future<void> setToken(String token) async {
    await initialize();
    await _prefs?.setString(ApiConfig.tokenStorageKey, token);
  }

  /// Get the current user ID
  static Future<String?> getUserId() async {
    await initialize();
    return _prefs?.getString(ApiConfig.userIdStorageKey);
  }

  /// Set the user ID
  static Future<void> setUserId(String userId) async {
    await initialize();
    await _prefs?.setString(ApiConfig.userIdStorageKey, userId);
  }

  /// Check if user is authenticated
  static Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Clear authentication data (logout)
  static Future<void> clearAuth() async {
    await initialize();
    await _prefs?.remove(ApiConfig.tokenStorageKey);
    await _prefs?.remove(ApiConfig.userIdStorageKey);
  }

  /// Get auth headers for API requests
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }
}