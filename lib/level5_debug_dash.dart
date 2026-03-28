// level5_debug_dash.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../compete_screen.dart';

class Level5DebugDash extends StatefulWidget {
  final LevelData levelData;
  final Future<void> Function(int levelId, int stars) onComplete;
  const Level5DebugDash({super.key, required this.levelData, required this.onComplete});

  @override
  State<Level5DebugDash> createState() => _Level5DebugDashState();
}

class _Level5DebugDashState extends State<Level5DebugDash> with TickerProviderStateMixin {
  // Buggy code snippets with bug location index and fix
  static const List<Map<String, dynamic>> _bugs = [
    {
      'code': 'int x = 5\nif x > 3:\n  print(x)',
      'bugLine': 0,
      'bug': 'Missing semicolon',
      'options': ['Missing semicolon', 'Wrong variable', 'Wrong condition', 'Extra space'],
    },
    {
      'code': 'for i in range(10)\n  sum += i\nprint(sum)',
      'bugLine': 0,
      'bug': 'Missing colon',
      'options': ['Missing colon', 'Wrong range', 'Missing indent', 'Wrong variable'],
    },
    {
      'code': 'def add(a, b):\n  return a - b',
      'bugLine': 1,
      'bug': 'Should be a + b',
      'options': ['Should be a + b', 'Missing return', 'Wrong params', 'Wrong indent'],
    },
    {
      'code': 'arr = [1,2,3]\nprint(arr[3])',
      'bugLine': 1,
      'bug': 'Index out of bounds',
      'options': ['Index out of bounds', 'Wrong array', 'Syntax error', 'Missing bracket'],
    },
    {
      'code': 'while True\n  x += 1\n  if x == 10: break',
      'bugLine': 0,
      'bug': 'Missing colon',
      'options': ['Missing colon', 'Infinite loop', 'Wrong condition', 'Missing break'],
    },
    {
      'code': 'class Dog\n  def bark(self):\n    print("Woof")',
      'bugLine': 0,
      'bug': 'Missing colon',
      'options': ['Missing colon', 'Wrong method', 'Missing self', 'Bad indentation'],
    },
    {
      'code': 'n = int(input())\nif n = 0:\n  print("zero")',
      'bugLine': 1,
      'bug': 'Should be n == 0',
      'options': ['Should be n == 0', 'Wrong print', 'Missing else', 'Wrong type'],
    },
  ];

  late AnimationController _bgCtrl;
  late AnimationController _shakeCtrl;
  int _currentBug = 0;
  int _score = 0;
  int _lives = 3;
  int _timeLeft = 45;
  bool _showResult = false;
  bool _wrongAnswer = false;
  Timer? _timer;
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) _endGame();
      });
    });
    _shuffleBugs();
  }

  void _shuffleBugs() {
    // Just use in order for simplicity
  }

  void _onAnswer(String answer) {
    if (_showResult) return;
    final bug = _bugs[_currentBug % _bugs.length];
    if (answer == bug['bug']) {
      setState(() { _score += 20; _currentBug++; });
    } else {
      _lives--;
      _shakeCtrl.forward(from: 0);
      setState(() { _wrongAnswer = true; });
      Future.delayed(const Duration(milliseconds: 400), () {
        setState(() => _wrongAnswer = false);
      });
      if (_lives <= 0) _endGame();
    }
  }

  void _endGame() {
    _timer?.cancel();
    setState(() => _showResult = true);
    final stars = _score >= 80 ? 3 : _score >= 40 ? 2 : _score > 0 ? 1 : 0;
    widget.onComplete(widget.levelData.id, stars);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _shakeCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bug = _bugs[_currentBug % _bugs.length];
    final lines = (bug['code'] as String).split('\n');
    final bugLine = bug['bugLine'] as int;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0010),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _LavaBgPainter(_bgCtrl.value),
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
                        color: _timeLeft <= 10 ? const Color(0xFFFF4757).withOpacity(0.2) : Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _timeLeft <= 10 ? const Color(0xFFFF4757) : Colors.white24),
                      ),
                      child: Text('⏱ $_timeLeft',
                          style: TextStyle(color: _timeLeft <= 10 ? const Color(0xFFFF4757) : Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 12),
                    Row(children: List.generate(3, (i) => Text(i < _lives ? '🔴' : '🖤', style: const TextStyle(fontSize: 14)))),
                    const SizedBox(width: 12),
                    Text('🐛 $_score', style: const TextStyle(color: Color(0xFFFF6348), fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(height: 8),
                const Text('🐛 SPOT THE BUG',
                    style: TextStyle(color: Color(0xFFFF6348), fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 14)),
                const SizedBox(height: 12),
                // Code display
                AnimatedBuilder(
                  animation: _shakeCtrl,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(sin(_shakeCtrl.value * pi * 6) * (_wrongAnswer ? 8 : 0), 0),
                    child: child,
                  ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A0808),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFF6348).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: lines.asMap().entries.map((e) => Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: e.key == bugLine ? const Color(0xFFFF4757).withOpacity(0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: e.key == bugLine ? Border.all(color: const Color(0xFFFF4757).withOpacity(0.4)) : null,
                        ),
                        child: Row(children: [
                          Text('${e.key + 1}  ', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12, fontFamily: 'monospace')),
                          Text(e.value, style: const TextStyle(color: Color(0xFF00FF87), fontSize: 14, fontFamily: 'monospace')),
                          if (e.key == bugLine) ...[
                            const Spacer(),
                            const Icon(Icons.bug_report, color: Color(0xFFFF4757), size: 16),
                          ]
                        ]),
                      )).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('What\'s the bug?', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 12),
                // Options
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: (bug['options'] as List<String>).map((opt) =>
                        GestureDetector(
                          onTap: () => _onAnswer(opt),
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFFF6348).withOpacity(0.25)),
                            ),
                            child: Text(opt, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
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
            stars: _score >= 80 ? 3 : _score >= 40 ? 2 : _score > 0 ? 1 : 0,
            xpEarned: widget.levelData.xpReward * (_score >= 80 ? 3 : _score >= 40 ? 2 : 1) ~/ 3,
            coinsEarned: widget.levelData.coinReward * (_score >= 80 ? 3 : _score >= 40 ? 2 : 1) ~/ 3,
            onContinue: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _LavaBgPainter extends CustomPainter {
  final double t;
  _LavaBgPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 5; i++) {
      final x = sin(t * 2 * pi + i * 1.2) * size.width * 0.3 + size.width * 0.5;
      final y = cos(t * pi + i * 0.8) * size.height * 0.2 + size.height * 0.7;
      paint.color = const Color(0xFFFF6348).withOpacity(0.04);
      canvas.drawCircle(Offset(x, y), 80 + i * 30.0, paint);
    }
  }
  @override
  bool shouldRepaint(_LavaBgPainter old) => old.t != t;
}