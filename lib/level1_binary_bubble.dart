import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import '../compete_screen.dart';

class Level1BinaryBubble extends StatefulWidget {
  final LevelData levelData;
  final Future<void> Function(int levelId, int stars) onComplete;

  const Level1BinaryBubble({super.key, required this.levelData, required this.onComplete});

  @override
  State<Level1BinaryBubble> createState() => _Level1BinaryBubbleState();
}

class _Level1BinaryBubbleState extends State<Level1BinaryBubble> with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  final List<_Bubble> _bubbles = [];
  int _score = 0;
  int _lives = 3;
  int _timeLeft = 60;
  int _question = 0;
  bool _gameOver = false;
  bool _showResult = false;
  Timer? _timer;
  Timer? _spawnTimer;
  final _rand = Random();

  // Questions: decimal → binary or binary → decimal
  static const List<Map<String, dynamic>> _questions = [
    {'q': 'What is 5 in binary?', 'correct': '101', 'wrong': ['110', '100', '111']},
    {'q': 'What is 3 in binary?', 'correct': '011', 'wrong': ['010', '100', '111']},
    {'q': 'What is 1010 in decimal?', 'correct': '10', 'wrong': ['8', '12', '11']},
    {'q': 'What is 7 in binary?', 'correct': '111', 'wrong': ['110', '101', '011']},
    {'q': 'What is 1100 in decimal?', 'correct': '12', 'wrong': ['10', '14', '11']},
    {'q': 'What is 15 in binary?', 'correct': '1111', 'wrong': ['1110', '1101', '0111']},
    {'q': 'What is 0110 in decimal?', 'correct': '6', 'wrong': ['4', '8', '5']},
    {'q': 'What is 9 in binary?', 'correct': '1001', 'wrong': ['1010', '0110', '1011']},
  ];

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _startGame();
  }

  void _startGame() {
    _score = 0; _lives = 3; _timeLeft = 60; _question = 0; _gameOver = false;
    _bubbles.clear();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) _endGame();
      });
    });
    _spawnTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (!_gameOver) _spawnBubbles();
    });
    _spawnBubbles();
  }

  void _spawnBubbles() {
    if (_gameOver) return;
    final q = _questions[_question % _questions.length];
    final correct = q['correct'] as String;
    final wrong = List<String>.from(q['wrong'] as List);
    wrong.shuffle(_rand);
    // Show 4 bubbles
    final allAnswers = [correct, wrong[0], wrong[1], wrong[2]]..shuffle(_rand);
    setState(() {
      _bubbles.removeWhere((b) => b.popped);
      for (int i = 0; i < allAnswers.length; i++) {
        _bubbles.add(_Bubble(
          label: allAnswers[i],
          isCorrect: allAnswers[i] == correct,
          x: 0.1 + _rand.nextDouble() * 0.8,
          speed: 0.003 + _rand.nextDouble() * 0.002,
          size: 54 + _rand.nextDouble() * 20,
          color: _bubbleColor(i),
        ));
      }
    });
  }

  Color _bubbleColor(int i) {
    final colors = [
      const Color(0xFF00D4FF),
      const Color(0xFF7B2FFF),
      const Color(0xFFFF6348),
      const Color(0xFF00FF87),
    ];
    return colors[i % colors.length];
  }

  void _popBubble(_Bubble bubble) {
    if (bubble.popped || _gameOver) return;
    setState(() {
      bubble.popped = true;
      bubble.poppingAnim = true;
      if (bubble.isCorrect) {
        _score += 10;
        _question++;
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) setState(() => _bubbles.clear());
        });
      } else {
        _lives--;
        if (_lives <= 0) _endGame();
      }
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _bubbles.remove(bubble));
    });
  }

  void _endGame() {
    _timer?.cancel();
    _spawnTimer?.cancel();
    setState(() { _gameOver = true; _showResult = true; });
    final stars = _score >= 80 ? 3 : _score >= 40 ? 2 : _score > 0 ? 1 : 0;
    widget.onComplete(widget.levelData.id, stars);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _timer?.cancel();
    _spawnTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_question % _questions.length];
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF060818),
      body: Stack(
        children: [
          // Animated ocean BG
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              size: size,
              painter: _OceanBgPainter(_bgCtrl.value),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHUD(q),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    child: _buildBubbleField(size),
                  ),
                ),
              ],
            ),
          ),
          if (_showResult) _buildResultOverlay(),
        ],
      ),
    );
  }

  Widget _buildHUD(Map<String, dynamic> q) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 18),
              ),
              const Spacer(),
              // Timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _timeLeft <= 10 ? const Color(0xFFFF4757).withOpacity(0.2) : Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _timeLeft <= 10 ? const Color(0xFFFF4757) : Colors.white24),
                ),
                child: Text('⏱ $_timeLeft',
                    style: TextStyle(
                        color: _timeLeft <= 10 ? const Color(0xFFFF4757) : Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 12),
              // Lives
              Row(children: List.generate(3, (i) => Text(i < _lives ? '❤️' : '🖤', style: const TextStyle(fontSize: 16)))),
              const SizedBox(width: 12),
              // Score
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('⚡ $_score', style: const TextStyle(color: Color(0xFF00D4FF), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.2)),
            ),
            child: Text(
              q['q'] as String,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 6),
          const Text('Pop the correct bubble! 🫧', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBubbleField(Size size) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (_, __) {
        return Stack(
          children: _bubbles.map((b) {
            if (!b.poppingAnim) b.y -= b.speed;
            if (b.y < -0.1) b.y = 1.1;

            return Positioned(
              left: b.x * size.width - b.size / 2,
              top: b.y * (size.height * 0.65) + 60,
              child: GestureDetector(
                onTap: () => _popBubble(b),
                child: AnimatedScale(
                  scale: b.poppingAnim ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: _BubbleWidget(bubble: b),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildResultOverlay() {
    final stars = _score >= 80 ? 3 : _score >= 40 ? 2 : _score > 0 ? 1 : 0;
    return LevelCompleteDialog(
      level: widget.levelData,
      stars: stars,
      xpEarned: widget.levelData.xpReward * stars ~/ 3,
      coinsEarned: widget.levelData.coinReward * stars ~/ 3,
      onContinue: () => Navigator.pop(context),
    );
  }
}

class _Bubble {
  String label;
  bool isCorrect;
  double x;
  double y = 1.1;
  double speed;
  double size;
  Color color;
  bool popped = false;
  bool poppingAnim = false;

  _Bubble({
    required this.label,
    required this.isCorrect,
    required this.x,
    required this.speed,
    required this.size,
    required this.color,
  });
}

class _BubbleWidget extends StatelessWidget {
  final _Bubble bubble;
  const _BubbleWidget({required this.bubble});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: bubble.size,
      height: bubble.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            bubble.color.withOpacity(0.9),
            bubble.color.withOpacity(0.4),
          ],
        ),
        border: Border.all(color: bubble.color.withOpacity(0.6), width: 2),
        boxShadow: [BoxShadow(color: bubble.color.withOpacity(0.4), blurRadius: 12)],
      ),
      child: Center(
        child: Text(bubble.label,
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: bubble.size * 0.22)),
      ),
    );
  }
}

class _OceanBgPainter extends CustomPainter {
  final double t;
  _OceanBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Wave effect
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 3; i >= 0; i--) {
      paint.color = const Color(0xFF00D4FF).withOpacity(0.03 + i * 0.01);
      final path = Path();
      path.moveTo(0, size.height);
      for (double x = 0; x <= size.width; x += 5) {
        final y = size.height * 0.6 + sin((x / size.width * 2 * pi) + t * 2 * pi + i * 0.5) * 20;
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_OceanBgPainter old) => old.t != t;
}