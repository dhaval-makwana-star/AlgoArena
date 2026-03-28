import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'socket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AiBattleScreen — The complete 1v1 vs Bot experience
// Navigate here from DashboardScreen when user taps the "AI Battle" room card.
//
// Usage:
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => AiBattleScreen(socketService: socketService),
//   ));
// ─────────────────────────────────────────────────────────────────────────────

class AiBattleScreen extends StatefulWidget {
  final SocketService socketService;
  const AiBattleScreen({super.key, required this.socketService});

  @override
  State<AiBattleScreen> createState() => _AiBattleScreenState();
}

// ─── Battle Phase State Machine ──────────────────────────────────────────────
enum BattlePhase {
  loading,      // Gemini is generating the question
  countdown,    // 3-2-1 countdown
  battle,       // Active — player types, bot "thinks"
  result,       // Winner declared
  error,        // FIX: new error phase for auth/connection failures
}

class _AiBattleScreenState extends State<AiBattleScreen>
    with TickerProviderStateMixin {

  // ─── State ──────────────────────────────────────────────────────────────
  BattlePhase _phase = BattlePhase.loading;
  String _statusMessage = "Connecting to arena...";

  // FIX: Track join retry attempts
  int _joinRetryCount = 0;
  static const int _maxRetries = 3;

  // Bot info
  String _botName = "GlitchBot";
  String _botEmoji = "🤖";
  String _botLevel = "Rookie";
  String _botTaunt = "";
  int _botProgress = 0;           // 0–100, drives the bot "thinking" bar

  // Question
  String _question = "";
  String _hint = "";
  String _difficulty = "Medium";
  int _timeLeft = 60;
  String _correctAnswer = "";
  String _explanation = "";

  // Player answer
  final TextEditingController _answerCtrl = TextEditingController();
  bool _answerSubmitted = false;
  String _wrongFeedback = "";

  // Countdown
  int _countdownValue = 3;

  // Result
  bool _playerWon = false;
  int _coinsEarned = 0;
  int _xpEarned = 0;
  String _resultMessage = "";
  String _botEndLine = "";

  // Room
  String _roomId = "";

  // Timers & animations
  Timer? _gameTimer;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _shakeCtrl;
  late Animation<Offset> _shakeAnim;
  late AnimationController _resultCtrl;
  late Animation<double> _resultAnim;

  // ─── Colours ────────────────────────────────────────────────────────────
  static const _bg = Color(0xFF060818);
  static const _card = Color(0xFF0D1225);
  static const _accent = Color(0xFF7B2FFF);
  static const _red = Color(0xFFFF4757);
  static const _gold = Color(0xFFFFB800);
  static const _green = Color(0xFF00FF87);
  static const _cyan = Color(0xFF00D4FF);

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: Offset.zero, end: const Offset(0.03, 0)), weight: 1),
      TweenSequenceItem(tween: Tween(begin: const Offset(0.03, 0), end: const Offset(-0.03, 0)), weight: 2),
      TweenSequenceItem(tween: Tween(begin: const Offset(-0.03, 0), end: Offset.zero), weight: 1),
    ]).animate(_shakeCtrl);

    _resultCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _resultAnim = CurvedAnimation(parent: _resultCtrl, curve: Curves.elasticOut);

    _registerSocketListeners();
    _joinBattle();
  }

  // ─── Join the battle ────────────────────────────────────────────────────
  // FIX: Added retry logic and proper error handling for null user / GMS issues
  Future<void> _joinBattle() async {
    if (!mounted) return;

    setState(() => _statusMessage = "Connecting to arena...");

    // FIX: Wait for Firebase Auth to be ready — GMS errors can cause a brief delay
    User? user;
    for (int attempt = 0; attempt < 3; attempt++) {
      user = FirebaseAuth.instance.currentUser;
      if (user != null) break;
      // Wait 1s before retrying — gives GMS time to recover
      await Future.delayed(const Duration(seconds: 1));
    }

    if (user == null) {
      // FIX: Show error state instead of silently hanging
      if (mounted) {
        setState(() {
          _phase = BattlePhase.error;
          _statusMessage = "Not signed in. Please restart the app and log in again.";
        });
      }
      return;
    }

    Map<String, dynamic> data = {};
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      data = doc.data() ?? {};
    } catch (e) {
      // FIX: Firestore fetch failed (possibly GMS issue) — use safe defaults
      debugPrint("⚠️ Firestore fetch failed: $e");
      data = {};
    }

    final username = data['username'] ?? 'Coder';
    final aiStreak = data['aiLossStreak'] ?? 0;

    // FIX: Check socket connection before emitting
    if (!widget.socketService.socket.connected) {
      if (mounted) {
        setState(() {
          _statusMessage = "Connecting to server...";
        });
      }
      // Give the socket a moment to connect
      await Future.delayed(const Duration(seconds: 2));
      if (!widget.socketService.socket.connected) {
        if (mounted) {
          setState(() {
            _phase = BattlePhase.error;
            _statusMessage = "Cannot reach server. Check your internet and try again.";
          });
        }
        return;
      }
    }

    widget.socketService.socket.emit("joinAiBattle", {
      "uid": user.uid,
      "username": username,
      "aiStreak": aiStreak,
    });
  }

  // ─── All Socket Listeners ────────────────────────────────────────────────
  void _registerSocketListeners() {
    final s = widget.socketService.socket;

    // Server confirmed join — show bot card
    s.on("aiBattleJoined", (data) {
      if (!mounted) return;
      setState(() {
        _roomId = data['roomId'] ?? '';
        _botName = data['bot']['name'] ?? 'GlitchBot';
        _botEmoji = data['bot']['emoji'] ?? '🤖';
        _botLevel = data['bot']['level'] ?? 'Rookie';
        _statusMessage = "Opponent found! Preparing challenge...";
      });
    });

    // Status updates while Gemini generates
    s.on("aiBattleStatus", (data) {
      if (!mounted) return;
      setState(() => _statusMessage = data['message'] ?? '');
    });

    // 3-2-1 countdown
    s.on("aiBattleCountdown", (data) {
      if (!mounted) return;
      setState(() {
        _phase = BattlePhase.countdown;
        _countdownValue = data['count'] ?? 3;
      });
    });

    // Battle starts — got the question
    s.on("aiBattleStarted", (data) {
      if (!mounted) return;
      setState(() {
        _phase = BattlePhase.battle;
        _question = data['question'] ?? '';
        _hint = data['hint'] ?? '';
        _difficulty = data['difficulty'] ?? 'Medium';
        _botName = data['botName'] ?? _botName;
        _botEmoji = data['botEmoji'] ?? _botEmoji;
        _botTaunt = data['openingTaunt'] ?? '';
        _timeLeft = data['timeLimit'] ?? 60;
        _botProgress = 0;
      });
      _startTimer();
    });

    // Bot is "thinking" — progress updates
    s.on("aiBattleThinking", (data) {
      if (!mounted) return;
      setState(() {
        _botProgress = data['progress'] ?? _botProgress;
        _botTaunt = data['taunt'] ?? _botTaunt;
      });
    });

    // Player submitted wrong answer
    s.on("aiBattleWrongAnswer", (data) {
      if (!mounted) return;
      setState(() => _wrongFeedback = data['taunt'] ?? '❌ Wrong! Try again.');
      _shakeCtrl.forward(from: 0);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() { _wrongFeedback = ''; _answerSubmitted = false; });
      });
    });

    // Battle over
    s.on("aiBattleFinished", (data) {
      if (!mounted) return;
      _gameTimer?.cancel();
      setState(() {
        _phase = BattlePhase.result;
        _playerWon = data['winner'] == 'player';
        _resultMessage = data['message'] ?? '';
        _botEndLine = data['botLine'] ?? '';
        _coinsEarned = data['coinsEarned'] ?? 0;
        _xpEarned = data['xpEarned'] ?? 0;
        _correctAnswer = data['correctAnswer'] ?? '';
        _explanation = data['explanation'] ?? '';
      });
      _resultCtrl.forward(from: 0);
      _updateFirestore();
    });

    // FIX: Handle server-side auth error event
    s.on("aiBattleError", (data) {
      if (!mounted) return;
      _gameTimer?.cancel();
      setState(() {
        _phase = BattlePhase.error;
        _statusMessage = data['message'] ?? 'Something went wrong. Please try again.';
      });
    });
  }

  // ─── Game Timer ─────────────────────────────────────────────────────────
  void _startTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_timeLeft > 0) _timeLeft--;
      });
    });
  }

  // ─── Submit Answer ───────────────────────────────────────────────────────
  void _submitAnswer() {
    if (_answerSubmitted || _phase != BattlePhase.battle) return;
    final answer = _answerCtrl.text.trim();
    if (answer.isEmpty) return;

    setState(() => _answerSubmitted = true);
    widget.socketService.socket.emit("submitAiBattleAnswer", {
      "roomId": _roomId,
      "answer": answer,
    });
  }

  // ─── Update Firestore After Battle ───────────────────────────────────────
  Future<void> _updateFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      if (_playerWon) {
        await ref.update({
          'coins': FieldValue.increment(_coinsEarned),
          'xp': FieldValue.increment(_xpEarned),
          'aiWins': FieldValue.increment(1),
          'aiLossStreak': 0,
        });
      } else {
        await ref.update({
          'xp': FieldValue.increment(_xpEarned),
          'aiLosses': FieldValue.increment(1),
          'aiLossStreak': FieldValue.increment(1),
        });
      }
    } catch (e) {
      // FIX: Don't crash if Firestore update fails (GMS / network issue)
      debugPrint("⚠️ Firestore update failed: $e");
    }
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    _resultCtrl.dispose();
    _answerCtrl.dispose();
    // Remove listeners to avoid leaks
    final s = widget.socketService.socket;
    s.off("aiBattleJoined");
    s.off("aiBattleStatus");
    s.off("aiBattleCountdown");
    s.off("aiBattleStarted");
    s.off("aiBattleThinking");
    s.off("aiBattleWrongAnswer");
    s.off("aiBattleFinished");
    s.off("aiBattleError"); // FIX: unregister new listener
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [
        _buildBackground(),
        SafeArea(child: _buildBody()),
      ]),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case BattlePhase.loading:    return _buildLoadingPhase();
      case BattlePhase.countdown:  return _buildCountdownPhase();
      case BattlePhase.battle:     return _buildBattlePhase();
      case BattlePhase.result:     return _buildResultPhase();
      case BattlePhase.error:      return _buildErrorPhase(); // FIX
    }
  }

  // ─── Loading Phase ───────────────────────────────────────────────────────
  Widget _buildLoadingPhase() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      // Bot avatar pulsing
      ScaleTransition(
        scale: _pulseAnim,
        child: Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(colors: [Color(0xFF1A0A3A), Color(0xFF060818)]),
            border: Border.all(color: _red, width: 2),
            boxShadow: [BoxShadow(color: _red.withOpacity(0.4), blurRadius: 20)],
          ),
          child: Center(child: Text(_botEmoji, style: const TextStyle(fontSize: 48))),
        ),
      ),
      const SizedBox(height: 24),
      Text(_botName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(_statusMessage, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14)),
      const SizedBox(height: 32),
      const CircularProgressIndicator(color: Color(0xFF7B2FFF), strokeWidth: 2),
    ]));
  }

  // ─── Error Phase (FIX: new) ──────────────────────────────────────────────
  Widget _buildErrorPhase() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text("⚠️", style: TextStyle(fontSize: 64)),
          const SizedBox(height: 20),
          const Text(
            "Connection Error",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            _statusMessage,
            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Retry button
          GestureDetector(
            onTap: () {
              if (_joinRetryCount < _maxRetries) {
                _joinRetryCount++;
                setState(() {
                  _phase = BattlePhase.loading;
                  _statusMessage = "Reconnecting... (attempt $_joinRetryCount)";
                });
                _joinBattle();
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7B2FFF), Color(0xFF00D4FF)]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  _joinRetryCount < _maxRetries ? "RETRY" : "GO BACK",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text("Back to Home",
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
          ),
        ]),
      ),
    );
  }

  // ─── Countdown Phase ─────────────────────────────────────────────────────
  Widget _buildCountdownPhase() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text("GET READY", style: TextStyle(
          color: Colors.white.withOpacity(0.4), fontSize: 13,
          fontWeight: FontWeight.bold, letterSpacing: 4)),
      const SizedBox(height: 20),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
        child: Text(
          _countdownValue > 0 ? "$_countdownValue" : "GO!",
          key: ValueKey(_countdownValue),
          style: TextStyle(
            color: _countdownValue > 0 ? Colors.white : _green,
            fontSize: 120, fontWeight: FontWeight.w900,
          ),
        ),
      ),
      const SizedBox(height: 20),
      Text("vs $_botName $_botEmoji", style: TextStyle(
          color: Colors.white.withOpacity(0.6), fontSize: 16)),
    ]));
  }

  // ─── Battle Phase ────────────────────────────────────────────────────────
  Widget _buildBattlePhase() {
    final timerColor = _timeLeft > 20 ? _green : (_timeLeft > 10 ? _gold : _red);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const SizedBox(height: 8),

        // ── Header Row ──
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white54, size: 18),
            ),
          ),
          // Difficulty badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _diffColor(_difficulty).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _diffColor(_difficulty).withOpacity(0.4)),
            ),
            child: Text(_difficulty,
                style: TextStyle(color: _diffColor(_difficulty), fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          // Timer
          _buildTimer(timerColor),
        ]),

        const SizedBox(height: 28),

        // ── VS Banner ──
        Row(children: [
          // Player side
          Expanded(child: _buildPlayerCard()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text("VS", style: TextStyle(
                color: Colors.white.withOpacity(0.3), fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          // Bot side
          Expanded(child: _buildBotCard()),
        ]),

        const SizedBox(height: 24),

        // ── Question Card ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [BoxShadow(color: _accent.withOpacity(0.1), blurRadius: 20)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("CHALLENGE", style: TextStyle(
                color: _accent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 3)),
            const SizedBox(height: 12),
            Text(_question, style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.5)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text("💡 $_hint", style: TextStyle(
                  color: Colors.white.withOpacity(0.45), fontSize: 12)),
            ),
          ]),
        ),

        const SizedBox(height: 20),

        // ── Answer Input ──
        SlideTransition(
          position: _shakeAnim,
          child: Column(children: [
            Container(
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _wrongFeedback.isNotEmpty
                      ? _red.withOpacity(0.6)
                      : Colors.white.withOpacity(0.1),
                  width: 1.5,
                ),
              ),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _answerCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: "Type your answer...",
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onSubmitted: (_) => _submitAnswer(),
                    textInputAction: TextInputAction.go,
                    autocorrect: false,
                  ),
                ),
                GestureDetector(
                  onTap: _submitAnswer,
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF7B2FFF), Color(0xFF00D4FF)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text("GO", style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ]),
            ),
            if (_wrongFeedback.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _red.withOpacity(0.3)),
                ),
                child: Text(_wrongFeedback,
                    style: TextStyle(color: _red.withOpacity(0.9), fontSize: 13)),
              ),
            ],
          ]),
        ),

        const SizedBox(height: 16),

        // ── Bot "thinking" bar ──
        _buildBotThinkingBar(),
      ]),
    );
  }

  // ─── Timer Widget ────────────────────────────────────────────────────────
  Widget _buildTimer(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.timer, color: color, size: 16),
        const SizedBox(width: 5),
        Text("${_timeLeft}s", style: TextStyle(
            color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // ─── Player Card ─────────────────────────────────────────────────────────
  Widget _buildPlayerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _cyan.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cyan.withOpacity(0.2)),
      ),
      child: Column(children: [
        const Text("🧑‍💻", style: TextStyle(fontSize: 32)),
        const SizedBox(height: 6),
        const Text("YOU", style: TextStyle(
            color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity, height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _answerCtrl.text.isEmpty ? 0 : 0.5,
            child: Container(
              decoration: BoxDecoration(
                  color: _cyan, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ),
      ]),
    );
  }

  // ─── Bot Card ────────────────────────────────────────────────────────────
  Widget _buildBotCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _red.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(_botEmoji, style: const TextStyle(fontSize: 32)),
        const SizedBox(height: 6),
        Text(_botName, style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        // Bot thinking progress bar
        Container(
          width: double.infinity, height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(2),
          ),
          child: AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 500),
            alignment: Alignment.centerLeft,
            widthFactor: _botProgress / 100,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF4757), Color(0xFFFF8C42)]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ─── Bot Thinking Bar ────────────────────────────────────────────────────
  Widget _buildBotThinkingBar() {
    if (_botTaunt.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _red.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _red.withOpacity(0.15)),
      ),
      child: Row(children: [
        Text(_botEmoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text(_botTaunt,
            style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13))),
        // Animated dots
        _buildTypingDots(),
      ]),
    );
  }

  Widget _buildTypingDots() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final v = _pulseCtrl.value;
        return Row(children: [0, 1, 2].map((i) {
          final opacity = ((v + i * 0.33) % 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 5, height: 5,
            decoration: BoxDecoration(
              color: _red.withOpacity(0.3 + opacity * 0.5),
              shape: BoxShape.circle,
            ),
          );
        }).toList());
      },
    );
  }

  // ─── Result Phase ────────────────────────────────────────────────────────
  Widget _buildResultPhase() {
    final color = _playerWon ? _green : _red;
    final emoji = _playerWon ? "🏆" : "💀";
    final title = _playerWon ? "YOU WIN!" : "YOU LOSE!";

    return ScaleTransition(
      scale: _resultAnim,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(height: 40),

          // Big result emoji
          Text(emoji, style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 16),

          Text(title, style: TextStyle(
              color: color, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text(_resultMessage, style: TextStyle(
              color: Colors.white.withOpacity(0.6), fontSize: 14),
              textAlign: TextAlign.center),

          const SizedBox(height: 24),

          // Bot reaction
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(children: [
              Text(_botEmoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_botName, style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(_botEndLine, style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 12,
                    fontStyle: FontStyle.italic)),
              ])),
            ]),
          ),

          const SizedBox(height: 24),

          // Correct answer & explanation
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("CORRECT ANSWER", style: TextStyle(
                  color: Colors.white.withOpacity(0.35), fontSize: 10,
                  fontWeight: FontWeight.bold, letterSpacing: 2)),
              const SizedBox(height: 8),
              Text(_correctAnswer, style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(_explanation, style: TextStyle(
                  color: Colors.white.withOpacity(0.5), fontSize: 13, height: 1.5)),
            ]),
          ),

          const SizedBox(height: 24),

          // Rewards
          if (_playerWon) Row(children: [
            Expanded(child: _buildRewardChip("⚡ +$_xpEarned XP", const Color(0xFF7B2FFF))),
            const SizedBox(width: 12),
            Expanded(child: _buildRewardChip("🪙 +$_coinsEarned Coins", const Color(0xFFFFB800))),
          ]) else
            _buildRewardChip("⚡ +$_xpEarned XP (participation)", const Color(0xFF7B2FFF)),

          const SizedBox(height: 28),

          // Buttons
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                // Re-navigate to AI Battle for rematch — handled by parent
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF4757), Color(0xFFFF6B81)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(child: Text("REMATCH 🔁",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
              ),
            )),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: const Text("HOME", style: TextStyle(
                    color: Colors.white60, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ]),

          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  Widget _buildRewardChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Center(child: Text(label, style: TextStyle(
          color: color, fontWeight: FontWeight.bold, fontSize: 14))),
    );
  }

  // ─── Background ──────────────────────────────────────────────────────────
  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.5),
          radius: 1.2,
          colors: [Color(0xFF1A0A3A), Color(0xFF060818)],
        ),
      ),
    );
  }

  Color _diffColor(String d) {
    switch (d) {
      case 'Easy':   return _green;
      case 'Medium': return _gold;
      case 'Hard':   return _red;
      case 'Legend': return const Color(0xFFBF5FFF);
      default:       return Colors.white54;
    }
  }
}