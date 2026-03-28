// level6_algo_archer.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../compete_screen.dart';

class Level6AlgoArcher extends StatefulWidget {
  final LevelData levelData;
  final Future<void> Function(int levelId, int stars) onComplete;
  const Level6AlgoArcher({super.key, required this.levelData, required this.onComplete});

  @override
  State<Level6AlgoArcher> createState() => _Level6AlgoArcherState();
}

class _Level6AlgoArcherState extends State<Level6AlgoArcher> with TickerProviderStateMixin {
  // Question → correct algorithm
  static const List<Map<String, dynamic>> _questions = [
    {'q': 'Find shortest path in weighted graph', 'correct': 'Dijkstra', 'options': ['Dijkstra', 'BFS', 'DFS', 'Prim\'s']},
    {'q': 'Sort array efficiently O(n log n)', 'correct': 'Merge Sort', 'options': ['Bubble Sort', 'Merge Sort', 'Selection Sort', 'Insertion Sort']},
    {'q': 'Search in sorted array O(log n)', 'correct': 'Binary Search', 'options': ['Linear Search', 'Jump Search', 'Binary Search', 'Fibonacci Search']},
    {'q': 'Find minimum spanning tree', 'correct': 'Kruskal\'s', 'options': ['Kruskal\'s', 'Dijkstra', 'Floyd-Warshall', 'Bellman-Ford']},
    {'q': 'Detect cycle in directed graph', 'correct': 'DFS', 'options': ['BFS', 'DFS', 'Topological Sort', 'Union-Find']},
    {'q': 'Find all shortest paths', 'correct': 'Floyd-Warshall', 'options': ['Dijkstra', 'Floyd-Warshall', 'Bellman-Ford', 'BFS']},
    {'q': 'Balance a binary tree', 'correct': 'AVL Tree', 'options': ['Red-Black Tree', 'AVL Tree', 'B-Tree', 'Splay Tree']},
    {'q': 'String pattern matching', 'correct': 'KMP', 'options': ['Naive', 'KMP', 'Rabin-Karp', 'Z-Algorithm']},
  ];

  late AnimationController _bgCtrl;
  late AnimationController _arrowCtrl;

