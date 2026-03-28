// level3_memory_matrix.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../compete_screen.dart';

class Level3MemoryMatrix extends StatefulWidget {
  final LevelData levelData;
  final Future<void> Function(int levelId, int stars) onComplete;
  const Level3MemoryMatrix({super.key, required this.levelData, required this.onComplete});

  @override
  State<Level3MemoryMatrix> createState() => _Level3MemoryMatrixState();
}

class _Level3MemoryMatrixState extends State<Level3MemoryMatrix> with TickerProviderStateMixin {
  static const List<String> _codeSnippets = [
    'int x = 5;',
    'for(i=0)',
    'return a;',
    'if(n>0)',
    'arr[i]++',
    'null ptr',
    'O(n log)',
    'stack.pop',
    'queue.add',
  ];

  late AnimationController _bgCtrl;
  int _gridN = 3; // 3x3
  List<int> _sequence = [];
  List<bool> _revealed = [];
  List<bool> _userSelected = [];
  int _round = 0;
  int _score = 0;
  int _lives = 3;
  bool _showingSequence = false;
  bool _playerTurn = false;
  bool _showResult = false;
  int _userIndex = 0;
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _startRound();
  }

  Future<void> _startRound() async {
    _round++;
    final count = 2 + _round;
    _sequence = List.generate(count, (_) => _rand.nextInt(_gridN * _gridN));
    _revealed = List.filled(_gridN * _gridN, false);
    _userSelected = List.filled(_gridN * _gridN, false);
    _userIndex = 0;
    setState(() => _showingSequence = true);

    for (final idx in _sequence) {
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => _revealed[idx] = true);
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() => _revealed[idx] = false);
    }
    await Future.delayed(const Duration(milliseconds: 300));
    setState(() { _showingSequence = false; _playerTurn = true; });
  }

  void _onTap(int idx) {
    if (!_playerTurn || _showResult) return;
    if (_userIndex >= _sequence.length) return;

    setState(() => _userSelected[idx] = true);

    if (_sequence[_userIndex] == idx) {
      _userIndex++;
      _score += 15;
      if (_userIndex == _sequence.length) {
        _playerTurn = false;
        if (_round >= 5) {
          _endGame();
        } else {
          Future.delayed(const Duration(milliseconds: 600), _startRound);
        }
      }
    } else {
      _lives--;
      setState(() {});
      Future.delayed(const Duration(milliseconds: 300), () {
        setState(() => _userSelected = List.filled(_gridN * _gridN, false));
      });
      if (_lives <= 0) _endGame();
    }
  }

  void _endGame() {
    setState(() => _showResult = true);
    final stars = _score >= 120 ? 3 : _score >= 60 ? 2 : _score > 0 ? 1 : 0;
    widget.onComplete(widget.levelData.id, stars);
  }

  @override
  void dispose() { _bgCtrl.dispose(); super.dispose(); }

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
              painter: _CyberBgPainter(_bgCtrl.value),
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
                    Text('Round $_round/5', style: const TextStyle(color: Color(0xFF00D4FF), fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Row(children: List.generate(3, (i) => Text(i < _lives ? '💙' : '🖤', style: const TextStyle(fontSize: 16)))),
                    const SizedBox(width: 16),
                    Text('⚡ $_score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00D4FF).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3)),
                  ),
                  child: Text(
                    _showingSequence ? '👁 Watch the sequence...' : _playerTurn ? '🧠 Repeat the sequence!' : 'Get ready...',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Spacer(),
                _buildGrid(),
                const Spacer(),
              ],
            ),
          ),
          if (_showResult) LevelCompleteDialog(
            level: widget.levelData,
            stars: _score >= 120 ? 3 : _score >= 60 ? 2 : _score > 0 ? 1 : 0,
            xpEarned: widget.levelData.xpReward * (_score >= 120 ? 3 : _score >= 60 ? 2 : 1) ~/ 3,
            coinsEarned: widget.levelData.coinReward * (_score >= 120 ? 3 : _score >= 60 ? 2 : 1) ~/ 3,
            onContinue: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _gridN,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _gridN * _gridN,
        itemBuilder: (_, i) {
          final isRevealed = _revealed[i];
          final isSelected = _userSelected[i];
          final label = i < _codeSnippets.length ? _codeSnippets[i] : '...';
          return GestureDetector(
            onTap: () => _onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isRevealed
                    ? const Color(0xFF00D4FF).withOpacity(0.6)
                    : isSelected
                    ? const Color(0xFF00FF87).withOpacity(0.4)
                    : Colors.white.withOpacity(0.05),
                border: Border.all(
                  color: isRevealed
                      ? const Color(0xFF00D4FF)
                      : isSelected
                      ? const Color(0xFF00FF87)
                      : Colors.white.withOpacity(0.12),
                  width: isRevealed || isSelected ? 2 : 1,
                ),
                boxShadow: isRevealed ? [const BoxShadow(color: Color(0xFF00D4FF), blurRadius: 16)] : null,
              ),
              child: Center(
                child: Text(
                  isRevealed ? label : _playerTurn ? '?' : '',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CyberBgPainter extends CustomPainter {
  final double t;
  _CyberBgPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF00D4FF).withOpacity(0.025)..strokeWidth = 1;
    for (int i = 0; i < 8; i++) {
      final x = (i / 8.0) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (int i = 0; i < 12; i++) {
      final y = (i / 12.0) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Scanning line
    final scanY = (t % 1.0) * size.height;
    final scanPaint = Paint()
      ..color = const Color(0xFF00D4FF).withOpacity(0.1)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(0, scanY), Offset(size.width, scanY), scanPaint);
  }
  @override
  bool shouldRepaint(_CyberBgPainter old) => old.t != t;
}