import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../compete_screen.dart';

class Level2SyntaxCandy extends StatefulWidget {
  final LevelData levelData;
  final Future<void> Function(int levelId, int stars) onComplete;
  const Level2SyntaxCandy({super.key, required this.levelData, required this.onComplete});

  @override
  State<Level2SyntaxCandy> createState() => _Level2SyntaxCandyState();
}

class _Level2SyntaxCandyState extends State<Level2SyntaxCandy> with TickerProviderStateMixin {
  static const int _gridSize = 6;
  static const List<String> _tokens = ['if', 'for', '{}', '()', '=>', '=='];
  static const List<Color> _tokenColors = [
    Color(0xFFFF6B9D), Color(0xFFFFB800), Color(0xFF00D4FF),
    Color(0xFF00FF87), Color(0xFF7B2FFF), Color(0xFFFF6348),
  ];

  late List<List<int>> _grid;
  int? _selectedRow, _selectedCol;
  int _score = 0;
  int _moves = 20;
  bool _showResult = false;
  bool _processing = false;

  late AnimationController _bgCtrl;
  late List<List<AnimationController>> _cellCtrls;

  final _rand = Random();

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat();
    _cellCtrls = List.generate(_gridSize, (r) =>
        List.generate(_gridSize, (c) =>
            AnimationController(vsync: this, duration: const Duration(milliseconds: 300))));
    _initGrid();
  }

  void _initGrid() {
    _grid = List.generate(_gridSize, (_) => List.generate(_gridSize, (_) => _rand.nextInt(_tokens.length)));
    // Prevent initial matches
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize; c++) {
        while (_hasMatchAt(r, c)) {
          _grid[r][c] = _rand.nextInt(_tokens.length);
        }
      }
    }
  }

  bool _hasMatchAt(int r, int c) {
    final v = _grid[r][c];
    if (c >= 2 && _grid[r][c-1] == v && _grid[r][c-2] == v) return true;
    if (r >= 2 && _grid[r-1][c] == v && _grid[r-2][c] == v) return true;
    return false;
  }

  void _onTapCell(int r, int c) {
    if (_processing || _showResult) return;
    if (_selectedRow == null) {
      setState(() { _selectedRow = r; _selectedCol = c; });
    } else {
      final dr = (r - _selectedRow!).abs();
      final dc = (c - _selectedCol!).abs();
      if ((dr == 1 && dc == 0) || (dr == 0 && dc == 1)) {
        _swap(_selectedRow!, _selectedCol!, r, c);
      }
      setState(() { _selectedRow = null; _selectedCol = null; });
    }
  }

  Future<void> _swap(int r1, int c1, int r2, int c2) async {
    setState(() {
      _processing = true;
      final tmp = _grid[r1][c1];
      _grid[r1][c1] = _grid[r2][c2];
      _grid[r2][c2] = tmp;
      _moves--;
    });

    await Future.delayed(const Duration(milliseconds: 200));
    final matched = _findMatches();
    if (matched.isEmpty) {
      // Swap back
      setState(() {
        final tmp = _grid[r1][c1];
        _grid[r1][c1] = _grid[r2][c2];
        _grid[r2][c2] = tmp;
        _moves++;
      });
    } else {
      await _processMatches(matched);
    }

    setState(() => _processing = false);
    if (_moves <= 0) _endGame();
  }

  Set<String> _findMatches() {
    final matched = <String>{};
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < _gridSize - 2; c++) {
        if (_grid[r][c] == _grid[r][c+1] && _grid[r][c] == _grid[r][c+2]) {
          matched.add('$r,$c'); matched.add('$r,${c+1}'); matched.add('$r,${c+2}');
        }
      }
    }
    for (int c = 0; c < _gridSize; c++) {
      for (int r = 0; r < _gridSize - 2; r++) {
        if (_grid[r][c] == _grid[r+1][c] && _grid[r][c] == _grid[r+2][c]) {
          matched.add('$r,$c'); matched.add('${r+1},$c'); matched.add('${r+2},$c');
        }
      }
    }
    return matched;
  }

  Future<void> _processMatches(Set<String> matched) async {
    // Flash matched cells
    for (final key in matched) {
      final parts = key.split(',');
      final r = int.parse(parts[0]);
      final c = int.parse(parts[1]);
      _cellCtrls[r][c].forward(from: 0);
    }
    setState(() {
      _score += matched.length * 15;
      for (final key in matched) {
        final parts = key.split(',');
        _grid[int.parse(parts[0])][int.parse(parts[1])] = -1;
      }
    });
    await Future.delayed(const Duration(milliseconds: 300));

    // Gravity: drop tiles
    setState(() {
      for (int c = 0; c < _gridSize; c++) {
        int empty = _gridSize - 1;
        for (int r = _gridSize - 1; r >= 0; r--) {
          if (_grid[r][c] != -1) {
            _grid[empty][c] = _grid[r][c];
            if (empty != r) _grid[r][c] = -1;
            empty--;
          }
        }
        for (int r = empty; r >= 0; r--) {
          _grid[r][c] = _rand.nextInt(_tokens.length);
        }
      }
    });

    await Future.delayed(const Duration(milliseconds: 200));
    final newMatches = _findMatches();
    if (newMatches.isNotEmpty) await _processMatches(newMatches);
  }

  void _endGame() {
    setState(() => _showResult = true);
    final stars = _score >= 300 ? 3 : _score >= 150 ? 2 : _score > 0 ? 1 : 0;
    widget.onComplete(widget.levelData.id, stars);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    for (final row in _cellCtrls) for (final c in row) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0030),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _CandyBgPainter(_bgCtrl.value)),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHUD(),
                const SizedBox(height: 10),
                Expanded(child: Center(child: _buildGrid())),
              ],
            ),
          ),
          if (_showResult) _buildResultOverlay(),
        ],
      ),
    );
  }

  Widget _buildHUD() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 18),
          ),
          const Spacer(),
          _chip('🍬 Score', '$_score', const Color(0xFFFF6B9D)),
          const SizedBox(width: 10),
          _chip('🔄 Moves', '$_moves', const Color(0xFFFFB800)),
        ],
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 11)),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
      ]),
    );
  }

  Widget _buildGrid() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF6B9D).withOpacity(0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_gridSize, (r) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_gridSize, (c) => _buildCell(r, c)),
        )),
      ),
    );
  }

  Widget _buildCell(int r, int c) {
    final v = _grid[r][c];
    final isSelected = _selectedRow == r && _selectedCol == c;
    final color = v >= 0 ? _tokenColors[v] : Colors.transparent;

    return GestureDetector(
      onTap: () => _onTapCell(r, c),
      child: AnimatedBuilder(
        animation: _cellCtrls[r][c],
        builder: (_, __) {
          final scale = 1.0 + sin(_cellCtrls[r][c].value * pi) * 0.3;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 50,
              height: 50,
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: v >= 0
                    ? LinearGradient(
                  colors: [color.withOpacity(0.9), color.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : null,
                color: v < 0 ? Colors.transparent : null,
                border: isSelected
                    ? Border.all(color: Colors.white, width: 3)
                    : Border.all(color: color.withOpacity(0.3), width: 1),
                boxShadow: isSelected
                    ? [BoxShadow(color: color, blurRadius: 12)]
                    : v >= 0 ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6)]
                    : null,
              ),
              child: v >= 0
                  ? Center(
                child: Text(
                  _tokens[v],
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: _tokens[v].length > 2 ? 11 : 14,
                  ),
                ),
              )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultOverlay() {
    final stars = _score >= 300 ? 3 : _score >= 150 ? 2 : _score > 0 ? 1 : 0;
    return LevelCompleteDialog(
      level: widget.levelData,
      stars: stars,
      xpEarned: widget.levelData.xpReward * stars ~/ 3,
      coinsEarned: widget.levelData.coinReward * stars ~/ 3,
      onContinue: () => Navigator.pop(context),
    );
  }
}

class _CandyBgPainter extends CustomPainter {
  final double t;
  _CandyBgPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (int i = 0; i < 8; i++) {
      final x = (i / 8.0 + t * 0.1) % 1.0 * size.width;
      final y = sin(t * 2 * pi + i) * size.height * 0.3 + size.height * 0.5;
      paint.color = const Color(0xFFFF6B9D).withOpacity(0.04);
      canvas.drawCircle(Offset(x, y), 60 + i * 10.0, paint);
    }
  }
  @override
  bool shouldRepaint(_CandyBgPainter old) => old.t != t;
}