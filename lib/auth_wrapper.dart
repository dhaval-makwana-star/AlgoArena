import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';
import 'teacher_dashboard_screen.dart';
import 'firestore_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  // Returns: 'teacher' | 'student' | 'new' | null
  Future<String?> _detectRole(String uid) async {
    // 1. Check teacher collection first
    final teacherDoc = await FirebaseFirestore.instance
        .collection('teachers')
        .doc(uid)
        .get();
    if (teacherDoc.exists) return 'teacher';

    // 2. Check student collection
    final studentDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (studentDoc.exists) return 'student';

    // 3. Brand new user
    return 'new';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return _loadingScreen();
        }

        // Not logged in
        if (!authSnapshot.hasData) {
          return LoginScreen();
        }

        final uid = authSnapshot.data!.uid;

        return FutureBuilder<String?>(
          future: _detectRole(uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return _loadingScreen();
            }

            final role = roleSnapshot.data;

            if (role == 'teacher') {
              return TeacherDashboardScreen(user: authSnapshot.data!);
            }

            if (role == 'student') {
              return const DashboardScreen();
            }

            // New user → profile setup
            return const ProfileSetupScreen();
          },
        );
      },
    );
  }

  Widget _loadingScreen() {
    return const Scaffold(
      backgroundColor: Color(0xFF060818),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFF00D4FF),
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}