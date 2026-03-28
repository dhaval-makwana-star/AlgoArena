import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../compete_screen.dart';

class Level4CodeConnect extends StatefulWidget {
  final LevelData levelData;
  final Future<void> Function(int levelId, int stars) onComplete;
  const Level4CodeConnect({super.key, required this.levelData, required this.onComplete});

  @override
  State<Level4CodeConnect> createState() => _Level4CodeConnectState();
}

class _Level4CodeConnectState extends State<Level4CodeConnect> with TickerProviderStateMixin {
  // Matching pairs: concept → definition
  static const List<List<String>> _allPairs = [
    ['Array', 'Indexed collection'],
    ['Stack', 'LIFO structure'],
    ['Queue', 'FIFO structure'],
    ['HashMap', 'Key-value store'],
    ['Tree', 'Hierarchical nodes'],
    ['Graph', 'Nodes & edges'],
    ['O(1)', 'Constant time'],
    ['O(n)', 'Linear time'],
  ];

  late AnimationController _bgCtrl;
  List<List<String>> _currentPairs = [];
  List<String> _leftItems = [];
  List<String> _rightItems = [];
  String? _selectedLeft;
  String? _selectedRight;
  Set<String> _matchedLeft = {};
  Set<String> _matchedRight = {};
  int _score = 0;
  int _errors = 0;
  int _round = 0;
  bool _showResult = false;
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _loadRound();
  }

  void _loadRound() {
    _round++;
    final shuffled = List<List<String>>.from(_allPairs)..shuffle(_rand);
    _currentPairs = shuffled.take(4).toList();
    _leftItems = _currentPairs.map((p) => p[0]).toList()..shuffle(_rand);
    _rightItems = _currentPairs.map((p) => p[1]).toList()..shuffle(_rand);
    _selectedLeft = null;
    _selectedRight = null;
    _matchedLeft = {};
    _matchedRight = {};
    setState(() {});
  }

  void _onSelectLeft(String item) {
    if (_matchedLeft.contains(item)) return;
    setState(() { _selectedLeft = item; });
    _tryMatch();
  }

  void _onSelectRight(String item) {
    if (_matchedRight.contains(item)) return;
    setState(() { _selectedRight = item; });
    _tryMatch();
  }

  void _tryMatch() {
    if (_selectedLeft == null || _selectedRight == null) return;
    // Check if valid pair
    final isValid = _currentPairs.any((p) => p[0] == _selectedLeft && p[1] == _selectedRight);
    if (isValid) {
      setState(() {
        _matchedLeft.add(_selectedLeft!);
        _matchedRight.add(_selectedRight!);
        _score += 25;
        _selectedLeft = null;
        _selectedRight = null;
      });
      if (_matchedLeft.length == _currentPairs.length) {
        if (_round >= 3) {
          Future.delayed(const Duration(milliseconds: 500), _endGame);
        } else {
          Future.delayed(const Duration(milliseconds: 600), _loadRound);
        }
      }
    } else {
      _errors++;
      Future.delayed(const Duration(milliseconds: 500), () {
        setState(() { _selectedLeft = null; _selectedRight = null; });
      });
    }
  }

  void _endGame() {
    setState(() => _showResult = true);
    final stars = _errors <= 2 ? 3 : _errors <= 5 ? 2 : 1;
    widget.onComplete(widget.levelData.id, stars);
  }

  @override
  void dispose() { _bgCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060C1A),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _OceanWavePainter(_bgCtrl.value),
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
                    Text('Round $_round/3', style: const TextStyle(color: Color(0xFF40C4FF), fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Text('❌ $_errors errors', style: const TextStyle(color: Color(0xFFFF6348), fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(width: 16),
                    Text('⚡ $_score', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(height: 8),
                const Text('🔗 CONNECT THE PAIRS',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 14)),
                const SizedBox(height: 6),
                const Text('Tap concept → definition',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                const Spacer(),
                _buildMatchGrid(),
                const Spacer(),
              ],
            ),
          ),
          if (_showResult) LevelCompleteDialog(
            level: widget.levelData,
            stars: _errors <= 2 ? 3 : _errors <= 5 ? 2 : 1,
            xpEarned: widget.levelData.xpReward * (_errors <= 2 ? 3 : _errors <= 5 ? 2 : 1) ~/ 3,
            coinsEarned: widget.levelData.coinReward * (_errors <= 2 ? 3 : _errors <= 5 ? 2 : 1) ~/ 3,
            onContinue: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: Column(children: _leftItems.map((item) => _leftCard(item)).toList())),
          const SizedBox(width: 16),
          // Connection lines area
          SizedBox(width: 24, child: CustomPaint(
            size: const Size(24, 400),
            painter: _ConnectorPainter(_matchedLeft, _leftItems, _rightItems, _currentPairs),
          )),
          const SizedBox(width: 16),
          Expanded(child: Column(children: _rightItems.map((item) => _rightCard(item)).toList())),
        ],
      ),
    );
  }

  Widget _leftCard(String item) {
    final isMatched = _matchedLeft.contains(item);
    final isSelected = _selectedLeft == item;
    return GestureDetector(
      onTap: () => _onSelectLeft(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isMatched
              ? const Color(0xFF00FF87).withOpacity(0.15)
              : isSelected
              ? const Color(0xFF40C4FF).withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
          border: Border.all(
            color: isMatched
                ? const Color(0xFF00FF87)
                : isSelected
                ? const Color(0xFF40C4FF)
                : Colors.white.withOpacity(0.15),
            width: isSelected || isMatched ? 2 : 1,
          ),
          boxShadow: isMatched ? [const BoxShadow(color: Color(0xFF00FF87), blurRadius: 10)] : null,
        ),
        child: Row(children: [
          Text(item, style: TextStyle(
            color: isMatched ? const Color(0xFF00FF87) : Colors.white,
            fontWeight: FontWeight.bold, fontSize: 13,
          )),
          if (isMatched) const Spacer(),
          if (isMatched) const Text('✓', style: TextStyle(color: Color(0xFF00FF87))),
        ]),
      ),
    );
  }

  Widget _rightCard(String item) {
    final isMatched = _matchedRight.contains(item);
    final isSelected = _selectedRight == item;
    return GestureDetector(
      onTap: () => _onSelectRight(item),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isMatched
              ? const Color(0xFF00FF87).withOpacity(0.15)
              : isSelected
              ? const Color(0xFF7B2FFF).withOpacity(0.2)
              : Colors.white.withOpacity(0.06),
          border: Border.all(
            color: isMatched
                ? const Color(0xFF00FF87)
                : isSelected
                ? const Color(0xFF7B2FFF)
                : Colors.white.withOpacity(0.15),
            width: isSelected || isMatched ? 2 : 1,
          ),
        ),
        child: Text(item, style: TextStyle(
          color: isMatched ? const Color(0xFF00FF87) : Colors.white70,
          fontSize: 12,
        )),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  final Set<String> matchedLeft;
  final List<String> leftItems;
  final List<String> rightItems;
  final List<List<String>> pairs;
  _ConnectorPainter(this.matchedLeft, this.leftItems, this.rightItems, this.pairs);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00FF87).withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final itemH = 60.0;
    for (final left in matchedLeft) {
      final li = leftItems.indexOf(left);
      final pair = pairs.firstWhere((p) => p[0] == left);
      final ri = rightItems.indexOf(pair[1]);
      final y1 = li * itemH + itemH / 2;
      final y2 = ri * itemH + itemH / 2;
      canvas.drawLine(Offset(0, y1), Offset(size.width, y2), paint);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) => old.matchedLeft != matchedLeft;
}

class _OceanWavePainter extends CustomPainter {
  final double t;
  _OceanWavePainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 3; i++) {
      paint.color = const Color(0xFF40C4FF).withOpacity(0.03 + i * 0.01);
      final path = Path();
      path.moveTo(0, size.height);
      for (double x = 0; x <= size.width; x += 8) {
        final y = size.height * 0.7 + sin((x / size.width * 2 * pi) + t * 2 * pi + i) * 30;
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(path, paint);
    }
  }
  @override
  bool shouldRepaint(_OceanWavePainter old) => old.t != t;
}