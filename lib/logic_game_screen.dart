import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class LogicGameScreen extends StatefulWidget {
  const LogicGameScreen({super.key});

  @override
  State<LogicGameScreen> createState() => _LogicGameScreenState();
}

class _LogicGameScreenState extends State<LogicGameScreen> with TickerProviderStateMixin {
  // ─── Base question bank (correct is always index 0 here, shuffled before display) ──
  static const List<Map<String, dynamic>> _questionBank = [
    {
      'question': 'You have 8 balls, one is heavier. Minimum weighings on balance scale?',
      'options': ['2', '3', '1', '4'],
      'correct': 0,
      'explanation': 'Weigh 3v3. If balanced → heavy is in remaining 2 (1 more weighing). If unbalanced → weigh 1v1 from heavier group. Total: 2.',
      'category': 'Puzzles', 'xp': 30,
    },
    {
      'question': 'Array has all elements twice except one. O(n) time, O(1) space solution?',
      'options': ['XOR all elements', 'Sort and scan', 'HashMap counting', 'Binary search'],
      'correct': 0,
      'explanation': 'XOR: a XOR a = 0, a XOR 0 = a. All duplicates cancel out, leaving the unique element.',
      'category': 'Bit Manipulation', 'xp': 25,
    },
    {
      'question': 'Most efficient check if N is a power of 2?',
      'options': ['N > 0 && (N & (N-1)) == 0', 'N % 2 == 0', 'log2(N) is integer', 'Loop dividing by 2'],
      'correct': 0,
      'explanation': 'Powers of 2 have exactly one bit set. N-1 flips all lower bits. AND gives 0 only for powers of 2. O(1) and elegant.',
      'category': 'Bit Manipulation', 'xp': 25,
    },
    {
      'question': 'Find element in sorted rotated array in O(log n)?',
      'options': ['Modified binary search: check which half is sorted', 'Linear scan from pivot', 'Two pointer approach', 'Merge sort then binary search'],
      'correct': 0,
      'explanation': 'At each mid, one half must be sorted. Check if target is in sorted half → recurse there. The other half contains the rotation point.',
      'category': 'Binary Search', 'xp': 30,
    },
    {
      'question': 'Why does Greedy fail for Coin Change problem?',
      'options': ['Locally optimal choices may miss global optimum', 'It\'s too slow', 'It runs out of memory', 'It can\'t handle all denominations'],
      'correct': 0,
      'explanation': 'Example: coins=[1,3,4], amount=6. Greedy picks 4+1+1=3 coins. Optimal: 3+3=2 coins. DP guarantees the global optimum.',
      'category': 'Dynamic Programming', 'xp': 35,
    },
    {
      'question': 'Find k-th largest in streaming data efficiently?',
      'options': ['Min-heap of size k', 'Max-heap of all elements', 'Sorted array', 'Hash table with counts'],
      'correct': 0,
      'explanation': 'Maintain min-heap of size k. Root is always k-th largest. O(log k) per insertion vs O(n log n) sorting everything.',
      'category': 'Heaps', 'xp': 30,
    },
    {
      'question': 'Detect linked list cycle using O(1) space?',
      'options': ['Floyd\'s two-pointer (fast & slow)', 'HashSet of visited nodes', 'Array of node addresses', 'Count nodes recursively'],
      'correct': 0,
      'explanation': 'Floyd\'s: fast moves 2 steps, slow moves 1. If cycle exists, they must meet inside the cycle. No extra memory needed.',
      'category': 'Linked Lists', 'xp': 25,
    },
    {
      'question': 'Best strategy to merge K sorted lists of total N elements?',
      'options': ['Min-heap with one element per list → O(N log K)', 'Pairwise merge → O(NK)', 'Concatenate and sort → O(N log N)', 'K pointers simultaneously'],
      'correct': 0,
      'explanation': 'Min-heap approach: always extract global minimum, push next from that list. O(N log K) which is optimal for this problem.',
      'category': 'Heaps', 'xp': 35,
    },
    {
      'question': 'Which detects negative cycles in a graph?',
      'options': ['Bellman-Ford', 'Dijkstra', 'Floyd-Warshall for detection', 'BFS'],
      'correct': 0,
      'explanation': 'Bellman-Ford relaxes V-1 times. If a V-th relaxation is possible, a negative cycle exists. Dijkstra fails with negative edges.',
      'category': 'Graphs', 'xp': 30,
    },
    {
      'question': 'Topological sort can only work on which type of graph?',
      'options': ['Directed Acyclic Graph (DAG)', 'Undirected graph', 'Graph with cycles', 'Complete graph'],
      'correct': 0,
      'explanation': 'Topological ordering requires no cycles (edges only go "forward"). A cycle means no valid ordering exists.',
      'category': 'Graphs', 'xp': 25,
    },
  ];

