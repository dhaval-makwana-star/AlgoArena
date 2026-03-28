// level10_master_forge.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../compete_screen.dart';

class Level10MasterForge extends StatefulWidget {
  final LevelData levelData;
  final Future<void> Function(int levelId, int stars) onComplete;
  const Level10MasterForge({super.key, required this.levelData, required this.onComplete});

  @override
  State<Level10MasterForge> createState() => _Level10MasterForgeState();
}

class _Level10MasterForgeState extends State<Level10MasterForge> with TickerProviderStateMixin {
  // Mixed supreme challenges
  static const List<Map<String, dynamic>> _trials = [
    {
      'category': 'COMPLEXITY',
      'q': 'Time complexity of merge sort?',
      'answer': 'O(n log n)',
      'options': ['O(n²)', 'O(n log n)', 'O(log n)', 'O(n)'],
    },
    {
      'category': 'RECURSION',
      'q': 'Base case for factorial(n)?',
      'answer': 'n == 0 or n == 1',
      'options': ['n == 0 or n == 1', 'n > 0', 'n < 0', 'n == -1'],
    },
    {
      'category': 'TREES',
      'q': 'Inorder traversal of BST gives?',
      'answer': 'Sorted sequence',
      'options': ['Sorted sequence', 'Reverse sorted', 'Random order', 'Breadth-first'],
    },
    {
      'category': 'GRAPHS',
      'q': 'BFS uses which data structure?',
      'answer': 'Queue',
      'options': ['Stack', 'Queue', 'Heap', 'Array'],
    },
    {
      'category': 'DP',
      'q': 'Overlapping subproblems + optimal substructure = ?',
      'answer': 'Dynamic Programming',
      'options': ['Greedy', 'Divide & Conquer', 'Dynamic Programming', 'Backtracking'],
    },
    {
      'category': 'HASHING',
      'q': 'Worst case for HashMap lookup?',
      'answer': 'O(n)',
      'options': ['O(1)', 'O(log n)', 'O(n)', 'O(n²)'],
    },
    {
      'category': 'OOP',
      'q': 'Which principle does "Program to an interface" follow?',
      'answer': 'Dependency Inversion',
      'options': ['Single Responsibility', 'Dependency Inversion', 'Open/Closed', 'Liskov'],
    },
    {
      'category': 'SYSTEMS',
      'q': 'What does ACID stand for in databases?',
      'answer': 'Atomicity Consistency Isolation Durability',
      'options': ['Atomicity Consistency Isolation Durability', 'Async Consistent Indexed Data', 'Abstraction Control Indexing Delivery', 'Access Control Identity Database'],
    },
  ];

  late AnimationController _bgCtrl;
  late AnimationController _swordCtrl;
  late AnimationController _bossCtrl;

  int _current = 0;
  int _score = 0;
  int _bossHp = 8;
  int _playerHp = 5;
  bool _showResult = false;
  String? _combo;
  int _comboCount = 0;
  bool _animatingAttack = false;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _swordCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _bossCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  void _onAnswer(String ans) async {
    if (_showResult || _animatingAttack) return;
    final trial = _trials[_current % _trials.length];
    final correct = ans == trial['answer'];

    setState(() => _animatingAttack = true);
    if (correct) {
      _comboCount++;
      final dmg = _comboCount >= 3 ? 2 : 1;
      _bossHp -= dmg;
      _score += 50 * _comboCount;
      _combo = _comboCount >= 3 ? '🔥 COMBO x$_comboCount! -$dmg HP!' : '⚔️ HIT! -$dmg HP';
      await _swordCtrl.forward(from: 0);
      await _bossCtrl.forward(from: 0);
    } else {
      _comboCount = 0;
      _playerHp--;
      _combo = '💀 MISS! -1 HP to you';
      await _bossCtrl.forward(from: 0);
    }

    _current++;
    setState(() {
      _animatingAttack = false;
    });

    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _combo = null);

