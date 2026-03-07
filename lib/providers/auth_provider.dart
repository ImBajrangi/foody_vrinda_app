import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/resource_cache_service.dart';
import '../config/app_config.dart';

const String _userDataCacheKey = 'cached_user_data';

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthStatus _status = AuthStatus.uninitialized;
  User? _user;
  UserModel? _userData;
  String? _error;
  String? _lastErrorCode;

  AuthStatus get status => _status;
  User? get user => _user;
  UserModel? get userData => _userData;
  String? get error => _error;
  String? get lastErrorCode => _lastErrorCode;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _user != null;
  bool get isLoading => _status == AuthStatus.loading;

  // Check if current user is developer
  bool get isDeveloper =>
      _userData?.role == UserRole.developer ||
      AppConfig.isDeveloperEmail(_user?.email);

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    // Try to load cached user data immediately for faster startup
    await _loadCachedUserData();

    // Then listen for auth state changes (will sync from Firestore)
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  /// Load cached user data from SharedPreferences for instant startup
  Future<void> _loadCachedUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_userDataCacheKey);

      if (cachedJson != null) {
        final jsonData = json.decode(cachedJson) as Map<String, dynamic>;
        _userData = UserModel.fromJson(jsonData);

        // Check if there's a current Firebase user
        final currentUser = _authService.currentUser;
        if (currentUser != null && _userData != null) {
          _user = currentUser;
          _status = AuthStatus.authenticated;
          notifyListeners();
          print('AuthProvider: Loaded cached user data - ${_userData?.email}');
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

  Future<void> _onAuthStateChanged(User? user) async {
    print('AuthProvider: Auth state changed - user: ${user?.email}');

    if (user == null) {
      _status = AuthStatus.unauthenticated;
      _user = null;
      _userData = null;
      await _clearCachedUserData();
    } else {
      _user = user;

      // Check if developer email
      if (AppConfig.isDeveloperEmail(user.email)) {
        // Auto-assign developer role
        _userData = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName ?? 'Developer',
          photoURL: user.photoURL,
          role: UserRole.developer,
        );

        // Update Firestore with developer role - force sync
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
            'role': 'developer',
            if (user.displayName != null) 'displayName': user.displayName,
            if (user.photoURL != null) 'photoURL': user.photoURL,
            'lastSync': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          print('AuthProvider: Error updating developer role: $e');
        }

        print('AuthProvider: Developer account detected - ${user.email}');
      } else {
        // Regular user - fetch from Firestore
        _userData = await _authService.getUserData(user.uid);

        // If no user data exists or missing name, use from Google
        if (_userData == null) {
          _userData = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName,
            photoURL: user.photoURL,
            role: UserRole.customer,
          );
        } else if ((_userData!.displayName == null ||
                _userData!.displayName!.isEmpty) &&
            user.displayName != null &&
            user.displayName!.isNotEmpty) {
          _userData = _userData!.copyWith(
            displayName: user.displayName,
            photoURL: _userData!.photoURL ?? user.photoURL,
          );
        }
      }

      _status = AuthStatus.authenticated;
      print(
        'AuthProvider: Authenticated as ${_userData?.role.value} - ${user.email}',
      );

      // Trigger pre-caching for the user's role
      if (_userData != null) {
        ResourceCacheService().preCacheResources(_userData!.role);
        // Save user data to local cache for faster startup
        await _saveUserDataToCache(_userData!);
      }
    }
    notifyListeners();
  }

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      print('AuthProvider: Attempting email sign in for $email');
      await _authService.signInWithEmail(email, password);
      return true;
    } on FirebaseAuthException catch (e) {
      print('AuthProvider: FirebaseAuthException - ${e.code}: ${e.message}');
      _lastErrorCode = e.code;
      _error = _getFirebaseAuthError(e.code);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      print('AuthProvider: Sign in error - $e');
      _error = 'Sign in failed: ${e.toString().replaceAll('Exception: ', '')}';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUpWithEmail(String email, String password) async {
    try {
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      print('AuthProvider: Attempting email sign up for $email');
      await _authService.signUpWithEmail(email, password);
      return true;
    } on FirebaseAuthException catch (e) {
      print('AuthProvider: FirebaseAuthException - ${e.code}: ${e.message}');
      _lastErrorCode = e.code;
      _error = _getFirebaseAuthError(e.code);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      print('AuthProvider: Sign up error - $e');
      _error = 'Sign up failed: ${e.toString().replaceAll('Exception: ', '')}';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      print('AuthProvider: Attempting Google sign in');
      final result = await _authService.signInWithGoogle();

      if (result == null) {
        // User cancelled
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return false;
      }

      return true;
    } catch (e, stackTrace) {
      print('AuthProvider: Google sign in error - $e');
      print('AuthProvider: Google sign in stackTrace - $stackTrace');
      _error = 'Google sign in failed: ${e.toString()}';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> signInAnonymously() async {
    try {
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      await _authService.signInAnonymously();
    } catch (e) {
      print('AuthProvider: Anonymous sign in error - $e');
      _error = 'Failed to continue as guest';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      print('AuthProvider: Sign out error - $e');
      _error = 'Failed to sign out';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    _lastErrorCode = null;
    notifyListeners();
  }

  Future<void> refreshUserData() async {
    if (_user != null) {
      if (AppConfig.isDeveloperEmail(_user!.email)) {
        // Keep developer role
        _userData = _userData?.copyWith(role: UserRole.developer);
      } else {
        _userData = await _authService.getUserData(_user!.uid);
      }
      notifyListeners();
    }
  }

  String _getFirebaseAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'Email is already registered';
      case 'invalid-email':
        return 'Invalid email address';
      case 'weak-password':
        return 'Password is too weak';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later';
      case 'invalid-credential':
        return 'Invalid email or password';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled';
      case 'network-request-failed':
        return 'Network error. Please check your connection';
      default:
        return 'Authentication failed: $code';
    }
  }
}
