import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

/// Authentication state enum
enum AuthStatus {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

/// Authentication state class
class AuthState {
  final AuthStatus status;
  final UserProfile? user;
  final String? error;

  const AuthState({
    required this.status,
    this.user,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error ?? this.error,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthState &&
        other.status == status &&
        other.user == user &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(status, user, error);
}

/// Authentication state notifier
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(status: AuthStatus.initial)) {
    _initializeAuth();
  }

  /// Initialize authentication state from stored data
  Future<void> _initializeAuth() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final isAuthenticated = await AuthService.isAuthenticated();
      if (isAuthenticated) {
        final profile = await AuthService.getCachedUserProfile();
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: profile,
        );
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString(),
      );
    }
  }

  /// Login with email and password
  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);

    try {
      final response = await AuthService.login(
        email: email,
        password: password,
      );

      final profile = await AuthService.getUserProfile();

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: profile,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Register new user
  Future<void> register({
    required String email,
    required String password,
    String dialect = 'lebanese',
    String difficulty = 'beginner',
    Map<String, String>? translitStyle,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);

    try {
      final response = await AuthService.register(
        email: email,
        password: password,
        dialect: dialect,
        difficulty: difficulty,
        translitStyle: translitStyle,
      );

      final profile = await AuthService.getUserProfile();

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: profile,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Logout the current user
  Future<void> logout() async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      await AuthService.logout();
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
      );
    } catch (e) {
      // Even if logout fails on server, clear local state
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
      );
    }
  }

  /// Update user profile
  Future<void> updateProfile(UserProfile profile) async {
    try {
      final updatedProfile = await AuthService.updateUserProfile(profile);
      state = state.copyWith(user: updatedProfile);
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Refresh authentication token
  Future<bool> refreshToken() async {
    try {
      final success = await AuthService.refreshToken();
      if (!success) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
      return success;
    } catch (e) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return false;
    }
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Authentication provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// Convenience providers for specific auth data
final userProvider = Provider<UserProfile?>((ref) {
  return ref.watch(authProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status == AuthStatus.authenticated;
});

final authStatusProvider = Provider<AuthStatus>((ref) {
  return ref.watch(authProvider).status;
});

final authErrorProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).error;
});