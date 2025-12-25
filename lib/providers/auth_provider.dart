import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.uninitialized;
  User? _user;
  UserModel? _userData;
  String? _error;

  AuthStatus get status => _status;
  User? get user => _user;
  UserModel? get userData => _userData;
  String? get error => _error;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _user != null;
  bool get isLoading => _status == AuthStatus.loading;

  AuthProvider() {
    _initAuth();
  }

  void _initAuth() {
    _authService.authStateChanges.listen(_onAuthStateChanged);
  }

  Future<void> _onAuthStateChanged(User? user) async {
    if (user == null) {
      _status = AuthStatus.unauthenticated;
      _user = null;
      _userData = null;
    } else {
      _user = user;
      _userData = await _authService.getUserData(user.uid);
      _status = AuthStatus.authenticated;

      // If no user data exists, create it
      if (_userData == null) {
        _userData = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          displayName: user.displayName,
          photoURL: user.photoURL,
          role: UserRole.customer,
        );
      }
    }
    notifyListeners();
  }

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _status = AuthStatus.loading;
      _error = null;
      notifyListeners();

      await _authService.signInWithEmail(email, password);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getFirebaseAuthError(e.code);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
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

      await _authService.signUpWithEmail(email, password);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getFirebaseAuthError(e.code);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'An unexpected error occurred';
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
      _error = 'Failed to continue as guest';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _authService.signOut();
    } catch (e) {
      _error = 'Failed to sign out';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> refreshUserData() async {
    if (_user != null) {
      _userData = await _authService.getUserData(_user!.uid);
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
      default:
        return 'Authentication failed. Please try again';
    }
  }
}
