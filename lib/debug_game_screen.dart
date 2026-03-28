import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DebugGameScreen extends StatefulWidget {
  const DebugGameScreen({super.key});

  @override
  State<DebugGameScreen> createState() => _DebugGameScreenState();
}

class _DebugGameScreenState extends State<DebugGameScreen> with TickerProviderStateMixin {
  static const List<Map<String, dynamic>> _questions = [
    {
      'buggyCode': 'def binary_search(arr, target):\n    left, right = 0, len(arr)\n    while left < right:\n        mid = (left + right) // 2\n        if arr[mid] == target: return mid\n        elif arr[mid] < target: left = mid + 1\n        else: right = mid - 1\n    return -1',
      'question': 'Find the bug in binary search:',
      'options': ['right = len(arr) → should be len(arr)-1', 'mid formula is wrong', 'return -1 is missing', 'while condition wrong'],
      'correct': 0,
      'explanation': 'right should be len(arr)-1 (last valid index). len(arr) causes index out of bounds on first access.',
      'difficulty': 'Medium', 'xp': 25, 'coins': 15,
    },
    {
      'buggyCode': 'def fibonacci(n):\n    if n <= 0: return 0\n    if n == 1: return 1\n    return fibonacci(n-1) + fibonacci(n-3)',
      'question': 'Spot the bug in Fibonacci:',
      'options': ['fibonacci(n-3) should be fibonacci(n-2)', 'Base case n==1 is wrong', 'n<=0 should be n<0', 'Missing memoization'],
      'correct': 0,
      'explanation': 'Fibonacci: F(n) = F(n-1) + F(n-2). Using n-3 gives completely wrong values.',
      'difficulty': 'Easy', 'xp': 15, 'coins': 10,
    },
    {
      'buggyCode': 'int[] arr = new int[5];\nfor (int i = 0; i <= arr.length; i++) {\n    arr[i] = i * 2;\n}',
      'question': 'What\'s wrong with this Java loop?',
      'options': ['i <= arr.length → should be i < arr.length', 'arr.length should be arr.size()', 'int[] declaration is wrong', 'i * 2 should be i + 2'],
      'correct': 0,
      'explanation': 'Array indices go from 0 to length-1. i <= length accesses index 5 on a 5-element array → ArrayIndexOutOfBoundsException.',
      'difficulty': 'Easy', 'xp': 15, 'coins': 10,
    },
    {
      'buggyCode': 'def reverse_string(s):\n    result = ""\n    for i in range(len(s)):\n        result = result + s[i]\n    return result',
      'question': 'This should reverse a string. Find the bug:',
      'options': ['Should be result = s[i] + result (prepend)', 'range should be reversed', 'result += s[i] is needed', 'return result[::-1]'],
      'correct': 0,
      'explanation': 'Appending s[i] to result copies the string unchanged. To reverse, prepend: result = s[i] + result.',
      'difficulty': 'Easy', 'xp': 15, 'coins': 10,
    },
    {
      'buggyCode': 'vector<int> v = {1, 2, 3, 4, 5};\nfor (int i = 0; i < v.size(); i++) {\n    if (v[i] % 2 == 0)\n        v.erase(v.begin() + i);\n}',
      'question': 'C++ code to remove even numbers. Bug?',
      'options': ['After erase, i must not increment (skips element)', 'v.size() should be v.length()', 'v.erase needs two iterators', 'Condition % 2 != 0'],
      'correct': 0,
      'explanation': 'After erasing at index i, next element shifts to i. Without adjusting i, that element is skipped. Fix: i-- after erase or use remove_if.',
      'difficulty': 'Hard', 'xp': 35, 'coins': 20,
    },
    {
      'buggyCode': 'def has_cycle(head):\n    slow = fast = head\n    while fast and fast.next:\n        slow = slow.next\n        fast = fast.next\n    return slow == fast',
      'question': 'Bug in linked list cycle detection:',
      'options': ['fast should move 2 steps: fast = fast.next.next', 'slow should also move 2 steps', 'Condition should be while slow != fast', 'Return should check fast is None'],
      'correct': 0,
      'explanation': 'Floyd\'s algorithm requires fast to move 2 steps. Without this, slow and fast always meet at the same point even without a cycle.',
      'difficulty': 'Hard', 'xp': 35, 'coins': 20,
    },
    {
      'buggyCode': 'public int maxDepth(TreeNode root) {\n    if (root == null) return 0;\n    return 1 + maxDepth(root.left) + maxDepth(root.right);\n}',
      'question': 'Max depth of binary tree. Find the bug:',
      'options': ['Should use Math.max() not addition', 'Base case should return 1', 'Should check root.left == null', 'Recursion order is wrong'],
      'correct': 0,
      'explanation': 'Max depth = 1 + max(leftDepth, rightDepth). Adding them computes total node count (like a subtree sum), not the deepest path.',
      'difficulty': 'Medium', 'xp': 25, 'coins': 15,
    },
    {
      'buggyCode': 'def two_sum(nums, target):\n    seen = {}\n    for i, num in enumerate(nums):\n        complement = target + num\n        if complement in seen:\n            return [seen[complement], i]\n        seen[num] = i\n    return []',
      'question': 'Bug in Two Sum solution:',
      'options': ['target + num → should be target - num', 'seen should be a list', 'enumerate is not needed', 'Return should give values not indices'],
      'correct': 0,
      'explanation': 'We need: num + complement = target, so complement = target - num. target + num gives us the wrong lookup value.',
      'difficulty': 'Medium', 'xp': 25, 'coins': 15,
    },
  ];

