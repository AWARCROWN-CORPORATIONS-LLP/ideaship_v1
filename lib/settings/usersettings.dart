// settings.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ideaship/auth/auth_log_reg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../user/userprofile.dart'; // Add this import

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required Future<void> Function() onThemeChanged});

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
    if (mounted) {
      setState(() {
        _darkMode = prefs.getBool('darkMode') ?? false;
        _followSystemTheme = prefs.getBool('followSystemTheme') ?? true;
        _username = prefs.getString('username') ?? '';
        _email = prefs.getString('email') ?? '';
      });
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserProfile()),
    );
  }

  Widget _buildThemeSection() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Follow System Theme'),
          value: _followSystemTheme,
          onChanged: (val) {
            setState(() {
              _followSystemTheme = val;
              if (val) _darkMode = false;
            });
            _saveBool('followSystemTheme', val);
            _saveBool('darkMode', _darkMode);
          },
        ),
        Opacity(
          opacity: _followSystemTheme ? 0.5 : 1.0,
          child: SwitchListTile(
            title: const Text('Dark Mode'),
            value: _darkMode,
            onChanged: _followSystemTheme
                ? null
                : (val) {
                    setState(() => _darkMode = val);
                    _saveBool('darkMode', val);
                  },
          ),
        ),
      ],
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout? This will delete all app data.'),
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
    await prefs.clear(); // This deletes all saved data in SharedPreferences (user prefs, theme settings, etc.)
    // If your app uses other storage (e.g., SQLite, Hive, files), add clearing logic here.
    // For example:
    // await DatabaseHelper().deleteDatabase(); // Hypothetical DB clear
    // await FileStorage.clearAll(); // Hypothetical file clear

    if (mounted) {
      _showSnackBar('Logged out successfully. All data has been cleared.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthLogReg()),
      );
    }
  }

  void _contactUs() {
    _showSnackBar('Contact: support@ideaship.com');
  }

  Future<void> _openTerms() async {
    final uri = Uri.parse('https://server.awarcrown.com/terms');
    try {
      await launchUrl(uri);
    } catch (e) {
      _showSnackBar('Could not open Terms of Service: $e');
    }
  }

  Future<void> _openPrivacy() async {
    final uri = Uri.parse('https://server.awarcrown.com/privacy');
    try {
      await launchUrl(uri);
    } catch (e) {
      _showSnackBar('Could not open Privacy Policy: $e');
    }
  }

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
              Text('Connect ideas with opportunities through innovative platforms.'),
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
         
          _buildSectionHeader('Account & Profile'),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _navigateToProfile,
          ),
          const Divider(),

          
          _buildSectionHeader('App Preferences'),
          _buildThemeSection(),
          const Divider(),

          
          _buildSectionHeader('Privacy & Security'),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: _showLogoutConfirmation,
          ),
          const Divider(),

          
          _buildSectionHeader('Support & Info'),
          ListTile(
            leading: const Icon(Icons.contact_support),
            title: const Text('Contact Us'),
            onTap: _contactUs,
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Service'),
            onTap: _openTerms,
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Privacy Policy'),
            onTap: _openPrivacy,
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
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}