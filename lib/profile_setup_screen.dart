import 'package:flutter/material.dart';
import 'firestore_service.dart';
import 'dashboard_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController usernameController = TextEditingController();
  final FirestoreService _firestore = FirestoreService();

  String selectedAvatar = "avatar1";
  bool isLoading = false;

  void saveProfile() async {
    if (usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Enter username")),
      );
      return;
    }

    setState(() => isLoading = true);

    // 🔥 Check if username exists
    bool exists = await _firestore.usernameExists(
      usernameController.text.trim(),
    );

    if (exists) {
      setState(() => isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Username already taken")),
      );
      return;
    }

    await _firestore.createUser(
      username: usernameController.text.trim(),
      avatar: selectedAvatar,
    );

    setState(() => isLoading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DashboardScreen()),
    );
  }

  Widget avatarItem(String avatar) {
    return GestureDetector(
      onTap: () {
        setState(() => selectedAvatar = avatar);
      },
      child: Container(
        margin: EdgeInsets.all(8),
        padding: EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(
            color: selectedAvatar == avatar ? Colors.cyan : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(Icons.person, color: Colors.white),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0F0C29),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                Text("👤 Setup Profile",
                    style: TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),

                SizedBox(height: 20),

                TextField(
                  controller: usernameController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Enter Username",
                    hintStyle: TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    avatarItem("avatar1"),
                    avatarItem("avatar2"),
                    avatarItem("avatar3"),
                  ],
                ),

                SizedBox(height: 20),

                ElevatedButton(
                  onPressed: saveProfile,
                  child: isLoading
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Text("Continue 🚀"),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}