    if (_bossHp <= 0 || _playerHp <= 0 || _current >= _trials.length) {
      _endGame();
    }
  }

  void _endGame() {
    setState(() => _showResult = true);
    final stars = _bossHp <= 0 && _playerHp >= 4 ? 3 : _bossHp <= 0 ? 2 : _score > 0 ? 1 : 0;
    widget.onComplete(widget.levelData.id, stars);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _swordCtrl.dispose();
    _bossCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trialIdx = _current % _trials.length;
    final trial = _trials[trialIdx];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0000),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _MasterBgPainter(_bgCtrl.value),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    GestureDetector(onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 18)),
                    const Spacer(),
                    Text('${_current + 1}/${_trials.length}',
                        style: const TextStyle(color: Color(0xFFFF4757), fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Text('⚔️ $_score', style: const TextStyle(color: Color(0xFFFF4757), fontWeight: FontWeight.bold, fontSize: 16)),
                  ]),
                ),
                // Boss + Player HP bars
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _hpBar('👿 FINAL BOSS', _bossHp, 8, const Color(0xFFFF4757)),
                      const SizedBox(height: 8),
                      _hpBar('⚔️ YOU', _playerHp, 5, const Color(0xFF00FF87)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Boss character
                AnimatedBuilder(
                  animation: _bossCtrl,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(sin(_bossCtrl.value * pi * 4) * 10, 0),
                    child: const Text('👿', style: TextStyle(fontSize: 70)),
                  ),
                ),
                // Combo feedback
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _combo != null
                      ? Container(
                    key: ValueKey(_combo),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _combo!.contains('MISS')
                          ? const Color(0xFFFF4757).withOpacity(0.15)
                          : const Color(0xFF00FF87).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_combo!,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  )
                      : const SizedBox(height: 32),
                ),
                // Category badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4757).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFF4757).withOpacity(0.4)),
                  ),
                  child: Text(trial['category'] as String,
                      style: const TextStyle(color: Color(0xFFFF4757), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 2)),
                ),
                const SizedBox(height: 10),
                // Question
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(trial['q'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const Spacer(),
                // Answer options
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: (trial['options'] as List<String>).map((opt) =>
                        GestureDetector(
                          onTap: () => _onAnswer(opt),
                          child: AnimatedBuilder(
                            animation: _swordCtrl,
                            builder: (_, __) => Container(
                              width: double.infinity,
                              margin: const EdgeInsets.symmetric(vertical: 5),
                              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  const Color(0xFF1A0000),
                                  const Color(0xFF2A0000),
                                ]),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFFF4757).withOpacity(0.25)),
                              ),
                              child: Row(children: [
                                const Text('⚔️ ', style: TextStyle(fontSize: 14)),
                                Expanded(child: Text(opt,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13))),
                              ]),
                            ),
                          ),
                        ),
                    ).toList(),
                  ),
                ),
              ],
            ),
          ),
          if (_showResult) LevelCompleteDialog(
            level: widget.levelData,
            stars: _bossHp <= 0 && _playerHp >= 4 ? 3 : _bossHp <= 0 ? 2 : _score > 0 ? 1 : 0,
            xpEarned: widget.levelData.xpReward * (_bossHp <= 0 && _playerHp >= 4 ? 3 : _bossHp <= 0 ? 2 : 1) ~/ 3,
            coinsEarned: widget.levelData.coinReward * (_bossHp <= 0 && _playerHp >= 4 ? 3 : _bossHp <= 0 ? 2 : 1) ~/ 3,
            onContinue: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _hpBar(String label, int hp, int max, Color color) {
    return Row(children: [
      SizedBox(width: 100, child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))),
      Expanded(
        child: Stack(children: [
          Container(height: 10, decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(5))),
          AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 400),
            widthFactor: (hp / max).clamp(0.0, 1.0),
            child: Container(height: 10, decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
              borderRadius: BorderRadius.circular(5),
              boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)],
            )),
          ),
        ]),
      ),
      const SizedBox(width: 8),
      Text('$hp/$max', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    ]);
  }
}

class _MasterBgPainter extends CustomPainter {
  final double t;
  _MasterBgPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    // Lava cracks
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 2;
    for (int i = 0; i < 5; i++) {
      paint.color = const Color(0xFFFF4757).withOpacity(0.06 + sin(t * 2 * pi + i) * 0.02);
      final path = Path();
      path.moveTo(i * size.width / 5, size.height);
      path.lineTo(size.width * 0.5 + sin(t * pi + i) * 50, 0);
      canvas.drawPath(path, paint);
    }
    // Glow at top
    final glowPaint = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFFF4757).withOpacity(0.1 + sin(t * 2 * pi) * 0.05),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: Offset(size.width / 2, 0), radius: 200));
    canvas.drawCircle(Offset(size.width / 2, 0), 200, glowPaint);
  }
  @override
  bool shouldRepaint(_MasterBgPainter old) => old.t != t;
}