import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/services.dart';
import '../../utils/app_constants.dart';
import '../../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await _updateUserLastActive(credential.user!.uid);
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await credential.user!.updateDisplayName(displayName);
        await _createUserDocument(
          credential.user!.uid,
          displayName: displayName,
          email: email,
        );
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      if (Firebase.apps.isEmpty) {
        throw Exception('Firebase is not initialized. Please restart the app.');
      }

      try {
        await _googleSignIn.signOut();
      } catch (e) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign in was cancelled');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception('Failed to get Google ID token. Make sure SHA-1 fingerprint is configured in Firebase Console.');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        final userDoc = await _firestore
            .collection(AppConstants.collectionUsers)
            .doc(userCredential.user!.uid)
            .get();

        if (!userDoc.exists) {
          await _createUserDocument(
            userCredential.user!.uid,
            displayName: userCredential.user!.displayName,
            email: userCredential.user!.email,
            profilePicture: userCredential.user!.photoURL,
          );
        } else {
          await _updateUserLastActive(userCredential.user!.uid);
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Google sign in failed: ${e.message ?? e.code}';
      if (e.code == 'account-exists-with-different-credential') {
        errorMessage = 'An account already exists with a different sign-in method.';
      } else if (e.code == 'invalid-credential') {
        errorMessage = 'Invalid credentials. Please try again.';
      }
      throw Exception(errorMessage);
    } on PlatformException catch (e) {
      String errorMessage = 'Google sign in failed';
      if (e.code == 'sign_in_failed') {
        if (e.message?.contains('10') == true || e.message?.contains('DEVELOPER_ERROR') == true) {
          errorMessage = 'Google Sign-In configuration error. Please ensure:\n'
              '1. SHA-1 fingerprint is added in Firebase Console\n'
              '2. Google Sign-In is enabled in Firebase Authentication\n'
              '3. google-services.json is up to date';
        } else {
          errorMessage = 'Google sign in failed: ${e.message ?? e.code}';
        }
      } else {
        errorMessage = 'Google sign in failed: ${e.message ?? e.code}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Google sign in failed: $e');
    }
  }

  Future<UserCredential> signInWithFacebook() async {
    try {
      if (Firebase.apps.isEmpty) {
        throw Exception('Firebase is not initialized. Please restart the app.');
      }

      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status != LoginStatus.success) {
        if (result.status == LoginStatus.cancelled) {
          throw Exception('Facebook sign in was cancelled');
        }
        throw Exception('Facebook sign in failed: ${result.message ?? 'Unknown error'}');
      }

      if (result.accessToken == null) {
        throw Exception('Failed to get Facebook access token');
      }

      final OAuthCredential facebookAuthCredential =
          FacebookAuthProvider.credential(result.accessToken!.tokenString);

      final userCredential = await _auth.signInWithCredential(facebookAuthCredential);

      if (userCredential.user != null) {
        final userData = await FacebookAuth.instance.getUserData();

        final userDoc = await _firestore
            .collection(AppConstants.collectionUsers)
            .doc(userCredential.user!.uid)
            .get();

        if (!userDoc.exists) {
          await _createUserDocument(
            userCredential.user!.uid,
            displayName: userData['name'] ?? userCredential.user!.displayName,
            email: userCredential.user!.email ?? userData['email'],
            profilePicture: userData['picture']?['data']?['url'] ?? userCredential.user!.photoURL,
          );
        } else {
          await _updateUserLastActive(userCredential.user!.uid);
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw Exception('Facebook sign in failed: ${e.message ?? e.code}');
    } catch (e) {
      throw Exception('Facebook sign in failed: $e');
    }
  }

  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(UserCredential) onVerificationComplete,
    required Function(String) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          final userCredential = await _auth.signInWithCredential(credential);
          onVerificationComplete(userCredential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(_handleAuthException(e).toString());
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<UserCredential> verifyOTP({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        final userDoc = await _firestore
            .collection(AppConstants.collectionUsers)
            .doc(userCredential.user!.uid)
            .get();

        if (!userDoc.exists) {
          await _createUserDocument(
            userCredential.user!.uid,
            phoneNumber: userCredential.user!.phoneNumber,
          );
        } else {
          await _updateUserLastActive(userCredential.user!.uid);
        }
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
      FacebookAuth.instance.logOut(),
    ]);
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');

    final updates = <String, dynamic>{};
    if (displayName != null) {
      await user.updateDisplayName(displayName);
      updates['displayName'] = displayName;
    }
    if (photoURL != null) {
      await user.updatePhotoURL(photoURL);
      updates['profilePicture'] = photoURL;
    }

    if (updates.isNotEmpty) {
      await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(user.uid)
          .update(updates);
    }
  }

  Future<UserModel?> getUserModel(String uid) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.collectionUsers)
          .doc(uid)
          .get();

      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _createUserDocument(
    String uid, {
    String? displayName,
    String? email,
    String? phoneNumber,
    String? profilePicture,
  }) async {
    final userModel = UserModel(
      uid: uid,
      displayName: displayName,
      email: email,
      phoneNumber: phoneNumber,
      profilePicture: profilePicture,
      createdAt: DateTime.now(),
      lastActive: DateTime.now(),
      isOnline: true,
    );

    await _firestore
        .collection(AppConstants.collectionUsers)
        .doc(uid)
        .set(userModel.toFirestore());
  }

  Future<void> _updateUserLastActive(String uid) async {
    await _firestore
        .collection(AppConstants.collectionUsers)
        .doc(uid)
        .update({
      'lastActive': Timestamp.now(),
      'isOnline': true,
    });
  }

  Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return Exception('The password provided is too weak.');
      case 'email-already-in-use':
        return Exception('An account already exists for that email.');
      case 'user-not-found':
        return Exception('No user found for that email.');
      case 'wrong-password':
        return Exception('Wrong password provided.');
      case 'invalid-email':
        return Exception('Invalid email address.');
      case 'user-disabled':
        return Exception('This account has been disabled.');
      case 'too-many-requests':
        return Exception('Too many requests. Please try again later.');
      case 'operation-not-allowed':
        return Exception('This operation is not allowed.');
      default:
        return Exception(e.message ?? 'An error occurred during authentication.');
    }
  }
}
