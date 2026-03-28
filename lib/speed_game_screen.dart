import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';

class SpeedGameScreen extends StatefulWidget {
  const SpeedGameScreen({super.key});

  @override
  State<SpeedGameScreen> createState() => _SpeedGameScreenState();
}

class _SpeedGameScreenState extends State<SpeedGameScreen> with TickerProviderStateMixin {
  // ─── Question Banks ───────────────────────────────────────────────────────
  static const Map<String, List<Map<String, String>>> _banks = {
    'easy': [
      {'q': 'Access array element by index?', 'a': 'o(1)'},
      {'q': 'LIFO data structure?', 'a': 'stack'},
      {'q': 'FIFO data structure?', 'a': 'queue'},
      {'q': 'Binary search requires array to be?', 'a': 'sorted'},
      {'q': 'Stack operation to add element?', 'a': 'push'},
      {'q': 'Stack operation to remove top?', 'a': 'pop'},
      {'q': 'Root of min-heap contains?', 'a': 'minimum'},
      {'q': 'DFS stands for?', 'a': 'depth first search'},
      {'q': 'BFS stands for?', 'a': 'breadth first search'},
      {'q': 'Bubble sort worst case?', 'a': 'o(n^2)'},
      {'q': 'Array insertion at end?', 'a': 'o(1)'},
      {'q': 'Linked list head access?', 'a': 'o(1)'},
    ],
    'medium': [
      {'q': 'QuickSort average case?', 'a': 'o(n log n)'},
      {'q': 'Preorder: visits root where?', 'a': 'first'},
      {'q': 'Inorder traversal on BST gives?', 'a': 'sorted output'},
      {'q': 'Heapify time complexity?', 'a': 'o(log n)'},
      {'q': 'Hash table average insert?', 'a': 'o(1)'},
      {'q': 'Dijkstra fails with?', 'a': 'negative weights'},
      {'q': 'Build heap from array?', 'a': 'o(n)'},
      {'q': 'AVL tree height balance?', 'a': '1'},
      {'q': 'Hash collision via linked list?', 'a': 'chaining'},
      {'q': 'Space complexity of DFS?', 'a': 'o(v)'},
      {'q': 'Merge sort space complexity?', 'a': 'o(n)'},
      {'q': 'BST search worst case?', 'a': 'o(n)'},
    ],
    'hard': [
      {'q': 'KMP algorithm time?', 'a': 'o(n+m)'},
      {'q': 'Database indexing tree?', 'a': 'b-tree'},
      {'q': 'Floyd-Warshall time?', 'a': 'o(v^3)'},
      {'q': 'Minimum spanning tree (greedy)?', 'a': 'kruskal'},
      {'q': 'Segment tree range query?', 'a': 'o(log n)'},
      {'q': 'Strongly connected components: Kosaraju?', 'a': 'o(v+e)'},
      {'q': 'Comparison sort lower bound?', 'a': 'o(n log n)'},
      {'q': 'Balanced BST DFS space?', 'a': 'o(log n)'},
      {'q': 'Bellman-Ford time?', 'a': 'o(ve)'},
      {'q': 'Trie insertion time?', 'a': 'o(m)'},
      {'q': 'Fenwick tree query?', 'a': 'o(log n)'},
      {'q': 'Suffix array construction?', 'a': 'o(n log n)'},
    ],
  };

  // ─── Game Config ─────────────────────────────────────────────────────────
  static const int _gameSeconds = 60;
  static const int _thresholdEasyToMedium = 5;
  static const int _thresholdMediumToHard = 12;

  // ─── State ────────────────────────────────────────────────────────────────
  String _difficulty = 'easy';
  Map<String, String> _currentQ = {'q': '', 'a': ''};
  final TextEditingController _ansCtrl = TextEditingController();
  int _score = 0;
  int _correct = 0;
  int _wrong = 0;
  int _timeLeft = _gameSeconds;
  bool _isRunning = false;
  bool _gameOver = false;
  bool _answered = false;
  String _feedback = '';
  bool _feedbackCorrect = false;
  int _streak = 0;
  int _maxStreak = 0;
  Timer? _timer;
  final Random _rng = Random();
  final Set<int> _usedIndices = {};

