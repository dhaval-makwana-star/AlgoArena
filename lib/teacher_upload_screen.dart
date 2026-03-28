import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

// pubspec.yaml dependencies needed:
// file_picker: ^6.1.1
// http: ^1.2.1

class TeacherUploadScreen extends StatefulWidget {
  final String teacherId;
  final Map<String, dynamic>? teacherData;
  const TeacherUploadScreen(
      {super.key, required this.teacherId, this.teacherData});

  @override
  State<TeacherUploadScreen> createState() => _TeacherUploadScreenState();
}

class _TeacherUploadScreenState extends State<TeacherUploadScreen>
    with TickerProviderStateMixin {
  // ── Cloudinary config ───────────────────────────────────────────────────
  static const String _cloudName = 'dsylxcxwv';
  static const String _uploadPreset = 'profile_upload';

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();

  String _selectedCategory = 'Data Structures & Algorithms';
  String _selectedLevel = 'Beginner';
  bool _isFree = true;
  bool _isUploading = false;

  final List<Map<String, dynamic>> _lectures = [];
  final List<Map<String, dynamic>> _notes = [];

  late AnimationController _progressCtrl;

  final _categories = [
    'Data Structures & Algorithms',
    'Web Development',
    'Mobile Development',
    'Machine Learning',
    'System Design',
    'Database Management',
    'DevOps & Cloud',
    'Competitive Programming',
  ];

  final _levels = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _progressCtrl.forward();
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  // ── Cloudinary upload helper ─────────────────────────────────────────────
  Future<String?> _uploadToCloudinary(File file, String resourceType) async {
    try {
      final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload');
      final req = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await req.send();
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final json = jsonDecode(body) as Map<String, dynamic>;
        return json['secure_url'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ── Pick & upload video ──────────────────────────────────────────────────
  Future<void> _addLectureFromDevice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    _showUploadingDialog('Uploading video to Cloudinary…');
    final file = File(result.files.single.path!);
    final url = await _uploadToCloudinary(file, 'video');
    if (mounted) Navigator.pop(context); // close dialog

    if (url != null) {
      _showAddLectureSheet(prefilledUrl: url);
    } else {
      _snack('Upload failed. Try again.', isError: true);
    }
  }

  // ── Pick & upload PDF ────────────────────────────────────────────────────
  Future<void> _addNoteFromDevice() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    _showUploadingDialog('Uploading file to Cloudinary…');
    final file = File(result.files.single.path!);
    final url = await _uploadToCloudinary(file, 'raw');
    if (mounted) Navigator.pop(context);

    if (url != null) {
      _showAddNoteSheet(prefilledUrl: url);
    } else {
      _snack('Upload failed. Try again.', isError: true);
    }
  }

  void _showUploadingDialog(String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0D1B3E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                  color: Color(0xFFFF6B35), strokeWidth: 2.5),
              const SizedBox(height: 18),
              Text(msg,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7), fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Add lecture bottom sheet ─────────────────────────────────────────────
  void _showAddLectureSheet({String prefilledUrl = ''}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B3E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => _AddContentSheet(
        title: 'Add Video Lecture',
        icon: '🎬',
        fields: ['Lecture Title', 'Video URL', 'Duration (e.g. 15 min)'],
        prefilledValues: ['', prefilledUrl, ''],
        onAdd: (vals) {
          if (vals[0].isNotEmpty && vals[1].isNotEmpty) {
            setState(() => _lectures.add({
              'title': vals[0],
              'url': vals[1],
              'duration': vals[2],
            }));
          }
        },
      ),
    );
  }

  // ── Add note bottom sheet ────────────────────────────────────────────────
  void _showAddNoteSheet({String prefilledUrl = ''}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B3E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (_) => _AddContentSheet(
        title: 'Add Study Note',
        icon: '📄',
        fields: ['Note Title', 'File URL', 'Description'],
        prefilledValues: ['', prefilledUrl, ''],
        onAdd: (vals) {
          if (vals[0].isNotEmpty && vals[1].isNotEmpty) {
            setState(() => _notes.add({
              'title': vals[0],
              'url': vals[1],
              'description': vals[2],
            }));
          }
        },
      ),
    );
  }

  // ── Show add options picker ──────────────────────────────────────────────
  void _showLectureOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B3E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Video Lecture',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            const SizedBox(height: 20),
            _optionTile(
              icon: Icons.upload_file_rounded,
              color: const Color(0xFFFF6B35),
              title: 'Upload from device',
              subtitle: 'Upload MP4/MOV to Cloudinary',
              onTap: () {
                Navigator.pop(context);
                _addLectureFromDevice();
              },
            ),
            const SizedBox(height: 12),
            _optionTile(
              icon: Icons.link_rounded,
              color: const Color(0xFF00D4FF),
              title: 'Paste a URL',
              subtitle: 'YouTube, Vimeo or direct link',
              onTap: () {
                Navigator.pop(context);
                _showAddLectureSheet();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNoteOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B3E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Study Notes',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            const SizedBox(height: 20),
            _optionTile(
              icon: Icons.upload_file_rounded,
              color: const Color(0xFF7B2FFF),
              title: 'Upload PDF / Doc',
              subtitle: 'Upload file to Cloudinary',
              onTap: () {
                Navigator.pop(context);
                _addNoteFromDevice();
              },
            ),
            const SizedBox(height: 12),
            _optionTile(
              icon: Icons.link_rounded,
              color: const Color(0xFF00D4FF),
              title: 'Paste a URL',
              subtitle: 'Google Drive, Notion, etc.',
              onTap: () {
                Navigator.pop(context);
                _showAddNoteSheet();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  // ── Publish ──────────────────────────────────────────────────────────────
  Future<void> _publishCourse() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _snack('Please enter a course title.', isError: true);
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      _snack('Please enter a course description.', isError: true);
      return;
    }
    if (_lectures.isEmpty && _notes.isEmpty) {
      _snack('Add at least one lecture or note.', isError: true);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isUploading = true);

    try {
      final courseRef =
      FirebaseFirestore.instance.collection('courses').doc();

      // Map category short-label → emoji + colors
      final meta = _categoryMeta(_selectedCategory);

      await courseRef.set({
        'id': courseRef.id,
        'teacherId': widget.teacherId,
        'teacherName': widget.teacherData?['name'] ?? 'Instructor',
        'teacherExpertise': widget.teacherData?['expertise'] ?? '',
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category': _selectedCategory,
        'level': _selectedLevel,
        'isFree': _isFree,
        'duration': _durationCtrl.text.trim(),
        'lecturesCount': _lectures.length,
        'notesCount': _notes.length,
        'enrolledCount': 0,
        'rating': 0.0,
        'ratingCount': 0,
        'status': 'published',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'tags': [_selectedCategory, _selectedLevel],
        'thumbnailEmoji': meta['emoji'],
        'colors': meta['colors'],
      });

      for (int i = 0; i < _lectures.length; i++) {
        await courseRef.collection('lectures').add({
          'index': i,
          'title': _lectures[i]['title'],
          'url': _lectures[i]['url'],
          'duration': _lectures[i]['duration'],
          'type': 'video',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      for (int i = 0; i < _notes.length; i++) {
        await courseRef.collection('notes').add({
          'index': i,
          'title': _notes[i]['title'],
          'url': _notes[i]['url'],
          'description': _notes[i]['description'],
          'type': 'document',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await FirebaseFirestore.instance
          .collection('teachers')
          .doc(widget.teacherId)
          .update({'coursesCount': FieldValue.increment(1)});

      if (mounted) {
        _snack('Course published successfully! 🎉');
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pop(context);
      }
    } catch (e) {
      _snack('Failed to publish. Try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Map<String, dynamic> _categoryMeta(String category) {
    final map = {
      'Data Structures & Algorithms': {
        'emoji': '🧠',
        'colors': ['#00D4FF', '#7B2FFF']
      },
      'Web Development': {
        'emoji': '🌐',
        'colors': ['#FF6B35', '#FFB347']
      },
      'Mobile Development': {
        'emoji': '📱',
        'colors': ['#00D4FF', '#00C853']
      },
      'Machine Learning': {
        'emoji': '🤖',
        'colors': ['#7B2FFF', '#FF6B35']
      },
      'System Design': {
        'emoji': '🏗️',
        'colors': ['#00C853', '#00D4FF']
      },
      'Database Management': {
        'emoji': '🗄️',
        'colors': ['#FFD700', '#FF6B35']
      },
      'DevOps & Cloud': {
        'emoji': '☁️',
        'colors': ['#00D4FF', '#7B2FFF']
      },
      'Competitive Programming': {
        'emoji': '⚡',
        'colors': ['#FFD700', '#FF6B35']
      },
    };
    return map[category] ??
        {'emoji': '💻', 'colors': ['#00D4FF', '#7B2FFF']};
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor:
        isError ? const Color(0xFFFF4757) : const Color(0xFF00C853),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060818),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    _buildCourseInfoSection(),
                    const SizedBox(height: 24),
                    _buildLecturesSection(),
                    const SizedBox(height: 24),
                    _buildNotesSection(),
                    const SizedBox(height: 32),
                    _buildPublishButton(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text('Create New Course',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
          ),
          // Cloudinary badge
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF3448C5), Color(0xFF00A4B4)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.cloud_upload_rounded,
                    color: Colors.white, size: 13),
                SizedBox(width: 5),
                Text('Cloudinary',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('📋', 'Course Details'),
        const SizedBox(height: 14),
        _field(
            controller: _titleCtrl,
            hint: 'Course Title',
            icon: Icons.title_rounded),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.10)),
          ),
          child: TextField(
            controller: _descCtrl,
            maxLines: 4,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Course description — what will students learn?',
              hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.3), fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _dropdownField(
          icon: Icons.category_rounded,
          value: _selectedCategory,
          items: _categories,
          onChanged: (v) => setState(() => _selectedCategory = v!),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _dropdownField(
                icon: Icons.bar_chart_rounded,
                value: _selectedLevel,
                items: _levels,
                onChanged: (v) => setState(() => _selectedLevel = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _field(
                  controller: _durationCtrl,
                  hint: 'Total Duration',
                  icon: Icons.access_time_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => setState(() => _isFree = !_isFree),
          child: Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border:
              Border.all(color: Colors.white.withOpacity(0.10)),
            ),
            child: Row(
              children: [
                const Icon(Icons.monetization_on_outlined,
                    color: Colors.white38, size: 20),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                      _isFree ? 'Free Course 🎁' : 'Premium Course 💎',
                      style:
                      const TextStyle(color: Colors.white, fontSize: 14),
                    )),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: _isFree
                        ? const LinearGradient(colors: [
                      Color(0xFF00C853),
                      Color(0xFF00D4FF)
                    ])
                        : null,
                    color: _isFree
                        ? null
                        : Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Align(
                    alignment: _isFree
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLecturesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('🎬', 'Video Lectures')),
            GestureDetector(
              onTap: _showLectureOptions,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFFB347)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Add',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_lectures.isEmpty)
          _emptyContent('Upload video files or paste YouTube/Vimeo links')
        else
          ..._lectures.asMap().entries.map((e) => _contentItem(
            emoji: '🎬',
            title: e.value['title'] ?? '',
            subtitle: e.value['duration'] ?? '',
            color: const Color(0xFFFF6B35),
            onDelete: () =>
                setState(() => _lectures.removeAt(e.key)),
          )),
      ],
    );
  }

  Widget _buildNotesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('📄', 'Study Notes')),
            GestureDetector(
              onTap: _showNoteOptions,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF00D4FF), Color(0xFF7B2FFF)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Add',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_notes.isEmpty)
          _emptyContent('Upload PDFs or paste Google Drive / Notion links')
        else
          ..._notes.asMap().entries.map((e) => _contentItem(
            emoji: '📄',
            title: e.value['title'] ?? '',
            subtitle: e.value['description'] ?? '',
            color: const Color(0xFF00D4FF),
            onDelete: () => setState(() => _notes.removeAt(e.key)),
          )),
      ],
    );
  }

  Widget _buildPublishButton() {
    return GestureDetector(
      onTap: _isUploading ? null : _publishCourse,
      child: Container(
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B35), Color(0xFFFFD700)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B35).withOpacity(0.45),
              blurRadius: 24,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Center(
          child: _isUploading
              ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5))
              : const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.rocket_launch_rounded,
                  color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Publish Course',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _sectionTitle(String emoji, String title) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
          TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.white38, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _dropdownField({
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF0D1B3E),
          isExpanded: true,
          icon: const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white38, size: 20),
          ),
          items: items.map((e) {
            return DropdownMenuItem(
              value: e,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(e,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
              ),
            );
          }).toList(),
          onChanged: onChanged,
          padding: const EdgeInsets.only(left: 40, top: 4, bottom: 4),
        ),
      ),
    );
  }

  Widget _emptyContent(String hint) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Text(hint,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white.withOpacity(0.3), fontSize: 13)),
    );
  }

  Widget _contentItem({
    required String emoji,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.white38, size: 18),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ── Add Content Sheet ─────────────────────────────────────────────────────────
class _AddContentSheet extends StatefulWidget {
  final String title;
  final String icon;
  final List<String> fields;
  final List<String> prefilledValues;
  final Function(List<String>) onAdd;

  const _AddContentSheet({
    required this.title,
    required this.icon,
    required this.fields,
    required this.onAdd,
    this.prefilledValues = const [],
  });

  @override
  State<_AddContentSheet> createState() => _AddContentSheetState();
}

class _AddContentSheetState extends State<_AddContentSheet> {
  late List<TextEditingController> _ctrls;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(widget.fields.length, (i) {
      final prefill = i < widget.prefilledValues.length
          ? widget.prefilledValues[i]
          : '';
      return TextEditingController(text: prefill);
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Text(widget.title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18)),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(widget.fields.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border:
                  Border.all(color: Colors.white.withOpacity(0.12)),
                ),
                child: TextField(
                  controller: _ctrls[i],
                  style:
                  const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: widget.fields[i],
                    hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                        child: Text('Cancel',
                            style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600))),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    widget.onAdd(
                        _ctrls.map((c) => c.text.trim()).toList());
                    Navigator.pop(context);
                  },
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B35), Color(0xFFFFB347)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                        child: Text('Add',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700))),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}