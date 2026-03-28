import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

// NOTE: Add to pubspec.yaml:
// url_launcher: ^6.2.5

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseData;
  const CourseDetailScreen(
      {super.key, required this.courseId, required this.courseData});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _isEnrolled = false;
  bool _isEnrolling = false;
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _checkEnrollment();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _checkEnrollment() async {
    if (_user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('enrollments')
        .doc('${_user!.uid}_${widget.courseId}')
        .get();
    if (mounted) setState(() => _isEnrolled = doc.exists);
  }

  Future<void> _enroll() async {
    if (_user == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _isEnrolling = true);

    try {
      final enrollId = '${_user!.uid}_${widget.courseId}';
      await FirebaseFirestore.instance
          .collection('enrollments')
          .doc(enrollId)
          .set({
        'studentId': _user!.uid,
        'studentName': _user!.displayName ?? 'Student',
        'courseId': widget.courseId,
        'courseName': widget.courseData['title'],
        'teacherId': widget.courseData['teacherId'],
        'teacherName': widget.courseData['teacherName'],
        'enrolledAt': FieldValue.serverTimestamp(),
        'progress': 0,
        'completedLectures': [],
      });

      // Increment enrolled count
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .update({'enrolledCount': FieldValue.increment(1)});

      if (mounted) {
        setState(() => _isEnrolled = true);
        _snack('🎉 Enrolled successfully! Start learning now.');
      }
    } catch (e) {
      _snack('Failed to enroll. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isEnrolling = false);
    }
  }

  void _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _snack('Could not open link.', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? const Color(0xFFFF4757) : const Color(0xFF00C853),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.courseData;
    final colors = (d['colors'] as List<dynamic>? ?? ['#00D4FF', '#7B2FFF'])
        .map((c) => Color(int.parse('0xFF${(c as String).replaceAll('#', '')}')))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFF060818),
      body: Column(
        children: [
          _buildHero(d, colors),
          _buildTabBar(),
          Expanded(child: _buildTabContent()),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(d),
    );
  }

  Widget _buildHero(Map<String, dynamic> d, List<Color> colors) {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _HeroGridPainter()),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      if (d['isFree'] == true)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('FREE',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12)),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(d['category'] ?? '',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11)),
                              ),
                              const SizedBox(height: 8),
                              Text(d['title'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20,
                                      height: 1.2),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 6),
                              Text('by ${d['teacherName'] ?? ''}',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                        Text(d['thumbnailEmoji'] ?? '💻',
                            style: const TextStyle(fontSize: 60)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: _tabs,
          indicator: BoxDecoration(
            gradient: const LinearGradient(
                colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)]),
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(4),
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white38,
          labelStyle:
          const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: '🎬  Lectures'),
            Tab(text: '📄  Notes'),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabs,
      children: [
        _buildLecturesList(),
        _buildNotesList(),
      ],
    );
  }

  Widget _buildLecturesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('lectures')
          .orderBy('index')
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4FF)));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyState('🎬', 'No lectures yet');
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            final isLocked = !_isEnrolled && i > 1;
            return _lectureItem(i + 1, d, isLocked);
          },
        );
      },
    );
  }

  Widget _lectureItem(int num, Map<String, dynamic> d, bool isLocked) {
    return GestureDetector(
      onTap: () {
        if (isLocked) {
          _snack('Enroll in this course to access all lectures.', isError: false);
          return;
        }
        final url = d['url'] as String? ?? '';
        if (url.isNotEmpty) _openUrl(url);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isLocked
              ? Colors.white.withOpacity(0.03)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(isLocked ? 0.05 : 0.10),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: isLocked
                    ? null
                    : const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFFFB347)]),
                color: isLocked ? Colors.white.withOpacity(0.05) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: isLocked
                    ? const Icon(Icons.lock_rounded, color: Colors.white24, size: 18)
                    : Text('$num',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d['title'] ?? '',
                      style: TextStyle(
                          color: isLocked
                              ? Colors.white.withOpacity(0.3)
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if ((d['duration'] as String? ?? '').isNotEmpty)
                    Text(d['duration']!,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 12)),
                ],
              ),
            ),
            if (!isLocked)
              const Icon(Icons.play_circle_filled_rounded,
                  color: Color(0xFFFF6B35), size: 28),
            if (num <= 2 && isLocked)
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C853).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('FREE',
                    style: TextStyle(
                        color: Color(0xFF00C853),
                        fontWeight: FontWeight.w700,
                        fontSize: 10)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .collection('notes')
          .orderBy('index')
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4FF)));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyState('📄', 'No notes available');
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return _noteItem(d, !_isEnrolled && i > 0);
          },
        );
      },
    );
  }

  Widget _noteItem(Map<String, dynamic> d, bool isLocked) {
    return GestureDetector(
      onTap: () {
        if (isLocked) {
          _snack('Enroll to access all study notes.');
          return;
        }
        final url = d['url'] as String? ?? '';
        if (url.isNotEmpty) _openUrl(url);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isLocked
              ? Colors.white.withOpacity(0.03)
              : const Color(0xFF00D4FF).withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isLocked
                ? Colors.white.withOpacity(0.05)
                : const Color(0xFF00D4FF).withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isLocked
                    ? Colors.white.withOpacity(0.05)
                    : const Color(0xFF00D4FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: isLocked
                    ? const Icon(Icons.lock_rounded, color: Colors.white24, size: 18)
                    : const Text('📄', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d['title'] ?? '',
                      style: TextStyle(
                          color: isLocked
                              ? Colors.white.withOpacity(0.3)
                              : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if ((d['description'] as String? ?? '').isNotEmpty)
                    Text(d['description']!,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (!isLocked)
              const Icon(Icons.download_rounded,
                  color: Color(0xFF00D4FF), size: 26),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(String emoji, String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(msg,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4), fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildBottomBar(Map<String, dynamic> d) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: const Color(0xFF060818),
        border:
        Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: _isEnrolled
          ? Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF00C853).withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF00C853).withOpacity(0.3)),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Color(0xFF00C853), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('You are enrolled!',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                Text('Keep learning and growing 🚀',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12)),
              ],
            ),
          ),
        ],
      )
          : GestureDetector(
        onTap: _isEnrolling ? null : _enroll,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D4FF).withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Center(
            child: _isEnrolling
                ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.rocket_launch_rounded,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  d['isFree'] == true
                      ? 'Enroll for Free'
                      : 'Enroll Now',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..strokeWidth = 0.5;
    const spacing = 24.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_HeroGridPainter old) => false;
}