import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'teacher_upload_screen.dart';
import 'teacher_course_detail_screen.dart';

class TeacherDashboardScreen extends StatefulWidget {
  final User user;
  const TeacherDashboardScreen({super.key, required this.user});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen>
    with TickerProviderStateMixin {
  int _selectedTab = 0;
  Map<String, dynamic>? _teacherData;
  late AnimationController _bgCtrl;
  late AnimationController _entryCtrl;
  late Animation<double> _entryAnim;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _entryAnim =
        CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _loadTeacherData();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTeacherData() async {
    final doc = await FirebaseFirestore.instance
        .collection('teachers')
        .doc(widget.user.uid)
        .get();
    if (mounted && doc.exists) {
      setState(() => _teacherData = doc.data());
      _entryCtrl.forward();
    }
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B3E),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out?',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text('You will be redirected to the login screen.',
            style: TextStyle(
                color: Colors.white.withOpacity(0.6), fontSize: 14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log out',
                  style: TextStyle(
                      color: Color(0xFFFF4757),
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm == true) {
      HapticFeedback.mediumImpact();
      await FirebaseAuth.instance.signOut();
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060818),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _TDashBgPainter(_bgCtrl.value),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                _buildStatsRow(),
                _buildTabBar(),
                Expanded(child: _buildTabContent()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedTab == 0 ? _buildFAB() : null,
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFFB347)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFFFF6B35).withOpacity(0.4),
                    blurRadius: 12)
              ],
            ),
            child: const Center(
                child: Text('🎓', style: TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hey, ${_teacherData?['name']?.split(' ').first ?? 'Instructor'}! 👋',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17),
                ),
                Text('Teacher Dashboard',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 12)),
              ],
            ),
          ),
          // Verified badge
          if (_teacherData?['isVerified'] == true)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: const Color(0xFF00C853).withOpacity(0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded,
                      color: Color(0xFF00C853), size: 12),
                  SizedBox(width: 4),
                  Text('Verified',
                      style: TextStyle(
                          color: Color(0xFF00C853),
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout_rounded,
                color: Colors.white54, size: 22),
            onPressed: _logout,
          ),
        ],
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .where('teacherId', isEqualTo: widget.user.uid)
          .snapshots(),
      builder: (_, snap) {
        final courses = snap.data?.docs ?? [];
        int totalStudents = 0;
        double totalRating = 0;
        for (final doc in courses) {
          final d = doc.data() as Map<String, dynamic>;
          totalStudents += (d['enrolledCount'] as int? ?? 0);
          totalRating += (d['rating'] as num? ?? 0).toDouble();
        }
        final avgRating =
        courses.isNotEmpty ? totalRating / courses.length : 0.0;

        return FadeTransition(
          opacity: _entryAnim,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                _statCard('📚', '${courses.length}', 'Courses',
                    const Color(0xFFFF6B35)),
                const SizedBox(width: 10),
                _statCard('👥', '$totalStudents', 'Students',
                    const Color(0xFF00D4FF)),
                const SizedBox(width: 10),
                _statCard('⭐', avgRating.toStringAsFixed(1), 'Avg Rating',
                    const Color(0xFFFFD700)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _statCard(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    final tabs = ['My Courses', 'Students', 'Analytics'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: List.generate(tabs.length, (i) {
            final active = _selectedTab == i;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTab = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: active
                        ? const LinearGradient(
                        colors: [Color(0xFFFF6B35), Color(0xFFFFB347)])
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      tabs[i],
                      style: TextStyle(
                        color: active ? Colors.white : Colors.white38,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 0:
        return _buildCoursesTab();
      case 1:
        return _buildStudentsTab();
      case 2:
        return _buildAnalyticsTab();
      default:
        return const SizedBox();
    }
  }

  // ── Courses tab ───────────────────────────────────────────────────────────
  // FIX: Removed `.orderBy('createdAt', descending: true)` from the Firestore
  // query — combining where() + orderBy() requires a composite Firestore index
  // that doesn't exist, causing the query to silently return 0 results.
  // We now sort the results in Dart instead, which works without any index.
  Widget _buildCoursesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .where('teacherId', isEqualTo: widget.user.uid)
      // ← orderBy removed here; sorting is done in Dart below
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
        }

        // Show Firestore errors in debug so you can catch future issues
        if (snap.hasError) {
          return Center(
            child: Text('Error: ${snap.error}',
                style: const TextStyle(color: Colors.redAccent)),
          );
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _buildEmptyState();

        // Sort by createdAt descending in Dart (newest first)
        final sorted = [...docs];
        sorted.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTs = aData['createdAt'];
          final bTs = bData['createdAt'];
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          // Firestore Timestamps are Comparable
          if (aTs is Timestamp && bTs is Timestamp) {
            return bTs.compareTo(aTs); // newest first
          }
          return 0;
        });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          itemCount: sorted.length,
          itemBuilder: (_, i) {
            final data = sorted[i].data() as Map<String, dynamic>;
            return _buildCourseCard(sorted[i].id, data);
          },
        );
      },
    );
  }

  Widget _buildCourseCard(String courseId, Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          // FIX: Wrap in StreamBuilder so the card data is always
          // fresh from Firestore when navigating to detail screen
          builder: (_) => StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('courses')
                .doc(courseId)
                .snapshots(),
            builder: (_, snap) {
              final liveData = snap.hasData && snap.data!.exists
                  ? (snap.data!.data() as Map<String, dynamic>)
                  : data; // fall back to passed data while loading
              return TeacherCourseDetailScreen(
                courseId: courseId,
                courseData: liveData,
              );
            },
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: _courseColors(data['category'] ?? '')),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      data['thumbnailEmoji'] ??
                          _categoryEmoji(data['category'] ?? ''),
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['title'] ?? 'Untitled Course',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(data['category'] ?? '',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12)),
                    ],
                  ),
                ),
                _statusBadge(data['status'] ?? 'draft'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _miniStat(Icons.play_circle_outline_rounded,
                    '${data['lecturesCount'] ?? 0} lectures'),
                const SizedBox(width: 16),
                _miniStat(Icons.people_outline_rounded,
                    '${data['enrolledCount'] ?? 0} enrolled'),
                const SizedBox(width: 16),
                _miniStat(Icons.star_outline_rounded,
                    '${(data['rating'] as num? ?? 0.0).toStringAsFixed(1)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 14),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.4), fontSize: 12)),
      ],
    );
  }

  Widget _statusBadge(String status) {
    final isPublished = status == 'published';
    final color =
    isPublished ? const Color(0xFF00C853) : const Color(0xFFFF6B35);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(isPublished ? 'Live' : 'Draft',
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📚', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('No courses yet',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20)),
          const SizedBox(height: 8),
          Text('Tap the + button to create your first course',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 14)),
        ],
      ),
    );
  }

  // ── Students tab ──────────────────────────────────────────────────────────
  Widget _buildStudentsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('enrollments')
          .where('teacherId', isEqualTo: widget.user.uid)
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('👥', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text('No students yet',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20)),
                const SizedBox(height: 8),
                Text('Students will appear here once they enroll',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 14)),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFFB347)],
                ).createShader(b),
                child: Text('${docs.length} Students Enrolled',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16)),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  return _studentCard(d);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _studentCard(Map<String, dynamic> d) {
    final name = d['studentName'] as String? ?? 'Student';
    final courseName = d['courseName'] as String? ?? '';
    final progress = d['progress'] as int? ?? 0;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(d['studentId'] as String? ?? '')
          .get(),
      builder: (_, userSnap) {
        final userData =
        userSnap.hasData && userSnap.data!.exists
            ? (userSnap.data!.data() as Map<String, dynamic>)
            : <String, dynamic>{};
        final avatarUrl = userData['avatarUrl'] as String?;
        final avatar = userData['avatar'] ?? '🧑‍💻';
        final xp = userData['xp'] ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)]),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(
                    child: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? Image.network(avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _avatarFallback(avatar))
                        : _avatarFallback(avatar),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(courseName,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress / 100,
                              backgroundColor:
                              Colors.white.withOpacity(0.08),
                              valueColor:
                              const AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFF6B35)),
                              minHeight: 5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$progress%',
                            style: const TextStyle(
                                color: Color(0xFFFF6B35),
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('⚡ $xp XP',
                    style: const TextStyle(
                        color: Color(0xFF00D4FF),
                        fontWeight: FontWeight.w700,
                        fontSize: 11)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _avatarFallback(String emoji) {
    return Container(
      color: const Color(0xFF060818),
      child:
      Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
    );
  }

  // ── Analytics tab ─────────────────────────────────────────────────────────
  Widget _buildAnalyticsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .where('teacherId', isEqualTo: widget.user.uid)
          .snapshots(),
      builder: (_, courseSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('enrollments')
              .where('teacherId', isEqualTo: widget.user.uid)
              .snapshots(),
          builder: (_, enrollSnap) {
            final courses = courseSnap.data?.docs ?? [];
            final enrollments = enrollSnap.data?.docs ?? [];

            int totalEnrolled = 0;
            double totalRating = 0;
            int publishedCount = 0;

            for (final doc in courses) {
              final d = doc.data() as Map<String, dynamic>;
              totalEnrolled += (d['enrolledCount'] as int? ?? 0);
              totalRating += (d['rating'] as num? ?? 0).toDouble();
              if (d['status'] == 'published') publishedCount++;
            }

            final avgRating = courses.isNotEmpty
                ? (totalRating / courses.length)
                : 0.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _analyticsCard('👥', 'Total Enrollments', '$totalEnrolled',
                      const Color(0xFF00D4FF),
                      subtitle: 'Across all your courses'),
                  const SizedBox(height: 12),
                  _analyticsCard(
                      '📚',
                      'Published Courses',
                      '$publishedCount / ${courses.length}',
                      const Color(0xFFFF6B35),
                      subtitle: 'Active on the platform'),
                  const SizedBox(height: 12),
                  _analyticsCard('⭐', 'Average Rating',
                      avgRating.toStringAsFixed(2), const Color(0xFFFFD700),
                      subtitle: 'From student reviews'),
                  const SizedBox(height: 12),
                  _analyticsCard('📈', 'Recent Enrollments',
                      '${enrollments.length}', const Color(0xFF00C853),
                      subtitle: 'Students enrolled so far'),
                  const SizedBox(height: 20),
                  if (courses.isNotEmpty)
                    _buildTopCourseSpotlight(courses),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopCourseSpotlight(List<QueryDocumentSnapshot> courses) {
    QueryDocumentSnapshot? top;
    int maxEnrolled = -1;
    for (final doc in courses) {
      final d = doc.data() as Map<String, dynamic>;
      final e = d['enrolledCount'] as int? ?? 0;
      if (e > maxEnrolled) {
        maxEnrolled = e;
        top = doc;
      }
    }
    if (top == null) return const SizedBox();
    final d = top.data() as Map<String, dynamic>;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFF6B35).withOpacity(0.12),
            const Color(0xFFFFB347).withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border:
        Border.all(color: const Color(0xFFFF6B35).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TOP PERFORMING COURSE',
                    style: TextStyle(
                        color: Color(0xFFFF6B35),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text(d['title'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('$maxEnrolled students enrolled',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _analyticsCard(
      String emoji,
      String label,
      String value,
      Color color, {
        String subtitle = '',
      }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 13)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 11)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────────────
  Widget _buildFAB() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, a, __) => TeacherUploadScreen(
                teacherId: widget.user.uid, teacherData: _teacherData),
            transitionsBuilder: (_, a, __, child) => SlideTransition(
              position: Tween<Offset>(
                  begin: const Offset(0, 1), end: Offset.zero)
                  .animate(CurvedAnimation(
                  parent: a, curve: Curves.easeOutCubic)),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        ).then((_) => setState(() {}));
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFFFB347)]),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withOpacity(0.5),
              blurRadius: 24,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  List<Color> _courseColors(String category) {
    final map = {
      'DSA': [const Color(0xFF00D4FF), const Color(0xFF7B2FFF)],
      'Web': [const Color(0xFFFF6B35), const Color(0xFFFFB347)],
      'Mobile': [const Color(0xFF00C853), const Color(0xFF00D4FF)],
      'ML': [const Color(0xFF7B2FFF), const Color(0xFFFF6B35)],
    };
    return map.entries
        .firstWhere(
            (e) => category.toLowerCase().contains(e.key.toLowerCase()),
        orElse: () => MapEntry('', [
          const Color(0xFF00D4FF),
          const Color(0xFF7B2FFF),
        ]))
        .value;
  }

  String _categoryEmoji(String category) {
    if (category.toLowerCase().contains('dsa') ||
        category.toLowerCase().contains('algo')) return '🧠';
    if (category.toLowerCase().contains('web')) return '🌐';
    if (category.toLowerCase().contains('mobile')) return '📱';
    if (category.toLowerCase().contains('ml') ||
        category.toLowerCase().contains('machine')) return '🤖';
    if (category.toLowerCase().contains('system')) return '🏗️';
    if (category.toLowerCase().contains('database')) return '🗄️';
    if (category.toLowerCase().contains('cloud')) return '☁️';
    return '💻';
  }
}

// ── Background painter ────────────────────────────────────────────────────────
class _TDashBgPainter extends CustomPainter {
  final double t;
  _TDashBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0A0F1E), Color(0xFF060818)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final orbPaint = Paint()..style = PaintingStyle.fill;
    final cx1 = size.width * 0.9 + sin(t * 2 * pi) * 30;
    final cy1 = size.height * 0.05 + cos(t * 2 * pi) * 20;
    orbPaint.shader = RadialGradient(colors: [
      const Color(0xFFFF6B35).withOpacity(0.12),
      Colors.transparent,
    ]).createShader(
        Rect.fromCircle(center: Offset(cx1, cy1), radius: 200));
    canvas.drawCircle(Offset(cx1, cy1), 200, orbPaint);

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 0.5;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_TDashBgPainter old) => old.t != t;
}