  int _current = 0;
  int _score = 0;
  int _totalXP = 0;
  int _totalCoins = 0;
  int _lives = 3;
  int? _selected;
  bool _answered = false;
  bool _gameOver = false;
  bool _gameWon = false;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _slideAnim = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  void _selectOption(int idx) {
    if (_answered) return;
    setState(() {
      _selected = idx;
      _answered = true;
    });

    final correct = idx == _questions[_current]['correct'];

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;

      if (correct) {
        setState(() {
          _score++;
          _totalXP += _questions[_current]['xp'] as int;
          _totalCoins += _questions[_current]['coins'] as int;
        });
      } else {
        setState(() => _lives--);
      }

      if (_lives <= 0) {
        setState(() => _gameOver = true);
        return;
      }

      if (_current >= _questions.length - 1) {
        setState(() => _gameWon = true);
        _awardRewards();
        return;
      }

      setState(() {
        _current++;
        _selected = null;
        _answered = false;
      });
      _slideCtrl.forward(from: 0);
    });
  }

  Future<void> _awardRewards() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'xp': FieldValue.increment(_totalXP),
      'coins': FieldValue.increment(_totalCoins),
    });
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060818),
      body: Stack(children: [
        _buildBg(),
        SafeArea(
          child: _gameOver
              ? _buildGameOver()
              : _gameWon
              ? _buildWin()
              : _buildGame(),
        ),
      ]),
    );
  }

  Widget _buildBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.3, -0.5),
          radius: 1.2,
          colors: [Color(0xFF1A0A20), Color(0xFF060818)],
        ),
      ),
    );
  }

  Widget _buildGame() {
    final q = _questions[_current];
    return Column(
      children: [
        _buildHeader(q),
        Expanded(
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  _buildProgress(),
                  const SizedBox(height: 16),
                  _buildBugCard(q),
                  const SizedBox(height: 16),
                  _buildQuestion(q),
                  const SizedBox(height: 12),
                  ...List.generate(4, (i) => _buildOption(i, q)),
                  if (_answered) ...[
                    const SizedBox(height: 16),
                    _buildExplanation(q),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(Map<String, dynamic> q) {
    final diff = q['difficulty'] as String;
    final diffColors = {'Easy': const Color(0xFF00FF87), 'Medium': const Color(0xFFFFB800), 'Hard': const Color(0xFFFF4757)};
    final dc = diffColors[diff] ?? const Color(0xFF00D4FF);

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
          const Text('🐛 Debug Mode', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: dc.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: dc.withOpacity(0.4)),
            ),
            child: Text(diff, style: TextStyle(color: dc, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Row(children: List.generate(3, (i) =>
              Text(i < _lives ? '❤️' : '🖤', style: const TextStyle(fontSize: 16)))),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: (_current + 1) / _questions.length,
        backgroundColor: Colors.white.withOpacity(0.06),
        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF4757)),
        minHeight: 6,
      ),
    );
  }

  Widget _buildBugCard(Map<String, dynamic> q) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF4757).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔴', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Text('buggy_code.py',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            q['buggyCode'] as String,
            style: const TextStyle(
              color: Color(0xFF00FF87),
              fontSize: 12,
              fontFamily: 'monospace',
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(Map<String, dynamic> q) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4757).withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF4757).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Text('🔍', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(q['question'] as String,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(int idx, Map<String, dynamic> q) {
    final isCorrect = _answered && idx == q['correct'];
    final isWrong = _answered && idx == _selected && idx != q['correct'];
    final options = q['options'] as List;

    Color bg = Colors.white.withOpacity(0.05);
    Color border = Colors.white.withOpacity(0.1);
    if (isCorrect) { bg = const Color(0xFF00FF87).withOpacity(0.12); border = const Color(0xFF00FF87).withOpacity(0.5); }
    if (isWrong) { bg = const Color(0xFFFF4757).withOpacity(0.12); border = const Color(0xFFFF4757).withOpacity(0.5); }

    return GestureDetector(
      onTap: () => _selectOption(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            if (isCorrect) const Icon(Icons.check_circle, color: Color(0xFF00FF87), size: 20)
            else if (isWrong) const Icon(Icons.cancel, color: Color(0xFFFF4757), size: 20)
            else Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Center(child: Text('${idx + 1}',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.bold))),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(options[idx] as String,
                  style: TextStyle(
                      color: isCorrect ? const Color(0xFF00FF87) : isWrong ? const Color(0xFFFF4757) : Colors.white,
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: isCorrect || isWrong ? FontWeight.bold : FontWeight.normal)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanation(Map<String, dynamic> q) {
    final correct = _selected == q['correct'];
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
              Text(correct ? '✅ Bug Found!' : '❌ Missed it!',
                  style: TextStyle(
                      color: correct ? const Color(0xFF00FF87) : const Color(0xFFFF4757),
                      fontWeight: FontWeight.bold)),
              if (correct) ...[
                const Spacer(),
                Text('+${q['xp']} XP  +${q['coins']} 🪙',
                    style: const TextStyle(color: Color(0xFFFFB800), fontWeight: FontWeight.bold, fontSize: 12)),
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

  Widget _buildGameOver() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💔', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            const Text('OUT OF LIVES!',
                style: TextStyle(color: Color(0xFFFF4757), fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text('Bugs found: $_score / $_current',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16)),
            const SizedBox(height: 8),
            Text('XP: $_totalXP  Coins: $_totalCoins',
                style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            _btn('Try Again', () {
              setState(() {
                _current = 0; _score = 0; _totalXP = 0; _totalCoins = 0;
                _lives = 3; _selected = null; _answered = false; _gameOver = false; _gameWon = false;
              });
              _slideCtrl.forward(from: 0);
            }, const Color(0xFFFF4757)),
            const SizedBox(height: 12),
            _btn('← Back', () => Navigator.pop(context), Colors.white.withOpacity(0.08)),
          ],
        ),
      ),
    );
  }

  Widget _buildWin() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🐛✅', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            const Text('ALL BUGS FIXED!',
                style: TextStyle(color: Color(0xFF00FF87), fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text('$_score / ${_questions.length} bugs found',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF00FF87), Color(0xFF00D4FF)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('+$_totalXP XP  +$_totalCoins 🪙',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            ),
            const SizedBox(height: 32),
            _btn('Play Again', () {
              setState(() {
                _current = 0; _score = 0; _totalXP = 0; _totalCoins = 0;
                _lives = 3; _selected = null; _answered = false; _gameOver = false; _gameWon = false;
              });
              _slideCtrl.forward(from: 0);
            }, const Color(0xFF00FF87)),
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