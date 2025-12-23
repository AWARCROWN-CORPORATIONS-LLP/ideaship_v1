// settings.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ideaship/auth/auth_log_reg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../user/userprofile.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'encrypt.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _username = '';
  String _email = '';
  String _appVersion = '';
  bool _notificationsEnabled = true;
  String _selectedLanguage = 'English';
  bool _deletionPending = false;
  int _deletionDaysLeft = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = "v${info.version} (Build ${info.buildNumber})";
      });
    } catch (e) {
      // fallback version if error occurs
      if (!mounted) return;
      setState(() {
        _appVersion = "1.0.0+1";
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
      _deletionPending = prefs.getBool('deletion_pending') ?? false;
      _deletionDaysLeft = prefs.getInt('deletion_days_left') ?? 0;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF007AFF),
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

  void _showSwitchAccountConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.swap_horiz, color: Color.fromARGB(255, 34, 0, 112), size: 28),
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
            style: TextButton.styleFrom(foregroundColor: const Color.fromARGB(255, 0, 0, 0)),
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
            Icon(Icons.logout, color: Color.fromARGB(255, 0, 0, 0), size: 28),
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
            style: TextButton.styleFrom(foregroundColor: const Color.fromARGB(255, 0, 0, 0)),
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
          'Your account will be scheduled for deletion and placed in a 30-day recovery period. '
          'During this time, you can log in anytime to restore your account.\n\n'
          'If you do not log in within 30 days, your account and all associated data will be permanently deleted.',
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
      _showSnackBar("Scheduling account deletion...");

      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString("username") ?? "";

      if (username.isEmpty) {
        _showSnackBar("User not found", isError: true);
        return;
      }

      final response = await http.post(
        Uri.parse("https://server.awarcrown.com/accountclear/delete_account"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username}),
      );

      if (response.statusCode == 200) {
        // IMPORTANT: soft delete, not permanent
        _showSnackBar("Account scheduled for deletion. You can restore it within 30 days.");

        // Clear local session (logout)
        await prefs.clear();

        if (!mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthLogReg()),
          (route) => false,
        );
      } else {
        _showSnackBar(
          "Unable to process deletion request. Please try again.",
          isError: true,
        );
      }
    } catch (e) {
      _showSnackBar("Network error. Please try again. ${e.toString()}", isError: true);
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackBar("Failed to open link.");
    }
  }

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

        await prefs.remove('cached_posts');
        await prefs.remove('cache_timestamp');
        await prefs.remove('like_queue');

        _showSnackBar('Cache cleared successfully');
      } catch (e) {
        _showSnackBar('Error clearing cache: ${e.toString()}', isError: true);
      }
    }
  }

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
      _showSnackBar('Error exporting data: ${e.toString()}', isError: true);
    }
  }

  // ---------------- ABOUT DIALOG -----------------

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// HEADER
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007AFF).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.psychology_alt_rounded,
                        color: Color(0xFF007AFF), size: 34),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Ideaship",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          "Version $_appVersion",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: Colors.grey.shade300, thickness: 1),
              const SizedBox(height: 16),

              /// TAGLINE
              const Text(
                "Developed by Awarcrown Elite Team",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Building the next generation of innovation — "
                "where ideas meet opportunity.",
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 22),

              /// LINKS SECTION
              _buildAboutRow(
                Icons.language_rounded,
                "Website",
                "https://awarcrown.com",
                () => _openLink("https://awarcrown.com"),
              ),

              const SizedBox(height: 12),

              _buildAboutRow(
                Icons.email_outlined,
                "Support Email",
                "support@awarcrown.com",
                () => _openLink("mailto:support@awarcrown.com"),
              ),

              const SizedBox(height: 22),
              Divider(color: Colors.grey.shade300, thickness: 1),
              const SizedBox(height: 12),

              /// COPYRIGHT
              Center(
                child: Text(
                  "© ${DateTime.now().year} Awarcrown Corporations LLP\nAll rights reserved.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              /// CLOSE BUTTON
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF007AFF),
                  ),
                  child: const Text(
                    "Close",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 23),
            children: [
              TextSpan(
                text: 'Built with ',
                style: TextStyle(
                  fontFamily: 'DMSans',
                  color: Colors.grey.shade500,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(
                text: '❤️\n',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(
                text: 'For Startups',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  color: Colors.black,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
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

          if (_deletionPending)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                // ignore: deprecated_member_use
                border: Border.all(color: Colors.orange.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.timer, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Account scheduled for deletion",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Your account will be permanently deleted in "
                          "$_deletionDaysLeft days.\n"
                          "Logging in will instantly restore it.",
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                iconColor: _deletionPending ? Colors.grey : Colors.red,
                title: 'Delete Account',
                subtitle: _deletionPending ? 'Deletion already scheduled' : 'Permanently delete your account',
                isDestructive: true,
                onTap: _deletionPending
                    ? () {
                        _showSnackBar(
                          "Account deletion already scheduled. Login again to restore your account.",
                          isError: true,
                        );
                      }
                    : _showDeleteAccountConfirmation,
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
                subtitle: 'Feedback or support',
                onTap: () async {
                  try {
                    final nEnc = CryptoHelper.encryptText(_username);
                    final eEnc = CryptoHelper.encryptText(_email);
                    final n = Uri.encodeComponent(nEnc);
                    final e = Uri.encodeComponent(eEnc);
                    await _openLink("https://server.awarcrown.com/support/?n=$n&e=$e");
                  } catch (err) {
                    // If encryption fails for any reason, fallback to plain values (encoded).
                    final n = Uri.encodeComponent(_username);
                    final e = Uri.encodeComponent(_email);
                    await _openLink("https://server.awarcrown.com/support/?n=$n&e=$e");
                  }
                },
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
                iconColor: const Color.fromARGB(255, 167, 89, 89),
                title: 'About',
                subtitle: 'Version $_appVersion',
                onTap: _showAbout,
              ),
            ],
          ),

          const SizedBox(height: 5),
          _buildFooter(),
          const SizedBox(height: 10),
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