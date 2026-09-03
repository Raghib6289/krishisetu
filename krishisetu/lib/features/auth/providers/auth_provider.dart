import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isAuthenticated => user != null;
  UserRole? get role => user?.role;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _apiClient;

  AuthNotifier(this._apiClient) : super(const AuthState());

  Future<Map<String, dynamic>> sendOtp(String phone, {String? userType, String? name}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final res = await _apiClient.sendOtp(phone, userType: userType, name: name);
      state = state.copyWith(isLoading: false);
      return res;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to send OTP.');
      return {'status': 'error', 'message': e.toString()};
    }
  }

  Future<bool> verifyOtpAndLogin(
    String phone,
    String otp, {
    String? userType,
    String? name,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final data = await _apiClient.verifyOtp(phone, otp, userType: userType, name: name);
      final user = UserModel.fromJson(data);
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Invalid OTP. Please check or use demo code: 123456',
      );
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final data = await _apiClient.login(email, password);
      final user = UserModel.fromJson(data);
      state = state.copyWith(user: user, isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Login failed. Please check credentials.',
      );
      return false;
    }
  }

  // Instant role switch for SIH evaluation & demos
  void switchDemoRole(UserRole role) {
    UserModel demoUser;
    switch (role) {
      case UserRole.farmer:
        demoUser = const UserModel(
          id: 'usr_farmer_101',
          name: 'Ramesh Patil',
          email: 'farmer@krishisetu.com',
          phone: '+91 98765 43210',
          role: UserRole.farmer,
          location: 'Dindori Farm Hub, Nashik',
          token: 'jwt_farmer_demo',
        );
        break;
      case UserRole.buyer:
        demoUser = const UserModel(
          id: 'usr_buyer_202',
          name: 'Reliance Fresh Bulk Hub',
          email: 'buyer@krishisetu.com',
          phone: '+91 98220 11223',
          role: UserRole.buyer,
          location: 'Vashi Wholesale Terminal, Navi Mumbai',
          token: 'jwt_buyer_demo',
        );
        break;
      case UserRole.driver:
        demoUser = const UserModel(
          id: 'usr_driver_303',
          name: 'Santosh Shinde',
          email: 'driver@krishisetu.com',
          phone: '+91 94231 88776',
          role: UserRole.driver,
          location: 'Nashik Central Logistics Yard',
          token: 'jwt_driver_demo',
        );
        break;
      case UserRole.guest:
        state = state.copyWith(clearUser: true);
        return;
    }
    state = state.copyWith(user: demoUser, isLoading: false);
  }

  void logout() {
    state = const AuthState();
  }
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthNotifier(apiClient);
});
