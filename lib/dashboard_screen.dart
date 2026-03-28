import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'profile_screen.dart';
import 'room_screen.dart';
import 'socket_service.dart';
import 'syntax_game_screen.dart';
import 'debug_game_screen.dart';
import 'logic_game_screen.dart';
import 'speed_game_screen.dart';
import 'firestore_service.dart';
import 'compete_screen.dart';
import 'course_detail_screen.dart';
import 'ai_battle_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final SocketService socketService = SocketService();
  // 0=Arena, 1=Learn, 2=Compete, 3=Daily, 4=Profile
  int _selectedTab = 0;

  static const List<Map<String, dynamic>> _rooms = [
    {
      'name': 'Room 101',
      'label': 'OPEN ARENA',
      'sub': 'Any Difficulty',
      'emoji': '⚔️',
      'color1': Color(0xFF00D4FF),
      'color2': Color(0xFF7B2FFF),
      'isAiBattle': false, // ← NEW
    },
    {
      'name': 'AI Battle',
      'label': 'AI BATTLE',
      'sub': '1v1 vs Bot',
      'emoji': '🤖',
      'color1': Color(0xFFFF4757),
      'color2': Color(0xFFFF6B81),
      'isAiBattle': true, // ← NEW: marks this card as AI Battle
    },
    {
      'name': 'Code War',
      'label': 'CODE WAR',
      'sub': 'Hard Mode',
      'emoji': '🔥',
      'color1': Color(0xFFFFB800),
      'color2': Color(0xFFFF6348),
      'isAiBattle': false, // ← NEW
    },
  ];

  late AnimationController _heroCtrl;
  late Animation<double> _heroAnim;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _heroAnim = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);
    _heroCtrl.forward();

    FirestoreService().updateLoginStreak();

    socketService.connect();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      socketService.socket.on('connect', (_) => _registerUser(uid));
      if (socketService.socket.connected) _registerUser(uid);
    }
  }

  void _registerUser(String uid) {
    FirebaseFirestore.instance.collection('users').doc(uid).get().then((doc) {
      final username = doc.data()?['username'] ?? 'Coder';
      socketService.setUser(uid, username);
    });
  }

  @override
  void dispose() {
    socketService.disconnect();
    _heroCtrl.dispose();
    super.dispose();
  }

  // ─── UPDATED: _joinRoom now checks for AI Battle ──────────────────────────
  void _joinRoom(String roomName, {bool isAiBattle = false}) {
    // ← NEW: If it's AI Battle, go to AiBattleScreen instead
    if (isAiBattle) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, animation, __) =>
              AiBattleScreen(socketService: socketService),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
              Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                  .animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOut)),
              child: child,
            ),
          ),
        ),
      );
      return;
    }

    // Original logic for all other rooms
    socketService.joinRoom(roomName);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) =>
            RoomScreen(roomId: roomName, socketService: socketService),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
            Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        ),
      ),
    );
  }

  Future<void> claimReward() async {
    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .update({'coins': FieldValue.increment(100), 'rewardClaimed': true});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.hasData
            ? (snapshot.data!.data() as Map<String, dynamic>)
            : <String, dynamic>{};
        final avatarUrl = data['avatarUrl'] as String?;
        final avatarEmoji = data['avatar'] ?? '🧑‍💻';

        return Scaffold(
          backgroundColor: const Color(0xFF060818),
          bottomNavigationBar: _buildBottomNav(avatarUrl, avatarEmoji),
          body: IndexedStack(
            index: _selectedTab,
            children: [
              _buildArenaTab(data, avatarUrl, avatarEmoji),
              _buildLearnTab(),
              const CompeteScreen(),
              _buildDailyTab(),
              _buildProfileTab(avatarUrl, avatarEmoji),
            ],
          ),
        );
      },
    );
  }

  // ─── Arena Tab ────────────────────────────────────────────────────────────
  Widget _buildArenaTab(
      Map<String, dynamic> data, String? avatarUrl, String avatarEmoji) {
    return Stack(
      children: [
        _buildBackground(),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(data, avatarUrl, avatarEmoji),
                const SizedBox(height: 24),
                _buildHeroCard(),
                const SizedBox(height: 28),
                _buildSectionLabel('GAME MODES'),
                const SizedBox(height: 14),
                _buildGameModes(),
                const SizedBox(height: 28),
                _buildSectionLabel('LIVE ROOMS'),
                const SizedBox(height: 14),
                _buildRoomCards(),
                const SizedBox(height: 28),
                _buildSectionLabel('TOP PLAYERS'),
                const SizedBox(height: 14),
                _buildLeaderboard(),
                const SizedBox(height: 28),
                _buildSprintDuel(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Learn Tab ────────────────────────────────────────────────────────────
  Widget _buildLearnTab() {
    return Stack(
      children: [
        _buildBackground(),
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    const Text('📚', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 10),
                    ShaderMask(
                      shaderCallback: (b) => const LinearGradient(
                        colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
                      ).createShader(b),
                      child: const Text('Learn',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 26,
                              letterSpacing: -0.5)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D4FF).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF00D4FF).withOpacity(0.25)),
                      ),
                      child: const Text('By Instructors',
                          style: TextStyle(
                              color: Color(0xFF00D4FF),
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text('Expert-curated courses for coders',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 13)),
              ),
              // Course list
              Expanded(child: _buildCourseList()),
            ],
          ),
        ),
      ],
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
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D4FF)));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('📭', style: TextStyle(fontSize: 52)),
                const SizedBox(height: 12),
                const Text('No courses yet',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18)),
                const SizedBox(height: 8),
                Text('Instructors haven\'t published any course yet',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _buildCourseCard(docs[i].id, data);
          },
        );
      },
    );
  }

  Widget _buildCourseCard(String id, Map<String, dynamic> d) {
    final colors = (d['colors'] as List<dynamic>? ?? ['#00D4FF', '#7B2FFF'])
        .map((c) =>
        Color(int.parse('0xFF${(c as String).replaceAll('#', '')}')))
        .toList();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) =>
              CourseDetailScreen(courseId: id, courseData: d),
          transitionsBuilder: (_, a, __, child) => FadeTransition(
              opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
              child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gradient header
            Container(
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors[0], colors[1]],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: _MiniGridPainter())),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (d['isFree'] == true
                            ? const Color(0xFF00C853)
                            : const Color(0xFFFFD700))
                            .withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(d['isFree'] == true ? 'FREE' : 'PRO',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 10)),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(d['level'] ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 10)),
                    ),
                  ),
                  Center(
                    child: Text(d['thumbnailEmoji'] ?? '💻',
                        style: const TextStyle(fontSize: 46)),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d['title'] ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          color: Colors.white38, size: 12),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(d['teacherName'] ?? '',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      // Rating
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFFD700), size: 13),
                      const SizedBox(width: 3),
                      Text(
                        '${(d['rating'] as num? ?? 0.0).toStringAsFixed(1)}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _infoChip(Icons.play_circle_outline_rounded,
                          '${d['lecturesCount'] ?? 0} videos'),
                      const SizedBox(width: 10),
                      _infoChip(Icons.description_outlined,
                          '${d['notesCount'] ?? 0} notes'),
                      const SizedBox(width: 10),
                      _infoChip(Icons.people_outline_rounded,
                          '${d['enrolledCount'] ?? 0}'),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                              colors: [colors[0], colors[1]]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Enroll',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11)),
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
        Icon(icon, color: Colors.white38, size: 12),
        const SizedBox(width: 3),
        Text(label,
            style:
            TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
      ],
    );
  }

  // ─── Daily Tab ────────────────────────────────────────────────────────────
  Widget _buildDailyTab() {
    return Stack(
      children: [
        _buildBackground(),
        SafeArea(child: _DailyTabContent()),
      ],
    );
  }

  // ─── Profile Tab ──────────────────────────────────────────────────────────
  Widget _buildProfileTab(String? avatarUrl, String avatarEmoji) {
    return Stack(
      children: [
        _buildBackground(),
        SafeArea(
          child: Center(
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen())),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)]),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0xFF00D4FF).withOpacity(0.35),
                            blurRadius: 20)
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: ClipOval(
                        child: (avatarUrl != null && avatarUrl.isNotEmpty)
                            ? Image.network(avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _avatarFallback(avatarEmoji, size: 84))
                            : _avatarFallback(avatarEmoji, size: 84),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('VIEW PROFILE',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Text('Tap to open',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4), fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback(String emoji, {required double size}) {
    return Container(
      width: size,
      height: size,
      color: const Color(0xFF060818),
      child: Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.45))),
    );
  }

  // ─── Background ───────────────────────────────────────────────────────────
  Widget _buildBackground() {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.4),
              radius: 1.2,
              colors: [Color(0xFF0D1B3E), Color(0xFF060818)],
            ),
          ),
        ),
        CustomPaint(size: Size.infinite, painter: _GridPainter()),
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                const Color(0xFF00D4FF).withOpacity(0.12),
                Colors.transparent,
              ]),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Top Bar ──────────────────────────────────────────────────────────────
  Widget _buildTopBar(
      Map<String, dynamic> data, String? avatarUrl, String avatarEmoji) {
    return Column(
      children: [
        if ((data['rewardClaimed'] ?? false) == false)
          GestureDetector(
            onTap: () async {
              await claimReward();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Row(
                      children: [Text('🎉 You got 100 coins!')]),
                  backgroundColor: const Color(0xFFFFB800),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ));
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFFFB800), Color(0xFFFF6348)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🎁', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text('CLAIM YOUR STARTER REWARD!',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
        Row(
          children: [
            _statChip('⚡ XP', '${data['xp'] ?? 0}', const Color(0xFF00D4FF)),
            const SizedBox(width: 8),
            _statChip('🔥', '${data['streak'] ?? 0}', const Color(0xFFFF6348)),
            const SizedBox(width: 8),
            _statChip('🪙', '${data['coins'] ?? 0}', const Color(0xFFFFB800)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen())),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                      colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)]),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF00D4FF).withOpacity(0.3),
                        blurRadius: 12)
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2.5),
                  child: ClipOval(
                    child: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? Image.network(avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _topBarFallback(avatarEmoji))
                        : _topBarFallback(avatarEmoji),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _topBarFallback(String emoji) {
    return Container(
      color: const Color(0xFF060818),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 20))),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: color.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 5),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ],
      ),
    );
  }

  // ─── Hero Card ────────────────────────────────────────────────────────────
  Widget _buildHeroCard() {
    return FadeTransition(
      opacity: _heroAnim,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00D4FF).withOpacity(0.25),
              blurRadius: 30,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('SEASON 1',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2)),
                  ),
                  const SizedBox(height: 12),
                  const Text('START YOUR\nCODING QUEST',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.2,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Text('Beat opponents. Earn coins. Level up.',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => setState(() => _selectedTab = 2),
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle),
                child: const Center(
                    child: Text('🏆', style: TextStyle(fontSize: 34))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Game Modes ───────────────────────────────────────────────────────────
  Widget _buildGameModes() {
    final modes = [
      {
        'icon': '< >',
        'label': 'Syntax',
        'sub': 'Learn patterns',
        'color': const Color(0xFF00D4FF),
        'screen': const SyntaxGameScreen(),
      },
      {
        'icon': '🐛',
        'label': 'Debug',
        'sub': 'Fix bugs',
        'color': const Color(0xFFFF4757),
        'screen': const DebugGameScreen(),
      },
      {
        'icon': '🧩',
        'label': 'Logic',
        'sub': 'Think deep',
        'color': const Color(0xFF7B2FFF),
        'screen': const LogicGameScreen(),
      },
      {
        'icon': '⚡',
        'label': 'Speed',
        'sub': 'Race the clock',
        'color': const Color(0xFFFFB800),
        'screen': const SpeedGameScreen(),
      },
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: modes.map((m) => _gameModeCard(m)).toList(),
    );
  }

  Widget _gameModeCard(Map<String, dynamic> m) {
    final color = m['color'] as Color;
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => m['screen'] as Widget)),
      child: Container(
        width: 76,
        height: 88,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(m['icon'] as String,
                style: TextStyle(
                    color: color,
                    fontSize: m['icon'] == '< >' ? 14 : 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(m['label'] as String,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(m['sub'] as String,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.35), fontSize: 9),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // ─── Room Cards ───────────────────────────────────────────────────────────
  Widget _buildRoomCards() {
    return SizedBox(
      height: 150,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _rooms.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        // ↓ UPDATED: pass isAiBattle flag to _roomCard
        itemBuilder: (context, i) => _roomCard(_rooms[i]),
      ),
    );
  }

  // ─── UPDATED: _roomCard now routes AI Battle differently ──────────────────
  Widget _roomCard(Map<String, dynamic> room) {
    final c1 = room['color1'] as Color;
    final c2 = room['color2'] as Color;
    final bool isAiBattle = room['isAiBattle'] as bool? ?? false; // ← NEW

    return GestureDetector(
      // ↓ UPDATED: pass isAiBattle so _joinRoom knows what to do
      onTap: () => _joinRoom(room['name'] as String, isAiBattle: isAiBattle),
      child: Container(
        width: 165,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c1.withOpacity(0.18), c2.withOpacity(0.12)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c1.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(room['emoji'] as String,
                    style: const TextStyle(fontSize: 20)),
                const Spacer(),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Color(0xFF00FF87), size: 6),
                      SizedBox(width: 4),
                      Text('LIVE',
                          style: TextStyle(
                              color: Color(0xFF00FF87),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1)),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(room['label'] as String,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5)),
            const SizedBox(height: 3),
            Text(room['sub'] as String,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 11)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [c1.withOpacity(0.6), c2.withOpacity(0.6)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('JOIN ROOM',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Leaderboard ──────────────────────────────────────────────────────────
  Widget _buildLeaderboard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('xp', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF00D4FF)))),
          );
        }

        final docs = snapshot.data!.docs;
        final myUid = FirebaseAuth.instance.currentUser?.uid;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Row(
                  children: [
                    const Text('🏆', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    const Text('GLOBAL LEADERBOARD',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                    const Spacer(),
                    Text('SEASON 1',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.3), fontSize: 10)),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              ...docs.asMap().entries.map((entry) {
                final rank = entry.key;
                final data = entry.value.data() as Map<String, dynamic>;
                final isMe = entry.value.id == myUid;
                return _leaderboardRow(rank, data, isMe);
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _leaderboardRow(int rank, Map<String, dynamic> data, bool isMe) {
    final rankEmojis = ['🥇', '🥈', '🥉', '4️⃣', '5️⃣'];
    final rankColors = [
      const Color(0xFFFFD700),
      const Color(0xFFB0C4DE),
      const Color(0xFFCD7F32),
      Colors.white38,
      Colors.white24,
    ];

    final avatarUrl = data['avatarUrl'] as String?;
    final username = data['username'] ?? 'U';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFF00D4FF).withOpacity(0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isMe
            ? Border.all(color: const Color(0xFF00D4FF).withOpacity(0.25))
            : null,
      ),
      child: Row(
        children: [
          Text(rankEmojis[rank], style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rankColors[rank].withOpacity(0.15),
              border:
              Border.all(color: rankColors[rank].withOpacity(0.3)),
            ),
            child: ClipOval(
              child: (avatarUrl != null && avatarUrl.isNotEmpty)
                  ? Image.network(avatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(username[0].toUpperCase(),
                        style: TextStyle(
                            color: rankColors[rank],
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ))
                  : Center(
                child: Text(username[0].toUpperCase(),
                    style: TextStyle(
                        color: rankColors[rank],
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(username,
                        style: TextStyle(
                            color: isMe
                                ? const Color(0xFF00D4FF)
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D4FF).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('YOU',
                            style: TextStyle(
                                color: Color(0xFF00D4FF),
                                fontSize: 8,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                Text('🔥 ${data['streak'] ?? 0} streak',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.35), fontSize: 10)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${data['xp'] ?? 0}',
                  style: TextStyle(
                      color: rankColors[rank],
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              Text('XP',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.35), fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Sprint Duel ──────────────────────────────────────────────────────────
  Widget _buildSprintDuel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('⚡ SPRINT DUEL',
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text('Solve max DSA problems in 60 seconds',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFFFFB800), Color(0xFFFF6348)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('SOON',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── Bottom Nav ───────────────────────────────────────────────────────────
  Widget _buildBottomNav(String? avatarUrl, String avatarEmoji) {
    final items = [
      {
        'icon': Icons.code,
        'label': 'Arena',
        'activeColor': const Color(0xFF00D4FF)
      },
      {
        'icon': Icons.school_rounded,
        'label': 'Learn',
        'activeColor': const Color(0xFF7B2FFF)
      },
      {
        'icon': Icons.emoji_events,
        'label': 'Compete',
        'activeColor': const Color(0xFFFFB800)
      },
      {
        'icon': Icons.calendar_today,
        'label': 'Daily',
        'activeColor': const Color(0xFF00FF87)
      },
      {
        'icon': Icons.person,
        'label': 'Profile',
        'activeColor': const Color(0xFF7B2FFF)
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0F1E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      child: Row(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          final isSelected = _selectedTab == i;
          final activeColor = item['activeColor'] as Color;
          final isProfileTab = i == 4;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: isSelected ? activeColor : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.15 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: isProfileTab &&
                          avatarUrl != null &&
                          avatarUrl.isNotEmpty
                          ? Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? activeColor
                                : Colors.white24,
                            width: 1.5,
                          ),
                        ),
                        child: ClipOval(
                          child: Image.network(avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                item['icon'] as IconData,
                                color: isSelected
                                    ? activeColor
                                    : Colors.white24,
                                size: 22,
                              )),
                        ),
                      )
                          : Icon(item['icon'] as IconData,
                          color:
                          isSelected ? activeColor : Colors.white24,
                          size: 22),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        color: isSelected ? activeColor : Colors.white24,
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white.withOpacity(0.4),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 3,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DAILY TAB — Full Featured Widget
// ═══════════════════════════════════════════════════════════════════════════════

class _DailyTabContent extends StatefulWidget {
  @override
  State<_DailyTabContent> createState() => _DailyTabContentState();
}

class _DailyTabContentState extends State<_DailyTabContent>
    with TickerProviderStateMixin {

  // ─── Colors ────────────────────────────────────────────────────────────────
  static const _bg       = Color(0xFF060818);
  static const _card     = Color(0xFF0D1225);
  static const _accent   = Color(0xFF7B2FFF);
  static const _cyan     = Color(0xFF00D4FF);
  static const _green    = Color(0xFF00FF87);
  static const _gold     = Color(0xFFFFB800);
  static const _red      = Color(0xFFFF4757);

  // ─── DSA Daily Challenge Bank (seeded by day-of-year) ──────────────────────
  static const List<Map<String, dynamic>> _challengeBank = [
    {
      'question': 'What is the time complexity of QuickSort in the average case?',
      'options': ['O(n log n)', 'O(n²)', 'O(n)', 'O(log n)'],
      'correct': 0,
      'explanation': 'QuickSort averages O(n log n) due to balanced partitioning on random inputs.',
      'topic': 'Sorting', 'difficulty': 'Easy', 'xp': 20, 'coins': 10,
    },
    {
      'question': 'Which data structure supports O(1) average-case lookup?',
      'options': ['Hash Table', 'Binary Search Tree', 'Linked List', 'Stack'],
      'correct': 0,
      'explanation': 'Hash tables use hashing to map keys → buckets, giving O(1) average lookup.',
      'topic': 'Data Structures', 'difficulty': 'Easy', 'xp': 20, 'coins': 10,
    },
    {
      'question': 'In a min-heap with N elements, what is the time to extract the minimum?',
      'options': ['O(log N)', 'O(1)', 'O(N)', 'O(N log N)'],
      'correct': 0,
      'explanation': 'After removing root (min), heapify-down restores the heap in O(log N).',
      'topic': 'Heaps', 'difficulty': 'Medium', 'xp': 30, 'coins': 15,
    },
    {
      'question': 'Which traversal of a BST gives elements in sorted order?',
      'options': ['Inorder', 'Preorder', 'Postorder', 'Level-order'],
      'correct': 0,
      'explanation': 'Inorder (Left → Root → Right) visits BST nodes in ascending sorted order.',
      'topic': 'Trees', 'difficulty': 'Easy', 'xp': 20, 'coins': 10,
    },
    {
      'question': 'What is the space complexity of Merge Sort?',
      'options': ['O(N)', 'O(1)', 'O(log N)', 'O(N²)'],
      'correct': 0,
      'explanation': 'Merge Sort requires O(N) auxiliary space for the temporary merge arrays.',
      'topic': 'Sorting', 'difficulty': 'Medium', 'xp': 30, 'coins': 15,
    },
    {
      'question': 'Floyd\'s cycle detection algorithm uses how many pointers?',
      'options': ['2', '1', '3', '4'],
      'correct': 0,
      'explanation': 'Floyd\'s (tortoise & hare) uses a slow pointer (1 step) and fast pointer (2 steps).',
      'topic': 'Linked Lists', 'difficulty': 'Medium', 'xp': 35, 'coins': 20,
    },
    {
      'question': 'What does BFS use internally to traverse a graph?',
      'options': ['Queue', 'Stack', 'Heap', 'Array'],
      'correct': 0,
      'explanation': 'BFS processes nodes level by level using a Queue (FIFO) structure.',
      'topic': 'Graphs', 'difficulty': 'Easy', 'xp': 20, 'coins': 10,
    },
    {
      'question': 'What algorithm finds the shortest path in a weighted graph with no negative edges?',
      'options': ['Dijkstra\'s', 'Bellman-Ford', 'Floyd-Warshall', 'DFS'],
      'correct': 0,
      'explanation': 'Dijkstra\'s greedily picks the nearest unvisited node — O((V+E) log V) with a heap.',
      'topic': 'Graphs', 'difficulty': 'Hard', 'xp': 50, 'coins': 30,
    },
    {
      'question': 'Which technique avoids recomputing overlapping subproblems?',
      'options': ['Dynamic Programming', 'Greedy', 'Backtracking', 'Divide & Conquer'],
      'correct': 0,
      'explanation': 'DP stores results of subproblems (memoization / tabulation) to avoid redundant work.',
      'topic': 'DP', 'difficulty': 'Medium', 'xp': 35, 'coins': 20,
    },
    {
      'question': 'What is the worst-case height of an AVL tree with N nodes?',
      'options': ['O(log N)', 'O(N)', 'O(√N)', 'O(N log N)'],
      'correct': 0,
      'explanation': 'AVL trees maintain a balance factor of ±1, guaranteeing O(log N) height.',
      'topic': 'Trees', 'difficulty': 'Hard', 'xp': 50, 'coins': 30,
    },
    {
      'question': 'Which sorting algorithm is stable AND in-place?',
      'options': ['Insertion Sort', 'Merge Sort', 'Quick Sort', 'Heap Sort'],
      'correct': 0,
      'explanation': 'Insertion Sort is stable (preserves order of equal elements) and O(1) extra space.',
      'topic': 'Sorting', 'difficulty': 'Medium', 'xp': 30, 'coins': 15,
    },
    {
      'question': 'In Kruskal\'s algorithm, which data structure tracks connected components?',
      'options': ['Union-Find (DSU)', 'Hash Map', 'Stack', 'Priority Queue'],
      'correct': 0,
      'explanation': 'Union-Find (Disjoint Set Union) efficiently merges and queries connected components.',
      'topic': 'Graphs', 'difficulty': 'Hard', 'xp': 50, 'coins': 30,
    },
    {
      'question': 'What is the output of XOR-ing all elements when all appear twice except one?',
      'options': ['The unique element', 'Zero', 'The sum', 'Undefined'],
      'correct': 0,
      'explanation': 'XOR of same numbers = 0. Pairs cancel out, leaving only the unique element.',
      'topic': 'Bit Manipulation', 'difficulty': 'Medium', 'xp': 35, 'coins': 20,
    },
    {
      'question': 'Time complexity to build a max-heap from an unsorted array?',
      'options': ['O(N)', 'O(N log N)', 'O(log N)', 'O(N²)'],
      'correct': 0,
      'explanation': 'Bottom-up heap construction runs in O(N) — counterintuitively better than O(N log N).',
      'topic': 'Heaps', 'difficulty': 'Hard', 'xp': 50, 'coins': 30,
    },
    {
      'question': 'Which problem is solved using the "sliding window" technique?',
      'options': ['Maximum subarray of size K', 'Longest common subsequence', 'N-Queens', 'Coin Change'],
      'correct': 0,
      'explanation': 'Sliding window maintains a window of fixed or variable size, moving across the array.',
      'topic': 'Arrays', 'difficulty': 'Medium', 'xp': 35, 'coins': 20,
    },
    {
      'question': 'What does topological sort require about the graph?',
      'options': ['Directed Acyclic Graph (DAG)', 'Undirected Graph', 'Weighted Graph', 'Complete Graph'],
      'correct': 0,
      'explanation': 'Topological sort only applies to DAGs — cycles would create circular dependencies.',
      'topic': 'Graphs', 'difficulty': 'Medium', 'xp': 35, 'coins': 20,
    },
  ];

  // ─── Spin Rewards ──────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> _spinRewards = [
    {'label': '🪙 50',   'coins': 50,  'xp': 0,   'color': Color(0xFFFFB800)},
    {'label': '⚡ 25 XP','coins': 0,   'xp': 25,  'color': Color(0xFF7B2FFF)},
    {'label': '🪙 100',  'coins': 100, 'xp': 0,   'color': Color(0xFFFF6348)},
    {'label': '⚡ 10 XP','coins': 0,   'xp': 10,  'color': Color(0xFF00D4FF)},
    {'label': '🪙 25',   'coins': 25,  'xp': 0,   'color': Color(0xFF00FF87)},
    {'label': '⚡ 50 XP','coins': 0,   'xp': 50,  'color': Color(0xFFFF4757)},
    {'label': '🪙 200',  'coins': 200, 'xp': 0,   'color': Color(0xFFFFB800)},
    {'label': '⚡ 15 XP','coins': 0,   'xp': 15,  'color': Color(0xFF7B2FFF)},
  ];

  // ─── State ─────────────────────────────────────────────────────────────────
  Map<String, dynamic>? _todayChallenge;
  int? _selectedAnswer;
  bool _answered = false;
  bool _challengeClaimed = false;
  bool _spinUsed = false;
  bool _isSpinning = false;
  int _spinResultIndex = -1;
  bool _showSpinResult = false;

  // ─── Animations ────────────────────────────────────────────────────────────
  late AnimationController _spinCtrl;
  late Animation<double> _spinAnim;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _resultCtrl;
  late Animation<double> _resultAnim;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500));
    _spinAnim = CurvedAnimation(parent: _spinCtrl, curve: Curves.easeOutCubic);

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.97, end: 1.03).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 0.0), weight: 1),
    ]).animate(_shakeCtrl);

    _resultCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _resultAnim = CurvedAnimation(parent: _resultCtrl, curve: Curves.elasticOut);

    _loadDailyState();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  // ─── Get today's date key (resets daily) ───────────────────────────────────
  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }

  // ─── Pick today's challenge deterministically ───────────────────────────────
  Map<String, dynamic> _getTodaysChallenge() {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    return _challengeBank[dayOfYear % _challengeBank.length];
  }

  // ─── Load state from Firestore ─────────────────────────────────────────────
  Future<void> _loadDailyState() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final data = doc.data() ?? {};
    final dailyData = data['daily'] as Map<String, dynamic>? ?? {};
    final todayData = dailyData[_todayKey] as Map<String, dynamic>? ?? {};

    if (mounted) {
      setState(() {
        _todayChallenge = _getTodaysChallenge();
        _challengeClaimed = todayData['challengeClaimed'] == true;
        _spinUsed = todayData['spinUsed'] == true;
        if (_challengeClaimed) {
          _answered = true;
          _selectedAnswer = todayData['selectedAnswer'] as int?;
        }
      });
    }
  }

  // ─── Submit challenge answer ────────────────────────────────────────────────
  Future<void> _submitAnswer(int index) async {
    if (_answered) return;
    setState(() {
      _selectedAnswer = index;
      _answered = true;
    });

    final challenge = _todayChallenge!;
    final isCorrect = index == challenge['correct'];

    if (isCorrect) {
      _resultCtrl.forward(from: 0);
      await _claimChallengeReward(challenge);
    } else {
      _shakeCtrl.forward(from: 0);
    }
  }

  Future<void> _claimChallengeReward(Map<String, dynamic> challenge) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _challengeClaimed) return;
    setState(() => _challengeClaimed = true);

    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
    await ref.update({
      'coins': FieldValue.increment(challenge['coins']),
      'xp': FieldValue.increment(challenge['xp']),
      'daily.$_todayKey.challengeClaimed': true,
      'daily.$_todayKey.selectedAnswer': _selectedAnswer,
    });
  }

  // ─── Spin the wheel ────────────────────────────────────────────────────────
  Future<void> _spinWheel() async {
    if (_spinUsed || _isSpinning) return;
    setState(() => _isSpinning = true);

    // Pick random reward
    final rng = Random();
    final rewardIdx = rng.nextInt(_spinRewards.length);
    // Full rotations + land on the segment
    final totalRotations = 5 + rng.nextInt(3);
    final segmentAngle = (2 * pi) / _spinRewards.length;
    final targetAngle = totalRotations * 2 * pi + rewardIdx * segmentAngle;

    _spinCtrl.reset();
    _spinAnim = Tween(begin: 0.0, end: targetAngle).animate(
        CurvedAnimation(parent: _spinCtrl, curve: Curves.easeOutCubic));
    await _spinCtrl.forward();

    setState(() {
      _isSpinning = false;
      _spinResultIndex = rewardIdx;
      _showSpinResult = true;
      _spinUsed = true;
    });
    _resultCtrl.forward(from: 0);

    // Save to Firestore
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final reward = _spinRewards[rewardIdx];
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final updates = <String, dynamic>{
        'daily.$_todayKey.spinUsed': true,
        'daily.$_todayKey.spinReward': reward['label'],
      };
      if ((reward['coins'] as int) > 0) updates['coins'] = FieldValue.increment(reward['coins']);
      if ((reward['xp'] as int) > 0) updates['xp'] = FieldValue.increment(reward['xp']);
      await ref.update(updates);
    }
  }

  void _dismissSpinResult() => setState(() => _showSpinResult = false);

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_todayChallenge == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)));
    }
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildStreakBanner(),
              const SizedBox(height: 24),
              _buildSectionLabel('TODAY\'S CHALLENGE'),
              const SizedBox(height: 14),
              _buildChallengeCard(),
              const SizedBox(height: 28),
              _buildSectionLabel('DAILY SPIN'),
              const SizedBox(height: 14),
              _buildSpinSection(),
              const SizedBox(height: 28),
              _buildSectionLabel('THIS WEEK\'S PROGRESS'),
              const SizedBox(height: 14),
              _buildWeeklyProgress(),
              const SizedBox(height: 28),
              _buildSectionLabel('UPCOMING CHALLENGES'),
              const SizedBox(height: 14),
              _buildUpcomingChallenges(),
              const SizedBox(height: 20),
            ],
          ),
        ),
        // Spin result overlay
        if (_showSpinResult) _buildSpinResultOverlay(),
      ],
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final now = DateTime.now();
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final weekday = days[now.weekday - 1];
    final dateStr = '$weekday, ${months[now.month - 1]} ${now.day}';
    return Row(
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('DAILY HQ', style: TextStyle(
              color: _green, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 3)),
          const SizedBox(height: 4),
          const Text('Your Daily Arena', style: TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _green.withOpacity(0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.calendar_today, color: _green, size: 13),
            const SizedBox(width: 6),
            Text(dateStr, style: TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
        ),
      ],
    );
  }

  // ─── Streak Banner ────────────────────────────────────────────────────────
  Widget _buildStreakBanner() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
          .snapshots(),
      builder: (_, snap) {
        final data = snap.hasData ? (snap.data!.data() as Map<String, dynamic>? ?? {}) : {};
        final streak = data['streak'] ?? 0;
        final coins = data['coins'] ?? 0;
        final xp = data['xp'] ?? 0;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_accent.withOpacity(0.3), _cyan.withOpacity(0.15)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _accent.withOpacity(0.3)),
          ),
          child: Row(children: [
            // Streak fire
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 60, height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _gold.withOpacity(0.15),
                  border: Border.all(color: _gold.withOpacity(0.4), width: 2),
                ),
                child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('🔥', style: TextStyle(fontSize: 22)),
                  Text('$streak', style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ])),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$streak Day Streak!',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Keep grinding to unlock legendary rewards',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
              const SizedBox(height: 10),
              Row(children: [
                _miniStat('🪙', '$coins', _gold),
                const SizedBox(width: 10),
                _miniStat('⚡', '$xp XP', _cyan),
              ]),
            ])),
          ]),
        );
      },
    );
  }

  Widget _miniStat(String icon, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(icon, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 5),
        Text(val, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // ─── Challenge Card ───────────────────────────────────────────────────────
  Widget _buildChallengeCard() {
    final challenge = _todayChallenge!;
    final difficulty = challenge['difficulty'] as String;
    final diffColors = {'Easy': _green, 'Medium': _gold, 'Hard': _red};
    final diffColor = diffColors[difficulty] ?? _cyan;

    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(_shakeAnim.value, 0),
        child: child,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _cyan.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: _cyan.withOpacity(0.08), blurRadius: 24)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_cyan.withOpacity(0.15), _accent.withOpacity(0.1)],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: diffColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: diffColor.withOpacity(0.5)),
                ),
                child: Text(difficulty, style: TextStyle(
                    color: diffColor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(challenge['topic'] as String, style: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 11)),
              ),
              const Spacer(),
              if (_challengeClaimed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _green.withOpacity(0.4)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle, color: _green, size: 13),
                    const SizedBox(width: 4),
                    Text('DONE', style: TextStyle(
                        color: _green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ]),
                )
              else
                Row(children: [
                  Text('🪙 ${challenge['coins']}', style: TextStyle(
                      color: _gold, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('⚡ ${challenge['xp']} XP', style: TextStyle(
                      color: _cyan, fontSize: 12, fontWeight: FontWeight.bold)),
                ]),
            ]),
          ),

          // Question
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Today\'s Question', style: TextStyle(
                  color: Colors.white.withOpacity(0.35), fontSize: 11,
                  fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 12),
              Text(challenge['question'] as String, style: const TextStyle(
                  color: Colors.white, fontSize: 16, height: 1.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),

              // Options
              ...(challenge['options'] as List).asMap().entries.map((e) {
                final idx = e.key;
                final opt = e.value as String;
                return _buildOption(idx, opt, challenge['correct'] as int);
              }),

              // Explanation (shown after answering)
              if (_answered) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('💡 EXPLANATION', style: TextStyle(
                        color: _cyan, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text(challenge['explanation'] as String, style: TextStyle(
                        color: Colors.white.withOpacity(0.6), fontSize: 13, height: 1.5)),
                  ]),
                ),

                // Reward claimed badge
                if (_challengeClaimed) ...[
                  const SizedBox(height: 14),
                  ScaleTransition(
                    scale: _resultAnim,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_green.withOpacity(0.2), _cyan.withOpacity(0.1)]),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _green.withOpacity(0.4)),
                      ),
                      child: Center(child: Text(
                        '🎉 +${challenge['coins']} Coins & +${challenge['xp']} XP Claimed!',
                        style: TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 13),
                      )),
                    ),
                  ),
                ],
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildOption(int idx, String text, int correctIdx) {
    Color borderColor = Colors.white.withOpacity(0.1);
    Color bgColor = Colors.white.withOpacity(0.04);
    Color textColor = Colors.white.withOpacity(0.8);
    Widget? trailingIcon;

    if (_answered) {
      if (idx == correctIdx) {
        borderColor = _green.withOpacity(0.6);
        bgColor = _green.withOpacity(0.1);
        textColor = _green;
        trailingIcon = Icon(Icons.check_circle, color: _green, size: 18);
      } else if (idx == _selectedAnswer && idx != correctIdx) {
        borderColor = _red.withOpacity(0.6);
        bgColor = _red.withOpacity(0.1);
        textColor = _red;
        trailingIcon = Icon(Icons.cancel, color: _red, size: 18);
      }
    } else if (_selectedAnswer == idx) {
      borderColor = _cyan.withOpacity(0.6);
      bgColor = _cyan.withOpacity(0.1);
    }

    final labels = ['A', 'B', 'C', 'D'];

    return GestureDetector(
      onTap: () => _submitAnswer(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: borderColor.withOpacity(0.2),
              border: Border.all(color: borderColor),
            ),
            child: Center(child: Text(labels[idx], style: TextStyle(
                color: textColor, fontSize: 11, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(
              color: textColor, fontSize: 14, fontWeight: FontWeight.w500))),
          if (trailingIcon != null) trailingIcon,
        ]),
      ),
    );
  }

  // ─── Spin Wheel Section ───────────────────────────────────────────────────
  Widget _buildSpinSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _gold.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: _gold.withOpacity(0.07), blurRadius: 24)],
      ),
      child: Column(children: [
        Row(children: [
          const Text('🎰', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('DAILY SPIN', style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Spin once per day for free rewards!', style: TextStyle(
                color: Colors.white.withOpacity(0.4), fontSize: 11)),
          ]),
          const Spacer(),
          if (_spinUsed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Resets tomorrow', style: TextStyle(
                  color: Colors.white.withOpacity(0.35), fontSize: 10)),
            ),
        ]),
        const SizedBox(height: 24),

        // Wheel
        Stack(alignment: Alignment.center, children: [
          // Outer glow ring
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(scale: _spinUsed ? 1.0 : _pulseAnim.value, child: child),
            child: Container(
              width: 240, height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: _spinRewards.map((r) => (r['color'] as Color).withOpacity(0.3)).toList(),
                ),
              ),
            ),
          ),
          // Wheel
          AnimatedBuilder(
            animation: _spinAnim,
            builder: (_, __) => Transform.rotate(
              angle: _spinAnim.value,
              child: CustomPaint(
                size: const Size(220, 220),
                painter: _WheelPainter(_spinRewards),
              ),
            ),
          ),
          // Center pin
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFFFFB800), Color(0xFFFF6348)]),
              boxShadow: [BoxShadow(color: _gold.withOpacity(0.5), blurRadius: 12)],
            ),
            child: const Center(child: Text('★', style: TextStyle(color: Colors.white, fontSize: 16))),
          ),
          // Pointer triangle at top
          Positioned(
            top: 0,
            child: CustomPaint(
              size: const Size(20, 24),
              painter: _PointerPainter(),
            ),
          ),
        ]),

        const SizedBox(height: 24),

        // Spin button
        GestureDetector(
          onTap: _spinUsed ? null : _spinWheel,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: _spinUsed
                  ? null
                  : const LinearGradient(colors: [Color(0xFFFFB800), Color(0xFFFF6348)]),
              color: _spinUsed ? Colors.white.withOpacity(0.05) : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _spinUsed ? Colors.white.withOpacity(0.1) : _gold.withOpacity(0.5)),
              boxShadow: _spinUsed ? [] : [BoxShadow(color: _gold.withOpacity(0.3), blurRadius: 16)],
            ),
            child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_isSpinning ? '🌀' : (_spinUsed ? '✅' : '🎯'),
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Text(
                _isSpinning ? 'Spinning...' : (_spinUsed ? 'Already Spun Today' : 'SPIN NOW — FREE!'),
                style: TextStyle(
                  color: _spinUsed ? Colors.white38 : Colors.white,
                  fontWeight: FontWeight.bold, fontSize: 15,
                ),
              ),
            ])),
          ),
        ),
      ]),
    );
  }

  // ─── Spin Result Overlay ──────────────────────────────────────────────────
  Widget _buildSpinResultOverlay() {
    final reward = _spinRewards[_spinResultIndex];
    final color = reward['color'] as Color;
    return GestureDetector(
      onTap: _dismissSpinResult,
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Center(
          child: ScaleTransition(
            scale: _resultAnim,
            child: Container(
              margin: const EdgeInsets.all(40),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: color.withOpacity(0.6), width: 2),
                boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 40)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('🎉', style: const TextStyle(fontSize: 60)),
                const SizedBox(height: 12),
                const Text('YOU WON!', style: TextStyle(
                    color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Text(reward['label'] as String, style: TextStyle(
                      color: color, fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 20),
                Text('Added to your account!', style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 14)),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _dismissSpinResult,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text('AWESOME! 🚀', style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Weekly Progress ──────────────────────────────────────────────────────
  Widget _buildWeeklyProgress() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
          .snapshots(),
      builder: (_, snap) {
        final data = snap.hasData ? (snap.data!.data() as Map<String, dynamic>? ?? {}) : {};
        final dailyData = data['daily'] as Map<String, dynamic>? ?? {};

        // Build the last 7 days
        final days = ['M','T','W','T','F','S','S'];
        final now = DateTime.now();
        final List<Map<String, dynamic>> week = [];
        for (int i = 6; i >= 0; i--) {
          final d = now.subtract(Duration(days: i));
          final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
          final dayData = dailyData[key] as Map<String, dynamic>? ?? {};
          week.add({
            'label': days[d.weekday - 1],
            'done': dayData['challengeClaimed'] == true,
            'isToday': i == 0,
          });
        }

        final completedCount = week.where((d) => d['done'] == true).length;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$completedCount / 7 days completed',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text('Complete all 7 for a bonus reward!',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
              ])),
              if (completedCount == 7)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _gold.withOpacity(0.4)),
                  ),
                  child: Text('🏆 Perfect Week!', style: TextStyle(
                      color: _gold, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ]),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: week.map((d) {
                final done = d['done'] as bool;
                final isToday = d['isToday'] as bool;
                return Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? _green.withOpacity(0.2)
                          : isToday
                          ? _cyan.withOpacity(0.1)
                          : Colors.white.withOpacity(0.04),
                      border: Border.all(
                        color: done
                            ? _green.withOpacity(0.6)
                            : isToday
                            ? _cyan.withOpacity(0.5)
                            : Colors.white.withOpacity(0.1),
                        width: isToday ? 2 : 1,
                      ),
                    ),
                    child: Center(child: Text(
                      done ? '✓' : (isToday ? '●' : '○'),
                      style: TextStyle(
                          color: done ? _green : (isToday ? _cyan : Colors.white38),
                          fontSize: done ? 14 : (isToday ? 10 : 12),
                          fontWeight: FontWeight.bold),
                    )),
                  ),
                  const SizedBox(height: 6),
                  Text(d['label'] as String, style: TextStyle(
                      color: isToday ? _cyan : Colors.white38,
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
                ]);
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: completedCount / 7,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.06),
                valueColor: AlwaysStoppedAnimation<Color>(
                  completedCount == 7 ? _gold : _green,
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  // ─── Upcoming Challenges ──────────────────────────────────────────────────
  Widget _buildUpcomingChallenges() {
    final now = DateTime.now();
    return Column(
      children: List.generate(3, (i) {
        final futureDay = now.add(Duration(days: i + 1));
        final dayOfYear = futureDay.difference(DateTime(futureDay.year, 1, 1)).inDays;
        final challenge = _challengeBank[dayOfYear % _challengeBank.length];
        final days = ['Tomorrow', 'In 2 days', 'In 3 days'];
        final diffColors = {'Easy': _green, 'Medium': _gold, 'Hard': _red};
        final diffColor = diffColors[challenge['difficulty']] ?? _cyan;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: diffColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: diffColor.withOpacity(0.3)),
              ),
              child: Center(child: Text('🔒', style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(days[i], style: TextStyle(
                  color: Colors.white.withOpacity(0.35), fontSize: 10,
                  fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 4),
              Text(challenge['topic'] as String, style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: diffColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: diffColor.withOpacity(0.3)),
              ),
              child: Text(challenge['difficulty'] as String, style: TextStyle(
                  color: diffColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ]),
        );
      }),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(label, style: TextStyle(
        color: Colors.white.withOpacity(0.4), fontSize: 11,
        fontWeight: FontWeight.bold, letterSpacing: 3));
  }
}

// ─── Wheel Painter ────────────────────────────────────────────────────────────
class _WheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> segments;
  _WheelPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segAngle = (2 * pi) / segments.length;

    for (int i = 0; i < segments.length; i++) {
      final startAngle = i * segAngle - pi / 2;
      final color = segments[i]['color'] as Color;

      // Segment fill
      final paint = Paint()..color = color.withOpacity(i.isEven ? 0.85 : 0.65)..style = PaintingStyle.fill;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          startAngle, segAngle, true, paint);

      // Segment border
      final borderPaint = Paint()..color = Colors.white.withOpacity(0.15)
        ..style = PaintingStyle.stroke..strokeWidth = 1.5;
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          startAngle, segAngle, true, borderPaint);

      // Label text
      final textAngle = startAngle + segAngle / 2;
      final textRadius = radius * 0.65;
      final textX = center.dx + textRadius * cos(textAngle);
      final textY = center.dy + textRadius * sin(textAngle);

      canvas.save();
      canvas.translate(textX, textY);
      canvas.rotate(textAngle + pi / 2);

      final tp = TextPainter(
        text: TextSpan(
          text: segments[i]['label'] as String,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    // Outer ring
    final ringPaint = Paint()..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.stroke..strokeWidth = 3;
    canvas.drawCircle(center, radius, ringPaint);
  }

  @override
  bool shouldRepaint(_WheelPainter old) => false;
}

// ─── Pointer Painter ──────────────────────────────────────────────────────────
class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFB800)..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
    // White outline
    final border = Paint()..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawPath(path, border);
  }
  @override
  bool shouldRepaint(_PointerPainter old) => false;
}

// ─── Painters ────────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 0.5;
    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.07)
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