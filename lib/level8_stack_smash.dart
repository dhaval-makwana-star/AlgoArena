// level8_stack_smash.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../compete_screen.dart';

class Level8StackSmash extends StatefulWidget {
  final LevelData levelData;
  final Future<void> Function(int levelId, int stars) onComplete;
  const Level8StackSmash({super.key, required this.levelData, required this.onComplete});

  @override
  State<Level8StackSmash> createState() => _Level8StackSmashState();
}

class _Level8StackSmashState extends State<Level8StackSmash> with TickerProviderStateMixin {
  // Simulate stack/queue operations
  static const List<Map<String, dynamic>> _puzzles = [
    {
      'type': 'Stack',
      'ops': ['PUSH 1', 'PUSH 2', 'PUSH 3', 'POP', 'TOP?'],
      'answer': '2',
      'options': ['1', '2', '3', 'empty'],
      'hint': 'LIFO: Last In First Out',
    },
    {
      'type': 'Queue',
      'ops': ['ENQUEUE A', 'ENQUEUE B', 'ENQUEUE C', 'DEQUEUE', 'FRONT?'],
      'answer': 'B',
      'options': ['A', 'B', 'C', 'empty'],
      'hint': 'FIFO: First In First Out',
    },
    {
      'type': 'Stack',
      'ops': ['PUSH 5', 'PUSH 3', 'POP', 'POP', 'TOP?'],
      'answer': 'empty',
      'options': ['5', '3', 'empty', '8'],
      'hint': 'Stack is empty after 2 pops',
    },
    {
      'type': 'Queue',
      'ops': ['ENQUEUE 10', 'ENQUEUE 20', 'DEQUEUE', 'DEQUEUE', 'SIZE?'],
      'answer': '0',
      'options': ['0', '1', '2', '10'],
      'hint': 'Both elements dequeued',
    },
    {
      'type': 'Stack',
      'ops': ['PUSH X', 'PUSH Y', 'PUSH Z', 'POP', 'POP', 'TOP?'],
      'answer': 'X',
      'options': ['X', 'Y', 'Z', 'empty'],
      'hint': 'X remains after 2 pops',
    },
  ];

  late AnimationController _bgCtrl;
  late AnimationController _popCtrl;
  int _currentPuzzle = 0;
  int _score = 0;
  bool _showResult = false;
  List<String> _displayedOps = [];
  int _opIndex = 0;
  Timer? _opTimer;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _popCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _showNextPuzzle();
  }

  void _showNextPuzzle() {
    _displayedOps = [];
    _opIndex = 0;
    _opTimer?.cancel();
    _opTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      final puzzle = _puzzles[_currentPuzzle];
      final ops = puzzle['ops'] as List<String>;
      if (_opIndex < ops.length - 1) {
        setState(() => _displayedOps.add(ops[_opIndex++]));
      } else {
        _opTimer?.cancel();
      }
    });
  }

  void _onAnswer(String ans) {
    if (_showResult) return;
    final puzzle = _puzzles[_currentPuzzle];
    if (ans == puzzle['answer']) {
      setState(() { _score += 30; _currentPuzzle++; });
      _popCtrl.forward(from: 0);
      if (_currentPuzzle >= _puzzles.length) {
        Future.delayed(const Duration(milliseconds: 500), _endGame);
      } else {
        Future.delayed(const Duration(milliseconds: 400), _showNextPuzzle);
      }
    } else {
      setState(() {});
    }
  }

  void _endGame() {
    setState(() => _showResult = true);
    final stars = _score >= 90 ? 3 : _score >= 60 ? 2 : _score > 0 ? 1 : 0;
    widget.onComplete(widget.levelData.id, stars);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _popCtrl.dispose();
    _opTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentPuzzle >= _puzzles.length) {
      return const Scaffold(backgroundColor: Color(0xFF060818), body: Center(child: CircularProgressIndicator()));
    }
    final puzzle = _puzzles[_currentPuzzle];

    return Scaffold(
      backgroundColor: const Color(0xFF0A001A),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _NeonBgPainter(_bgCtrl.value),
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
                    Text('${_currentPuzzle + 1}/${_puzzles.length}',
                        style: const TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Text('💥 $_score', style: const TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.bold, fontSize: 16)),
                  ]),
                ),
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE040FB).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE040FB).withOpacity(0.4)),
                  ),
                  child: Text(puzzle['type'] as String,
                      style: const TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
                const SizedBox(height: 10),
                Text(puzzle['hint'] as String, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 16),
                // Operations display
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE040FB).withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      ..._displayedOps.map((op) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: op.startsWith('POP') || op.startsWith('DEQUEUE')
                              ? const Color(0xFFFF6348).withOpacity(0.1)
                              : const Color(0xFFE040FB).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Text(
                            op.startsWith('POP') || op.startsWith('DEQUEUE') ? '←' : '→',
                            style: TextStyle(
                              color: op.startsWith('POP') || op.startsWith('DEQUEUE')
                                  ? const Color(0xFFFF6348) : const Color(0xFFE040FB),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(op, style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                        ]),
                      )),
                      // Question
                      const Divider(color: Colors.white12),
                      Text(
                        (puzzle['ops'] as List<String>).last,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('What is the result?', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 3,
                    children: (puzzle['options'] as List<String>).map((opt) =>
                        GestureDetector(
                          onTap: () => _onAnswer(opt),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE040FB).withOpacity(0.3)),
                            ),
                            child: Center(
                              child: Text(opt, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
            stars: _score >= 90 ? 3 : _score >= 60 ? 2 : _score > 0 ? 1 : 0,
            xpEarned: widget.levelData.xpReward * (_score >= 90 ? 3 : _score >= 60 ? 2 : 1) ~/ 3,
            coinsEarned: widget.levelData.coinReward * (_score >= 90 ? 3 : _score >= 60 ? 2 : 1) ~/ 3,
            onContinue: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _NeonBgPainter extends CustomPainter {
  final double t;
  _NeonBgPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1;
    for (int i = 0; i < 6; i++) {
      final r = 80 + i * 40.0;
      final x = size.width * 0.5;
      final y = size.height * 0.3;
      paint.color = const Color(0xFFE040FB).withOpacity(0.04);
      canvas.drawCircle(Offset(x, y), r + sin(t * 2 * pi + i) * 10, paint);
    }
  }
  @override
  bool shouldRepaint(_NeonBgPainter old) => old.t != t;
}