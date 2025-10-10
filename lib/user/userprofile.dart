import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  String? _username;
  String? _email;
  String? _role;
  String? _major;
  bool _isDarkMode = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isDarkMode = prefs.getBool('isDarkMode') ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _username = prefs.getString('username') ?? '';
          _email = prefs.getString('email') ?? '';
          _role = prefs.getString('role') ?? '';
          _major = prefs.getString('major');
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  ColorScheme _buildColorScheme() {
    final primaryColor = const Color(0xFF1268D1);
    if (_isDarkMode) {
      return ColorScheme.dark(
        primary: primaryColor,
        onPrimary: Colors.white,
        surface: const Color(0xFF121212),
        onSurface: Colors.white,
        surfaceContainerHighest: const Color(0xFF1E1E1E),
        onSurfaceVariant: Colors.grey[400]!,
        outline: Colors.grey[700]!,
        error: Colors.red,
        onError: Colors.white,
        secondary: Colors.grey[600]!,
        onSecondary: Colors.white,
      );
    } else {
      return ColorScheme.light(
        primary: primaryColor,
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: Colors.black87,
        surfaceContainerHighest: Colors.grey[100]!,
        onSurfaceVariant: Colors.black54,
        outline: Colors.grey[400]!,
        error: Colors.red,
        onError: Colors.white,
        secondary: Colors.grey[600]!,
        onSecondary: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = _buildColorScheme();

    final themeData = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
    );

    return Theme(
      data: themeData,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0.4,
          backgroundColor: colorScheme.surface,
          title: Text(
            'Profile',
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Profile picture placeholder
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: colorScheme.primary,
                      child: Text(
                        _username?.isNotEmpty == true
                            ? _username!.substring(0, 1).toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _username ?? 'User',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _email ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      color: colorScheme.surfaceContainerHighest,
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Role',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _role ?? 'Not specified',
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_major != null && _major!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Card(
                        color: colorScheme.surfaceContainerHighest,
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Major',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _major!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    // TODO: Add more profile sections like bio, posts, etc.
                  ],
                ),
              ),
      ),
    );
  }
}