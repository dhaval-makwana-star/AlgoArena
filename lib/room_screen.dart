import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'socket_service.dart';

class RoomScreen extends StatefulWidget {
  final String roomId;
  final SocketService socketService;

  const RoomScreen({
    super.key,
    required this.roomId,
    required this.socketService,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> with TickerProviderStateMixin {
  // ─── State ────────────────────────────────────────────────────────────────
  String _phase = 'waiting'; // waiting | countdown | battle | finished
  int _playerCount = 0;
  List<Map<String, dynamic>> _players = [];
  int _countdown = 3;
  String _question = '';
  String _hint = '';
  String _complexity = '';
  int _timeLeft = 60;
  String _resultMessage = '';
  bool _iWon = false;
  int _coinsEarned = 0;
  bool _wrongAnswer = false;
  String _wrongMsg = '';

  final TextEditingController _answerCtrl = TextEditingController();

  // ─── Animations ──────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _countdownCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _shakeAnim;
  late Animation<double> _countdownScale;
  late AnimationController _timerCtrl;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _joinRoom();
    _listenSockets();
  }

  void _initAnimations() {
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnim = Tween<double>(begin: 0, end: 12).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));

    _countdownCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _countdownScale = Tween<double>(begin: 1.5, end: 1.0).animate(
        CurvedAnimation(parent: _countdownCtrl, curve: Curves.elasticOut));

    _timerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }

  void _joinRoom() {
    widget.socketService.joinRoom(widget.roomId);
  }

