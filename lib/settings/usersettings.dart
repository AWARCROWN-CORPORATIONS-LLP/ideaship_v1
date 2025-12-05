// settings.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ideaship/auth/auth_log_reg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../user/userprofile.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SettingsPage extends StatefulWidget {
  final Future<void> Function() onThemeChanged;

  const SettingsPage({
    super.key,
    required this.onThemeChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  bool _followSystemTheme = true;
  String _username = '';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
      _followSystemTheme = prefs.getBool('followSystemTheme') ?? true;
      _username = prefs.getString('username') ?? '';
      _email = prefs.getString('email') ?? '';
    });
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    await widget.onThemeChanged(); // refresh theme
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserProfile()),
    );
  }

  // ---------------- THEME SECTION -----------------

  Widget _buildThemeSection() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Follow System Theme'),
          value: _followSystemTheme,
          onChanged: (val) async {
            setState(() {
              _followSystemTheme = val;
              if (val) _darkMode = false;
            });

            await _saveBool('followSystemTheme', val);
            await _saveBool('darkMode', _darkMode);
          },
        ),
        Opacity(
          opacity: _followSystemTheme ? 0.4 : 1.0,
          child: SwitchListTile(
            title: const Text('Dark Mode'),
            value: _darkMode,
            onChanged: _followSystemTheme
                ? null
                : (val) async {
                    setState(() => _darkMode = val);
                    await _saveBool('darkMode', val);
                  },
          ),
        ),
      ],
    );
  }

  // ---------------- LOGOUT -----------------

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
            'Are you sure you want to logout? This will delete all local app data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    _showSnackBar('Logged out successfully.');

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const AuthLogReg()),
    );
  }

  // ---------------- DELETE ACCOUNT -----------------

  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account?\n\n'
          'This action is permanent and cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAccount();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    try {
      _showSnackBar("Processing account deletion...");

      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString("username") ?? "";

      
      final response = await http.post(
        Uri.parse("https://server.awarcrown.com/api/delete_account"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username}),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showSnackBar("Account deleted successfully.");
      } else {
        _showSnackBar("Account deleted locally (server offline).");
      }

      await prefs.clear();

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthLogReg()),
      );
    } catch (e) {
      _showSnackBar("Error deleting account: $e");
    }
  }

  // ---------------- LINKS -----------------

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackBar("Failed to open link.");
    }
  }

  // ---------------- ABOUT DIALOG -----------------

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ideaship v1.0.0'),
              SizedBox(height: 8),
              Text('Developed by Awarcrown Elite Team'),
              SizedBox(height: 8),
              Text('Connecting ideas with opportunities.'),
              SizedBox(height: 8),
              Text('Website: https://awarcrown.com'),
              Text('Email: info@awarcrown.com'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---------------- UI -----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: ListView(
        children: [
          // Account
          _buildSectionHeader('Account & Profile'),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _navigateToProfile,
          ),
          const Divider(),

          // Theme
          _buildSectionHeader('App Preferences'),
          _buildThemeSection(),
          const Divider(),

          // Security
          _buildSectionHeader('Privacy & Security'),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: _showLogoutConfirmation,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
            onTap: _showDeleteAccountConfirmation,
          ),
          const Divider(),

          // Support
          _buildSectionHeader('Support & Info'),
          ListTile(
            leading: const Icon(Icons.contact_support),
            title: const Text('Contact Us'),
            onTap: () => _showSnackBar('Contact: support@ideaship.com'),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Service'),
            onTap: () => _openLink('https://server.awarcrown.com/terms'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            onTap: () => _openLink('https://server.awarcrown.com/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: _showAbout,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
