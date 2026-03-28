import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> checkUserExists() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await _db.collection('users').doc(user.uid).get();
    return doc.exists;
  }

  Future<bool> usernameExists(String username) async {
    final result = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .get();
    return result.docs.isNotEmpty;
  }

  Future<void> createUser({
    required String username,
    required String avatar,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .set({
      'username': username,
      'avatar': avatar,
      'coins': 0,
      'rewardClaimed': false,
      'xp': 0,
      'streak': 1,
      'lastLoginDate': todayStr, // 🔥 Track last login for streak
      'totalWins': 0,
      'totalGamesPlayed': 0,
    });
  }

  /// Call this on every login/app open. Increments streak if user
  /// logged in yesterday, resets to 1 if they missed a day.
  Future<void> updateLoginStreak() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = _db.collection('users').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final lastLoginDate = data['lastLoginDate'] as String? ?? '';
    final currentStreak = (data['streak'] as num?)?.toInt() ?? 0;

    // Already logged in today — do nothing
    if (lastLoginDate == todayStr) return;

    // Check if last login was yesterday
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    int newStreak;
    if (lastLoginDate == yesterdayStr) {
      // Consecutive day → increment
      newStreak = currentStreak + 1;
    } else {
      // Missed a day → reset
      newStreak = 1;
    }

    await docRef.update({
      'streak': newStreak,
      'lastLoginDate': todayStr,
    });
  }

  /// Award XP and coins to the current user after winning/completing a game.
  Future<void> awardXpAndCoins({required int xp, required int coins}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({
      'xp': FieldValue.increment(xp),
      'coins': FieldValue.increment(coins),
      'totalGamesPlayed': FieldValue.increment(1),
    });
  }

  /// Award a win (called only for the actual winner in 1v1).
  Future<void> awardWin({required int coins, required int xp}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({
      'coins': FieldValue.increment(coins),
      'xp': FieldValue.increment(xp),
      'totalWins': FieldValue.increment(1),
      'totalGamesPlayed': FieldValue.increment(1),
    });
  }
}