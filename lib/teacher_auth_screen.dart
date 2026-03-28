import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'teacher_dashboard_screen.dart';

class TeacherAuthScreen extends StatefulWidget {
  const TeacherAuthScreen({super.key});

  @override
  State<TeacherAuthScreen> createState() => _TeacherAuthScreenState();
}

class _TeacherAuthScreenState extends State<TeacherAuthScreen> with TickerProviderStateMixin {
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _expertiseCtrl = TextEditingController();

  late AnimationController _bgCtrl;
  late AnimationController _switchCtrl;
  late Animation<double> _switchFade;
  late Animation<double> _orbAnim;

  final List<String> _expertiseOptions = [
    'Data Structures & Algorithms',
    'Web Development',
    'Mobile Development',
    'Machine Learning',
    'System Design',
    'Database Management',
    'DevOps & Cloud',
    'Competitive Programming',
  ];
  String? _selectedExpertise;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat(reverse: true);
    _switchCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _switchFade = CurvedAnimation(parent: _switchCtrl, curve: Curves.easeOut);
    _orbAnim = CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut);
    _switchCtrl.forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _switchCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _nameCtrl.dispose();
    _expertiseCtrl.dispose();
    super.dispose();
  }

  void _toggleMode() {
    HapticFeedback.selectionClick();
    _switchCtrl.reverse().then((_) {
      setState(() => _isLogin = !_isLogin);
      _switchCtrl.forward();
    });
  }

  void _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _snack('Please fill in all required fields.', isError: true);
      return;
    }

    if (!_isLogin) {
      if (_nameCtrl.text.trim().isEmpty) {
        _snack('Please enter your full name.', isError: true);
        return;
      }
      if (_selectedExpertise == null) {
        _snack('Please select your area of expertise.', isError: true);
        return;
      }
      if (password != _confirmCtrl.text.trim()) {
        _snack('Passwords do not match.', isError: true);
        return;
      }
      if (password.length < 6) {
        _snack('Password must be at least 6 characters.', isError: true);
        return;
      }
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        // Verify teacher role
        final doc = await FirebaseFirestore.instance
            .collection('teachers')
            .doc(cred.user!.uid)
            .get();
        if (!doc.exists) {
          await FirebaseAuth.instance.signOut();
          _snack('No teacher account found. Please sign up.', isError: true);
          return;
        }
        if (mounted) _goToDashboard(cred.user!);
      } else {
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        // Save to teachers collection
        await FirebaseFirestore.instance.collection('teachers').doc(cred.user!.uid).set({
          'uid': cred.user!.uid,
          'name': _nameCtrl.text.trim(),
          'email': email,
          'expertise': _selectedExpertise,
          'bio': '',
          'avatarUrl': '',
          'coursesCount': 0,
          'studentsCount': 0,
          'rating': 0.0,
          'isVerified': false,
          'joinedAt': FieldValue.serverTimestamp(),
          'role': 'teacher',
        });
        if (mounted) _goToDashboard(cred.user!);
      }
    } on FirebaseAuthException catch (e) {
      _snack(_friendlyError(e.code), isError: true);
    } catch (e) {
      _snack('Something went wrong. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToDashboard(User user) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => TeacherDashboardScreen(user: user),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ]),
        backgroundColor: isError ? const Color(0xFFFF4757) : const Color(0xFF00C853),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

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
              painter: _TeacherBgPainter(_bgCtrl.value),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: FadeTransition(
                    opacity: _switchFade,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          _buildHeader(),
                          const SizedBox(height: 28),
                          _buildToggle(),
                          const SizedBox(height: 28),
                          if (!_isLogin) ...[
                            _buildField(
                              controller: _nameCtrl,
                              hint: 'Full Name',
                              icon: Icons.person_outline_rounded,
                            ),
                            const SizedBox(height: 14),
                            _buildExpertiseDropdown(),
                            const SizedBox(height: 14),
                          ],
                          _buildField(
                            controller: _emailCtrl,
                            hint: 'Email address',
                            icon: Icons.email_outlined,
                            type: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 14),
                          _buildPasswordField(
                            controller: _passwordCtrl,
                            hint: 'Password',
                            obscure: _obscurePassword,
                            onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          if (!_isLogin) ...[
                            const SizedBox(height: 14),
                            _buildPasswordField(
                              controller: _confirmCtrl,
                              hint: 'Confirm Password',
                              obscure: _obscureConfirm,
                              onToggle: () =>
                                  setState(() => _obscureConfirm = !_obscureConfirm),
                            ),
                          ],
                          const SizedBox(height: 32),
                          _buildSubmitButton(),
                          if (!_isLogin) ...[
                            const SizedBox(height: 20),
                            _buildTeacherPerks(),
                          ],
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFFFFB347)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.school_rounded, color: Colors.white, size: 14),
                SizedBox(width: 6),
                Text('Teacher Portal',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFFFB347)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.4), blurRadius: 20)
            ],
          ),
          child: const Center(child: Text('🎓', style: TextStyle(fontSize: 28))),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFFD700)],
          ).createShader(b),
          child: Text(
            _isLogin ? 'Welcome back,\nInstructor!' : 'Join as an\nInstructor',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isLogin
              ? 'Sign in to manage your courses and students'
              : 'Share your knowledge, inspire thousands',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildToggle() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          _toggleTab('Sign In', _isLogin, () => !_isLogin ? _toggleMode() : null),
          _toggleTab('Sign Up', !_isLogin, () => _isLogin ? _toggleMode() : null),
        ],
      ),
    );
  }

  Widget _toggleTab(String label, bool active, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
              colors: [Color(0xFFFF6B35), Color(0xFFFFB347)],
            )
                : null,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [BoxShadow(color: const Color(0xFFFF6B35).withOpacity(0.3), blurRadius: 10)]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : Colors.white38,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType type = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: type,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 15),
          prefixIcon: Icon(icon, color: Colors.white38, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 15),
          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white38, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.white38,
              size: 20,
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  Widget _buildExpertiseDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedExpertise,
          hint: Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text('Area of Expertise',
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 15)),
          ),
          dropdownColor: const Color(0xFF0D1B3E),
          isExpanded: true,
          icon: const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white38),
          ),
          items: _expertiseOptions.map((e) {
            return DropdownMenuItem(
              value: e,
              child: Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(e,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis),
              ),
            );
          }).toList(),
          onChanged: (val) => setState(() => _selectedExpertise = val),
          padding: const EdgeInsets.symmetric(vertical: 2),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _submit,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFFB347)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isLogin ? Icons.login_rounded : Icons.rocket_launch_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                _isLogin ? 'Enter Dashboard' : 'Start Teaching',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherPerks() {
    final perks = [
      ('🎯', 'Reach thousands of students'),
      ('📊', 'Track student progress & analytics'),
      ('💰', 'Build your educator reputation'),
      ('🏆', 'Get verified teacher badge'),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B35).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Why teach on AlgoArena?',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 12),
          ...perks.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Text(p.$1, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 10),
                Text(p.$2,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.6), fontSize: 13)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _TeacherBgPainter extends CustomPainter {
  final double t;
  _TeacherBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.3, -0.4),
        radius: 1.4,
        colors: [const Color(0xFF1A0D00), const Color(0xFF060818)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final orbPaint = Paint()..style = PaintingStyle.fill;
    final cx1 = size.width * 0.8 + sin(t * 2 * pi) * 25;
    final cy1 = size.height * 0.15 + cos(t * 2 * pi) * 15;
    orbPaint.shader = RadialGradient(colors: [
      const Color(0xFFFF6B35).withOpacity(0.20),
      Colors.transparent,
    ]).createShader(Rect.fromCircle(center: Offset(cx1, cy1), radius: 160));
    canvas.drawCircle(Offset(cx1, cy1), 160, orbPaint);

    final cx2 = size.width * 0.15 + cos(t * 2 * pi + 2) * 20;
    final cy2 = size.height * 0.7 + sin(t * 2 * pi + 2) * 25;
    orbPaint.shader = RadialGradient(colors: [
      const Color(0xFFFFB347).withOpacity(0.12),
      Colors.transparent,
    ]).createShader(Rect.fromCircle(center: Offset(cx2, cy2), radius: 180));
    canvas.drawCircle(Offset(cx2, cy2), 180, orbPaint);

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.02)
      ..strokeWidth = 0.5;
    const spacing = 44.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_TeacherBgPainter old) => old.t != t;
}