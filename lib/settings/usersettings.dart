// settings.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ideaship/auth/auth_log_reg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../user/userprofile.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _username = '';
  String _email = '';
  String _appVersion = '1.0.0';
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    // App version - can be updated manually or via package_info_plus if available
    // For now using default version
    if (mounted) {
      setState(() {
        _appVersion = '1.0.0';
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _username = prefs.getString('username') ?? '';
      _email = prefs.getString('email') ?? '';
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _selectedLanguage = prefs.getString('selected_language') ?? 'English';
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 3 : 2),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const UserProfile()),
    );
  }

  // ---------------- SWITCH ACCOUNT -----------------

  void _showSwitchAccountConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.swap_horiz, color: Color(0xFF007AFF), size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Switch Account')),
          ],
        ),
        content: const Text(
          'You will be logged out and redirected to the login page. You can then sign in with a different account.\n\nYour current session data will be cleared.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _switchAccount();
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF007AFF)),
            child: const Text('Switch Account'),
          ),
        ],
      ),
    );
  }

  Future<void> _switchAccount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;

    _showSnackBar('Switching account...');
    
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AuthLogReg()),
      (route) => false,
    );
  }

  // ---------------- LOGOUT -----------------

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Logout')),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout? This will delete all local app data.',
          style: TextStyle(height: 1.5),
        ),
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
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
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

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AuthLogReg()),
      (route) => false,
    );
  }

  // ---------------- DELETE ACCOUNT -----------------

  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Delete Account')),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete your account?\n\n'
          'This action is permanent and cannot be undone. All your data will be permanently deleted.',
          style: TextStyle(height: 1.5),
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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

  // ---------------- CLEAR CACHE -----------------

  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Cache'),
        content: const Text(
          'This will clear all cached data including images and temporary files. This may improve app performance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        // Clear cache-related keys (keep user data)
        await prefs.remove('cached_posts');
        await prefs.remove('cache_timestamp');
        await prefs.remove('like_queue');
        
        _showSnackBar('Cache cleared successfully');
      } catch (e) {
        _showSnackBar('Error clearing cache: $e', isError: true);
      }
    }
  }

  // ---------------- EXPORT DATA -----------------

  Future<void> _exportData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? 'user';
      final email = prefs.getString('email') ?? '';
      
      final exportData = {
        'username': username,
        'email': email,
        'exported_at': DateTime.now().toIso8601String(),
        'app_version': _appVersion,
      };
      
      final jsonData = jsonEncode(exportData);
      await Clipboard.setData(ClipboardData(text: jsonData));
      
      _showSnackBar('Data copied to clipboard');
    } catch (e) {
      _showSnackBar('Error exporting data: $e', isError: true);
    }
  }

  // ---------------- ABOUT DIALOG -----------------

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('About'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lightbulb_outline, color: Color(0xFF007AFF), size: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ideaship',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text('v$_appVersion', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Developed by Awarcrown Elite Team',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connecting ideas with opportunities.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _buildAboutRow(Icons.language, 'Website', 'https://awarcrown.com', () {
                _openLink('https://awarcrown.com');
              }),
              const SizedBox(height: 8),
              _buildAboutRow(Icons.email, 'Email', 'info@awarcrown.com', () {
                _openLink('mailto:info@awarcrown.com');
              }),
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

  Widget _buildAboutRow(IconData icon, String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // ---------------- UI -----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Color(0xFF1A1A1A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // User Info Card
          _buildUserCard(),
          const SizedBox(height: 8),

          // Account Section
          _buildSectionCard(
            title: 'Account',
            children: [
              _buildSettingTile(
                icon: Icons.person_outline,
                iconColor: const Color(0xFF007AFF),
                title: 'Edit Profile',
                onTap: _navigateToProfile,
              ),
              _buildDivider(),
              _buildSettingTile(
                icon: Icons.swap_horiz,
                iconColor: const Color(0xFF007AFF),
                title: 'Switch Account',
                subtitle: 'Sign in with a different account',
                onTap: _showSwitchAccountConfirmation,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Preferences Section
          _buildSectionCard(
            title: 'Preferences',
            children: [
              SwitchListTile(
                secondary: Icon(Icons.notifications_outlined, color: Colors.grey.shade700),
                title: const Text('Notifications'),
                subtitle: const Text('Enable push notifications'),
                value: _notificationsEnabled,
                onChanged: (value) async {
                  setState(() => _notificationsEnabled = value);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('notifications_enabled', value);
                  _showSnackBar(value ? 'Notifications enabled' : 'Notifications disabled');
                },
              ),
              _buildDivider(),
              ListTile(
                leading: Icon(Icons.language, color: Colors.grey.shade700),
                title: const Text('Language'),
                subtitle: Text(_selectedLanguage),
                trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
                onTap: () => _showLanguageSelector(),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Data & Storage Section
          _buildSectionCard(
            title: 'Data & Storage',
            children: [
              _buildSettingTile(
                icon: Icons.storage_outlined,
                iconColor: Colors.orange,
                title: 'Clear Cache',
                subtitle: 'Free up storage space',
                onTap: _clearCache,
              ),
              _buildDivider(),
              _buildSettingTile(
                icon: Icons.download_outlined,
                iconColor: Colors.green,
                title: 'Export Data',
                subtitle: 'Copy your account data',
                onTap: _exportData,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Privacy & Security Section
          _buildSectionCard(
            title: 'Privacy & Security',
            children: [
              _buildSettingTile(
                icon: Icons.logout,
                iconColor: Colors.orange,
                title: 'Logout',
                onTap: _showLogoutConfirmation,
              ),
              _buildDivider(),
              _buildSettingTile(
                icon: Icons.delete_forever_outlined,
                iconColor: Colors.red,
                title: 'Delete Account',
                subtitle: 'Permanently delete your account',
                onTap: _showDeleteAccountConfirmation,
                isDestructive: true,
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Support Section
          _buildSectionCard(
            title: 'Support & Information',
            children: [
              _buildSettingTile(
                icon: Icons.contact_support_outlined,
                iconColor: const Color(0xFF007AFF),
                title: 'Contact Us',
                subtitle: 'support@ideaship.com',
                onTap: () => _openLink('mailto:support@ideaship.com'),
              ),
              _buildDivider(),
              _buildSettingTile(
                icon: Icons.description_outlined,
                iconColor: Colors.blue,
                title: 'Terms of Service',
                onTap: () => _openLink('https://server.awarcrown.com/terms'),
              ),
              _buildDivider(),
              _buildSettingTile(
                icon: Icons.privacy_tip_outlined,
                iconColor: Colors.purple,
                title: 'Privacy Policy',
                onTap: () => _openLink('https://server.awarcrown.com/privacy'),
              ),
              _buildDivider(),
              _buildSettingTile(
                icon: Icons.info_outline,
                iconColor: Colors.grey,
                title: 'About',
                subtitle: 'Version $_appVersion',
                onTap: _showAbout,
              ),
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF007AFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: Color(0xFF007AFF),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _username.isEmpty ? 'User' : _username,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (_email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : const Color(0xFF1A1A1A),
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          : null,
      trailing: Icon(Icons.chevron_right, color: Colors.grey.shade400),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 60,
      color: Colors.grey.shade200,
    );
  }

  void _showLanguageSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['English']
              .map((lang) => RadioListTile<String>(
                    title: Text(lang),
                    value: lang,
                    groupValue: _selectedLanguage,
                    onChanged: (value) async {
                      if (value != null) {
                        setState(() => _selectedLanguage = value);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('selected_language', value);
                        if (mounted) {
                          Navigator.pop(context);
                          _showSnackBar('Language changed to $value');
                        }
                      }
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }
}
