import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../utils/app_constants.dart';
import '../../models/user_model.dart';
import '../../supabase_config.dart';

class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb 
        ? SupabaseConfig.googleWebClientId 
        : (defaultTargetPlatform == TargetPlatform.iOS 
            ? SupabaseConfig.googleIosClientId 
            : null),
    serverClientId: SupabaseConfig.googleWebClientId,
    scopes: ['email', 'profile', 'openid'],
  );

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _updateUserLastActive(response.user!.id);
      }

      return response;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<AuthResponse> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'display_name': displayName,
        },
      );

      if (response.user != null) {
        await _createUserDocument(
          response.user!.id,
          displayName: displayName,
          email: email,
        );
      }

      return response;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<AuthResponse> signInWithGoogle() async {
    try {
      // Sign out first to ensure fresh login
      try {
        await _googleSignIn.signOut();
      } catch (e) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google sign in was cancelled');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.idToken == null) {
        throw Exception('Failed to get Google ID token.');
      }

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      if (response.user != null) {
        final userDoc = await _supabase
            .from(AppConstants.collectionUsers)
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();

        if (userDoc == null) {
          await _createUserDocument(
            response.user!.id,
            displayName: response.user!.userMetadata?['full_name'] ?? googleUser.displayName,
            email: response.user!.email,
            profilePicture: response.user!.userMetadata?['avatar_url'],
          );
        } else {
          await _updateUserLastActive(response.user!.id);
        }
      }

      return response;
    } on AuthException catch (e) {
      String errorMessage = 'Google sign in failed: ${e.message}';
      throw Exception(errorMessage);
    } on PlatformException catch (e) {
      String errorMessage = 'Google sign in failed';
      if (e.code == 'sign_in_failed') {
        errorMessage = 'Google Sign-In configuration error. Please ensure configuration is correct.';
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Google sign in failed: $e');
    }
  }

  Future<AuthResponse> signInWithFacebook() async {
    try {
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

      final response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.facebook,
        idToken: result.accessToken!.tokenString,
      );

      if (response.user != null) {
        final userData = await FacebookAuth.instance.getUserData();

        final userDoc = await _supabase
            .from(AppConstants.collectionUsers)
            .select()
            .eq('id', response.user!.id)
            .maybeSingle();

        if (userDoc == null) {
          await _createUserDocument(
            response.user!.id,
            displayName: userData['name'] ?? response.user!.userMetadata?['full_name'],
            email: response.user!.email ?? userData['email'],
            profilePicture: userData['picture']?['data']?['url'],
          );
        } else {
          await _updateUserLastActive(response.user!.id);
        }
      }

      return response;
    } on AuthException catch (e) {
      throw Exception('Facebook sign in failed: ${e.message}');
    } catch (e) {
      throw Exception('Facebook sign in failed: $e');
    }
  }

  Future<void> signOut() async {
    await Future.wait([
      _supabase.auth.signOut(),
      _googleSignIn.signOut(),
      FacebookAuth.instance.logOut(),
    ]);
  }

  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('No user signed in');

    final updates = <String, dynamic>{};
    if (displayName != null) {
      updates['display_name'] = displayName;
    }
    if (photoURL != null) {
      updates['avatar_url'] = photoURL;
    }

    if (updates.isNotEmpty) {
      await _supabase.auth.updateUser(
        UserAttributes(
          data: updates,
        ),
      );

      // Also update in users table
      await _supabase
          .from(AppConstants.collectionUsers)
          .update({
            if (displayName != null) 'display_name': displayName,
            if (photoURL != null) 'profile_picture': photoURL,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);
    }
  }

  Future<UserModel?> getUserModel(String uid) async {
    try {
      final doc = await _supabase
          .from(AppConstants.collectionUsers)
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (doc != null) {
        return UserModel.fromMap(doc);
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

    await _supabase
        .from(AppConstants.collectionUsers)
        .insert(userModel.toMap());
  }

  Future<void> _updateUserLastActive(String uid) async {
    await _supabase
        .from(AppConstants.collectionUsers)
        .update({
          'last_active': DateTime.now().toIso8601String(),
          'is_online': true,
        })
        .eq('id', uid);
  }

  Exception _handleAuthException(AuthException e) {
    final message = e.message.toLowerCase();
    
    if (message.contains('password') && message.contains('weak')) {
      return Exception('The password provided is too weak.');
    } else if (message.contains('already') && message.contains('registered')) {
      return Exception('An account already exists for that email.');
    } else if (message.contains('not found') || message.contains('invalid')) {
      return Exception('Invalid email or password.');
    } else if (message.contains('disabled')) {
      return Exception('This account has been disabled.');
    } else if (message.contains('many requests')) {
      return Exception('Too many requests. Please try again later.');
    } else {
      return Exception(e.message);
    }
  }
}
