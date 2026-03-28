import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'course_detail_screen.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedLevel = 'All';
  late AnimationController _bgCtrl;
  bool _isSeeding = false;

  final _categories = [
    'All',
    'DSA',
    'Web Dev',
    'Mobile',
    'ML/AI',
    'System Design',
    'Database',
    'DevOps',
  ];

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat(reverse: true);
    _seedSampleCoursesIfNeeded();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Seeds sample courses into Firestore on first load
  Future<void> _seedSampleCoursesIfNeeded() async {
    final snap = await FirebaseFirestore.instance
        .collection('courses')
        .limit(1)
        .get();
    if (snap.docs.isNotEmpty) return; // Already seeded

    setState(() => _isSeeding = true);
    final sampleCourses = _getSampleCourses();
    final batch = FirebaseFirestore.instance.batch();

    for (final course in sampleCourses) {
      final ref = FirebaseFirestore.instance.collection('courses').doc();
      batch.set(ref, {...course, 'id': ref.id, 'createdAt': FieldValue.serverTimestamp()});

      // Add sample lectures
      for (int i = 0; i < (course['lecturesCount'] as int); i++) {
        final lRef = ref.collection('lectures').doc();
        batch.set(lRef, {
          'index': i,
          'title': _sampleLectureTitles(course['category'] as String)[i % 8],
          'url': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
          'duration': '${10 + (i * 3)} min',
          'type': 'video',
        });
      }
    }

    await batch.commit();
    if (mounted) setState(() => _isSeeding = false);
  }

  List<String> _sampleLectureTitles(String category) {
    final map = {
      'DSA': [
        'Introduction to Arrays & Complexity',
        'Linked Lists Deep Dive',
        'Stacks and Queues',
        'Binary Trees & BST',
        'Graph Algorithms',
        'Dynamic Programming Basics',
        'Greedy Algorithms',
        'Sorting & Searching'
      ],
      'Web Dev': [
        'HTML5 Fundamentals',
        'CSS Grid & Flexbox',
        'JavaScript ES6+',
        'React Hooks Deep Dive',
        'Node.js & Express',
        'REST API Design',
        'Database Integration',
        'Deployment & CI/CD'
      ],
      'ML': [
        'Python for ML',
        'NumPy & Pandas',
        'Linear Regression',
        'Neural Networks',
        'CNN Architecture',
        'NLP Fundamentals',
        'Model Evaluation',
        'Deploying ML Models'
      ],
    };
    final key = map.keys.firstWhere(
            (k) => category.toLowerCase().contains(k.toLowerCase()),
        orElse: () => 'DSA');
    return map[key]!;
  }

  List<Map<String, dynamic>> _getSampleCourses() {
    return [
      {
        'teacherId': 'sample_teacher_1',
        'teacherName': 'Arjun Mehta',
        'teacherExpertise': 'Data Structures & Algorithms',
        'title': 'Master DSA: Zero to Hero',
        'description':
        'The most comprehensive DSA course on the platform. Covers arrays, trees, graphs, DP and everything you need to crack top tech interviews.',
        'category': 'DSA',
        'level': 'Beginner',
        'isFree': true,
        'duration': '40 hours',
        'lecturesCount': 8,
        'notesCount': 5,
        'enrolledCount': 4230,
        'rating': 4.9,
        'ratingCount': 892,
        'status': 'published',
        'tags': ['DSA', 'Interviews', 'Algorithms'],
        'thumbnailEmoji': '🧠',
        'colors': ['#00D4FF', '#7B2FFF'],
      },
      {
        'teacherId': 'sample_teacher_2',
        'teacherName': 'Priya Sharma',
        'teacherExpertise': 'Web Development',
        'title': 'Full-Stack Web Dev Bootcamp',
        'description':
        'Build 10 real-world projects using React, Node.js, MongoDB. Go from zero to full-stack developer with hands-on experience.',
        'category': 'Web Dev',
        'level': 'Intermediate',
        'isFree': false,
        'duration': '60 hours',
        'lecturesCount': 8,
        'notesCount': 8,
        'enrolledCount': 3105,
        'rating': 4.8,
        'ratingCount': 611,
        'status': 'published',
        'tags': ['React', 'Node.js', 'MongoDB'],
        'thumbnailEmoji': '🌐',
        'colors': ['#FF6B35', '#FFB347'],
      },
      {
        'teacherId': 'sample_teacher_3',
        'teacherName': 'Rahul Joshi',
        'teacherExpertise': 'Machine Learning',
        'title': 'Machine Learning A-Z',
        'description':
        'Learn ML from scratch using Python. Covers regression, classification, clustering, deep learning and real dataset projects.',
        'category': 'ML',
        'level': 'Intermediate',
        'isFree': true,
        'duration': '45 hours',
        'lecturesCount': 8,
        'notesCount': 6,
        'enrolledCount': 2879,
        'rating': 4.7,
        'ratingCount': 534,
        'status': 'published',
        'tags': ['Python', 'TensorFlow', 'sklearn'],
        'thumbnailEmoji': '🤖',
        'colors': ['#7B2FFF', '#FF6B35'],
      },
      {
        'teacherId': 'sample_teacher_4',
        'teacherName': 'Sneha Patil',
        'teacherExpertise': 'System Design',
        'title': 'System Design for SDE-2+',
        'description':
        'Learn how to design scalable, distributed systems. Covers load balancers, databases, caching, microservices and more.',
        'category': 'System Design',
        'level': 'Advanced',
        'isFree': false,
        'duration': '25 hours',
        'lecturesCount': 8,
        'notesCount': 7,
        'enrolledCount': 1965,
        'rating': 4.9,
        'ratingCount': 345,
        'status': 'published',
        'tags': ['Scalability', 'Databases', 'Architecture'],
        'thumbnailEmoji': '🏗️',
        'colors': ['#00C853', '#00D4FF'],
      },
      {
        'teacherId': 'sample_teacher_5',
        'teacherName': 'Karan Verma',
        'teacherExpertise': 'Mobile Development',
        'title': 'Flutter & Firebase: Complete Guide',
        'description':
        'Build beautiful cross-platform apps with Flutter. Covers widgets, state management, Firebase, and app deployment.',
        'category': 'Mobile',
        'level': 'Beginner',
        'isFree': true,
        'duration': '35 hours',
        'lecturesCount': 8,
        'notesCount': 4,
        'enrolledCount': 3421,
        'rating': 4.8,
        'ratingCount': 721,
        'status': 'published',
        'tags': ['Flutter', 'Dart', 'Firebase'],
        'thumbnailEmoji': '📱',
        'colors': ['#00D4FF', '#00C853'],
      },
      {
        'teacherId': 'sample_teacher_6',
        'teacherName': 'Ananya Roy',
        'teacherExpertise': 'Competitive Programming',
        'title': 'Competitive Programming Masterclass',
        'description':
        'Get ready for Codeforces, LeetCode, and coding competitions. Covers number theory, graph theory, segment trees and more.',
        'category': 'DSA',
        'level': 'Advanced',
        'isFree': false,
        'duration': '50 hours',
        'lecturesCount': 8,
        'notesCount': 9,
        'enrolledCount': 1120,
        'rating': 4.6,
        'ratingCount': 210,
        'status': 'published',
        'tags': ['Competitive', 'Codeforces', 'LeetCode'],
        'thumbnailEmoji': '⚡',
        'colors': ['#FFD700', '#FF6B35'],
      },
    ];
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
              painter: _LearnBgPainter(_bgCtrl.value),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                _buildSearchBar(),
                _buildCategoryFilter(),
                Expanded(child: _isSeeding ? _buildLoading() : _buildCourseList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📚', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
                ).createShader(b),
                child: const Text('Learn',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 28,
                        letterSpacing: -0.5)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Explore courses from expert instructors',
              style:
              TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search courses, topics...',
            hintStyle:
            TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
            prefixIcon:
            const Icon(Icons.search_rounded, color: Colors.white38, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon:
              const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
            )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final active = _selectedCategory == cat;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedCategory = cat);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                gradient: active
                    ? const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)])
                    : null,
                color: active ? null : Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active
                      ? Colors.transparent
                      : Colors.white.withOpacity(0.10),
                ),
                boxShadow: active
                    ? [
                  BoxShadow(
                      color: const Color(0xFF00D4FF).withOpacity(0.3),
                      blurRadius: 10)
                ]
                    : [],
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF00D4FF)),
          SizedBox(height: 16),
          Text('Loading courses...', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildCourseList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('courses')
          .where('status', isEqualTo: 'published')
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildLoading();
        }

        var docs = snap.data?.docs ?? [];

        // Filter
        docs = docs.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          final title = (d['title'] as String? ?? '').toLowerCase();
          final category = (d['category'] as String? ?? '').toLowerCase();
          final tags = (d['tags'] as List? ?? []).join(' ').toLowerCase();

          final matchSearch = _searchQuery.isEmpty ||
              title.contains(_searchQuery) ||
              category.contains(_searchQuery) ||
              tags.contains(_searchQuery);

          final matchCategory = _selectedCategory == 'All' ||
              category.contains(_selectedCategory.toLowerCase());

          return matchSearch && matchCategory;
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🔍', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                const Text('No courses found',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18)),
                const SizedBox(height: 8),
                Text('Try a different search or category',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 13)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _buildCourseCard(docs[i].id, data, i);
          },
        );
      },
    );
  }

  Widget _buildCourseCard(String id, Map<String, dynamic> d, int index) {
    final colors = (d['colors'] as List<dynamic>? ?? ['#00D4FF', '#7B2FFF'])
        .map((c) => Color(int.parse('0xFF${(c as String).replaceAll('#', '')}')))
        .toList();

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, a, __) =>
                CourseDetailScreen(courseId: id, courseData: d),
            transitionsBuilder: (_, a, __, child) => FadeTransition(
                opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
                child: child),
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail header
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors[0], colors[1]],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Stack(
                children: [
                  // Grid texture
                  Positioned.fill(
                    child: CustomPaint(painter: _MiniGridPainter()),
                  ),
                  // Level badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(d['level'] ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 11)),
                    ),
                  ),
                  // Price badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: d['isFree'] == true
                            ? const Color(0xFF00C853)
                            : const Color(0xFFFFD700),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        d['isFree'] == true ? 'FREE' : 'PRO',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      d['thumbnailEmoji'] ?? '💻',
                      style: const TextStyle(fontSize: 52),
                    ),
                  ),
                ],
              ),
            ),
            // Course info
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d['title'] ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          color: Colors.white38, size: 13),
                      const SizedBox(width: 4),
                      Text(d['teacherName'] ?? '',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _infoChip(Icons.play_circle_outline_rounded,
                          '${d['lecturesCount'] ?? 0} videos'),
                      const SizedBox(width: 10),
                      _infoChip(Icons.description_outlined,
                          '${d['notesCount'] ?? 0} notes'),
                      const SizedBox(width: 10),
                      _infoChip(Icons.access_time_rounded, d['duration'] ?? ''),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ...List.generate(5, (i) {
                        final rating =
                        (d['rating'] as num? ?? 0.0).toDouble();
                        return Icon(
                          i < rating.floor()
                              ? Icons.star_rounded
                              : (i < rating
                              ? Icons.star_half_rounded
                              : Icons.star_outline_rounded),
                          color: const Color(0xFFFFD700),
                          size: 15,
                        );
                      }),
                      const SizedBox(width: 6),
                      Text(
                        '${(d['rating'] as num? ?? 0.0).toStringAsFixed(1)} (${d['ratingCount'] ?? 0})',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        '${d['enrolledCount'] ?? 0} enrolled',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white38, size: 13),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(0.4), fontSize: 11)),
      ],
    );
  }
}

class _MiniGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 0.5;
    const spacing = 20.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_MiniGridPainter old) => false;
}

class _LearnBgPainter extends CustomPainter {
  final double t;
  _LearnBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.5),
        radius: 1.3,
        colors: [const Color(0xFF0A1428), const Color(0xFF060818)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final orbPaint = Paint()..style = PaintingStyle.fill;
    final cx = size.width * 0.7 + sin(t * 2 * pi) * 20;
    final cy = size.height * 0.1 + cos(t * 2 * pi) * 15;
    orbPaint.shader = RadialGradient(colors: [
      const Color(0xFF00D4FF).withOpacity(0.12),
      Colors.transparent,
    ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 160));
    canvas.drawCircle(Offset(cx, cy), 160, orbPaint);
  }

  @override
  bool shouldRepaint(_LearnBgPainter old) => old.t != t;
}