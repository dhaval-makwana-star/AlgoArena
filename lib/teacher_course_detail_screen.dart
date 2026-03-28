import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherCourseDetailScreen extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseData;
  const TeacherCourseDetailScreen(
      {super.key, required this.courseId, required this.courseData});

  @override
  State<TeacherCourseDetailScreen> createState() =>
      _TeacherCourseDetailScreenState();
}

class _TeacherCourseDetailScreenState extends State<TeacherCourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _togglePublishStatus() async {
    final current = widget.courseData['status'];
    final next = current == 'published' ? 'draft' : 'published';
    await FirebaseFirestore.instance
        .collection('courses')
        .doc(widget.courseId)
        .update({'status': next});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            next == 'published' ? 'Course is now Live! 🚀' : 'Course moved to Draft',
            style: const TextStyle(color: Colors.white)),
        backgroundColor:
        next == 'published' ? const Color(0xFF00C853) : const Color(0xFFFF6B35),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ));
      Navigator.pop(context);
    }
  }

  void _deleteCourse() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B3E),
        title: const Text('Delete Course?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        content: Text(
            'This will permanently delete "${widget.courseData['title']}". This cannot be undone.',
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child:
            const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Color(0xFFFF4757), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('courses')
          .doc(widget.courseId)
          .delete();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.courseData;
    return Scaffold(
      backgroundColor: const Color(0xFF060818),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(d),
            _buildTabBar(),
            Expanded(child: _buildTabContent()),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(d),
    );
  }

  Widget _buildHeader(Map<String, dynamic> d) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 16),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded,
                    color: Colors.white70, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Text(d['title'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFFF4757), size: 22),
                onPressed: _deleteCourse,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _chip(d['category'] ?? '', const Color(0xFF00D4FF)),
                const SizedBox(width: 8),
                _chip(d['level'] ?? '', const Color(0xFFFFD700)),
                const SizedBox(width: 8),
                _chip(
                    d['isFree'] == true ? 'Free' : 'Premium',
                    d['isFree'] == true
                        ? const Color(0xFF00C853)
                        : const Color(0xFFFF6B35)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 11)),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabs,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFFFB347)]),
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(4),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle:
        const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        tabs: const [
          Tab(text: 'Lectures'),
          Tab(text: 'Notes'),
          Tab(text: 'Stats'),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    return TabBarView(
      controller: _tabs,
      children: [
        _buildLecturesList(),
        _buildNotesList(),
        _buildStats(),
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
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyTab('🎬', 'No lectures added yet');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return _lectureItem(i + 1, d);
          },
        );
      },
    );
  }

  Widget _lectureItem(int num, Map<String, dynamic> d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
                child: Text('$num',
                    style: const TextStyle(
                        color: Color(0xFFFF6B35),
                        fontWeight: FontWeight.w700,
                        fontSize: 14))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d['title'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if ((d['duration'] as String? ?? '').isNotEmpty)
                  Text(d['duration']!,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11)),
              ],
            ),
          ),
          const Icon(Icons.play_circle_filled_rounded,
              color: Color(0xFFFF6B35), size: 28),
        ],
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
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _emptyTab('📄', 'No notes added yet');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return _noteItem(d);
          },
        );
      },
    );
  }

  Widget _noteItem(Map<String, dynamic> d) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
                child: Text('📄', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d['title'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if ((d['description'] as String? ?? '').isNotEmpty)
                  Text(d['description']!,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.download_rounded,
              color: Color(0xFF00D4FF), size: 24),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final d = widget.courseData;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _statRow('👥', 'Enrolled Students',
              '${d['enrolledCount'] ?? 0}', const Color(0xFF00D4FF)),
          _statRow('⭐', 'Average Rating',
              '${(d['rating'] as num? ?? 0.0).toStringAsFixed(1)} / 5.0',
              const Color(0xFFFFD700)),
          _statRow('🎬', 'Total Lectures',
              '${d['lecturesCount'] ?? 0}', const Color(0xFFFF6B35)),
          _statRow('📄', 'Total Notes',
              '${d['notesCount'] ?? 0}', const Color(0xFF7B2FFF)),
          _statRow('⏱️', 'Course Duration',
              d['duration'] ?? 'N/A', const Color(0xFF00C853)),
        ],
      ),
    );
  }

  Widget _statRow(String emoji, String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 14))),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
        ],
      ),
    );
  }

  Widget _emptyTab(String emoji, String msg) {
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
    final isPublished = d['status'] == 'published';
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: const Color(0xFF060818),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: GestureDetector(
        onTap: _togglePublishStatus,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPublished
                  ? [const Color(0xFF333333), const Color(0xFF444444)]
                  : [const Color(0xFFFF6B35), const Color(0xFFFFD700)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isPublished
                ? []
                : [
              BoxShadow(
                  color: const Color(0xFFFF6B35).withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isPublished
                      ? Icons.unpublished_rounded
                      : Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  isPublished ? 'Unpublish Course' : 'Publish Course',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}