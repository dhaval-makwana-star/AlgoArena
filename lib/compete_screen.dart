import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'level1_binary_bubble.dart';
import 'level2_syntax_candy.dart';
import 'level3_memory_matrix.dart';
import 'level4_code_connect.dart';
import 'level5_debug_dash.dart';
import 'level6_algo_archer.dart';
import 'level7_regex_rush.dart';
import 'level8_stack_smash.dart';
import 'level9_dp_dungeon.dart';
import 'level10_master_forge.dart';

class CompeteScreen extends StatefulWidget {
  const CompeteScreen({super.key});

  @override
  State<CompeteScreen> createState() => _CompeteScreenState();
}

class _CompeteScreenState extends State<CompeteScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late AnimationController _floatCtrl;
  late List<AnimationController> _nodeCtrls;
  int _unlockedLevel = 1;
  Map<int, int> _levelStars = {};
  bool _loading = true;

  static const List<LevelData> _levels = [
    LevelData(
      id: 1,
      title: 'Binary Bubbles',
      subtitle: 'Pop correct binary values',
      icon: '🫧',
      theme: LevelTheme.forest,
      difficulty: 'Beginner',
      xpReward: 50,
      coinReward: 20,
    ),
    LevelData(
      id: 2,
      title: 'Syntax Candy',
      subtitle: 'Match syntax patterns',
      icon: '🍬',
      theme: LevelTheme.candy,
      difficulty: 'Beginner',
      xpReward: 75,
      coinReward: 30,
    ),
    LevelData(
      id: 3,
      title: 'Memory Matrix',
      subtitle: 'Remember code sequences',
      icon: '🧠',
      theme: LevelTheme.cyber,
      difficulty: 'Easy',
      xpReward: 100,
      coinReward: 40,
    ),
    LevelData(
      id: 4,
      title: 'Code Connect',
      subtitle: 'Connect matching concepts',
      icon: '🔗',
      theme: LevelTheme.ocean,
      difficulty: 'Easy',
      xpReward: 125,
      coinReward: 50,
    ),
    LevelData(
      id: 5,
      title: 'Debug Dash',
      subtitle: 'Race to fix bugs',
      icon: '🐛',
      theme: LevelTheme.lava,
      difficulty: 'Medium',
      xpReward: 150,
      coinReward: 60,
    ),
    LevelData(
      id: 6,
      title: 'Algo Archer',
      subtitle: 'Shoot correct algorithms',
      icon: '🏹',
      theme: LevelTheme.galaxy,
      difficulty: 'Medium',
      xpReward: 200,
      coinReward: 80,
    ),
    LevelData(
      id: 7,
      title: 'Regex Rush',
      subtitle: 'Pattern match at speed',
      icon: '⚡',
      theme: LevelTheme.storm,
      difficulty: 'Hard',
      xpReward: 250,
      coinReward: 100,
    ),
    LevelData(
      id: 8,
      title: 'Stack Smash',
      subtitle: 'Crush data structure puzzles',
      icon: '💥',
      theme: LevelTheme.neon,
      difficulty: 'Hard',
      xpReward: 300,
      coinReward: 120,
    ),
    LevelData(
      id: 9,
      title: 'DP Dungeon',
      subtitle: 'Solve dynamic programming',
      icon: '🏰',
      theme: LevelTheme.dungeon,
      difficulty: 'Expert',
      xpReward: 400,
      coinReward: 160,
    ),
    LevelData(
      id: 10,
      title: 'Master Forge',
      subtitle: 'The ultimate coding trial',
      icon: '⚔️',
      theme: LevelTheme.master,
      difficulty: 'Master',
      xpReward: 600,
      coinReward: 250,
    ),
  ];

  // Tree layout: x offset from center (-1, 0, 1), y position
  static const List<_NodePos> _nodePositions = [
    _NodePos(0.0, 0),    // Level 1 - center
    _NodePos(-0.6, 1),   // Level 2 - left
    _NodePos(0.6, 2),    // Level 3 - right
    _NodePos(0.0, 3),    // Level 4 - center
    _NodePos(-0.6, 4),   // Level 5 - left
    _NodePos(0.6, 5),    // Level 6 - right
    _NodePos(0.0, 6),    // Level 7 - center
    _NodePos(-0.5, 7),   // Level 8 - left
    _NodePos(0.5, 8),    // Level 9 - right
    _NodePos(0.0, 9),    // Level 10 - center (BOSS)
  ];

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _nodeCtrls = List.generate(
      10,
          (i) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600)),
    );
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) { setState(() => _loading = false); return; }
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data() ?? {};
    final levels = Map<String, dynamic>.from(data['levels'] ?? {});
    int unlocked = 1;
    Map<int, int> stars = {};
    for (int i = 1; i <= 10; i++) {
      final ld = levels['level_$i'];
      if (ld != null) {
        stars[i] = (ld['stars'] as num?)?.toInt() ?? 0;
        if (stars[i]! > 0 && i + 1 <= 10) unlocked = i + 1;
      }
    }
    setState(() {
      _unlockedLevel = unlocked;
      _levelStars = stars;
      _loading = false;
    });
    // Staggered node animations
    for (int i = 0; i < 10; i++) {
      await Future.delayed(Duration(milliseconds: 80 * i));
      if (mounted) _nodeCtrls[i].forward();
    }
  }

  void _openLevel(LevelData level) async {
    if (level.id > _unlockedLevel) return;
    Widget? screen;
    switch (level.id) {
      case 1: screen = Level1BinaryBubble(levelData: level, onComplete: _onLevelComplete); break;
      case 2: screen = Level2SyntaxCandy(levelData: level, onComplete: _onLevelComplete); break;
      case 3: screen = Level3MemoryMatrix(levelData: level, onComplete: _onLevelComplete); break;
      case 4: screen = Level4CodeConnect(levelData: level, onComplete: _onLevelComplete); break;
      case 5: screen = Level5DebugDash(levelData: level, onComplete: _onLevelComplete); break;
      case 6: screen = Level6AlgoArcher(levelData: level, onComplete: _onLevelComplete); break;
      case 7: screen = Level7RegexRush(levelData: level, onComplete: _onLevelComplete); break;
      case 8: screen = Level8StackSmash(levelData: level, onComplete: _onLevelComplete); break;
      case 9: screen = Level9DpDungeon(levelData: level, onComplete: _onLevelComplete); break;
      case 10: screen = Level10MasterForge(levelData: level, onComplete: _onLevelComplete); break;
    }
    if (screen == null) return;
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => screen!,
        transitionsBuilder: (_, anim, __, child) => _levelTransition(anim, child, level),
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
    _loadProgress();
  }

  Widget _levelTransition(Animation<double> anim, Widget child, LevelData level) {
    return AnimatedBuilder(
      animation: anim,
      child: child,
      builder: (_, c) {
        final scale = Tween<double>(begin: 0.0, end: 1.0)
            .animate(CurvedAnimation(parent: anim, curve: Curves.elasticOut));
        final fade = CurvedAnimation(parent: anim, curve: Curves.easeIn);
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(scale: scale, child: c),
        );
      },
    );
  }

  Future<void> _onLevelComplete(int levelId, int stars) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final level = _levels[levelId - 1];
    final xpGain = (level.xpReward * (stars / 3)).round();
    final coinGain = (level.coinReward * (stars / 3)).round();

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'levels': {
        'level_$levelId': {'stars': stars, 'completed': true},
      },
      'xp': FieldValue.increment(xpGain),
      'coins': FieldValue.increment(coinGain),
    }, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _floatCtrl.dispose();
    for (final c in _nodeCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060818),
      body: Stack(
        children: [
          _buildAnimatedBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
                      : _buildLevelTree(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(_bgCtrl.value * 0.4 - 0.2, -0.3),
                  radius: 1.4,
                  colors: const [Color(0xFF0D1B3E), Color(0xFF060818)],
                ),
              ),
            ),
            // Floating orbs
            ...List.generate(5, (i) {
              final offset = (_bgCtrl.value + i * 0.2) % 1.0;
              final colors = [
                const Color(0xFF00D4FF),
                const Color(0xFF7B2FFF),
                const Color(0xFFFFB800),
                const Color(0xFFFF4757),
                const Color(0xFF00FF87),
              ];
              return Positioned(
                left: (0.1 + i * 0.2) * MediaQuery.of(context).size.width,
                top: offset * MediaQuery.of(context).size.height,
                child: Container(
                  width: 80 + i * 20.0,
                  height: 80 + i * 20.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      colors[i].withOpacity(0.08),
                      Colors.transparent,
                    ]),
                  ),
                ),
              );
            }),
            // Grid
            CustomPaint(size: Size.infinite, painter: _GridPainter()),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('COMPETE',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3)),
              Text('Level $_unlockedLevel / 10 unlocked',
                  style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 12)),
            ],
          ),
          const Spacer(),
          _progressBadge(),
        ],
      ),
    );
  }

  Widget _progressBadge() {
    final completed = _levelStars.values.where((s) => s > 0).length;
    final totalStars = _levelStars.values.fold(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF7B2FFF), Color(0xFF00D4FF)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text('$completed/10', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text('⭐ $totalStars', style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildLevelTree() {
    const nodeHeight = 130.0;
    const totalHeight = nodeHeight * 10 + 60;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          children: [
            // Draw connector paths
            CustomPaint(
              size: Size(double.infinity, totalHeight),
              painter: _TreePathPainter(
                nodePositions: _nodePositions,
                unlockedLevel: _unlockedLevel,
                nodeHeight: nodeHeight,
                levelStars: _levelStars,
              ),
            ),
            // Draw nodes
            ..._levels.asMap().entries.map((e) {
              final i = e.key;
              final level = e.value;
              final pos = _nodePositions[i];
              return AnimatedBuilder(
                animation: _nodeCtrls[i],
                builder: (_, __) {
                  final anim = CurvedAnimation(
                    parent: _nodeCtrls[i],
                    curve: Curves.elasticOut,
                  );
                  return Positioned(
                    top: pos.row * nodeHeight + 10,
                    left: null,
                    right: null,
                    child: Transform.scale(
                      scale: _nodeCtrls[i].value,
                      child: _buildNode(level, i, pos, nodeHeight),
                    ),
                  );
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNode(LevelData level, int index, _NodePos pos, double nodeHeight) {
    final screenWidth = MediaQuery.of(context).size.width;
    final centerX = screenWidth / 2;
    final nodeX = centerX + pos.xFraction * (screenWidth * 0.3) - 50;
    final isUnlocked = level.id <= _unlockedLevel;
    final isCompleted = (_levelStars[level.id] ?? 0) > 0;
    final stars = _levelStars[level.id] ?? 0;
    final isBoss = level.id == 10;

    return Positioned(
      left: nodeX,
      top: pos.row * nodeHeight + 10,
      child: GestureDetector(
        onTap: () => _openLevel(level),
        child: AnimatedBuilder(
          animation: _floatCtrl,
          builder: (_, __) {
            final floatY = isCompleted ? sin(_floatCtrl.value * pi) * 4 : 0.0;
            return Transform.translate(
              offset: Offset(0, floatY),
              child: _NodeWidget(
                level: level,
                isUnlocked: isUnlocked,
                isCompleted: isCompleted,
                isBoss: isBoss,
                stars: stars,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NodeWidget extends StatelessWidget {
  final LevelData level;
  final bool isUnlocked;
  final bool isCompleted;
  final bool isBoss;
  final int stars;

  const _NodeWidget({
    required this.level,
    required this.isUnlocked,
    required this.isCompleted,
    required this.isBoss,
    required this.stars,
  });

  @override
  Widget build(BuildContext context) {
    final themeColors = level.theme.colors;
    final c1 = themeColors[0];
    final c2 = themeColors[1];

    return SizedBox(
      width: 100,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Glow ring
              if (isUnlocked)
                Container(
                  width: isBoss ? 90 : 76,
                  height: isBoss ? 90 : 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: c1.withOpacity(0.35), blurRadius: 20, spreadRadius: 4),
                    ],
                    gradient: RadialGradient(colors: [
                      c1.withOpacity(0.15),
                      Colors.transparent,
                    ]),
                  ),
                ),
              // Main circle
              Container(
                width: isBoss ? 82 : 68,
                height: isBoss ? 82 : 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isUnlocked
                      ? LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : const LinearGradient(colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
                  border: Border.all(
                    color: isUnlocked ? c1.withOpacity(0.6) : Colors.white12,
                    width: isBoss ? 3 : 2,
                  ),
                  boxShadow: isCompleted
                      ? [BoxShadow(color: c1.withOpacity(0.4), blurRadius: 16)]
                      : null,
                ),
                child: Center(
                  child: isUnlocked
                      ? Text(level.icon, style: TextStyle(fontSize: isBoss ? 32 : 26))
                      : const Icon(Icons.lock, color: Colors.white24, size: 24),
                ),
              ),
              // Completed checkmark
              if (isCompleted)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF00FF87),
                    ),
                    child: const Icon(Icons.check, color: Colors.black, size: 13),
                  ),
                ),
              // Level number badge
              Positioned(
                left: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isUnlocked ? c1 : Colors.white12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${level.id}',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(level.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isUnlocked ? Colors.white : Colors.white30,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
          // Stars
          if (isCompleted) ...[
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => Text(
                '⭐',
                style: TextStyle(fontSize: 9, color: i < stars ? Colors.amber : Colors.white12),
              )),
            ),
          ],
          if (isUnlocked && !isCompleted)
            Container(
              margin: const EdgeInsets.only(top: 3),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: c1.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: c1.withOpacity(0.3)),
              ),
              child: Text(level.difficulty,
                  style: TextStyle(color: c1, fontSize: 8, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

class _TreePathPainter extends CustomPainter {
  final List<_NodePos> nodePositions;
  final int unlockedLevel;
  final double nodeHeight;
  final Map<int, int> levelStars;

  _TreePathPainter({
    required this.nodePositions,
    required this.unlockedLevel,
    required this.nodeHeight,
    required this.levelStars,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    for (int i = 0; i < nodePositions.length - 1; i++) {
      final from = nodePositions[i];
      final to = nodePositions[i + 1];
      final fromX = centerX + from.xFraction * (size.width * 0.3) + 34; // node center
      final fromY = from.row * nodeHeight + 44;
      final toX = centerX + to.xFraction * (size.width * 0.3) + 34;
      final toY = to.row * nodeHeight + 10;
      final isUnlocked = i + 2 <= unlockedLevel;
      final isCompleted = (levelStars[i + 1] ?? 0) > 0;

      final paint = Paint()
        ..strokeWidth = isCompleted ? 3 : 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      if (isCompleted) {
        paint.shader = LinearGradient(
          colors: [const Color(0xFF00D4FF), const Color(0xFF7B2FFF)],
        ).createShader(Rect.fromPoints(Offset(fromX, fromY), Offset(toX, toY)));
      } else if (isUnlocked) {
        paint.color = const Color(0xFF00D4FF).withOpacity(0.4);
        paint.strokeWidth = 2;
      } else {
        paint.color = Colors.white.withOpacity(0.08);
      }

      final path = Path();
      path.moveTo(fromX, fromY);
      // Curved bezier path
      final midX = (fromX + toX) / 2;
      final midY = (fromY + toY) / 2;
      path.quadraticBezierTo(fromX + (toX - fromX) * 0.1, midY, toX, toY);
      canvas.drawPath(path, paint);

      // Draw dots along completed path
      if (isCompleted) {
        final dotPaint = Paint()
          ..color = const Color(0xFF00D4FF).withOpacity(0.5)
          ..style = PaintingStyle.fill;
        for (double t = 0.2; t <= 0.8; t += 0.3) {
          final dx = fromX + (toX - fromX) * t;
          final dy = fromY + (toY - fromY) * t;
          canvas.drawCircle(Offset(dx, dy), 3, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TreePathPainter old) =>
      old.unlockedLevel != unlockedLevel || old.levelStars != levelStars;
}

// ─── Data Models ──────────────────────────────────────────────────────────────

class LevelData {
  final int id;
  final String title;
  final String subtitle;
  final String icon;
  final LevelTheme theme;
  final String difficulty;
  final int xpReward;
  final int coinReward;

  const LevelData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.theme,
    required this.difficulty,
    required this.xpReward,
    required this.coinReward,
  });
}

enum LevelTheme { forest, candy, cyber, ocean, lava, galaxy, storm, neon, dungeon, master }

extension LevelThemeExt on LevelTheme {
  static List<Color> colors(LevelTheme t) {
    switch (t) {
      case LevelTheme.forest: return [const Color(0xFF00FF87), const Color(0xFF00C853)];
      case LevelTheme.candy: return [const Color(0xFFFF6B9D), const Color(0xFFFF4081)];
      case LevelTheme.cyber: return [const Color(0xFF00D4FF), const Color(0xFF0091EA)];
      case LevelTheme.ocean: return [const Color(0xFF40C4FF), const Color(0xFF0288D1)];
      case LevelTheme.lava: return [const Color(0xFFFF6348), const Color(0xFFD32F2F)];
      case LevelTheme.galaxy: return [const Color(0xFF7B2FFF), const Color(0xFF4A0080)];
      case LevelTheme.storm: return [const Color(0xFFFFEB3B), const Color(0xFFF57F17)];
      case LevelTheme.neon: return [const Color(0xFFE040FB), const Color(0xFF7B1FA2)];
      case LevelTheme.dungeon: return [const Color(0xFFFFB800), const Color(0xFFF9A825)];
      case LevelTheme.master: return [const Color(0xFFFF4757), const Color(0xFFC62828)];
    }
  }
}

extension LevelThemeColorGetter on LevelTheme {
  List<Color> get colors {
    return LevelThemeExt.colors(this);
  }
}

class _NodePos {
  final double xFraction; // -1 to 1
  final int row;
  const _NodePos(this.xFraction, this.row);
}

// ─── Level Complete Dialog ────────────────────────────────────────────────────

class LevelCompleteDialog extends StatefulWidget {
  final LevelData level;
  final int stars;
  final int xpEarned;
  final int coinsEarned;
  final VoidCallback onContinue;

  const LevelCompleteDialog({
    super.key,
    required this.level,
    required this.stars,
    required this.xpEarned,
    required this.coinsEarned,
    required this.onContinue,
  });

  @override
  State<LevelCompleteDialog> createState() => _LevelCompleteDialogState();
}

class _LevelCompleteDialogState extends State<LevelCompleteDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late AnimationController _starCtrl;
  late AnimationController _confettiCtrl;
  late List<_ConfettiPiece> _confetti;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _starCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();
    _confettiCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _confetti = List.generate(40, (_) => _ConfettiPiece());
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _starCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeColors = widget.level.theme.colors;
    final c1 = themeColors[0];
    final c2 = themeColors[1];

    return Stack(
      children: [
        // Confetti
        AnimatedBuilder(
          animation: _confettiCtrl,
          builder: (_, __) => CustomPaint(
            size: MediaQuery.of(context).size,
            painter: _ConfettiPainter(_confetti, _confettiCtrl.value),
          ),
        ),
        // Dialog
        Center(
          child: ScaleTransition(
            scale: CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut),
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [const Color(0xFF0D1B3E), const Color(0xFF1A0A3E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: c1.withOpacity(0.4), width: 2),
                boxShadow: [BoxShadow(color: c1.withOpacity(0.3), blurRadius: 40)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('LEVEL COMPLETE!',
                      style: TextStyle(
                          color: c1,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2)),
                  const SizedBox(height: 8),
                  Text(widget.level.title,
                      style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 20),
                  // Stars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return AnimatedBuilder(
                        animation: _starCtrl,
                        builder: (_, __) {
                          final delay = i * 0.3;
                          final t = ((_starCtrl.value - delay) / 0.4).clamp(0.0, 1.0);
                          final earned = i < widget.stars;
                          return Transform.scale(
                            scale: earned ? (0.5 + t * 0.5) : 1.0,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '⭐',
                                style: TextStyle(
                                  fontSize: 40,
                                  color: earned ? Colors.amber : Colors.white12,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  // Rewards
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _rewardChip('⚡ XP', '+${widget.xpEarned}', const Color(0xFF00D4FF)),
                      _rewardChip('🪙 Coins', '+${widget.coinsEarned}', const Color(0xFFFFB800)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: widget.onContinue,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [c1, c2]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: c1.withOpacity(0.4), blurRadius: 16)],
                      ),
                      child: const Center(
                        child: Text('CONTINUE →',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                                fontSize: 14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rewardChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }
}

class _ConfettiPiece {
  final double x = Random().nextDouble();
  final double speed = 0.3 + Random().nextDouble() * 0.7;
  final double size = 4 + Random().nextDouble() * 8;
  final Color color = [
    const Color(0xFF00D4FF), const Color(0xFFFFB800),
    const Color(0xFFFF4757), const Color(0xFF00FF87),
    const Color(0xFF7B2FFF),
  ][Random().nextInt(5)];
  final double rotation = Random().nextDouble() * pi * 2;
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress;
  _ConfettiPainter(this.pieces, this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final y = (progress * p.speed * size.height * 1.5 - p.size) % (size.height + p.size);
      final paint = Paint()..color = p.color.withOpacity(0.8);
      canvas.save();
      canvas.translate(p.x * size.width, y);
      canvas.rotate(p.rotation + progress * 3);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

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
  bool shouldRepaint(covariant CustomPainter old) => false;
}