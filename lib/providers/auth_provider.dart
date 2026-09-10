import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../services/supabase_service.dart';
import '../services/resource_cache_service.dart';
import '../services/order_notification_manager.dart';
import '../services/kitchen_alarm_service.dart';
import '../services/delivery_alarm_service.dart';
import '../config/app_config.dart';

const String _userDataCacheKey = 'cached_user_data';

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();

  AuthStatus _status = AuthStatus.uninitialized;
  sb.User? _supabaseUser;
  UserModel? _userData;
  String? _error;
  String? _lastErrorCode;

  AuthStatus get status => _status;
  sb.User? get user => _supabaseUser;
  UserModel? get userData => _userData;
  String? get error => _error;
  String? get lastErrorCode => _lastErrorCode;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _userData != null;
  bool get isLoading => _status == AuthStatus.loading;

  // Check if current user is developer or admin
  bool get isDeveloper =>
      _userData?.role == UserRole.developer ||
      AppConfig.isDeveloperEmail(_supabaseUser?.email ?? _userData?.email);

  bool get isAdmin =>
      _userData?.role == UserRole.owner ||
      _userData?.role == UserRole.developer ||
      AppConfig.isAdminEmail(_supabaseUser?.email ?? _userData?.email);

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    // 1. Try to load cached user data immediately for zero-latency startup
    await _loadCachedUserData();

    // 2. Listen to Supabase Auth State Changes
    try {
      _supabaseService.client.auth.onAuthStateChange.listen((data) {
        _onSupabaseAuthStateChanged(data.session?.user);
      });
    } catch (e) {
      print('AuthProvider: Supabase auth state listener notice: $e');
    }
  }

  /// Load cached user data from SharedPreferences for instant startup
  Future<void> _loadCachedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_userDataCacheKey);

      if (cachedJson != null) {
        final jsonData = json.decode(cachedJson) as Map<String, dynamic>;
        _userData = UserModel.fromJson(jsonData);

        if (_userData != null) {
          _status = AuthStatus.authenticated;
          notifyListeners();
          print('AuthProvider: Loaded cached user data - ${_userData?.displayName ?? _userData?.email ?? _userData?.phoneNumber}');
        }
      }
    } catch (e) {
      print('AuthProvider: Error loading cached user data: $e');
    }
  }

  /// Save user data to SharedPreferences for faster startup
  Future<void> _saveUserDataToCache(UserModel userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userDataCacheKey, json.encode(userData.toJson()));
      print('AuthProvider: Saved user data to cache');
    } catch (e) {
      print('AuthProvider: Error saving user data to cache: $e');
    }
  }

  /// Clear cached user data on sign out
  Future<void> _clearCachedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userDataCacheKey);
      print('AuthProvider: Cleared cached user data');
    } catch (e) {
      print('AuthProvider: Error clearing cached user data: $e');
    }
  }

  Future<void> _onSupabaseAuthStateChanged(sb.User? sbUser) async {
    print('AuthProvider: Supabase auth state changed - user: ${sbUser?.email}');

    if (sbUser == null) {
      if (_userData != null && _userData!.phoneNumber != null && _userData!.phoneNumber!.isNotEmpty) {
        // Phone-authenticated user remains active
        return;
      }
      _status = AuthStatus.unauthenticated;
      _supabaseUser = null;
      _userData = null;
      await _clearCachedUserData();
    } else {
      _supabaseUser = sbUser;
      final email = sbUser.email ?? '';

      // Check if developer email
      if (AppConfig.isDeveloperEmail(email)) {
        _userData = UserModel(
          uid: sbUser.id,
          email: email,
          displayName: sbUser.userMetadata?['displayName'] ??
              sbUser.userMetadata?['full_name'] ??
              'Developer',
          photoURL: sbUser.userMetadata?['avatar_url'],
          role: UserRole.developer,
        );
      } else {
        // Check live Supabase record
        Map<String, dynamic>? liveProfile;
        try {
          liveProfile = await _supabaseService.getLiveUserRoleAndProfile(
            userId: sbUser.id,
            email: email,
          );
        } catch (_) {}

        if (liveProfile != null) {
          _userData = UserModel(
            uid: liveProfile['id'] ?? sbUser.id,
            email: liveProfile['email'] ?? email,
            displayName: liveProfile['display_name'] ??
                sbUser.userMetadata?['displayName'] ??
                'Devotee',
            photoURL: liveProfile['avatar_url'] ?? sbUser.userMetadata?['avatar_url'],
            phoneNumber: liveProfile['phone'],
            deliveryAddress: liveProfile['address'] ?? liveProfile['customer_address'],
            role: UserRoleExtension.fromString(liveProfile['role']),
            shopId: liveProfile['shop_id'],
          );
        } else {
          _userData = UserModel(
            uid: sbUser.id,
            email: email,
            displayName: sbUser.userMetadata?['displayName'] ??
                sbUser.userMetadata?['full_name'] ??
                (email.isNotEmpty ? email.split('@')[0] : 'Devotee'),
            photoURL: sbUser.userMetadata?['avatar_url'],
            role: AppConfig.isAdminEmail(email) ? UserRole.owner : UserRole.customer,
          );
        }
      }

      _status = AuthStatus.authenticated;
      if (_userData != null) {
        ResourceCacheService().preCacheResources(_userData!.role);
        await _saveUserDataToCache(_userData!);
        OrderNotificationManager().startListening(
          userRole: _userData!.role,
          shopId: _userData!.shopId,
          userId: _userData!.uid,
        );
      }
    }
    notifyListeners();
  }

  /// 1. PHONE LOOKUP SIGN IN (Pure Supabase - matching web v3)
  Future<bool> signInWithPhoneLookup(String phoneNumber) async {
    try {
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      final clean = phoneNumber.replaceAll(RegExp(r'\D'), '');
      if (clean.length < 10) {
        _error = 'Please enter a valid 10-digit mobile number';
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }

      final profile = await _supabaseService.loginWithPhoneLookup(clean);

      _userData = UserModel(
        uid: profile['id'] ?? 'user-$clean',
        email: profile['email'] ?? '',
        displayName: profile['display_name'] ?? 'Customer (${clean.substring(clean.length - 4)})',
        phoneNumber: profile['phone'] ?? clean.substring(clean.length - 10),
        deliveryAddress: profile['address'] ?? profile['customer_address'],
        photoURL: profile['avatar_url'],
        role: UserRoleExtension.fromString(profile['role']),
        shopId: profile['shop_id'] ?? 'shop-vrinda-main',
        shopIds: profile['shop_ids'] != null
            ? List<String>.from(profile['shop_ids'])
            : (profile['shop_id'] != null ? [profile['shop_id']] : ['shop-vrinda-main']),
      );

      _status = AuthStatus.authenticated;
      await _saveUserDataToCache(_userData!);
      ResourceCacheService().preCacheResources(_userData!.role);
      OrderNotificationManager().startListening(
        userRole: _userData!.role,
        shopId: _userData!.shopId,
        userId: _userData!.uid,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// 2. EMAIL SIGN IN (Pure Supabase Auth + Cloud Users)
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      final cleanEmail = email.trim().toLowerCase();
      print('AuthProvider: Attempting Supabase email sign in for $cleanEmail');

      try {
        final res = await _supabaseService.client.auth.signInWithPassword(
          email: cleanEmail,
          password: password,
        );
        if (res.user != null) {
          _supabaseUser = res.user;
          await _onSupabaseAuthStateChanged(res.user);
          return true;
        }
      } catch (sbErr) {
        print('Supabase direct auth note: $sbErr, checking foody_logged_users...');
      }

      // Check Supabase cloud user table
      final cloudProfile = await _supabaseService.getLiveUserRoleAndProfile(email: cleanEmail);
      if (cloudProfile != null) {
        _userData = UserModel(
          uid: cloudProfile['id'] ?? 'user-${DateTime.now().millisecondsSinceEpoch}',
          email: cloudProfile['email'] ?? cleanEmail,
          displayName: cloudProfile['display_name'] ?? cleanEmail.split('@')[0],
          phoneNumber: cloudProfile['phone'],
          deliveryAddress: cloudProfile['address'] ?? cloudProfile['customer_address'],
          photoURL: cloudProfile['avatar_url'],
          role: UserRoleExtension.fromString(cloudProfile['role']),
          shopId: cloudProfile['shop_id'] ?? 'shop-vrinda-main',
        );

        _status = AuthStatus.authenticated;
        await _saveUserDataToCache(_userData!);
        notifyListeners();
        return true;
      }

      _error = 'Invalid email or password. If new, please register below.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Sign in failed: ${e.toString().replaceAll('Exception: ', '')}';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// 3. STEP-BY-STEP EMAIL SIGN UP (Pure Supabase Auth)
  Future<bool> signUpWithEmail(
    String email,
    String password, {
    String? displayName,
    String? phoneNumber,
    String? deliveryAddress,
  }) async {
    try {
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      final cleanEmail = email.trim().toLowerCase();
      final cleanPhone = (phoneNumber ?? '').replaceAll(RegExp(r'\D'), '');

      String uid = 'user-${DateTime.now().millisecondsSinceEpoch}';

      try {
        final res = await _supabaseService.client.auth.signUp(
          email: cleanEmail,
          password: password,
          data: {
            'displayName': displayName ?? cleanEmail.split('@')[0],
            'phone': cleanPhone,
            'address': deliveryAddress ?? '',
          },
        );
        if (res.user != null) {
          uid = res.user!.id;
          _supabaseUser = res.user;
        }
      } catch (sbErr) {
        print('Supabase signup notice: $sbErr');
      }

      // Create in Supabase Cloud table
      final userProfile = {
        'id': uid,
        'email': cleanEmail,
        'displayName': displayName ?? cleanEmail.split('@')[0],
        'phone': cleanPhone,
        'address': deliveryAddress ?? '',
        'role': 'customer',
        'shopId': 'shop-vrinda-main',
      };

      await _supabaseService.createCloudUser(userProfile);

      _userData = UserModel(
        uid: uid,
        email: cleanEmail,
        displayName: displayName ?? cleanEmail.split('@')[0],
        phoneNumber: cleanPhone,
        deliveryAddress: deliveryAddress,
        role: UserRole.customer,
        shopId: 'shop-vrinda-main',
      );

      _status = AuthStatus.authenticated;
      await _saveUserDataToCache(_userData!);
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Sign up failed: ${e.toString().replaceAll('Exception: ', '')}';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// 4. GOOGLE SIGN IN (Pure Supabase OAuth)
  Future<bool> signInWithGoogle() async {
    try {
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      print('AuthProvider: Attempting Supabase Google OAuth sign in');
      final res = await _supabaseService.client.auth.signInWithOAuth(
        sb.OAuthProvider.google,
        redirectTo: 'https://eat.vrindopnishad.in/',
      );

      if (!res) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }

      return true;
    } catch (e) {
      print('AuthProvider: Google sign in notice - $e');
      _error = 'Google sign in unavailable in current browser session. Please sign in with Mobile number or Email.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// 5. GUEST SIGN IN
  Future<void> signInAnonymously() async {
    try {
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      _userData = UserModel(
        uid: 'guest-${DateTime.now().millisecondsSinceEpoch}',
        email: '',
        displayName: 'Devotee Guest',
        role: UserRole.customer,
      );
      _status = AuthStatus.authenticated;
      await _saveUserDataToCache(_userData!);
      notifyListeners();
    } catch (e) {
      _error = 'Failed to continue as guest';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  /// 6. OPERATIONAL ROLE SWITCHER (Dev & Admin)
  Future<void> switchRole(UserRole newRole, {String? shopId}) async {
    if (_userData == null) return;
    _userData = _userData!.copyWith(
      role: newRole,
      shopId: shopId ?? _userData!.shopId ?? 'shop-vrinda-main',
    );
    await _saveUserDataToCache(_userData!);
    ResourceCacheService().preCacheResources(newRole);
    KitchenAlarmService().acknowledgeAll();
    DeliveryAlarmService().acknowledgeAll();
    OrderNotificationManager().startListening(
      userRole: newRole,
      shopId: shopId ?? _userData!.shopId,
      userId: _userData!.uid,
    );

    if (_userData!.uid.isNotEmpty) {
      final updates = <String, dynamic>{
        'role': newRole.value,
      };
      if (shopId != null) {
        updates['shop_id'] = shopId;
      }
      _supabaseService.updateCloudUser(_userData!.uid, updates).catchError((_) {});
    }
    notifyListeners();
  }

  /// 7. SIGN OUT (Pure Supabase)
  Future<void> signOut() async {
    try {
      await _supabaseService.client.auth.signOut();
    } catch (e) {
      print('AuthProvider: Supabase sign out notice - $e');
    }
    OrderNotificationManager().stopListening();
    KitchenAlarmService().acknowledgeAll();
    DeliveryAlarmService().acknowledgeAll();
    _supabaseUser = null;
    _userData = null;
    _status = AuthStatus.unauthenticated;
    await _clearCachedUserData();
    notifyListeners();
  }

  /// 8. UPDATE PROFILE (Name, Phone, Delivery Address)
  Future<void> updateProfile({
    required String displayName,
    required String phoneNumber,
    required String deliveryAddress,
  }) async {
    if (_userData == null) return;
    try {
      _status = AuthStatus.loading;
      notifyListeners();

      final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');

      if (_userData!.uid.isNotEmpty) {
        await _supabaseService.updateCloudUser(_userData!.uid, {
          'display_name': displayName.trim(),
          'phone': cleanPhone,
          'customer_address': deliveryAddress.trim(),
          'address': deliveryAddress.trim(),
        });
      }

      _userData = _userData!.copyWith(
        displayName: displayName.trim(),
        phoneNumber: cleanPhone,
        deliveryAddress: deliveryAddress.trim(),
      );

      await _saveUserDataToCache(_userData!);
      _status = AuthStatus.authenticated;
      notifyListeners();
    } catch (e) {
      _status = AuthStatus.authenticated;
      _error = 'Failed to update profile: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    _lastErrorCode = null;
    notifyListeners();
  }

  Future<void> refreshUserData() async {
    if (_supabaseUser != null) {
      if (AppConfig.isDeveloperEmail(_supabaseUser!.email)) {
        _userData = _userData?.copyWith(role: UserRole.developer);
      } else {
        final profile = await _supabaseService.getLiveUserRoleAndProfile(userId: _supabaseUser!.id);
        if (profile != null) {
          _userData = UserModel(
            uid: profile['id'] ?? _supabaseUser!.id,
            email: profile['email'] ?? _supabaseUser!.email ?? '',
            displayName: profile['display_name'] ?? 'Devotee',
            phoneNumber: profile['phone'],
            deliveryAddress: profile['address'] ?? profile['customer_address'],
            role: UserRoleExtension.fromString(profile['role']),
            shopId: profile['shop_id'],
          );
        }
      }
      notifyListeners();
    }
  }
}
