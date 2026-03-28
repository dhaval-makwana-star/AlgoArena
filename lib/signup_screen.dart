import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'profile_setup_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  _SignupScreenState createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _emailFocused = false;
  bool _passwordFocused = false;
  bool _confirmFocused = false;
  String _passwordStrength = '';

  late AnimationController _bgCtrl;
  late AnimationController _entryCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _entryCtrl.forward();
    _passwordController.addListener(_checkStrength);
  }

  void _checkStrength() {
    final p = _passwordController.text;
    setState(() {
      if (p.isEmpty) _passwordStrength = '';
      else if (p.length < 6) _passwordStrength = 'weak';
      else if (p.length < 10 || !RegExp(r'[0-9]').hasMatch(p)) _passwordStrength = 'fair';
      else if (!RegExp(r'[A-Z]').hasMatch(p) || !RegExp(r'[!@#\$%^&*]').hasMatch(p)) _passwordStrength = 'good';
      else _passwordStrength = 'strong';
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _entryCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showSnack('Please fill in all fields.', isError: true);
      return;
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      _showSnack('Please enter a valid email.', isError: true);
      return;
    }
    if (password != confirm) {
      _showSnack("Passwords don't match.", isError: true);
      return;
    }
    if (password.length < 6) {
      _showSnack('Password must be at least 6 characters.', isError: true);
      return;
    }

    HapticFeedback.lightImpact();
    try {
      setState(() => isLoading = true);
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      // Navigate to profile setup directly after signup
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, __) => const ProfileSetupScreen(),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) _showSnack(_friendlyError(e.code), isError: true);
    } catch (e) {
      if (mounted) _showSnack('Something went wrong. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use': return 'An account already exists with this email.';
      case 'weak-password': return 'Password must be at least 6 characters.';
      case 'invalid-email': return 'Please enter a valid email address.';
      case 'network-request-failed': return 'No internet connection.';
      default: return 'Something went wrong. Please try again.';
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
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
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF060818),
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _SignupBgPainter(_bgCtrl.value),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildBackButton(),
                      const SizedBox(height: 28),
                      _buildBrand(),
                      const SizedBox(height: 36),
                      _buildHeading(),
                      const SizedBox(height: 32),
                      _buildEmailField(),
                      const SizedBox(height: 14),
                      _buildPasswordField(),
                      if (_passwordStrength.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildStrengthIndicator(),
                      ],
                      const SizedBox(height: 14),
                      _buildConfirmField(),
                      const SizedBox(height: 32),
                      _buildSignupButton(),
                      const SizedBox(height: 32),
                      _buildLoginLink(),
                      const SizedBox(height: 32),
                      _buildTerms(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white54, size: 16),
      ),
    );
  }

  Widget _buildBrand() {
    return Row(children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: const Color(0xFF7B2FFF).withOpacity(0.35), blurRadius: 16)],
        ),
        child: const Center(child: Text('⚔️', style: TextStyle(fontSize: 20))),
      ),
      const SizedBox(width: 12),
      const Text('AlgoArena',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          )),
    ]);
  }

  Widget _buildHeading() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Join the battle,', style: TextStyle(color: Colors.white38, fontSize: 15)),
      const SizedBox(height: 4),
      ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFF7B2FFF), Color(0xFF00D4FF)],
        ).createShader(bounds),
        child: const Text('Create your\ncoding identity',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: -0.5,
            )),
      ),
    ]);
  }

  Widget _buildEmailField() {
    return Focus(
      onFocusChange: (v) => setState(() => _emailFocused = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _emailFocused ? const Color(0xFF00D4FF) : Colors.white.withOpacity(0.1),
            width: _emailFocused ? 1.5 : 1,
          ),
          color: Colors.white.withOpacity(0.05),
          boxShadow: _emailFocused
              ? [BoxShadow(color: const Color(0xFF00D4FF).withOpacity(0.12), blurRadius: 20)]
              : null,
        ),
        child: TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          cursorColor: const Color(0xFF00D4FF),
          decoration: InputDecoration(
            hintText: 'Email address',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
            prefixIcon: Icon(Icons.mail_outline_rounded,
                color: _emailFocused ? const Color(0xFF00D4FF) : Colors.white24, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Focus(
      onFocusChange: (v) => setState(() => _passwordFocused = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _passwordFocused ? const Color(0xFF7B2FFF) : Colors.white.withOpacity(0.1),
            width: _passwordFocused ? 1.5 : 1,
          ),
          color: Colors.white.withOpacity(0.05),
          boxShadow: _passwordFocused
              ? [BoxShadow(color: const Color(0xFF7B2FFF).withOpacity(0.12), blurRadius: 20)]
              : null,
        ),
        child: TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          cursorColor: const Color(0xFF7B2FFF),
          decoration: InputDecoration(
            hintText: 'Password',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
            prefixIcon: Icon(Icons.lock_outline_rounded,
                color: _passwordFocused ? const Color(0xFF7B2FFF) : Colors.white24, size: 20),
            suffixIcon: GestureDetector(
              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
              child: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.white24, size: 20,
              ),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildStrengthIndicator() {
    final levels = {'weak': 1, 'fair': 2, 'good': 3, 'strong': 4};
    final colors = {
      'weak': const Color(0xFFFF4757),
      'fair': const Color(0xFFFFB800),
      'good': const Color(0xFF00D4FF),
      'strong': const Color(0xFF00FF87),
    };
    final level = levels[_passwordStrength] ?? 0;
    final color = colors[_passwordStrength] ?? Colors.white24;

    return Row(children: [
      ...List.generate(4, (i) => Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 3,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: i < level ? color : Colors.white.withOpacity(0.1),
          ),
        ),
      )),
      const SizedBox(width: 10),
      Text(
        _passwordStrength[0].toUpperCase() + _passwordStrength.substring(1),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    ]);
  }

  Widget _buildConfirmField() {
    final matches = _confirmPasswordController.text.isNotEmpty &&
        _confirmPasswordController.text == _passwordController.text;
    return Focus(
      onFocusChange: (v) => setState(() => _confirmFocused = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: matches
                ? const Color(0xFF00FF87)
                : _confirmFocused
                ? const Color(0xFF7B2FFF)
                : Colors.white.withOpacity(0.1),
            width: _confirmFocused || matches ? 1.5 : 1,
          ),
          color: Colors.white.withOpacity(0.05),
          boxShadow: matches
              ? [BoxShadow(color: const Color(0xFF00FF87).withOpacity(0.1), blurRadius: 16)]
              : _confirmFocused
              ? [BoxShadow(color: const Color(0xFF7B2FFF).withOpacity(0.12), blurRadius: 20)]
              : null,
        ),
        child: TextField(
          controller: _confirmPasswordController,
          obscureText: _obscureConfirm,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          cursorColor: const Color(0xFF7B2FFF),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => signUp(),
          decoration: InputDecoration(
            hintText: 'Confirm password',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
            prefixIcon: Icon(Icons.lock_outline_rounded,
                color: matches ? const Color(0xFF00FF87) : Colors.white24, size: 20),
            suffixIcon: matches
                ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00FF87), size: 20)
                : GestureDetector(
              onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
              child: Icon(
                _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.white24, size: 20,
              ),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildSignupButton() {
    return GestureDetector(
      onTap: isLoading ? null : signUp,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF7B2FFF), Color(0xFF00D4FF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B2FFF).withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          )
              : const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Start Coding',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.5)),
              SizedBox(width: 8),
              Text('⚡', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const LoginScreen())),
        child: RichText(
          text: TextSpan(
            text: 'Already have an account? ',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
            children: const [
              TextSpan(
                text: 'Sign in',
                style: TextStyle(
                    color: Color(0xFF7B2FFF),
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTerms() {
    return Center(
      child: Text(
        'By creating an account, you agree to our\nTerms of Service & Privacy Policy',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11, height: 1.5),
      ),
    );
  }
}

// ── Background Painter ────────────────────────────────────────────────────────
class _SignupBgPainter extends CustomPainter {
  final double t;
  _SignupBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.4, -0.3),
        radius: 1.4,
        colors: [const Color(0xFF100A2E), const Color(0xFF060818)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final orbPaint = Paint()..style = PaintingStyle.fill;

    // Purple orb top-left
    final cx1 = size.width * 0.15 + sin(t * 2 * pi) * 25;
    final cy1 = size.height * 0.1 + cos(t * 2 * pi) * 15;
    orbPaint.shader = RadialGradient(colors: [
      const Color(0xFF7B2FFF).withOpacity(0.2),
      Colors.transparent,
    ]).createShader(Rect.fromCircle(center: Offset(cx1, cy1), radius: 200));
    canvas.drawCircle(Offset(cx1, cy1), 200, orbPaint);

    // Cyan orb bottom-right
    final cx2 = size.width * 0.88 + cos(t * 2 * pi) * 20;
    final cy2 = size.height * 0.8 + sin(t * 2 * pi) * 25;
    orbPaint.shader = RadialGradient(colors: [
      const Color(0xFF00D4FF).withOpacity(0.12),
      Colors.transparent,
    ]).createShader(Rect.fromCircle(center: Offset(cx2, cy2), radius: 180));
    canvas.drawCircle(Offset(cx2, cy2), 180, orbPaint);

    // Grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.025)
      ..strokeWidth = 0.5;
    const spacing = 44.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Stars
    final pPaint = Paint()..style = PaintingStyle.fill;
    final rand = Random(99);
    for (int i = 0; i < 16; i++) {
      final px = rand.nextDouble() * size.width;
      final py = rand.nextDouble() * size.height;
      final twinkle = 0.2 + 0.8 * sin(t * 2 * pi * (0.3 + rand.nextDouble() * 0.7) + i * 0.8);
      pPaint.color = Colors.white.withOpacity(twinkle * 0.2);
      canvas.drawCircle(Offset(px, py), 1.2, pPaint);
    }
  }

  @override
  bool shouldRepaint(_SignupBgPainter old) => old.t != t;
}