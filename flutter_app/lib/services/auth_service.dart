import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Response model for authentication operations
class AuthResponse {
  final String userId;
  final String email;
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final Map<String, dynamic> profile;

  AuthResponse({
    required this.userId,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.profile,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      userId: json['user_id'] ?? '',
      email: json['email'] ?? '',
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      expiresIn: json['expires_in'] ?? 86400,
      profile: json['profile'] ?? {},
    );
  }
}

/// Profile model for user profile operations
class UserProfile {
  final String userId;
  final String email;
  final String? displayName;
  final String dialect;
  final String difficulty;
  final Map<String, String> translitStyle;
  final Map<String, dynamic> settings;

  UserProfile({
    required this.userId,
    required this.email,
    this.displayName,
    required this.dialect,
    required this.difficulty,
    required this.translitStyle,
    required this.settings,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['user_id'] ?? '',
      email: json['email'] ?? '',
      displayName: json['display_name'],
      dialect: json['dialect'] ?? 'lebanese',
      difficulty: json['difficulty'] ?? 'beginner',
      translitStyle: Map<String, String>.from(json['translit_style'] ?? {}),
      settings: json['settings'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'display_name': displayName,
      'dialect': dialect,
      'difficulty': difficulty,
      'translit_style': translitStyle,
      'settings': settings,
    };
  }
}

/// Service for handling authentication operations
class AuthService {
  static SharedPreferences? _prefs;
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userProfileKey = 'user_profile';

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

  /// Register a new user
  static Future<AuthResponse> register({
    required String email,
    required String password,
    String dialect = 'lebanese',
    String difficulty = 'beginner',
    Map<String, String>? translitStyle,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/register');

    final body = {
      'email': email,
      'password': password,
      'dialect': dialect,
      'difficulty': difficulty,
      'translit_style': translitStyle ?? {},
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      final authResponse = AuthResponse.fromJson(data);

      // Store tokens and user data
      await setToken(authResponse.accessToken);
      await setUserId(authResponse.userId);
      await _setRefreshToken(authResponse.refreshToken);
      await _storeUserProfile(UserProfile(
        userId: authResponse.userId,
        email: authResponse.email,
        dialect: dialect,
        difficulty: difficulty,
        translitStyle: translitStyle ?? {},
        settings: authResponse.profile,
      ));

      return authResponse;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['detail'] ?? 'Registration failed');
    }
  }

  /// Login with email and password
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/login');

    final body = {
      'email': email,
      'password': password,
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final authResponse = AuthResponse.fromJson(data);

      // Store tokens and user data
      await setToken(authResponse.accessToken);
      await setUserId(authResponse.userId);
      await _setRefreshToken(authResponse.refreshToken);

      // Fetch and store user profile
      final profile = await getUserProfile();
      if (profile != null) {
        await _storeUserProfile(profile);
      }

      return authResponse;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['detail'] ?? 'Login failed');
    }
  }

  /// Logout the current user
  static Future<void> logout() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/logout');
      final headers = await getAuthHeaders();

      await http.post(url, headers: headers);
    } catch (e) {
      // Continue with logout even if server request fails
    }

    // Clear local storage
    await clearAuth();
    await _clearRefreshToken();
    await _clearUserProfile();
  }

  /// Get user profile from server
  static Future<UserProfile?> getUserProfile() async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/profile');
      final headers = await getAuthHeaders();

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserProfile.fromJson(data);
      }
    } catch (e) {
      // Return cached profile if server request fails
    }

    return getCachedUserProfile();
  }

  /// Update user profile
  static Future<UserProfile> updateUserProfile(UserProfile profile) async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/profile');
    final headers = await getAuthHeaders();

    final response = await http.put(
      url,
      headers: headers,
      body: json.encode(profile.toJson()),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final updatedProfile = UserProfile.fromJson(data);
      await _storeUserProfile(updatedProfile);
      return updatedProfile;
    } else {
      final errorData = json.decode(response.body);
      throw Exception(errorData['detail'] ?? 'Profile update failed');
    }
  }

  /// Refresh authentication token
  static Future<bool> refreshToken() async {
    try {
      final refreshToken = await _getRefreshToken();
      if (refreshToken == null) return false;

      final url = Uri.parse('${ApiConfig.baseUrl}/api/v1/auth/refresh');
      final body = {'refresh_token': refreshToken};

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await setToken(data['access_token']);
        await _setRefreshToken(data['refresh_token']);
        return true;
      }
    } catch (e) {
      // Token refresh failed
    }

    return false;
  }

  /// Get cached user profile
  static Future<UserProfile?> getCachedUserProfile() async {
    await initialize();
    final profileJson = _prefs?.getString(_userProfileKey);
    if (profileJson != null) {
      final data = json.decode(profileJson);
      return UserProfile.fromJson(data);
    }
    return null;
  }

  // Private helper methods

  /// Store refresh token
  static Future<void> _setRefreshToken(String token) async {
    await initialize();
    await _prefs?.setString(_refreshTokenKey, token);
  }

  /// Get refresh token
  static Future<String?> _getRefreshToken() async {
    await initialize();
    return _prefs?.getString(_refreshTokenKey);
  }

  /// Clear refresh token
  static Future<void> _clearRefreshToken() async {
    await initialize();
    await _prefs?.remove(_refreshTokenKey);
  }

  /// Store user profile
  static Future<void> _storeUserProfile(UserProfile profile) async {
    await initialize();
    final profileJson = json.encode(profile.toJson());
    await _prefs?.setString(_userProfileKey, profileJson);
  }

  /// Clear user profile
  static Future<void> _clearUserProfile() async {
    await initialize();
    await _prefs?.remove(_userProfileKey);
  }
}