  // Targets moving across screen
  List<_Target> _targets = [];
  int _currentQ = 0;
  int _score = 0;
  int _lives = 3;
  int _timeLeft = 50;
  bool _showResult = false;
  Timer? _timer;
  Timer? _spawnTimer;
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _arrowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) _endGame();
      });
    });
    _spawnTargets();
    _spawnTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_showResult) _spawnTargets();
    });
  }

  void _spawnTargets() {
    if (_showResult) return;
    final q = _questions[_currentQ % _questions.length];
    final opts = List<String>.from(q['options'] as List)..shuffle(_rand);
    setState(() {
      _targets = opts.asMap().entries.map((e) {
        return _Target(
          label: e.value,
          isCorrect: e.value == q['correct'],
          x: 0.05 + _rand.nextDouble() * 0.85,
          y: 0.15 + e.key * 0.15,
          speed: 0.003 + _rand.nextDouble() * 0.003,
          color: _targetColors[e.key % _targetColors.length],
        );
      }).toList();
    });
  }

  static const List<Color> _targetColors = [
    Color(0xFF7B2FFF), Color(0xFF00D4FF), Color(0xFFFF6348), Color(0xFF00FF87),
  ];

  void _onShoot(_Target target) {
    if (target.hit || _showResult) return;
    setState(() => target.hit = true);

    if (target.isCorrect) {
      _score += 25;
      _currentQ++;
      Future.delayed(const Duration(milliseconds: 300), _spawnTargets);
    } else {
      _lives--;
      if (_lives <= 0) _endGame();
    }
    setState(() {});
  }

  void _endGame() {
    _timer?.cancel();
    _spawnTimer?.cancel();
    setState(() => _showResult = true);
    final stars = _score >= 100 ? 3 : _score >= 50 ? 2 : _score > 0 ? 1 : 0;
    widget.onComplete(widget.levelData.id, stars);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _arrowCtrl.dispose();
    _timer?.cancel();
    _spawnTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_currentQ % _questions.length];
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF080020),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _GalaxyBgPainter(_bgCtrl.value),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('⏱ $_timeLeft', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Row(children: List.generate(3, (i) => Text(i < _lives ? '💜' : '🖤', style: const TextStyle(fontSize: 14)))),
                    const SizedBox(width: 12),
                    Text('🏹 $_score', style: const TextStyle(color: Color(0xFF7B2FFF), fontWeight: FontWeight.bold, fontSize: 16)),
                  ]),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B2FFF).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF7B2FFF).withOpacity(0.3)),
                  ),
                  child: Text(q['q'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(height: 6),
                const Text('🏹 Shoot the correct algorithm!', style: TextStyle(color: Colors.white38, fontSize: 12)),
                // Targets area
                Expanded(
                  child: Stack(
                    children: _targets.where((t) => !t.hit).map((t) {
                      return AnimatedBuilder(
                        animation: _bgCtrl,
                        builder: (_, __) {
                          t.x += t.speed;
                          if (t.x > 1.1) t.x = -0.2;
                          return Positioned(
                            left: t.x * size.width - 60,
                            top: t.y * (size.height * 0.55),
                            child: GestureDetector(
                              onTap: () => _onShoot(t),
                              child: _TargetWidget(target: t),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          if (_showResult) LevelCompleteDialog(
            level: widget.levelData,
            stars: _score >= 100 ? 3 : _score >= 50 ? 2 : _score > 0 ? 1 : 0,
            xpEarned: widget.levelData.xpReward * (_score >= 100 ? 3 : _score >= 50 ? 2 : 1) ~/ 3,
            coinsEarned: widget.levelData.coinReward * (_score >= 100 ? 3 : _score >= 50 ? 2 : 1) ~/ 3,
            onContinue: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _Target {
  final String label;
  final bool isCorrect;
  double x;
  final double y;
  final double speed;
  final Color color;
  bool hit = false;
  _Target({required this.label, required this.isCorrect, required this.x, required this.y, required this.speed, required this.color});
}

class _TargetWidget extends StatelessWidget {
  final _Target target;
  const _TargetWidget({required this.target});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(colors: [target.color.withOpacity(0.8), target.color.withOpacity(0.4)]),
        border: Border.all(color: target.color, width: 2),
        boxShadow: [BoxShadow(color: target.color.withOpacity(0.4), blurRadius: 12)],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('🎯 ', style: TextStyle(fontSize: 14)),
        Text(target.label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
    );
  }
}

class _GalaxyBgPainter extends CustomPainter {
  final double t;
  final _rand = Random(42);
  _GalaxyBgPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final starPaint = Paint()..color = Colors.white.withOpacity(0.4);
    for (int i = 0; i < 60; i++) {
      final x = _rand.nextDouble() * size.width;
      final y = _rand.nextDouble() * size.height;
      final r = 0.5 + _rand.nextDouble() * 1.5;
      final twinkle = 0.3 + 0.7 * sin(t * 2 * pi * (0.5 + _rand.nextDouble()) + i);
      starPaint.color = Colors.white.withOpacity(twinkle * 0.5);
      canvas.drawCircle(Offset(x, y), r, starPaint);
    }
    // Nebula
    final nebulaPaint = Paint()..style = PaintingStyle.fill;
    nebulaPaint.color = const Color(0xFF7B2FFF).withOpacity(0.05);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.3), 200, nebulaPaint);
    nebulaPaint.color = const Color(0xFF00D4FF).withOpacity(0.04);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.6), 180, nebulaPaint);
  }
  @override
  bool shouldRepaint(_GalaxyBgPainter old) => old.t != t;
}