  // ─── Animations ──────────────────────────────────────────────────────────
  late AnimationController _feedbackCtrl;
  late AnimationController _questionCtrl;
  late AnimationController _shakeCtrl;
  late Animation<double> _feedbackAnim;
  late Animation<Offset> _questionSlide;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _feedbackCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _feedbackAnim = CurvedAnimation(parent: _feedbackCtrl, curve: Curves.easeOut);
    _questionCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _questionSlide = Tween<Offset>(begin: const Offset(0.3, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _questionCtrl, curve: Curves.easeOut));
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _shakeAnim = Tween<double>(begin: 0, end: 8).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
    _pickQuestion();
  }

  void _pickQuestion() {
    final bank = _banks[_difficulty]!;
    if (_usedIndices.length >= bank.length) _usedIndices.clear();
    int idx;
    do { idx = _rng.nextInt(bank.length); } while (_usedIndices.contains(idx));
    _usedIndices.add(idx);
    setState(() => _currentQ = Map<String, String>.from(bank[idx]));
    _questionCtrl.forward(from: 0);
  }

  void _startGame() {
    setState(() {
      _isRunning = true;
      _gameOver = false;
      _score = 0; _correct = 0; _wrong = 0;
      _timeLeft = _gameSeconds;
      _streak = 0; _maxStreak = 0;
      _difficulty = 'easy';
      _usedIndices.clear();
      _ansCtrl.clear();
    });
    _pickQuestion();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        t.cancel();
        _endGame();
      }
    });
  }

  void _submitAnswer() {
    final raw = _ansCtrl.text.trim().toLowerCase();
    if (raw.isEmpty) return;
    final correct = _currentQ['a']!.toLowerCase();
    final isCorrect = raw == correct;

    setState(() {
      if (isCorrect) {
        _correct++;
        _streak++;
        if (_streak > _maxStreak) _maxStreak = _streak;
        _score += 10 + (min(_streak - 1, 5) * 2);
        _feedback = '✅ Correct! +${10 + (min(_streak - 1, 5) * 2)} pts';
        _feedbackCorrect = true;
      } else {
        _wrong++;
        _streak = 0;
        _score -= 5;
        _feedback = '❌ "${_currentQ['a']}"';
        _feedbackCorrect = false;
        _shakeCtrl.forward(from: 0);
      }
      _answered = true;
    });

    // Adaptive difficulty
    if (_correct >= _thresholdMediumToHard) _difficulty = 'hard';
    else if (_correct >= _thresholdEasyToMedium) _difficulty = 'medium';

    _feedbackCtrl.forward(from: 0);
    _ansCtrl.clear();

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() { _answered = false; _feedback = ''; });
      _pickQuestion();
    });
  }

  void _endGame() {
    setState(() { _isRunning = false; _gameOver = true; });
    _timer?.cancel();
    _awardRewards();
  }

  Future<void> _awardRewards() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _score <= 0) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'xp': FieldValue.increment(_score),
      'coins': FieldValue.increment(max(0, _correct * 2)),
      'totalGamesPlayed': FieldValue.increment(1),
    });
  }

  Color get _diffColor {
    switch (_difficulty) {
      case 'medium': return const Color(0xFFFFB800);
      case 'hard': return const Color(0xFFFF4757);
      default: return const Color(0xFF00FF87);
    }
  }

  double get _timerPct => _timeLeft / _gameSeconds;

  Color get _timerColor {
    if (_timeLeft > 30) return const Color(0xFF00D4FF);
    if (_timeLeft > 10) return const Color(0xFFFFB800);
    return const Color(0xFFFF4757);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ansCtrl.dispose();
    _feedbackCtrl.dispose();
    _questionCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ FIX: resizeToAvoidBottomInset so keyboard doesn't overflow content
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF060818),
      body: Stack(children: [
        _buildBg(),
        SafeArea(
          child: _gameOver
              ? _buildGameOver()
              : !_isRunning
              ? _buildStart()
              : _buildGame(),
        ),
      ]),
    );
  }

  Widget _buildBg() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 1.2,
          colors: [_diffColor.withOpacity(0.08), const Color(0xFF060818)],
        ),
      ),
    );
  }

  Widget _buildStart() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚡', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            const Text('SPEED ROUND',
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 12),
            Text('60 seconds. Answer fast. Get more right → harder questions.',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15, height: 1.5),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            _buildScoreInfo('Easy → 5 correct', const Color(0xFF00FF87)),
            _buildScoreInfo('Medium → 12 correct', const Color(0xFFFFB800)),
            _buildScoreInfo('Hard → Beyond 12', const Color(0xFFFF4757)),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _startGame,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFB800), Color(0xFFFF6348)]),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: const Color(0xFFFFB800).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: const Center(
                  child: Text('⚡ START NOW',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Text('← Back', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreInfo(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildGame() {
    // ✅ FIX: Use a Column with Expanded + SingleChildScrollView to prevent overflow
    return Column(
      children: [
        _buildGameHeader(),
        _buildTimerBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildDiffBadge(),
                const SizedBox(height: 20),
                _buildQuestionBox(),
                const SizedBox(height: 24),
                if (_feedback.isNotEmpty) _buildFeedback(),
                const SizedBox(height: 12),
                _buildAnswerInput(),
                const SizedBox(height: 16),
                _buildStats(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGameHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () { _timer?.cancel(); Navigator.pop(context); },
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          const Text('⚡ Speed Round', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text('$_score pts',
              style: const TextStyle(color: Color(0xFFFFB800), fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildTimerBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$_timeLeft s',
                  style: TextStyle(color: _timerColor, fontWeight: FontWeight.bold, fontSize: 22)),
              if (_streak >= 3)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6348).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('🔥 x$_streak STREAK',
                      style: const TextStyle(color: Color(0xFFFF6348), fontWeight: FontWeight.bold, fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _timerPct,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(_timerColor),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffBadge() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: _diffColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _diffColor.withOpacity(0.4)),
          ),
          child: Text(
            _difficulty.toUpperCase(),
            style: TextStyle(color: _diffColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionBox() {
    return SlideTransition(
      position: _questionSlide,
      child: AnimatedBuilder(
        animation: _shakeAnim,
        builder: (ctx, child) => Transform.translate(
          offset: Offset(!_feedbackCorrect && _answered ? _shakeAnim.value * sin(_shakeAnim.value) : 0, 0),
          child: child,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_diffColor.withOpacity(0.08), Colors.white.withOpacity(0.03)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _diffColor.withOpacity(0.25)),
          ),
          child: Text(
            _currentQ['q'] ?? '',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildFeedback() {
    return FadeTransition(
      opacity: _feedbackAnim,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: _feedbackCorrect
              ? const Color(0xFF00FF87).withOpacity(0.12)
              : const Color(0xFFFF4757).withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _feedbackCorrect
                ? const Color(0xFF00FF87).withOpacity(0.4)
                : const Color(0xFFFF4757).withOpacity(0.4),
          ),
        ),
        child: Text(_feedback,
            style: TextStyle(
                color: _feedbackCorrect ? const Color(0xFF00FF87) : const Color(0xFFFF4757),
                fontWeight: FontWeight.bold,
                fontSize: 14),
            textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildAnswerInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _diffColor.withOpacity(0.3)),
      ),
      child: TextField(
        controller: _ansCtrl,
        autofocus: false, // ✅ FIX: don't autofocus to avoid immediate keyboard pop
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submitAnswer(),
        decoration: InputDecoration(
          hintText: 'Type & press Enter...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          suffixIcon: GestureDetector(
            onTap: _submitAnswer,
            child: Icon(Icons.arrow_forward_rounded, color: _diffColor, size: 24),
          ),
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _statBadge('✅', '$_correct', const Color(0xFF00FF87)),
        _statBadge('❌', '$_wrong', const Color(0xFFFF4757)),
        _statBadge('🎯', '${_correct + _wrong > 0 ? ((_correct / (_correct + _wrong)) * 100).round() : 0}%', const Color(0xFF00D4FF)),
        _statBadge('🔥', '$_maxStreak', const Color(0xFFFF6348)),
      ],
    );
  }

  Widget _statBadge(String emoji, String val, Color color) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildGameOver() {
    final acc = _correct + _wrong > 0 ? ((_correct / (_correct + _wrong)) * 100).round() : 0;
    final grade = _score >= 150
        ? ('S', const Color(0xFFFFD700))
        : _score >= 100
        ? ('A', const Color(0xFF00FF87))
        : _score >= 60
        ? ('B', const Color(0xFF00D4FF))
        : _score >= 30
        ? ('C', const Color(0xFFFFB800))
        : ('D', const Color(0xFFFF4757));

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [grade.$2, grade.$2.withOpacity(0.5)]),
              ),
              child: Center(
                child: Text(grade.$1,
                    style: const TextStyle(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('TIME\'S UP!',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 2)),
            const SizedBox(height: 24),
            _resultRow('Score', '$_score pts', const Color(0xFFFFB800)),
            _resultRow('Correct', '$_correct', const Color(0xFF00FF87)),
            _resultRow('Wrong', '$_wrong', const Color(0xFFFF4757)),
            _resultRow('Accuracy', '$acc%', const Color(0xFF00D4FF)),
            _resultRow('Max Streak', '$_maxStreak 🔥', const Color(0xFFFF6348)),
            const SizedBox(height: 24),
            if (_score > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB800).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.3)),
                ),
                child: Text('+$_score XP  +${max(0, _correct * 2)} 🪙',
                    style: const TextStyle(color: Color(0xFFFFB800), fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            const SizedBox(height: 32),
            _btn('⚡ Play Again', _startGame, const Color(0xFFFFB800)),
            const SizedBox(height: 12),
            _btn('← Back', () => Navigator.pop(context), Colors.white.withOpacity(0.08)),
          ],
        ),
      ),
    );
  }

  Widget _resultRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
        child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
      ),
    );
  }
}