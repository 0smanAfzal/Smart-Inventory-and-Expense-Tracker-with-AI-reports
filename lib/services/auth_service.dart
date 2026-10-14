// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user from Firebase Auth
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ==================== SIGN UP ====================
  Future<User?> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // 1. Create auth user
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user != null) {
        // 2. Save user data to Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'photo': '',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 3. Update display name in Firebase Auth (optional)
        await user.updateDisplayName(name);
        await user.reload();
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print('Sign-up error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Sign-up error: $e');
      rethrow;
    }
  }

  // ==================== SIGN IN ====================
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('Sign-in error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Sign-in error: $e');
      rethrow;
    }
  }

  // ==================== LOGOUT ====================
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Logout error: $e');
      rethrow;
    }
  }

  // ==================== GET USER DATA FROM FIRESTORE ====================
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        // Make sure we return the name and email
        return {
          'uid': uid,
          'name': data?['name'] ?? 'Unknown',
          'email': data?['email'] ?? '',
          'photo': data?['photo'] ?? '',
        };
      }
      return null;
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }

  // ==================== UPDATE USER PROFILE ====================
  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? email,
    String? photo,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name;
      if (email != null) updates['email'] = email;
      if (photo != null) updates['photo'] = photo;

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updates);
      }
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  // ==================== SEND PASSWORD RESET EMAIL ====================
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      print('Password reset error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Password reset error: $e');
      rethrow;
    }
  }
}