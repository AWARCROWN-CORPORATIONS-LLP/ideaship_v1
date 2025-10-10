// settings.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ideaship/auth/auth_log_reg.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required Future<void> Function() onThemeChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Notification toggles
  bool _pushMessages = true;
  bool _pushConnections = true;
  bool _pushStartups = true;
  bool _pushAnnouncements = true;
  bool _emailNotifications = true;

  // App preferences
  bool _darkMode = false;
  bool _followSystemTheme = true;
  bool _largeFont = false;
  bool _lowDataMode = false;

  // Privacy
  bool _enable2FA = false;

  // User data for profile (loaded from prefs)
  String _username = '';
  String _email = '';
  String _bio = '';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _pushMessages = prefs.getBool('pushMessages') ?? true;
        _pushConnections = prefs.getBool('pushConnections') ?? true;
        _pushStartups = prefs.getBool('pushStartups') ?? true;
        _pushAnnouncements = prefs.getBool('pushAnnouncements') ?? true;
        _emailNotifications = prefs.getBool('emailNotifications') ?? true;
        _darkMode = prefs.getBool('darkMode') ?? false;
        _followSystemTheme = prefs.getBool('followSystemTheme') ?? true;
        _largeFont = prefs.getBool('largeFont') ?? false;
        _lowDataMode = prefs.getBool('lowDataMode') ?? false;
        _enable2FA = prefs.getBool('enable2FA') ?? false;
        _username = prefs.getString('username') ?? '';
        _email = prefs.getString('email') ?? '';
        _bio = prefs.getString('bio') ?? '';
      });
    }
  }

  Future<void> _saveBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _saveString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  void _editProfile() {
    final nameController = TextEditingController(text: _username);
    final bioController = TextEditingController(text: _bio);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name/Username'),
            ),
            TextField(
              controller: bioController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            // TODO: Add profile picture picker using image_picker
            const SizedBox(height: 16),
            const Text('Profile Picture: Coming soon'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _saveString('username', nameController.text);
              _saveString('bio', bioController.text);
              setState(() {
                _username = nameController.text;
                _bio = bioController.text;
              });
              Navigator.pop(context);
              _showSnackBar('Profile updated');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _changePassword() {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Old Password'),
            ),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (newController.text == confirmController.text && newController.text.isNotEmpty) {
                // TODO: Call API to change password
                Navigator.pop(context);
                _showSnackBar('Password changed successfully');
              } else {
                _showSnackBar('Passwords do not match');
              }
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }

  void _updateEmail() {
    final emailController = TextEditingController(text: _email);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'New Email'),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Verify email via OTP
              _saveString('email', emailController.text);
              setState(() {
                _email = emailController.text;
              });
              Navigator.pop(context);
              _showSnackBar('Email updated. Please verify.');
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSection() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Push Notifications: Messages'),
          value: _pushMessages,
          onChanged: (val) {
            setState(() => _pushMessages = val);
            _saveBool('pushMessages', val);
          },
        ),
        SwitchListTile(
          title: const Text('Push Notifications: Connection Requests'),
          value: _pushConnections,
          onChanged: (val) {
            setState(() => _pushConnections = val);
            _saveBool('pushConnections', val);
          },
        ),
        SwitchListTile(
          title: const Text('Push Notifications: Startup Updates / New Ideas'),
          value: _pushStartups,
          onChanged: (val) {
            setState(() => _pushStartups = val);
            _saveBool('pushStartups', val);
          },
        ),
        SwitchListTile(
          title: const Text('Push Notifications: App Announcements'),
          value: _pushAnnouncements,
          onChanged: (val) {
            setState(() => _pushAnnouncements = val);
            _saveBool('pushAnnouncements', val);
          },
        ),
        SwitchListTile(
          title: const Text('Email Notifications'),
          value: _emailNotifications,
          onChanged: (val) {
            setState(() => _emailNotifications = val);
            _saveBool('emailNotifications', val);
          },
        ),
      ],
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
              if (val) _darkMode = false; // Reset dark mode if following system
            });
            _saveBool('followSystemTheme', val);
            _saveBool('darkMode', _darkMode);
            // TODO: Notify parent to rebuild theme
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
                    // TODO: Notify parent to rebuild theme
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
        content: const Text('Are you sure you want to logout?'),
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

  void _showDeleteAccountConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Call API to delete account
              _showSnackBar('Account deleted');
              _logout();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthLogReg()),
      );
    }
  }

  void _clearCache() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache'),
        content: const Text('This will free up app storage. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement cache clearing
              _showSnackBar('Cache cleared');
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _downloadData() {
    _showSnackBar('Download data feature coming soon');
  }

  void _toggle2FA() {
    setState(() => _enable2FA = !_enable2FA);
    _saveBool('enable2FA', _enable2FA);
    _showSnackBar(_enable2FA ? '2FA enabled (email-based)' : '2FA disabled');
    // TODO: Implement actual 2FA setup
  }

  void _showFAQ() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('FAQ'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Q: How to post an idea?'),
              Text('A: Tap the + button on home.'),
              SizedBox(height: 8),
              Text('Q: Contact support?'),
              Text('A: Use Contact Us in settings.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _contactUs() {
    // TODO: Open email or chat
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
              Text('This app is developed by Awarcrown Elite Team.'),
              SizedBox(height: 8),
              Text('Company Full Details:'),
              Text('Awarcrown Elite Team is a dynamic group of innovators and developers dedicated to creating cutting-edge applications that empower users worldwide.'),
              Text('Founded in 2023, we specialize in mobile app development, focusing on user-centric designs and robust backend solutions.'),
              Text('Our mission: To connect ideas with opportunities through innovative platforms like Ideaship.'),
              Text('Website: https://awarcrown.com'),
              Text('Email: info@awarcrown.com'),
              Text('Location: Global (Headquarters in [City, Country])'),
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

  void _submitFeedback() {
    final feedbackController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Feedback'),
        content: TextField(
          controller: feedbackController,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Your feedback'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // TODO: Send feedback to backend
              Navigator.pop(context);
              _showSnackBar('Thank you for your feedback!');
            },
            child: const Text('Submit'),
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
          // 1. Account & Profile
          _buildSectionHeader('Account & Profile'),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Profile'),
            onTap: _editProfile,
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change Password'),
            onTap: _changePassword,
          ),
          ListTile(
            leading: const Icon(Icons.email),
            title: const Text('Update Email/Phone'),
            onTap: _updateEmail,
          ),
          const Divider(),

          // 2. Notifications
          _buildSectionHeader('Notifications'),
          _buildNotificationSection(),
          const Divider(),

          // 3. App Preferences
          _buildSectionHeader('App Preferences'),
          _buildThemeSection(),
          SwitchListTile(
            title: const Text('Large Font Size'),
            value: _largeFont,
            onChanged: (val) {
              setState(() => _largeFont = val);
              _saveBool('largeFont', val);
              // TODO: Apply font scale
            },
          ),
          SwitchListTile(
            title: const Text('Low Data Mode (Reduce Images/Videos)'),
            value: _lowDataMode,
            onChanged: (val) {
              setState(() => _lowDataMode = val);
              _saveBool('lowDataMode', val);
            },
          ),
          const Divider(),

          // 4. Privacy & Security
          _buildSectionHeader('Privacy & Security'),
          SwitchListTile(
            title: const Text('Two-Factor Authentication (Email)'),
            value: _enable2FA,
            onChanged: (val) => _toggle2FA(),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: _showLogoutConfirmation,
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete Account'),
            onTap: _showDeleteAccountConfirmation,
          ),
          const Divider(),

          // 5. Data & Storage
          _buildSectionHeader('Data & Storage'),
          ListTile(
            leading: const Icon(Icons.cleaning_services),
            title: const Text('Clear Cache'),
            onTap: _clearCache,
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Download My Data'),
            onTap: _downloadData,
          ),
          const Divider(),

          // 6. Support & Info
          _buildSectionHeader('Support & Info'),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help / FAQ'),
            onTap: _showFAQ,
          ),
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
            leading: const Icon(Icons.info),
            title: const Text('App Version'),
            trailing: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: _showAbout,
          ),
          const Divider(),

          // 7. Optional: Feedback
          ListTile(
            leading: const Icon(Icons.feedback),
            title: const Text('Submit Feedback'),
            onTap: _submitFeedback,
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