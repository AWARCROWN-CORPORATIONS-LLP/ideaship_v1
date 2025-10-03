// dashboard.dart (simple placeholder)
// Displays user details from SharedPrefs, including role.

import 'package:flutter/material.dart';
import 'package:ideaship/auth/auth_log_reg.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? _username;
  String? _email;
  String? _role;
  String? _major; // Example for student

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username');
      _email = prefs.getString('email');
      _role = prefs.getString('role');
      _major = prefs.getString('major'); // Role-specific
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthLogReg()),
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome, $_username!'),
            Text('Email: $_email'),
            Text('Role: $_role'),
            if (_major != null) Text('Major: $_major'),
            ElevatedButton(
              onPressed: () {
                // Navigate to role-specific dashboard or features
              },
              child: const Text('Go to Features'),
            ),
          ],
        ),
      ),
    );
  }
}