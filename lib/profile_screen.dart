import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'login_screen.dart';

// ── Cloudinary Config ─────────────────────────────────────────────────────────
const String _cloudName = "dsylxcxwv";
const String _uploadPreset = "profile_upload";

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _avatarCtrl;
  late AnimationController _pulseCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _avatarAnim;
  late Animation<double> _pulseAnim;

  bool _loggingOut = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _avatarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _pulseCtrl =
    AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
            CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    _avatarAnim =
        CurvedAnimation(parent: _avatarCtrl, curve: Curves.elasticOut);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _entryCtrl.forward();
    Future.delayed(
        const Duration(milliseconds: 300), () => _avatarCtrl.forward());
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _entryCtrl.dispose();
    _avatarCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Cloudinary Upload ──────────────────────────────────────────────────────
  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);

    try {
      final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', picked.path));

      final response = await request.send();
      final body = await response.stream.bytesToString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      if (response.statusCode == 200 && json['secure_url'] != null) {
        final imageUrl = json['secure_url'] as String;
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .update({'avatarUrl': imageUrl});
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Avatar updated!'),
              backgroundColor: const Color(0xFF00D4FF).withOpacity(0.9),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        throw Exception('Upload failed: ${json['error']?['message']}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: const Color(0xFFFF4757).withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────────
  Future<void> _logout() async {
    HapticFeedback.heavyImpact();
    final confirm = await _showLogoutDialog();
    if (!confirm || !mounted) return;
    setState(() => _loggingOut = true);
    await AuthService().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, a, __) => const LoginScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
          (route) => false,
    );
  }

  Future<bool> _showLogoutDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => _LogoutDialog(),
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF060818),
      body: Stack(
        children: [
          // ── Animated background ──
          AnimatedBuilder(
            animation: _bgCtrl,
            builder: (_, __) => CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _ProfileBgPainter(_bgCtrl.value),
            ),
          ),

          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user!.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child:
                  CircularProgressIndicator(color: Color(0xFF00D4FF)),
                );
              }
              final data =
              snapshot.data!.data() as Map<String, dynamic>;
              final username = data['username'] ?? 'Coder';
              final coins = data['coins'] ?? 0;
              final xp = data['xp'] ?? 0;
              final streak = data['streak'] ?? 0;
              final totalWins = data['totalWins'] ?? 0;
              final totalGames = data['totalGamesPlayed'] ?? 0;
              // avatarUrl from Cloudinary; fallback emoji
              final avatarUrl = data['avatarUrl'] as String?;
              final avatarEmoji = data['avatar'] ?? '🧑‍💻';
              final winRate = totalGames > 0
                  ? ((totalWins / totalGames) * 100).toStringAsFixed(1)
                  : '0.0';
              final level = (xp / 500).floor() + 1;
              final xpInLevel = xp % 500;
              final xpProgress = xpInLevel / 500;

              return FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // ── App Bar ──
                      SliverAppBar(
                        expandedHeight: 0,
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        pinned: true,
                        leading: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            margin: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.1)),
                            ),
                            child: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white54,
                                size: 16),
                          ),
                        ),
                        actions: [
                          GestureDetector(
                            onTap: () =>
                                _showEditDialog(username, context),
                            child: Container(
                              margin: const EdgeInsets.all(10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00D4FF)
                                    .withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFF00D4FF)
                                        .withOpacity(0.3)),
                              ),
                              child: const Row(children: [
                                Icon(Icons.edit_outlined,
                                    color: Color(0xFF00D4FF), size: 15),
                                SizedBox(width: 5),
                                Text('Edit',
                                    style: TextStyle(
                                        color: Color(0xFF00D4FF),
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)),
                              ]),
                            ),
                          ),
                        ],
                      ),

                      SliverToBoxAdapter(
                        child: Padding(
                          padding:
                          const EdgeInsets.fromLTRB(20, 8, 20, 40),
                          child: Column(
                            children: [
                              // ── Avatar & Identity ──
                              _buildIdentityCard(
                                  avatarUrl,
                                  avatarEmoji,
                                  username,
                                  user.email ?? '',
                                  level,
                                  xpProgress,
                                  xpInLevel,
                                  xp),
                              const SizedBox(height: 24),

                              // ── Quick Stats Row ──
                              _buildQuickStats(
                                  coins, streak, totalWins, winRate),
                              const SizedBox(height: 24),

                              // ── XP Progress ──
                              _buildXpCard(
                                  xp, level, xpProgress, xpInLevel),
                              const SizedBox(height: 20),

                              // ── Detailed Stats ──
                              _buildStatsGrid(totalGames, totalWins,
                                  winRate, streak),
                              const SizedBox(height: 20),

                              // ── Achievements ──
                              _buildAchievements(streak, xp, totalWins),
                              const SizedBox(height: 20),

                              // ── Account Section ──
                              _buildAccountSection(
                                  user.email ?? '', context),
                              const SizedBox(height: 20),

                              // ── Logout Button ──
                              _buildLogoutButton(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Identity Card ──────────────────────────────────────────────────────────
  Widget _buildIdentityCard(
      String? avatarUrl,
      String avatarEmoji,
      String username,
      String email,
      int level,
      double xpProgress,
      int xpInLevel,
      int xp,
      ) {
    return ScaleTransition(
      scale: _avatarAnim,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0D1B3E).withOpacity(0.9),
              const Color(0xFF1A0A3E).withOpacity(0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border:
          Border.all(color: const Color(0xFF00D4FF).withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00D4FF).withOpacity(0.08),
              blurRadius: 30,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(children: [
          // Avatar with pulse ring + tap to change
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) => Transform.scale(
              scale: _pulseAnim.value,
              child: child,
            ),
            child: GestureDetector(
              onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)]),
                      boxShadow: [
                        BoxShadow(
                            color:
                            const Color(0xFF00D4FF).withOpacity(0.4),
                            blurRadius: 24,
                            spreadRadius: 2)
                      ],
                    ),
                  ),
                  // Inner dark ring
                  Container(
                    width: 102,
                    height: 102,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF060818),
                    ),
                  ),
                  // Avatar image or emoji
                  ClipOval(
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: _uploadingAvatar
                          ? const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF00D4FF), strokeWidth: 2),
                      )
                          : (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        loadingBuilder:
                            (_, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          }
                          return const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF00D4FF),
                                strokeWidth: 2),
                          );
                        },
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(avatarEmoji,
                              style: const TextStyle(
                                  fontSize: 44)),
                        ),
                      )
                          : Center(
                        child: Text(avatarEmoji,
                            style:
                            const TextStyle(fontSize: 44)),
                      ),
                    ),
                  ),
                  // Camera icon overlay (bottom right)
                  if (!_uploadingAvatar)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D4FF),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF060818), width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 13),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),
          // Hint text
          Text(
            'Tap to change photo',
            style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 10,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),

          // Username
          Text(username,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3)),
          const SizedBox(height: 4),
          // FIX: email overflow — use ellipsis
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
            TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
          ),
          const SizedBox(height: 14),

          // Level badge
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('⚡', style: TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Text('LEVEL $level',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1)),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Quick Stats Row ────────────────────────────────────────────────────────
  Widget _buildQuickStats(
      int coins, int streak, int wins, String winRate) {
    final items = [
      {
        'label': 'Coins',
        'value': '$coins',
        'icon': '🪙',
        'color': const Color(0xFFFFB800)
      },
      {
        'label': 'Streak',
        'value': '$streak',
        'icon': '🔥',
        'color': const Color(0xFFFF6348)
      },
      {
        'label': 'Wins',
        'value': '$wins',
        'icon': '🏆',
        'color': const Color(0xFF00FF87)
      },
      {
        'label': 'Win %',
        'value': winRate,
        'icon': '📊',
        'color': const Color(0xFF00D4FF)
      },
    ];

    return Row(
      children: items.map((item) {
        final color = item['color'] as Color;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Column(children: [
              Text(item['icon'] as String,
                  style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 6),
              Text(item['value'] as String,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
              const SizedBox(height: 2),
              Text(item['label'] as String,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        );
      }).toList(),
    );
  }

  // ── XP Progress Card ───────────────────────────────────────────────────────
  Widget _buildXpCard(
      int xp, int level, double progress, int xpInLevel) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('⚡', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          const Text('XP PROGRESS',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 1.5)),
          const Spacer(),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$xp total XP',
                style: const TextStyle(
                    color: Color(0xFF00D4FF),
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Level $level',
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            Text('$xpInLevel / 500 XP',
                style:
                const TextStyle(color: Colors.white38, fontSize: 11)),
            Text('Level ${level + 1}',
                style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(children: [
            Container(
              height: 10,
              width: double.infinity,
              color: Colors.white.withOpacity(0.07),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              height: 10,
              width: (MediaQuery.of(context).size.width - 80) * progress,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)]),
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF00D4FF).withOpacity(0.5),
                      blurRadius: 8)
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Stats Grid ─────────────────────────────────────────────────────────────
  Widget _buildStatsGrid(
      int games, int wins, String winRate, int streak) {
    final stats = [
      {
        'title': 'Games Played',
        'value': '$games',
        'icon': Icons.gamepad_outlined,
        'color': const Color(0xFF7B2FFF),
      },
      {
        'title': 'Total Wins',
        'value': '$wins',
        'icon': Icons.emoji_events_outlined,
        'color': const Color(0xFFFFB800),
      },
      {
        'title': 'Win Rate',
        'value': '$winRate%',
        'icon': Icons.bar_chart_rounded,
        'color': const Color(0xFF00D4FF),
      },
      {
        'title': 'Best Streak',
        'value': '$streak 🔥',
        'icon': Icons.local_fire_department_outlined,
        'color': const Color(0xFFFF6348),
      },
    ];

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('BATTLE STATS'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 2.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: stats.map((s) {
              final color = s['color'] as Color;
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.18)),
                ),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(s['icon'] as IconData,
                        color: color, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s['value'] as String,
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w900,
                                fontSize: 17)),
                        Text(s['title'] as String,
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                      ]),
                ]),
              );
            }).toList(),
          ),
        ]);
  }

  // ── Achievements ───────────────────────────────────────────────────────────
  Widget _buildAchievements(int streak, int xp, int wins) {
    final badges = [
      {
        'icon': '🔥',
        'label': 'On Fire',
        'desc': '3+ day streak',
        'earned': streak >= 3,
        'color': const Color(0xFFFF6348),
      },
      {
        'icon': '⚡',
        'label': 'XP Grinder',
        'desc': '500+ XP',
        'earned': xp >= 500,
        'color': const Color(0xFF00D4FF),
      },
      {
        'icon': '🏆',
        'label': 'Victor',
        'desc': '5+ wins',
        'earned': wins >= 5,
        'color': const Color(0xFFFFB800),
      },
      {
        'icon': '💎',
        'label': 'Legend',
        'desc': '1000+ XP',
        'earned': xp >= 1000,
        'color': const Color(0xFF7B2FFF),
      },
      {
        'icon': '🚀',
        'label': 'Rocket',
        'desc': '10+ wins',
        'earned': wins >= 10,
        'color': const Color(0xFF00FF87),
      },
      {
        'icon': '👑',
        'label': 'King',
        'desc': '7+ streak',
        'earned': streak >= 7,
        'color': const Color(0xFFFFD700),
      },
    ];

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('ACHIEVEMENTS'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.88,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: badges.map((b) {
              final earned = b['earned'] as bool;
              final color = b['color'] as Color;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                decoration: BoxDecoration(
                  color: earned
                      ? color.withOpacity(0.1)
                      : Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: earned
                        ? color.withOpacity(0.3)
                        : Colors.white.withOpacity(0.06),
                    width: earned ? 1.5 : 1,
                  ),
                  boxShadow: earned
                      ? [
                    BoxShadow(
                        color: color.withOpacity(0.15),
                        blurRadius: 12)
                  ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      b['icon'] as String,
                      style: TextStyle(
                          fontSize: 28,
                          color: earned
                              ? null
                              : Colors.white.withOpacity(0.15)),
                    ),
                    const SizedBox(height: 6),
                    Text(b['label'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: earned ? Colors.white : Colors.white24,
                            fontWeight: FontWeight.bold,
                            fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(b['desc'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: earned
                                ? color.withOpacity(0.8)
                                : Colors.white12,
                            fontSize: 9)),
                    if (earned) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('EARNED',
                            style: TextStyle(
                                color: color,
                                fontSize: 7,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5)),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      const Icon(Icons.lock_outline,
                          color: Colors.white12, size: 12),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ]);
  }

  // ── Account Section ────────────────────────────────────────────────────────
  Widget _buildAccountSection(String email, BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('ACCOUNT'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(18),
              border:
              Border.all(color: Colors.white.withOpacity(0.06)),
            ),
            child: Column(children: [
              // FIX: email passed directly — overflow handled inside tile
              _accountTile(Icons.email_outlined, 'Email', email,
                  const Color(0xFF00D4FF)),
              _divider(),
              _accountTile(Icons.shield_outlined, 'Account Type',
                  'Player', const Color(0xFF7B2FFF)),
              _divider(),
              _accountTile(Icons.notifications_outlined, 'Notifications',
                  'Enabled', const Color(0xFFFFB800)),
              _divider(),
              _accountTile(Icons.privacy_tip_outlined, 'Privacy Policy',
                  'View →', Colors.white38),
            ]),
          ),
        ]);
  }

  Widget _accountTile(
      IconData icon, String title, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 14),
        // FIX: use Flexible so title doesn't overflow
        Flexible(
          child: Text(title,
              style:
              const TextStyle(color: Colors.white70, fontSize: 14)),
        ),
        const SizedBox(width: 8),
        // FIX: value also flexible with ellipsis
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 13,
                fontWeight: FontWeight.w500),
          ),
        ),
      ]),
    );
  }

  Widget _divider() => Divider(
      height: 1,
      color: Colors.white.withOpacity(0.05),
      indent: 18,
      endIndent: 18);

  // ── Logout Button ──────────────────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: _loggingOut ? null : _logout,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFFF4757).withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border:
          Border.all(color: const Color(0xFFFF4757).withOpacity(0.3)),
        ),
        child: Center(
          child: _loggingOut
              ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  color: Color(0xFFFF4757), strokeWidth: 2.5))
              : const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded,
                  color: Color(0xFFFF4757), size: 18),
              SizedBox(width: 10),
              Text('Sign Out',
                  style: TextStyle(
                      color: Color(0xFFFF4757),
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Edit Dialog ─────────────────────────────────────────────────────────────
  void _showEditDialog(String current, BuildContext context) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0D1B3E),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Edit Username',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            const SizedBox(height: 20),
            TextField(
              controller: ctrl,
              style: const TextStyle(color: Colors.white),
              cursorColor: const Color(0xFF00D4FF),
              decoration: InputDecoration(
                hintText: 'New username',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.white.withOpacity(0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: Color(0xFF00D4FF), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('Cancel',
                          style: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final newName = ctrl.text.trim();
                    if (newName.isEmpty) return;
                    final uid =
                        FirebaseAuth.instance.currentUser?.uid;
                    if (uid != null) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(uid)
                          .update({'username': newName});
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('Save',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label,
        style: TextStyle(
            color: Colors.white.withOpacity(0.35),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.5));
  }
}

// ── Logout Confirm Dialog ─────────────────────────────────────────────────────
class _LogoutDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF0D1B3E),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
              color: const Color(0xFFFF4757).withOpacity(0.3))),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFFFF4757).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.logout_rounded,
                color: Color(0xFFFF4757), size: 28),
          ),
          const SizedBox(height: 16),
          const Text('Sign Out?',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20)),
          const SizedBox(height: 8),
          Text('Are you sure you want to leave the arena?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 14,
                  height: 1.4)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, false),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Center(
                    child: Text('Stay',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context, true),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4757).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFFF4757).withOpacity(0.4)),
                  ),
                  child: const Center(
                    child: Text('Sign Out',
                        style: TextStyle(
                            color: Color(0xFFFF4757),
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ),
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Animated Background ───────────────────────────────────────────────────────
class _ProfileBgPainter extends CustomPainter {
  final double t;
  _ProfileBgPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.5),
        radius: 1.3,
        colors: [const Color(0xFF0D1B3E), const Color(0xFF060818)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    final orb = Paint()..style = PaintingStyle.fill;

    final cx1 = size.width * 0.82 + sin(t * 2 * pi) * 28;
    final cy1 = size.height * 0.08 + cos(t * 2 * pi) * 18;
    orb.shader = RadialGradient(colors: [
      const Color(0xFF00D4FF).withOpacity(0.14),
      Colors.transparent,
    ]).createShader(
        Rect.fromCircle(center: Offset(cx1, cy1), radius: 160));
    canvas.drawCircle(Offset(cx1, cy1), 160, orb);

    final cx2 = size.width * 0.18 + cos(t * 2 * pi) * 22;
    final cy2 = size.height * 0.85 + sin(t * 2 * pi) * 26;
    orb.shader = RadialGradient(colors: [
      const Color(0xFF7B2FFF).withOpacity(0.12),
      Colors.transparent,
    ]).createShader(
        Rect.fromCircle(center: Offset(cx2, cy2), radius: 180));
    canvas.drawCircle(Offset(cx2, cy2), 180, orb);

    final grid = Paint()
      ..color = Colors.white.withOpacity(0.022)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final star = Paint()..style = PaintingStyle.fill;
    final rand = Random(77);
    for (int i = 0; i < 20; i++) {
      final px = rand.nextDouble() * size.width;
      final py = rand.nextDouble() * size.height;
      final tw = 0.2 +
          0.8 *
              sin(t * 2 * pi * (0.3 + rand.nextDouble() * 0.7) + i);
      star.color = Colors.white.withOpacity(tw * 0.22);
      canvas.drawCircle(Offset(px, py), 1.2, star);
    }
  }

  @override
  bool shouldRepaint(_ProfileBgPainter old) => old.t != t;
}