import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ─────────────────────────────────────────────────────────────────────────────
// 🔑  FREE Gemini API key — get yours free at https://aistudio.google.com/apikey
//     Paste your key below. No billing required for Gemini Flash.
// ─────────────────────────────────────────────────────────────────────────────
const String _kGeminiApiKey = 'AIzaSyBEENv9I_AcrjtLmpxoLFvcrQ0YUXxRGis';
const String _kGeminiEndpoint =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

class SyntaxGameScreen extends StatefulWidget {
  const SyntaxGameScreen({super.key});

  @override
  State<SyntaxGameScreen> createState() => _SyntaxGameScreenState();
}

class _SyntaxGameScreenState extends State<SyntaxGameScreen>
    with TickerProviderStateMixin {
  static const List<Map<String, dynamic>> _questionBank = [
    {
      'question': 'Complete: squares = [___ for x in range(10)]',
      'options': ['x*x', 'x^2', 'x**x', 'pow(x)'],
      'correct': 0,
      'explanation':
      'x*x multiplies x by itself. In Python, ^ is XOR not power. Use ** for powers.',
      'category': 'Python',
      'xp': 10,
    },
    {
      'question': 'Declare a variable in Java:',
      'options': ['int x = 5;', 'x = 5;', 'var x: int = 5;', 'declare int x = 5;'],
      'correct': 0,
      'explanation': 'Java requires explicit type declaration before variable name.',
      'category': 'Java',
      'xp': 10,
    },
    {
      'question': 'What does arr.sort() return in Python?',
      'options': ['None', 'sorted list', 'new list', 'True'],
      'correct': 0,
      'explanation':
      'list.sort() sorts in-place and returns None. Use sorted(arr) to get a new list.',
      'category': 'Python',
      'xp': 15,
    },
    {
      'question': 'Python lambda to add two numbers:',
      'options': [
        'lambda x, y: x + y',
        'lambda(x, y): x + y',
        'fn x, y => x + y',
        'def lambda(x,y): x+y'
      ],
      'correct': 0,
      'explanation':
      'Lambda syntax: lambda parameters: expression — no parentheses around params.',
      'category': 'Python',
      'xp': 15,
    },
    {
      'question': '== in Java checks:',
      'options': ['Reference equality', 'Value equality', 'Both', 'Neither'],
      'correct': 0,
      'explanation':
      'In Java, == checks if two references point to the same object. Use .equals() for value comparison.',
      'category': 'Java',
      'xp': 20,
    },
    {
      'question': 'C++ vector of integers declaration:',
      'options': ['vector<int> v;', 'int[] v;', 'List<int> v;', 'Array<int> v;'],
      'correct': 0,
      'explanation': 'C++ STL: #include <vector> then vector<type> name;',
      'category': 'C++',
      'xp': 20,
    },
    {
      'question': 'Python dict comprehension: numbers to squares',
      'options': [
        '{x: x**2 for x in range(5)}',
        '[x: x**2 for x in range(5)]',
        '{x => x**2 for x in range(5)}',
        'dict(x: x**2)'
      ],
      'correct': 0,
      'explanation':
      'Dict comprehension uses {} with key:value pairs separated by colon.',
      'category': 'Python',
      'xp': 20,
    },
    {
      'question': 'Python exception handling:',
      'options': [
        'try: ... except Exception as e:',
        'try: ... catch Exception e:',
        'try {} catch(e) {}',
        'begin rescue e:'
      ],
      'correct': 0,
      'explanation':
      'Python uses try/except (not try/catch like Java/C++). The "as" keyword binds the exception.',
      'category': 'Python',
      'xp': 15,
    },
    {
      'question': 'Java HashSet declaration:',
      'options': [
        'Set<Integer> s = new HashSet<>();',
        'HashSet s = new Set<Integer>();',
        'Set s = HashSet<Integer>();',
        'new HashSet<Integer> s;'
      ],
      'correct': 0,
      'explanation':
      'Use the interface type (Set) on the left, implementation (HashSet) on right with diamond operator.',
      'category': 'Java',
      'xp': 20,
    },
    {
      'question': 'C++ range-based for loop:',
      'options': [
        'for (int x : v) {}',
        'for (int x in v) {}',
        'for each (int x in v) {}',
        'foreach (int x : v) {}'
      ],
      'correct': 0,
      'explanation':
      'C++11 range-based for uses colon (:) not "in". Available since C++11.',
      'category': 'C++',
      'xp': 20,
    },
    {
      'question': 'Get all keys from Python dict d:',
      'options': ['d.keys()', 'd.getKeys()', 'keys(d)', 'd[keys]'],
      'correct': 0,
      'explanation':
      'd.keys() returns a dict_keys view object. Convert to list with list(d.keys()).',
      'category': 'Python',
      'xp': 10,
    },
    {
      'question': 'Reverse a Python list in-place:',
      'options': ['lst.reverse()', 'reversed(lst)', 'lst[::-1]', 'lst.sort(reverse=True)'],
      'correct': 0,
      'explanation':
      'lst.reverse() modifies the list in-place. reversed() and [::-1] create new objects.',
      'category': 'Python',
      'xp': 15,
    },
    {
      'question': 'C++ push to stack:',
      'options': ['st.push(x);', 'st.add(x);', 'st.append(x);', 'st.insert(x);'],
      'correct': 0,
      'explanation':
      'C++ std::stack uses push() to add and pop() to remove. top() peeks at top element.',
      'category': 'C++',
      'xp': 15,
    },
    {
      'question': 'Java generic method syntax:',
      'options': [
        'public <T> T method(T arg) {}',
        'public T method<T>(T arg) {}',
        'public method<T>(T arg): T {}',
        'generic T method(T arg) {}'
      ],
      'correct': 0,
      'explanation':
      'Java: type parameter <T> is declared before the return type in generic methods.',
      'category': 'Java',
      'xp': 25,
    },
    {
      'question': 'Python: Check if key exists in dict d:',
      'options': ['"key" in d', 'd.has("key")', 'd.contains("key")', 'haskey(d, "key")'],
      'correct': 0,
      'explanation':
      '"key" in d is the Pythonic way. Python 2 had d.has_key() but it was removed in Python 3.',
      'category': 'Python',
      'xp': 10,
    },
  ];

  late List<Map<String, dynamic>> _questions;

  int _current = 0;
  int _score = 0;
  int _lives = 3;
  int _totalXP = 0;
  int? _selected;
  bool _answered = false;
  bool _gameOver = false;
  bool _gameWon = false;
  bool _xpAwarded = false;

  // ── Hint / Gemini state ───────────────────────────────────────────────────
  bool _hintUsedThisQuestion = false; // reset each question
  int _freeHintsLeft = 1;             // 1 free hint per game session
  bool _hintLoading = false;

  late AnimationController _optionCtrl;
  late AnimationController _feedbackCtrl;
  late List<Animation<double>> _optionAnims;

  @override
  void initState() {
    super.initState();
    _optionCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _feedbackCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _optionAnims = List.generate(
        4,
            (i) => CurvedAnimation(
          parent: _optionCtrl,
          curve:
          Interval(i * 0.15, 0.6 + i * 0.1, curve: Curves.easeOutBack),
        ));
    _buildShuffledQuestions();
    _optionCtrl.forward();
  }

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

  // ── Gemini hint fetcher ───────────────────────────────────────────────────
  Future<String> _fetchGeminiHint(Map<String, dynamic> q) async {
    final question = q['question'] as String;
    final options = (q['options'] as List).cast<String>();
    final category = q['category'] as String;

    final optionsText = options
        .asMap()
        .entries
        .map((e) => '${String.fromCharCode(65 + e.key)}) ${e.value}')
        .join('\n');

    final prompt = '''
You are a helpful coding tutor inside a programming quiz app called AlgoArena.
A student is stuck on this $category syntax question:

Question: $question

Options:
$optionsText

Give a SHORT, helpful hint (2–3 sentences max) that:
- Guides their thinking WITHOUT revealing the answer directly
- Explains the key concept or syntax rule they need to think about
- Uses simple language a student would understand
- Does NOT say which option letter is correct

Respond with ONLY the hint text, no preamble, no "Hint:" prefix.
''';

    final response = await http.post(
      Uri.parse('$_kGeminiEndpoint?key=$_kGeminiApiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.4,
          'maxOutputTokens': 150,
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text']
      as String? ??
          'Think carefully about the syntax rules for ${q['category']}. Each option has subtle differences — focus on what the language specification requires.';
      return text.trim();
    } else {
      // Fallback hint if API fails
      return 'Think about the core ${q['category']} syntax rules here. '
          'Look at each option carefully and consider which one follows the '
          'official language specification.';
    }
  }

  // ── Show hint bottom sheet ────────────────────────────────────────────────
  Future<void> _onHintPressed() async {
    final q = _questions[_current];

    // Determine cost
    final isFree = _freeHintsLeft > 0;
    if (!isFree && _lives <= 1) {
      // Can't afford — show warning
      _showCannotAffordHint();
      return;
    }

    // Confirm cost with user (skip dialog if free)
    if (!isFree) {
      final confirmed = await _showHintCostDialog();
      if (!confirmed) return;
    }

    setState(() => _hintLoading = true);

    String hintText;
    try {
      hintText = await _fetchGeminiHint(q);
    } catch (_) {
      hintText =
      'Think about the core ${q['category']} syntax rules. Compare each option carefully.';
    }

    if (!mounted) return;
    setState(() {
      _hintLoading = false;
      _hintUsedThisQuestion = true;
      if (isFree) {
        _freeHintsLeft--;
      } else {
        _lives--;
        if (_lives <= 0) {
          _gameOver = true;
          _awardXP();
          return;
        }
      }
    });

    _showHintSheet(hintText, isFree);
  }

  Future<bool> _showHintCostDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0D1B2E),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('💡', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              const Text(
                'Use AI Hint?',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'This hint costs ❤️ 1 life.\nYou currently have $_lives lives.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 14),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 14)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7B2FFF), Color(0xFF00D4FF)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text('Get Hint',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ) ??
        false;
  }

  void _showCannotAffordHint() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFFFF4757).withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: const Text(
          '❤️ Need at least 2 lives to use a hint!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showHintSheet(String hintText, bool wasFree) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF7B2FFF).withOpacity(0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B2FFF).withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7B2FFF), Color(0xFF00D4FF)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('✨',
                        style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Hint',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        wasFree ? '🎁 Free hint used!' : '❤️ 1 life spent',
                        style: TextStyle(
                          color: wasFree
                              ? const Color(0xFF00FF87)
                              : const Color(0xFFFF4757),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white54, size: 16),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),
              Divider(color: Colors.white.withOpacity(0.08)),
              const SizedBox(height: 6),

              // Gemini badge
              Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7B2FFF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: const Color(0xFF7B2FFF).withOpacity(0.3)),
                    ),
                    child: const Text(
                      '⚡ Powered by Gemini',
                      style: TextStyle(
                          color: Color(0xFF7B2FFF),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Hint text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Text(
                  hintText,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 14.5,
                    height: 1.65,
                    letterSpacing: 0.1,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Remaining hints info
              if (_freeHintsLeft > 0)
                _infoChip(
                    '🎁 $_freeHintsLeft free hint remaining this game', const Color(0xFF00FF87))
              else
                _infoChip(
                    'ℹ️ Future hints cost ❤️ 1 life each', const Color(0xFF00D4FF)),

              const SizedBox(height: 16),

              // Close button
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7B2FFF), Color(0xFF00D4FF)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'Got it, let me think! 🧠',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Existing game logic (unchanged)
  // ─────────────────────────────────────────────────────────────────────────

  void _selectOption(int idx) {
    if (_answered) return;
    setState(() {
      _selected = idx;
      _answered = true;
    });

    final correct = idx == _questions[_current]['correct'];

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;

      if (correct) {
        final xp = _questions[_current]['xp'] as int;
        setState(() {
          _score++;
          _totalXP += xp;
        });
      } else {
        setState(() => _lives--);
      }

      if (_lives <= 0) {
        setState(() => _gameOver = true);
        _awardXP();
        return;
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
        _hintUsedThisQuestion = false; // ← reset hint flag for new question
      });
      _optionCtrl.forward(from: 0);
    });
  }

  Future<void> _awardXP() async {
    if (_xpAwarded) return;
    _xpAwarded = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);

    batch.update(ref, {
      'xp': FieldValue.increment(_totalXP),
      'coins': FieldValue.increment(_score * 2),
      'totalGamesPlayed': FieldValue.increment(1),
      if (_gameWon) 'totalWins': FieldValue.increment(1),
    });

    await batch.commit();
  }

  void _restartGame() {
    setState(() {
      _current = 0;
      _score = 0;
      _lives = 3;
      _totalXP = 0;
      _selected = null;
      _answered = false;
      _gameOver = false;
      _gameWon = false;
      _xpAwarded = false;
      _hintUsedThisQuestion = false;
      _freeHintsLeft = 1; // reset free hints for new game
    });
    _buildShuffledQuestions();
    _optionCtrl.forward(from: 0);
  }

  Color _optionColor(int idx) {
    if (!_answered) return Colors.white.withOpacity(0.06);
    final correct = _questions[_current]['correct'];
    if (idx == correct) return const Color(0xFF00FF87).withOpacity(0.15);
    if (idx == _selected && idx != correct)
      return const Color(0xFFFF4757).withOpacity(0.15);
    return Colors.white.withOpacity(0.04);
  }

  Color _optionBorder(int idx) {
    if (!_answered) return Colors.white.withOpacity(0.12);
    final correct = _questions[_current]['correct'];
    if (idx == correct) return const Color(0xFF00FF87).withOpacity(0.6);
    if (idx == _selected && idx != correct)
      return const Color(0xFFFF4757).withOpacity(0.6);
    return Colors.white.withOpacity(0.06);
  }

  @override
  void dispose() {
    _optionCtrl.dispose();
    _feedbackCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
          center: Alignment(0, -0.5),
          radius: 1.3,
          colors: [Color(0xFF0A1628), Color(0xFF060818)],
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
              20,
              0,
              20,
              MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              children: [
                _buildProgress(),
                const SizedBox(height: 20),
                _buildQuestionCard(q),
                const SizedBox(height: 16),

                // ── AI Hint button ──────────────────────────────────────
                if (!_answered) _buildHintButton(),

                const SizedBox(height: 16),
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
      ],
    );
  }

  // ── Hint button widget ────────────────────────────────────────────────────
  Widget _buildHintButton() {
    final isFree = _freeHintsLeft > 0;
    final alreadyUsed = _hintUsedThisQuestion;

    return GestureDetector(
      onTap: (alreadyUsed || _hintLoading) ? null : _onHintPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
        decoration: BoxDecoration(
          color: alreadyUsed
              ? Colors.white.withOpacity(0.04)
              : const Color(0xFF7B2FFF).withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: alreadyUsed
                ? Colors.white.withOpacity(0.08)
                : const Color(0xFF7B2FFF).withOpacity(0.45),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_hintLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF7B2FFF),
                ),
              )
            else
              Text(
                alreadyUsed ? '💡' : '✨',
                style: const TextStyle(fontSize: 16),
              ),
            const SizedBox(width: 8),
            Text(
              _hintLoading
                  ? 'Getting AI hint...'
                  : alreadyUsed
                  ? 'Hint used for this question'
                  : isFree
                  ? '✨ Get AI Hint  •  FREE'
                  : '✨ Get AI Hint  •  costs ❤️ 1 life',
              style: TextStyle(
                color: alreadyUsed
                    ? Colors.white.withOpacity(0.3)
                    : const Color(0xFF7B2FFF),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!alreadyUsed && isFree) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF87).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'FREE',
                  style: TextStyle(
                      color: Color(0xFF00FF87),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 15),
            ),
          ),
          const SizedBox(width: 10),
          const Flexible(
            child: Text(
              'Syntax Master',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: List.generate(
                3,
                    (i) => Text(
                  i < _lives ? '❤️' : '🖤',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 70, maxWidth: 100),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border:
              Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3)),
            ),
            child: Text(
              '⚡ $_totalXP XP',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF00D4FF),
                  fontWeight: FontWeight.bold,
                  fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${_current + 1} / ${_questions.length}',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 12)),
            Text('Score: $_score',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (_current + 1) / _questions.length,
            backgroundColor: Colors.white.withOpacity(0.08),
            valueColor:
            const AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> q) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D4FF).withOpacity(0.08),
            const Color(0xFF7B2FFF).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(q['category'] as String,
                    style: const TextStyle(
                        color: Color(0xFF00D4FF),
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(q['question'] as String,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildOption(int idx, Map<String, dynamic> q) {
    final labels = ['A', 'B', 'C', 'D'];
    final options = q['options'] as List;
    final isCorrect = _answered && idx == q['correct'];
    final isWrong = _answered && idx == _selected && idx != q['correct'];

    return ScaleTransition(
      scale: _optionAnims[idx],
      child: GestureDetector(
        onTap: () => _selectOption(idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _optionColor(idx),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: _optionBorder(idx), width: _answered ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCorrect
                      ? const Color(0xFF00FF87)
                      : isWrong
                      ? const Color(0xFFFF4757)
                      : Colors.white.withOpacity(0.08),
                ),
                child: Center(
                  child: isCorrect
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : isWrong
                      ? const Icon(Icons.close,
                      color: Colors.white, size: 16)
                      : Text(labels[idx],
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  options[idx] as String,
                  style: TextStyle(
                      color: isCorrect
                          ? const Color(0xFF00FF87)
                          : isWrong
                          ? const Color(0xFFFF4757)
                          : Colors.white,
                      fontSize: 14,
                      fontWeight: _answered && (isCorrect || isWrong)
                          ? FontWeight.bold
                          : FontWeight.normal),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExplanation(Map<String, dynamic> q) {
    final correct = _selected == q['correct'];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: correct
            ? const Color(0xFF00FF87).withOpacity(0.08)
            : const Color(0xFFFF4757).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: correct
              ? const Color(0xFF00FF87).withOpacity(0.3)
              : const Color(0xFFFF4757).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(correct ? '✅ Correct!' : '❌ Incorrect',
                  style: TextStyle(
                      color: correct
                          ? const Color(0xFF00FF87)
                          : const Color(0xFFFF4757),
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              if (correct) ...[
                const Spacer(),
                Text('+${q['xp']} XP',
                    style: const TextStyle(
                        color: Color(0xFF00D4FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(q['explanation'] as String,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  height: 1.5)),
        ],
      ),
    );
  }

  // ── Game Over ─────────────────────────────────────────────────────────────
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
                style: TextStyle(
                    color: Color(0xFFFF4757),
                    fontSize: 28,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text('You answered $_score / $_current correctly',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 16)),
            const SizedBox(height: 8),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4757).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: const Color(0xFFFF4757).withOpacity(0.3)),
              ),
              child: Text(
                '⚡ +$_totalXP XP saved to your profile',
                style: const TextStyle(
                    color: Color(0xFF00D4FF),
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 32),
            _resultButton('Try Again', _restartGame, const Color(0xFFFF4757)),
            const SizedBox(height: 12),
            _resultButton('← Back to Arena', () => Navigator.pop(context),
                Colors.white.withOpacity(0.1)),
          ],
        ),
      ),
    );
  }

  // ── Win ───────────────────────────────────────────────────────────────────
  Widget _buildWin() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 24),
            const Text('SYNTAX MASTER!',
                style: TextStyle(
                    color: Color(0xFFFFB800),
                    fontSize: 28,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text('$_score / ${_questions.length} correct',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 16)),
            const SizedBox(height: 8),
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '+$_totalXP XP  +${_score * 2} 🪙  saved!',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 17),
              ),
            ),
            const SizedBox(height: 32),
            _resultButton('Play Again', _restartGame, const Color(0xFF00D4FF)),
            const SizedBox(height: 12),
            _resultButton('← Back to Arena', () => Navigator.pop(context),
                Colors.white.withOpacity(0.1)),
          ],
        ),
      ),
    );
  }

  Widget _resultButton(String label, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ),
      ),
    );
  }
}