  // ─── Shuffled questions list (built in initState / restart) ───────────────
  late List<Map<String, dynamic>> _questions;

  int _current = 0;
  int _score = 0;
  int _totalXP = 0;
  int _streak = 0;
  int _maxStreak = 0;
  int? _selected;
  bool _answered = false;
  bool _gameWon = false;

  late AnimationController _cardCtrl;
  late Animation<double> _cardAnim;
  late AnimationController _streakCtrl;

  @override
  void initState() {
    super.initState();
    _cardCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _cardAnim = CurvedAnimation(parent: _cardCtrl, curve: Curves.easeOutBack);
    _streakCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _buildShuffledQuestions();
    _cardCtrl.forward();
  }

  /// ✅ FIX: Shuffle both question order AND option order per question
  /// so the correct answer is NOT always at index 0.
  void _buildShuffledQuestions() {
    final rng = Random();
    final shuffledBank = List<Map<String, dynamic>>.from(_questionBank)
      ..shuffle(rng);

    _questions = shuffledBank.map((q) {
      final options = List<String>.from(q['options'] as List);
      final correctText = options[q['correct'] as int];

      options.shuffle(rng);
      final newCorrectIndex = options.indexOf(correctText);

      return {
        ...q,
        'options': options,
        'correct': newCorrectIndex,
      };
    }).toList();
  }

