import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'auth_service.dart';
import 'signup_screen.dart';
import 'dashboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'profile_setup_screen.dart';
import 'teacher_auth_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService _auth = AuthService();

  bool isLoading = false;
  bool isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _emailFocused = false;
  bool _passwordFocused = false;

  late AnimationController _bgCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _teacherBadgeCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _teacherPulse;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _teacherBadgeCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _teacherPulse = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _teacherBadgeCtrl, curve: Curves.easeInOut));
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _entryCtrl.dispose();
    _teacherBadgeCtrl.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showSnack('Please fill in all fields.', isError: true);
      return;
    }
    HapticFeedback.lightImpact();
    try {
      setState(() => isLoading = true);
      final user = await _auth.login(email, password);
      if (user != null && mounted) await _handleNavigation(user);
    } catch (e) {
      if (mounted) _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void googleLogin() async {
    HapticFeedback.lightImpact();
    try {
      setState(() => isGoogleLoading = true);
      final user = await _auth.signInWithGoogle();
      if (user != null && mounted) await _handleNavigation(user);
    } catch (e) {
      if (mounted) _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => isGoogleLoading = false);
    }
  }

  Future<void> _handleNavigation(User user) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => doc.exists ? const DashboardScreen() : const ProfileSetupScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
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
              painter: _AuthBgPainter(_bgCtrl.value),
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
                      const SizedBox(height: 40),
                      _buildBrand(),
                      const SizedBox(height: 20),
                      _buildTeacherPortalBadge(),
                      const SizedBox(height: 24),
                      _buildHeading(),
                      const SizedBox(height: 32),
                      _buildEmailField(),
                      const SizedBox(height: 14),
                      _buildPasswordField(),
                      const SizedBox(height: 10),
                      _buildForgotPassword(),
                      const SizedBox(height: 28),
                      _buildLoginButton(),
                      const SizedBox(height: 24),
                      _buildDivider(),
                      const SizedBox(height: 24),
                      _buildGoogleButton(),
                      const SizedBox(height: 32),
                      _buildSignupLink(),
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
          boxShadow: [BoxShadow(color: const Color(0xFF00D4FF).withOpacity(0.35), blurRadius: 16)],
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

  Widget _buildTeacherPortalBadge() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, a, __) => const TeacherAuthScreen(),
            transitionsBuilder: (_, a, __, child) => SlideTransition(
              position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                  .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      },
      child: AnimatedBuilder(
        animation: _teacherPulse,
        builder: (_, __) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF6B35).withOpacity(0.15 + _teacherPulse.value * 0.05),
                  const Color(0xFFFFB347).withOpacity(0.10 + _teacherPulse.value * 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFFF6B35).withOpacity(0.4 + _teacherPulse.value * 0.2),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFFB347)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B35).withOpacity(0.4),
                        blurRadius: 8,
                      )
                    ],
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Are you a Teacher?',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Upload courses & teach the community',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFFB347)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Enter →',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeading() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Welcome back,', style: TextStyle(color: Colors.white38, fontSize: 15)),
      const SizedBox(height: 4),
      ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Color(0xFF00D4FF), Color(0xFFB060FF)],
        ).createShader(bounds),
        child: const Text('Sign in to\nyour arena',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -0.5,
            )),
      ),
    ]);
  }

  Widget _buildEmailField() {
    return Focus(
      onFocusChange: (f) => setState(() => _emailFocused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(_emailFocused ? 0.09 : 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _emailFocused
                ? const Color(0xFF00D4FF).withOpacity(0.6)
                : Colors.white.withOpacity(0.10),
            width: 1.2,
          ),
          boxShadow: _emailFocused
              ? [BoxShadow(color: const Color(0xFF00D4FF).withOpacity(0.08), blurRadius: 12)]
              : [],
        ),
        child: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Email address',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 15),
            prefixIcon: Icon(Icons.email_outlined,
                color: _emailFocused ? const Color(0xFF00D4FF) : Colors.white38, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Focus(
      onFocusChange: (f) => setState(() => _passwordFocused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(_passwordFocused ? 0.09 : 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _passwordFocused
                ? const Color(0xFF00D4FF).withOpacity(0.6)
                : Colors.white.withOpacity(0.10),
            width: 1.2,
          ),
          boxShadow: _passwordFocused
              ? [BoxShadow(color: const Color(0xFF00D4FF).withOpacity(0.08), blurRadius: 12)]
              : [],
        ),
        child: TextField(
          controller: passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Password',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 15),
            prefixIcon: Icon(Icons.lock_outline_rounded,
                color: _passwordFocused ? const Color(0xFF00D4FF) : Colors.white38, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: Colors.white38,
                size: 20,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
        child: const Text('Forgot password?',
            style: TextStyle(color: Color(0xFF00D4FF), fontSize: 13, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: isLoading ? null : login,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00D4FF).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
          )
              : const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Sign In',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.5)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(children: [
      Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.08))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('or continue with',
            style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
      ),
      Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.08))),
    ]);
  }

  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: isGoogleLoading ? null : googleLogin,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Center(
          child: isGoogleLoading
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2.5),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GoogleIcon(),
              const SizedBox(width: 12),
              const Text('Continue with Google',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignupLink() {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SignupScreen())),
        child: RichText(
          text: TextSpan(
            text: "Don't have an account? ",
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
            children: const [
              TextSpan(
                text: 'Create one',
                style: TextStyle(
                    color: Color(0xFF00D4FF), fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final bgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, r, bgPaint);
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'G',
        style: TextStyle(color: Color(0xFF4285F4), fontSize: 13, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _AuthBgPainter extends CustomPainter {
  final double t;
  _AuthBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.5),
        radius: 1.3,
        colors: [const Color(0xFF0D1B3E), const Color(0xFF060818)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final orbPaint = Paint()..style = PaintingStyle.fill;
    final cx1 = size.width * 0.85 + sin(t * 2 * pi) * 30;
    final cy1 = size.height * 0.12 + cos(t * 2 * pi) * 20;
    orbPaint.shader = RadialGradient(colors: [
      const Color(0xFF00D4FF).withOpacity(0.18),
      Colors.transparent,
    ]).createShader(Rect.fromCircle(center: Offset(cx1, cy1), radius: 180));
    canvas.drawCircle(Offset(cx1, cy1), 180, orbPaint);

    final cx2 = size.width * 0.1 + cos(t * 2 * pi + 1) * 25;
    final cy2 = size.height * 0.75 + sin(t * 2 * pi + 1) * 30;
    orbPaint.shader = RadialGradient(colors: [
      const Color(0xFF7B2FFF).withOpacity(0.15),
      Colors.transparent,
    ]).createShader(Rect.fromCircle(center: Offset(cx2, cy2), radius: 200));
    canvas.drawCircle(Offset(cx2, cy2), 200, orbPaint);

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

    final pPaint = Paint()..style = PaintingStyle.fill;
    final rand = Random(42);
    for (int i = 0; i < 18; i++) {
      final px = rand.nextDouble() * size.width;
      final py = rand.nextDouble() * size.height;
      final twinkle = 0.2 + 0.8 * sin(t * 2 * pi * (0.4 + rand.nextDouble() * 0.6) + i);
      pPaint.color = Colors.white.withOpacity(twinkle * 0.25);
      canvas.drawCircle(Offset(px, py), 1.2, pPaint);
    }
  }

  @override
  bool shouldRepaint(_AuthBgPainter old) => old.t != t;
}