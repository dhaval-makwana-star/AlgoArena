import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Email Signup
  Future<User?> signUp(String email, String password) async {
    try {
      final userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCred.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_friendlyAuthError(e.code));
    } catch (e) {
      throw Exception("Signup failed. Please try again.");
    }
  }

  // Email Login
  Future<User?> login(String email, String password) async {
    try {
      final userCred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCred.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(_friendlyAuthError(e.code));
    } catch (e) {
      throw Exception("Login failed. Please try again.");
    }
  }

  // Google Sign-In — returns null silently on cancel (no error shown)
  Future<User?> signInWithGoogle() async {
    try {
      await _googleSignIn.initialize();
      final GoogleSignInAccount account = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = account.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      return userCred.user;

    } on GoogleSignInException catch (e) {
      // User cancelled or dismissed the Google sign-in sheet — not an error
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return null; // silent return — show nothing to the user
      }
      throw Exception("Google Sign-In failed. Please try again.");
    } catch (e) {
      final msg = e.toString().toLowerCase();
      // Catch any other cancellation signals
      if (msg.contains('cancel') || msg.contains('dismissed') || msg.contains('aborted')) {
        return null;
      }
      throw Exception("Google Sign-In failed. Please try again.");
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  // Convert Firebase error codes to friendly messages
  String _friendlyAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}