  void _selectOption(int idx) {
    if (_answered) return;
    setState(() {
      _selected = idx;
      _answered = true;
    });

    final correct = idx == _questions[_current]['correct'];

    if (correct) {
      _streak++;
      if (_streak > _maxStreak) _maxStreak = _streak;
    } else {
      _streak = 0;
    }

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;

      if (correct) {
        final bonus = _streak >= 3 ? 2 : 1;
        setState(() {
          _score++;
          _totalXP += (_questions[_current]['xp'] as int) * bonus;
        });
      }

      if (_current >= _questions.length - 1) {
        setState(() => _gameWon = true);
        _awardXP();
        return;
      }

      setState(() {
        _current++;
        _selected = null;
        _answered = false;
      });
      _cardCtrl.forward(from: 0);
    });
  }

  Future<void> _awardXP() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'xp': FieldValue.increment(_totalXP),
      'coins': FieldValue.increment(_score * 3),
      'totalGamesPlayed': FieldValue.increment(1),
    });
  }

  void _restartGame() {
    setState(() {
      _current = 0; _score = 0; _totalXP = 0; _streak = 0; _maxStreak = 0;
      _selected = null; _answered = false; _gameWon = false;
    });
    _buildShuffledQuestions(); // Re-shuffle on restart
    _cardCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _streakCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF060818),
      body: Stack(children: [
        _buildBg(),
        SafeArea(
          child: _gameWon ? _buildWin() : _buildGame(),
        ),
      ]),
    );
  }

  Widget _buildBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.3, -0.4),
          radius: 1.2,
          colors: [Color(0xFF0D0A25), Color(0xFF060818)],
        ),
      ),
    );
  }

  Widget _buildGame() {
    final q = _questions[_current];
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20, 0, 20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: ScaleTransition(
              scale: _cardAnim,
              child: Column(
                children: [
                  _buildProgressAndStreak(),
                  const SizedBox(height: 16),
                  _buildCategoryBadge(q),
                  const SizedBox(height: 12),
                  _buildQuestionCard(q),
                  const SizedBox(height: 14),
                  ...List.generate(4, (i) => _buildOption(i, q)),
                  if (_answered) ...[
                    const SizedBox(height: 16),
                    _buildExplanation(q),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          const Text('🧩 Logic Builder', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF7B2FFF).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF7B2FFF).withOpacity(0.4)),
            ),
            child: Text('⚡ $_totalXP XP',
                style: const TextStyle(color: Color(0xFF7B2FFF), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressAndStreak() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${_current + 1} / ${_questions.length}',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
            if (_streak >= 2)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6348).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF6348).withOpacity(0.4)),
                ),
                child: Text('🔥 $_streak STREAK!',
                    style: const TextStyle(color: Color(0xFFFF6348), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (_current + 1) / _questions.length,
            backgroundColor: Colors.white.withOpacity(0.06),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7B2FFF)),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBadge(Map<String, dynamic> q) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF7B2FFF).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF7B2FFF).withOpacity(0.3)),
        ),
        child: Text(q['category'] as String,
            style: const TextStyle(color: Color(0xFF7B2FFF), fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> q) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF7B2FFF).withOpacity(0.1),
            const Color(0xFF00D4FF).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF7B2FFF).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🧠 THINK CAREFULLY',
              style: TextStyle(color: Color(0xFF7B2FFF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
          const SizedBox(height: 14),
          Text(q['question'] as String,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildOption(int idx, Map<String, dynamic> q) {
    final isCorrect = _answered && idx == q['correct'];
    final isWrong = _answered && idx == _selected && idx != q['correct'];
    final options = q['options'] as List;

    return GestureDetector(
      onTap: () => _selectOption(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCorrect
              ? const Color(0xFF00FF87).withOpacity(0.1)
              : isWrong
              ? const Color(0xFFFF4757).withOpacity(0.1)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCorrect
                ? const Color(0xFF00FF87).withOpacity(0.5)
                : isWrong
                ? const Color(0xFFFF4757).withOpacity(0.5)
                : Colors.white.withOpacity(0.08),
            width: isCorrect || isWrong ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCorrect
                    ? const Color(0xFF00FF87)
                    : isWrong
                    ? const Color(0xFFFF4757)
                    : const Color(0xFF7B2FFF).withOpacity(0.2),
              ),
              child: Center(
                child: isCorrect
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : isWrong
                    ? const Icon(Icons.close, color: Colors.white, size: 14)
                    : Text(String.fromCharCode(65 + idx),
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(options[idx] as String,
                  style: TextStyle(
                      color: isCorrect ? const Color(0xFF00FF87) : isWrong ? const Color(0xFFFF4757) : Colors.white,
                      fontSize: 14,
                      fontWeight: isCorrect || isWrong ? FontWeight.bold : FontWeight.normal,
                      height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanation(Map<String, dynamic> q) {
    final correct = _selected == q['correct'];
    final bonus = _streak >= 3 && correct;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(correct ? '✅ Correct!' : '❌ Wrong!',
                  style: TextStyle(
                      color: correct ? const Color(0xFF00FF87) : const Color(0xFFFF4757),
                      fontWeight: FontWeight.bold)),
              if (correct) ...[
                const Spacer(),
                Text(bonus ? '🔥 COMBO! +${(q['xp'] as int) * 2} XP' : '+${q['xp']} XP',
                    style: TextStyle(
                        color: bonus ? const Color(0xFFFF6348) : const Color(0xFF7B2FFF),
                        fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(q['explanation'] as String,
              style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildWin() {
    final perfect = _score == _questions.length;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(perfect ? '🏆' : '🧩', style: const TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            Text(
              perfect ? 'LOGIC MASTER!' : 'LEVEL COMPLETE!',
              style: TextStyle(
                  color: perfect ? const Color(0xFFFFB800) : const Color(0xFF7B2FFF),
                  fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text('$_score / ${_questions.length} correct',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
            const SizedBox(height: 4),
            Text('Max streak: $_maxStreak 🔥',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7B2FFF), Color(0xFF00D4FF)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('+$_totalXP XP  +${_score * 3} 🪙',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(height: 32),
            _btn('Play Again', _restartGame, const Color(0xFF7B2FFF)),
            const SizedBox(height: 12),
            _btn('← Back', () => Navigator.pop(context), Colors.white.withOpacity(0.08)),
          ],
        ),
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