// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = false;

  User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    // Listen to auth state changes
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      if (user != null) {
        _loadUserData(user.uid);
      } else {
        _userData = null;
        notifyListeners();
      }
    });
  }

  Future<void> _loadUserData(String uid) async {
    _isLoading = true;
    notifyListeners();
    try {
      _userData = await _authService.getUserData(uid);
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== SIGN UP ====================
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final user = await _authService.signUp(
        email: email,
        password: password,
        name: name,
      );
      if (user != null) {
        _user = user;
        await _loadUserData(user.uid);
        return true;
      }
      return false;
    } catch (e) {
      print('Sign-up error in provider: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== SIGN IN ====================
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final user = await _authService.signIn(
        email: email,
        password: password,
      );
      if (user != null) {
        _user = user;
        await _loadUserData(user.uid);
        return true;
      }
      return false;
    } catch (e) {
      print('Sign-in error in provider: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== LOGOUT ====================
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.logout();
      _user = null;
      _userData = null;
    } catch (e) {
      print('Logout error in provider: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== UPDATE PROFILE ====================
  Future<void> updateProfile({
    String? name,
    String? email,
    String? photo,
  }) async {
    if (_user == null) return;
    try {
      await _authService.updateUserProfile(
        uid: _user!.uid,
        name: name,
        email: email,
        photo: photo,
      );
      await _loadUserData(_user!.uid);
    } catch (e) {
      print('Update profile error: $e');
      rethrow;
    }
  }

  // ==================== CHANGE PASSWORD ====================
  // Firebase requires a "recent" sign-in before it will let you change a
  // password (security-sensitive operation), so we reauthenticate with the
  // current password first, then call updatePassword. Throws a
  // FirebaseAuthException on failure (e.g. wrong current password) so the UI
  // can show a specific error message.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final currentUser = _user;
    if (currentUser == null || currentUser.email == null) {
      throw FirebaseAuthException(
        code: 'no-user',
        message: 'No signed-in user found. Please log in again.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: currentUser.email!,
      password: currentPassword,
    );

    try {
      await currentUser.reauthenticateWithCredential(credential);
      await currentUser.updatePassword(newPassword);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(code: 'unknown', message: e.toString());
    }
  }

  // ==================== GET USER NAME (for quick access) ====================
  String get displayName => _userData?['name'] ?? _user?.displayName ?? 'User';

  // ==================== GET USER EMAIL ====================
  String get displayEmail => _userData?['email'] ?? _user?.email ?? '';

  // ==================== GET USER PHOTO ====================
  String get displayPhoto => _userData?['photo'] ?? '';

  // ==================== RESET PASSWORD ====================
  Future<void> resetPassword(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email: email);
    } catch (e) {
      rethrow;
    }
  }
}