  void _listenSockets() {
    final s = widget.socketService.socket;

    s.on('joinedRoom', (data) {
      if (!mounted) return;
      setState(() {
        _playerCount = data['playerCount'] ?? 0;
        _phase = 'waiting';
      });
    });

    s.on('playerCountUpdate', (data) {
      if (!mounted) return;
      setState(() {
        _playerCount = data['count'] ?? 0;
        _players = List<Map<String, dynamic>>.from(
            (data['players'] as List? ?? []).map((p) => Map<String, dynamic>.from(p)));
      });
    });

    s.on('countdown', (data) {
      if (!mounted) return;
      setState(() {
        _phase = 'countdown';
        _countdown = data['count'] ?? 3;
      });
      _countdownCtrl.forward(from: 0);
    });

    s.on('gameStarted', (data) {
      if (!mounted) return;
      setState(() {
        _phase = 'battle';
        _question = data['question'] ?? '';
        _hint = data['hint'] ?? '';
        _complexity = data['complexity'] ?? '';
        _timeLeft = data['timeLimit'] ?? 60;
      });
      _startTimer();
    });

    s.on('wrongAnswer', (data) {
      if (!mounted) return;
      setState(() {
        _wrongAnswer = true;
        _wrongMsg = data['message'] ?? '❌ Wrong! Try again.';
      });
      _shakeCtrl.forward(from: 0);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _wrongAnswer = false);
      });
      _answerCtrl.clear();
    });

    s.on('gameFinished', (data) {
      if (!mounted) return;
      _timerCtrl.stop();
      final myUid = FirebaseAuth.instance.currentUser?.uid;
      final winnerId = data['winnerId'];
      final coins = (data['coins'] ?? 0) as int;
      final xp = (data['xp'] ?? 0) as int;

      // ✅ FIX: Only the player whose UID matches winnerId is the winner.
      // The loser sees "Better Luck Next Time" and gets NO rewards.
      final iWon = winnerId != null && winnerId == myUid;

      setState(() {
        _phase = 'finished';
        _iWon = iWon;
        _resultMessage = data['message'] ?? 'Game Over';
        _coinsEarned = iWon ? coins : 0;
      });

      // ✅ FIX: Only award to the actual winner — not to everyone
      if (iWon && coins > 0) {
        _awardWinner(coins: coins, xp: xp > 0 ? xp : coins);
      }
    });

    s.on('roomBusy', (data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message'] ?? 'Room is busy'),
          backgroundColor: const Color(0xFFFF4757),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    });
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || _phase != 'battle') return false;
      setState(() {
        _timeLeft = (_timeLeft - 1).clamp(0, 999);
      });
      return _timeLeft > 0 && _phase == 'battle';
    });
  }

  // ✅ FIX: Renamed to _awardWinner and only called when _iWon is true.
  Future<void> _awardWinner({required int coins, required int xp}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'coins': FieldValue.increment(coins),
      'xp': FieldValue.increment(xp),
      'totalWins': FieldValue.increment(1),
      'totalGamesPlayed': FieldValue.increment(1),
    });
  }

  void _submitAnswer() {
    final answer = _answerCtrl.text.trim();
    if (answer.isEmpty) return;
    widget.socketService.submitAnswer(widget.roomId, answer);
  }

  @override
  void dispose() {
    final s = widget.socketService.socket;
    s.off('joinedRoom');
    s.off('playerCountUpdate');
    s.off('countdown');
    s.off('gameStarted');
    s.off('wrongAnswer');
    s.off('gameFinished');
    s.off('roomBusy');
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    _countdownCtrl.dispose();
    _timerCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ FIX: resizeToAvoidBottomInset prevents overflow when keyboard opens
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF060818),
      body: Stack(
        children: [
          _buildBg(),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBg() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.3),
          radius: 1.2,
          colors: [Color(0xFF0D1B3E), Color(0xFF060818)],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.roomId,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
                Text('1v1 Battle Arena',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
              ],
            ),
          ),
          if (_phase == 'battle') _buildTimerBadge(),
        ],
      ),
    );
  }

  Widget _buildTimerBadge() {
    final isUrgent = _timeLeft <= 10;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isUrgent ? const Color(0xFFFF4757).withOpacity(0.2) : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUrgent ? const Color(0xFFFF4757) : Colors.white.withOpacity(0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: isUrgent ? const Color(0xFFFF4757) : const Color(0xFF00D4FF), size: 16),
          const SizedBox(width: 6),
          Text('$_timeLeft s',
              style: TextStyle(
                  color: isUrgent ? const Color(0xFFFF4757) : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case 'waiting':
        return _buildWaiting();
      case 'countdown':
        return _buildCountdown();
      case 'battle':
        return _buildBattle();
      case 'finished':
        return _buildFinished();
      default:
        return _buildWaiting();
    }
  }

  // ─── Waiting ──────────────────────────────────────────────────────────────
  Widget _buildWaiting() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
                  ),
                  boxShadow: [BoxShadow(
                    color: const Color(0xFF00D4FF).withOpacity(0.4),
                    blurRadius: 30, spreadRadius: 5,
                  )],
                ),
                child: const Center(child: Text('⚔️', style: TextStyle(fontSize: 56))),
              ),
            ),
            const SizedBox(height: 32),
            Text(widget.roomId,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildPlayerSlots(),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _playerCount >= 2 ? 'Both players ready!' : 'Waiting for opponent...',
                    style: const TextStyle(color: Color(0xFF00D4FF), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Players: $_playerCount / 2',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 40),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                  Text('💡 Share this room name with a friend',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D4FF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(widget.roomId,
                        style: const TextStyle(
                            color: Color(0xFF00D4FF),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: 1)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerSlots() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _playerSlot(_players.isNotEmpty ? _players[0]['username'] : null, true),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('VS',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3)),
          ),
          _playerSlot(_players.length > 1 ? _players[1]['username'] : null, false),
        ],
      ),
    );
  }

  Widget _playerSlot(String? name, bool isLeft) {
    final filled = name != null;
    return Column(
      children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: filled
                ? LinearGradient(colors: isLeft
                ? [const Color(0xFF00D4FF), const Color(0xFF7B2FFF)]
                : [const Color(0xFFFF4757), const Color(0xFFFF6B81)])
                : null,
            color: filled ? null : Colors.white.withOpacity(0.06),
            border: Border.all(
              color: filled ? Colors.transparent : Colors.white.withOpacity(0.15),
              width: 2,
            ),
          ),
          child: Center(
            child: filled
                ? Text(name![0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))
                : Icon(Icons.person_outline, color: Colors.white.withOpacity(0.3), size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          name ?? 'Waiting...',
          style: TextStyle(
              color: filled ? Colors.white : Colors.white.withOpacity(0.3),
              fontSize: 12,
              fontWeight: filled ? FontWeight.bold : FontWeight.normal),
        ),
      ],
    );
  }

  // ─── Countdown ────────────────────────────────────────────────────────────
  Widget _buildCountdown() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Battle starts in', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16)),
          const SizedBox(height: 24),
          ScaleTransition(
            scale: _countdownScale,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB800), Color(0xFFFF6348)],
                ),
                boxShadow: [BoxShadow(
                  color: const Color(0xFFFFB800).withOpacity(0.5),
                  blurRadius: 40, spreadRadius: 10,
                )],
              ),
              child: Center(
                child: Text('$_countdown',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 72, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text('Get ready!',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _vsChip(_players.isNotEmpty ? _players[0]['username'] ?? 'P1' : 'P1'),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('⚡ VS ⚡',
                    style: TextStyle(color: Color(0xFFFFB800), fontWeight: FontWeight.bold, fontSize: 18)),
              ),
              _vsChip(_players.length > 1 ? _players[1]['username'] ?? 'P2' : 'P2'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vsChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  // ─── Battle ───────────────────────────────────────────────────────────────
  Widget _buildBattle() {
    // ✅ FIX: Wrap in SingleChildScrollView so keyboard doesn't overflow content
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        // Extra bottom padding so submit button stays above keyboard
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        children: [
          _buildTimerBar(),
          const SizedBox(height: 20),
          _buildComplexityBadge(),
          const SizedBox(height: 16),
          _buildQuestionCard(),
          const SizedBox(height: 16),
          if (_hint.isNotEmpty) _buildHintCard(),
          const SizedBox(height: 20),
          _buildAnswerInput(),
          const SizedBox(height: 12),
          if (_wrongAnswer) _buildWrongBanner(),
          const SizedBox(height: 16),
          _buildSubmitBtn(),
        ],
      ),
    );
  }

  Widget _buildTimerBar() {
    final pct = _timeLeft / 60.0;
    final color = _timeLeft > 20
        ? const Color(0xFF00D4FF)
        : _timeLeft > 10
        ? const Color(0xFFFFB800)
        : const Color(0xFFFF4757);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: pct.clamp(0.0, 1.0),
        backgroundColor: Colors.white.withOpacity(0.08),
        valueColor: AlwaysStoppedAnimation<Color>(color),
        minHeight: 8,
      ),
    );
  }

  Widget _buildComplexityBadge() {
    final colors = {
      'Easy': const Color(0xFF00FF87),
      'Medium': const Color(0xFFFFB800),
      'Hard': const Color(0xFFFF4757),
    };
    final c = colors[_complexity] ?? const Color(0xFF00D4FF);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: c.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.withOpacity(0.4)),
          ),
          child: Text(_complexity,
              style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
        const Spacer(),
        Text('⚡ First to answer wins!',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
      ],
    );
  }

  Widget _buildQuestionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D4FF).withOpacity(0.08),
            const Color(0xFF7B2FFF).withOpacity(0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00D4FF).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D4FF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('QUESTION',
                    style: TextStyle(color: Color(0xFF00D4FF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(_question,
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildHintCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB800).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_hint,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerInput() {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_wrongAnswer ? _shakeAnim.value * (DateTime.now().millisecond % 2 == 0 ? 1 : -1) : 0, 0),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _wrongAnswer
                ? const Color(0xFFFF4757).withOpacity(0.6)
                : Colors.white.withOpacity(0.12),
            width: _wrongAnswer ? 2 : 1,
          ),
        ),
        child: TextField(
          controller: _answerCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitAnswer(),
          decoration: InputDecoration(
            hintText: 'Type your answer here...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(18),
            suffixIcon: IconButton(
              icon: Icon(Icons.send_rounded, color: const Color(0xFF00D4FF).withOpacity(0.7)),
              onPressed: _submitAnswer,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWrongBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4757).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF4757).withOpacity(0.4)),
      ),
      child: Text(_wrongMsg,
          style: const TextStyle(color: Color(0xFFFF4757), fontWeight: FontWeight.w600),
          textAlign: TextAlign.center),
    );
  }

  Widget _buildSubmitBtn() {
    return GestureDetector(
      onTap: _submitAnswer,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: const Color(0xFF00D4FF).withOpacity(0.3),
            blurRadius: 20, offset: const Offset(0, 8),
          )],
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('SUBMIT ANSWER',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold,
                      fontSize: 15, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Finished ─────────────────────────────────────────────────────────────
  Widget _buildFinished() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_iWon ? '🏆' : '😔', style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 24),
            Text(
              _iWon ? 'YOU WIN!' : 'BETTER LUCK\nNEXT TIME',
              style: TextStyle(
                color: _iWon ? const Color(0xFFFFB800) : Colors.white,
                fontSize: 32, fontWeight: FontWeight.w900, height: 1.2,
                letterSpacing: 1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Text(_resultMessage,
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 15, height: 1.5),
                  textAlign: TextAlign.center),
            ),
            // ✅ FIX: Only show coin reward banner if this player actually won
            if (_iWon && _coinsEarned > 0) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFFB800), Color(0xFFFF6348)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Text('+$_coinsEarned coins  +${_coinsEarned} XP earned!',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: const Center(
                        child: Text('← Back', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _phase = 'waiting';
                        _playerCount = 0;
                        _players = [];
                        _question = '';
                        _hint = '';
                        _complexity = '';
                        _timeLeft = 60;
                        _resultMessage = '';
                        _iWon = false;
                        _coinsEarned = 0;
                        _answerCtrl.clear();
                      });
                      _joinRoom();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text('⚔️ Rematch', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}