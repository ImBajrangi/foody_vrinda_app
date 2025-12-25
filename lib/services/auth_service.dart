import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign up with email and password
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Create user document in Firestore
    if (credential.user != null) {
      await _createUserDocument(credential.user!);
    }

    return credential;
  }

  // Sign in anonymously
  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user data from Firestore
  Future<UserModel?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Create or update user document
  Future<void> _createUserDocument(User user) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final doc = await userRef.get();

    if (!doc.exists) {
      final newUser = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName,
        photoURL: user.photoURL,
        role: UserRole.customer,
      );

      await userRef.set(newUser.toFirestore());
    } else {
      // Update last login
      await userRef.update({'lastLogin': FieldValue.serverTimestamp()});
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String uid,
    String? displayName,
    String? photoURL,
  }) async {
    final updates = <String, dynamic>{};

    if (displayName != null) updates['displayName'] = displayName;
    if (photoURL != null) updates['photoURL'] = photoURL;

    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update(updates);
    }
  }

  // Update user role (admin only)
  Future<void> updateUserRole({
    required String uid,
    required UserRole role,
    String? shopId,
    List<String>? shopIds,
  }) async {
    final updates = <String, dynamic>{'role': role.value};

    if (shopId != null) updates['shopId'] = shopId;
    if (shopIds != null) updates['shopIds'] = shopIds;

    await _firestore.collection('users').doc(uid).update(updates);
  }

  // Get all users (developer only)
  Future<List<UserModel>> getAllUsers() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
    } catch (e) {
      print('Error getting all users: $e');
      return [];
    }
  }

  // Listen to user document changes
  Stream<UserModel?> userStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }
}
