// level9_dp_dungeon.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../compete_screen.dart';

class Level9DpDungeon extends StatefulWidget {
  final LevelData levelData;
  final Future<void> Function(int levelId, int stars) onComplete;
  const Level9DpDungeon({super.key, required this.levelData, required this.onComplete});

  @override
  State<Level9DpDungeon> createState() => _Level9DpDungeonState();
}

class _Level9DpDungeonState extends State<Level9DpDungeon> with TickerProviderStateMixin {
  // DP problems
  static const List<Map<String, dynamic>> _problems = [
    {
      'title': 'Fibonacci',
      'desc': 'What is fib(7)? (fib(0)=0, fib(1)=1)',
      'answer': '13',
      'options': ['8', '13', '21', '5'],
      'hint': 'fib(n) = fib(n-1) + fib(n-2)',
    },
    {
      'title': 'Coin Change',
      'desc': 'Min coins to make 7 using [1, 3, 4]?',
      'answer': '2',
      'options': ['2', '3', '4', '7'],
      'hint': '4 + 3 = 7 → 2 coins',
    },
    {
      'title': 'LCS',
      'desc': 'Longest Common Subsequence of "ABCB" and "BDCAB"?',
      'answer': '3',
      'options': ['2', '3', '4', '5'],
      'hint': 'LCS = "BCB" or "BCA" → length 3',
    },
    {
      'title': 'Knapsack',
      'desc': 'Max value: capacity=5, weights=[2,3,4], values=[3,4,5]',
      'answer': '7',
      'options': ['5', '7', '9', '4'],
      'hint': 'Items 1+2 (w=2+3=5, v=3+4=7)',
    },
    {
      'title': 'Edit Distance',
      'desc': 'Edit distance between "cat" and "cut"?',
      'answer': '1',
      'options': ['0', '1', '2', '3'],
      'hint': 'Replace a→u: 1 operation',
    },
  ];

  late AnimationController _bgCtrl;
  late AnimationController _torchCtrl;
  int _current = 0;
  int _score = 0;
  int _health = 5; // dungeon health
  bool _showResult = false;
  String? _feedback;
  bool _showFeedback = false;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _torchCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..repeat(reverse: true);
  }

  void _onAnswer(String ans) {
    if (_showResult || _showFeedback) return;
    final problem = _problems[_current];
    final correct = ans == problem['answer'];
    setState(() {
      _showFeedback = true;
      _feedback = correct ? '⚔️ Correct! Monster slain!' : '💀 Wrong! -1 HP';
      if (correct) { _score += 40; } else { _health--; }
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      setState(() { _showFeedback = false; _feedback = null; });
      if (correct) {
        _current++;
        if (_current >= _problems.length || _health <= 0) _endGame();
      } else if (_health <= 0) {
        _endGame();
      }
    });
  }

  void _endGame() {
    setState(() => _showResult = true);
    final stars = _health >= 4 ? 3 : _health >= 2 ? 2 : _score > 0 ? 1 : 0;
    widget.onComplete(widget.levelData.id, stars);
  }

  @override
  void dispose() { _bgCtrl.dispose(); _torchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    if (_current >= _problems.length) {
      return const Scaffold(backgroundColor: Color(0xFF060818));
    }
    final problem = _problems[_current];

    return Scaffold(
      backgroundColor: const Color(0xFF05020A),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _DungeonBgPainter(_bgCtrl.value),
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
                    // HP
                    Row(children: List.generate(5, (i) =>
                        Text(i < _health ? '❤️' : '🖤', style: const TextStyle(fontSize: 14)))),
                    const SizedBox(width: 16),
                    Text('🏰 $_score', style: const TextStyle(color: Color(0xFFFFB800), fontWeight: FontWeight.bold, fontSize: 16)),
                  ]),
                ),
                // Dungeon progress
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: List.generate(_problems.length, (i) => Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i < _current
                              ? const Color(0xFFFFB800)
                              : i == _current
                              ? const Color(0xFFFFB800).withOpacity(0.4)
                              : Colors.white.withOpacity(0.1),
                        ),
                      ),
                    )),
                  ),
                ),
                const SizedBox(height: 20),
                // Monster card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [const Color(0xFF1A0A00), const Color(0xFF2A1000)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.3)),
                    boxShadow: [const BoxShadow(color: Color(0xFFFFB800), blurRadius: 20, spreadRadius: -8)],
                  ),
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _torchCtrl,
                        builder: (_, __) => Text(
                          '🐉',
                          style: TextStyle(fontSize: 52 + _torchCtrl.value * 4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(problem['title'] as String,
                          style: const TextStyle(color: Color(0xFFFFB800), fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 13)),
                      const SizedBox(height: 10),
                      Text(problem['desc'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(problem['hint'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                if (_showFeedback)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _feedback!.contains('Correct')
                          ? const Color(0xFF00FF87).withOpacity(0.1)
                          : const Color(0xFFFF4757).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _feedback!.contains('Correct')
                            ? const Color(0xFF00FF87).withOpacity(0.4)
                            : const Color(0xFFFF4757).withOpacity(0.4),
                      ),
                    ),
                    child: Center(child: Text(_feedback!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 3,
                    children: (problem['options'] as List<String>).map((opt) =>
                        GestureDetector(
                          onTap: () => _onAnswer(opt),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1A0A00), Color(0xFF2A1000)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.3)),
                            ),
                            child: Center(child: Text(opt,
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
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
            stars: _health >= 4 ? 3 : _health >= 2 ? 2 : _score > 0 ? 1 : 0,
            xpEarned: widget.levelData.xpReward * (_health >= 4 ? 3 : _health >= 2 ? 2 : 1) ~/ 3,
            coinsEarned: widget.levelData.coinReward * (_health >= 4 ? 3 : _health >= 2 ? 2 : 1) ~/ 3,
            onContinue: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _DungeonBgPainter extends CustomPainter {
  final double t;
  _DungeonBgPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    // Stone wall effect
    final paint = Paint()..color = Colors.white.withOpacity(0.015);
    const brickW = 60.0, brickH = 24.0;
    for (double y = 0; y < size.height; y += brickH) {
      final offset = ((y / brickH).toInt() % 2 == 0) ? 0.0 : brickW / 2;
      for (double x = -brickW + offset; x < size.width; x += brickW) {
        canvas.drawRect(Rect.fromLTWH(x + 1, y + 1, brickW - 2, brickH - 2), paint);
      }
    }
    // Torch flicker
    final torchPaint = Paint()..color = const Color(0xFFFFB800).withOpacity(0.06 + sin(t * 2 * pi) * 0.02);
    canvas.drawCircle(Offset(40, size.height * 0.4), 80, torchPaint);
    canvas.drawCircle(Offset(size.width - 40, size.height * 0.4), 80, torchPaint);
  }
  @override
  bool shouldRepaint(_DungeonBgPainter old) => old.t != t;
}