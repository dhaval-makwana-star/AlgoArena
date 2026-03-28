// level7_regex_rush.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../compete_screen.dart';

class Level7RegexRush extends StatefulWidget {
  final LevelData levelData;
  final Future<void> Function(int levelId, int stars) onComplete;
  const Level7RegexRush({super.key, required this.levelData, required this.onComplete});

  @override
  State<Level7RegexRush> createState() => _Level7RegexRushState();
}

class _Level7RegexRushState extends State<Level7RegexRush> with TickerProviderStateMixin {
  static const List<Map<String, dynamic>> _challenges = [
    {'pattern': r'\d+', 'desc': 'Matches one or more digits', 'strings': ['abc', '123', 'xyz', '456'],
      'matches': [false, true, false, true]},
    {'pattern': r'[a-z]+', 'desc': 'Matches lowercase letters', 'strings': ['Hello', 'world', '123', 'abc'],
      'matches': [false, true, false, true]},
    {'pattern': r'^\w+@\w+\.\w+$', 'desc': 'Email pattern', 'strings': ['test@mail.com', 'notanemail', 'a@b.c', 'noat'],
      'matches': [true, false, true, false]},
    {'pattern': r'\b\w{4}\b', 'desc': 'Exactly 4-letter word', 'strings': ['test', 'hello', 'code', 'ai'],
      'matches': [true, false, true, false]},
    {'pattern': r'^[A-Z]', 'desc': 'Starts with uppercase', 'strings': ['Hello', 'world', 'Dart', 'flutter'],
      'matches': [true, false, true, false]},
    {'pattern': r'\d{3}-\d{4}', 'desc': 'Phone format XXX-XXXX', 'strings': ['123-4567', 'abc-defg', '999-1234', '12-345'],
      'matches': [true, false, true, false]},
  ];

  late AnimationController _bgCtrl;
  int _currentChallenge = 0;
  int _score = 0;
  int _timeLeft = 50;
  bool _showResult = false;
  Set<int> _answered = {};
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _timeLeft--;
        if (_timeLeft <= 0) _endGame();
      });
    });
  }

  void _onToggle(int stringIdx, bool currentVal) {
    if (_answered.contains(stringIdx) || _showResult) return;
    final challenge = _challenges[_currentChallenge % _challenges.length];
    final correct = (challenge['matches'] as List<bool>)[stringIdx];
    if (correct == !currentVal) { // they're toggling to correct
      setState(() {
        _answered.add(stringIdx);
        _score += 15;
      });
    }
    // Check if all answered
    if (_answered.length == 4) {
      Future.delayed(const Duration(milliseconds: 500), () {
        setState(() {
          _currentChallenge++;
          _answered = {};
        });
        if (_currentChallenge >= _challenges.length) _endGame();
      });
    }
  }

  void _endGame() {
    _timer?.cancel();
    setState(() => _showResult = true);
    final stars = _score >= 60 ? 3 : _score >= 30 ? 2 : _score > 0 ? 1 : 0;
    widget.onComplete(widget.levelData.id, stars);
  }

  @override
  void dispose() { _bgCtrl.dispose(); _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final challenge = _challenges[_currentChallenge % _challenges.length];
    final strings = challenge['strings'] as List<String>;
    final matches = challenge['matches'] as List<bool>;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A00),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _StormBgPainter(_bgCtrl.value),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
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
                        child: Text('⏱ $_timeLeft',
                            style: TextStyle(
                              color: _timeLeft <= 10 ? const Color(0xFFFFEB3B) : Colors.white,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                      const SizedBox(width: 12),
                      Text('⚡ $_score', style: const TextStyle(color: Color(0xFFFFEB3B), fontWeight: FontWeight.bold, fontSize: 16)),
                    ]),
                  ),
                  // Pattern display
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A00),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFEB3B).withOpacity(0.4)),
                    ),
                    child: Column(children: [
                      const Text('PATTERN', style: TextStyle(color: Color(0xFFFFEB3B), fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(challenge['pattern'] as String,
                          style: const TextStyle(color: Color(0xFF00FF87), fontSize: 20, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(challenge['desc'] as String, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  const Text('Does the pattern MATCH? Toggle each string:',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 12),
                  ...strings.asMap().entries.map((e) {
                    final i = e.key;
                    final str = e.value;
                    final isMatch = matches[i];
                    final isAnswered = _answered.contains(i);
                    return GestureDetector(
                      onTap: () => _onToggle(i, false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: isAnswered
                              ? const Color(0xFF00FF87).withOpacity(0.1)
                              : Colors.white.withOpacity(0.05),
                          border: Border.all(
                            color: isAnswered ? const Color(0xFF00FF87) : Colors.white.withOpacity(0.15),
                            width: isAnswered ? 2 : 1,
                          ),
                        ),
                        child: Row(children: [
                          Text(str, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 16)),
                          const Spacer(),
                          if (isAnswered) ...[
                            Text(isMatch ? '✅ MATCH' : '❌ NO MATCH',
                                style: TextStyle(color: isMatch ? const Color(0xFF00FF87) : const Color(0xFFFF6348), fontWeight: FontWeight.bold, fontSize: 12)),
                          ] else
                            Text(isMatch ? 'Match?' : 'No Match?',
                                style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ]),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          if (_showResult) LevelCompleteDialog(
            level: widget.levelData,
            stars: _score >= 60 ? 3 : _score >= 30 ? 2 : _score > 0 ? 1 : 0,
            xpEarned: widget.levelData.xpReward * (_score >= 60 ? 3 : _score >= 30 ? 2 : 1) ~/ 3,
            coinsEarned: widget.levelData.coinReward * (_score >= 60 ? 3 : _score >= 30 ? 2 : 1) ~/ 3,
            onContinue: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _StormBgPainter extends CustomPainter {
  final double t;
  _StormBgPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke..strokeWidth = 1;
    for (int i = 0; i < 5; i++) {
      final x = sin(t * 2 * pi + i * 1.4) * size.width * 0.4 + size.width * 0.5;
      paint.color = const Color(0xFFFFEB3B).withOpacity(0.04 + i * 0.01);
      canvas.drawLine(Offset(x, 0), Offset(size.width - x, size.height), paint);
    }
  }
  @override
  bool shouldRepaint(_StormBgPainter old) => old.t != t;
}