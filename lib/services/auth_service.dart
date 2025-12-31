import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_model.dart';
import '../config/app_config.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize GoogleSignIn with Web Client ID
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '166281611781-vh09rl3hjcb0872gulpd2oi6ut9nh16n.apps.googleusercontent.com'
        : null,
    serverClientId:
        '166281611781-vh09rl3hjcb0872gulpd2oi6ut9nh16n.apps.googleusercontent.com',
    scopes: ['email', 'https://www.googleapis.com/auth/userinfo.profile'],
  );

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create/update user document
      if (credential.user != null) {
        await _createOrUpdateUserDocument(credential.user!);
      }

      return credential;
    } catch (e) {
      print('AuthService: signInWithEmail error: $e');
      rethrow;
    }
  }

  // Sign up with email and password
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      if (credential.user != null) {
        await _createOrUpdateUserDocument(credential.user!);
      }

      return credential;
    } catch (e) {
      print('AuthService: signUpWithEmail error: $e');
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Optimized for Web
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        // Use signInWithPopup for best web UX
        final userCredential = await _auth.signInWithPopup(googleProvider);

        if (userCredential.user != null) {
          await _createOrUpdateUserDocument(userCredential.user!);
        }
        return userCredential;
      } else {
        // Trigger the mobile authentication flow
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        if (googleUser == null) {
          print('AuthService: Google sign in cancelled by user');
          return null;
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);

        if (userCredential.user != null) {
          await _createOrUpdateUserDocument(userCredential.user!);
        }

        print(
          'AuthService: Google sign in successful - ${userCredential.user?.email}',
        );
        return userCredential;
      }
    } catch (e) {
      print('AuthService: signInWithGoogle error: $e');
      rethrow;
    }
  }

  // Sign in anonymously
  Future<UserCredential> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      print('AuthService: Anonymous sign in successful');
      return credential;
    } catch (e) {
      print('AuthService: signInAnonymously error: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Try to sign out from Google but don't let it block Firebase sign out
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        print('AuthService: Google sign out error (ignoring): $e');
      }

      await _auth.signOut();
      print('AuthService: Sign out successful');
    } catch (e) {
      print('AuthService: signOut error: $e');
      rethrow;
    }
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
      print('AuthService: getUserData error: $e');
      return null;
    }
  }

  // Create or update user document
  Future<void> _createOrUpdateUserDocument(User user) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final doc = await userRef.get();

      // Determine role
      String role = 'customer';
      if (AppConfig.isDeveloperEmail(user.email)) {
        role = 'developer';
      } else if (doc.exists) {
        // Keep existing role
        role = doc.data()?['role'] ?? 'customer';
      }

      if (!doc.exists) {
        // Check if a document with this email already exists (pre-created staff)
        final preCreatedQuery = await _firestore
            .collection('users')
            .where('email', isEqualTo: user.email?.toLowerCase())
            .where('isPreCreated', isEqualTo: true)
            .limit(1)
            .get();

        Map<String, dynamic>? preCreatedData;
        if (preCreatedQuery.docs.isNotEmpty) {
          preCreatedData = preCreatedQuery.docs.first.data();
          role = preCreatedData['role'] ?? 'customer';
          print(
            'AuthService: Found pre-created record for ${user.email} with role $role',
          );

          // Delete the temporary pre-created document
          await preCreatedQuery.docs.first.reference.delete();
        }

        // Create new user document
        await userRef.set({
          'uid': user.uid,
          'email': user.email ?? '',
          'displayName': user.displayName ?? preCreatedData?['displayName'],
          'phoneNumber': preCreatedData?['phoneNumber'],
          'photoURL': user.photoURL,
          'role': role,
          'shopId':
              preCreatedData?['shopId'] ?? (role == 'developer' ? null : null),
          'shopIds': preCreatedData?['shopIds'],
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'lastSync': FieldValue.serverTimestamp(),
        });
        print('AuthService: Created new user document for ${user.email}');
      } else {
        // Update existing user - only update if the new values are not null
        final Map<String, dynamic> updates = {
          'lastLogin': FieldValue.serverTimestamp(),
          'lastSync': FieldValue.serverTimestamp(),
        };

        if (user.displayName != null && user.displayName!.isNotEmpty) {
          updates['displayName'] = user.displayName;
        }
        if (user.photoURL != null && user.photoURL!.isNotEmpty) {
          updates['photoURL'] = user.photoURL;
        }
        if (AppConfig.isDeveloperEmail(user.email)) {
          updates['role'] = 'developer';
        }

        if (updates.length > 2) {
          // More than just timestamps
          await userRef.update(updates);
        } else {
          await userRef.update(updates);
        }
        print('AuthService: Updated user document for ${user.email}');
      }
    } catch (e) {
      print('AuthService: _createOrUpdateUserDocument error: $e');
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
      print('AuthService: getAllUsers error: $e');
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

  // Check if user is signed in with Google
  Future<bool> isSignedInWithGoogle() async {
    return await _googleSignIn.isSignedIn();
  }
}
