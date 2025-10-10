// dashboard.dart
// ignore: unused_import
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ideaship/feed/createpost.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: unused_import
import 'package:ideaship/auth/auth_log_reg.dart';
import 'feed/posts.dart'; // Import the PostsPage from feed/posts.dart
// Import CreatePostPage
import 'settings/usersettings.dart'; // Import UserSettingsPage
import 'jobs/job_drawer.dart'; // Import the updated JobDrawer
// TODO: Import other pages as needed, e.g.,
// import 'feed/startups.dart';
// import 'feed/investors.dart';
// import 'feed/mentors.dart';
// import 'feed/companies.dart';
// import 'chat/message.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  late TabController _tabController;

  String? _username;
  String? _email;
  String? _role;
  String? _major;
  bool _isLoading = true;

  bool _isNotificationActive = false;
  bool _isMessageActive = false;

  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Updated to 5 tabs
    _loadUserData();
    _loadThemePreference();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Future<void> _toggleTheme() async {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
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
      if (mounted) {
        _showErrorBanner('Failed to load user data: ${e.toString()}');
      }
    }
  }

  void _showErrorBanner(String message) {
    if (!mounted) return;
    final colorScheme = _buildColorScheme();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.onError, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: colorScheme.onError,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: colorScheme.error,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 80,
          left: 20,
          right: 20,
        ),
        elevation: 8,
      ),
    );
  }

  // Call this method from other pages (e.g., PostsPage) to show backend errors
  // You can pass the DashboardPage's state or use a callback/GlobalKey to access this
  void showBackendError(String errorMessage) {
    _showErrorBanner(errorMessage);
  }

  void _openJobDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _showMessageDialog() {
    // TODO: Navigate to chat/message.dart instead of dialog
    // Navigator.push(context, MaterialPageRoute(builder: (context) => MessagePage()));
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final colorScheme = _buildColorScheme();
        return AlertDialog(
          title: Text('Messages Coming Soon!', style: TextStyle(color: colorScheme.onSurface)),
          content: Text(
            'We are building a larger community globally to connect. This is within weeks we will make this feature available.',
            style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Got it!', style: TextStyle(color: colorScheme.onSurface)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _isMessageActive = false;
        });
      }
    });
  }

  void _handleNotificationPress() {
    if (_isNotificationActive) return;
    setState(() {
      _isNotificationActive = true;
    });
    _showErrorBanner('Notifications coming soon!');
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isNotificationActive = false;
        });
      }
    });
  }

  void _handleMessagePress() {
    if (_isMessageActive) return;
    setState(() {
      _isMessageActive = true;
    });
    _showMessageDialog();
  }

  ColorScheme _buildColorScheme() {
    final primaryColor = const Color(0xFF1268D1);
    if (_isDarkMode) {
      return ColorScheme.dark(
        primary: primaryColor,
        onPrimary: Colors.white,
        surface: const Color(0xFF121212),
        onSurface: Colors.white,
        background: const Color(0xFF121212),
        onBackground: Colors.white,
        surfaceVariant: const Color(0xFF1E1E1E),
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
        background: Colors.white,
        onBackground: Colors.black87,
        surfaceVariant: Colors.grey[100]!,
        onSurfaceVariant: Colors.black54,
        outline: Colors.grey[400]!,
        error: Colors.red,
        onError: Colors.white,
        secondary: Colors.grey[600]!,
        onSecondary: Colors.white,
      );
    }
  }

  AppBar _buildAppBar(ColorScheme colorScheme) {
    List<Widget> actions = [
      IconButton(
        onPressed: _isNotificationActive ? null : _handleNotificationPress,
        icon: Icon(
          Icons.notifications_outlined,
          color: _isNotificationActive ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
        ),
      ),
      IconButton(
        onPressed: _isMessageActive ? null : _handleMessagePress,
        icon: Icon(
          Icons.chat_bubble_outline,
          color: _isMessageActive ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
        ),
      ),
      IconButton(
        onPressed: _toggleTheme,
        icon: Icon(
          _isDarkMode ? Icons.light_mode : Icons.dark_mode,
          color: colorScheme.onSurface,
        ),
      ),
    ];

    if (_selectedIndex == 0) {
      return AppBar(
        elevation: 0.4,
        backgroundColor: colorScheme.surface,
        title: Text("Ideaship",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
                fontSize: 25)),
        actions: actions,
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(text: "Feed"),
            Tab(text: "Startups"),
          
          ],
        ),
      );
    } else {
      String title;
      switch (_selectedIndex) {
        case 1:
          title = 'Roles';
          break;
        case 3:
          title = 'Alerts';
          break;
        case 4:
          title = 'Settings';
          break;
        default:
          title = 'Ideaship';
      }
      return AppBar(
        title: Text(title, style: TextStyle(color: colorScheme.onSurface)),
        backgroundColor: colorScheme.surface,
        elevation: 0.4,
        actions: actions,
      );
    }
  }

  Widget _buildBody(ColorScheme colorScheme) {
    switch (_selectedIndex) {
      case 0:
        return Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: const [
                PostsPage(), // Dynamic feed from feed/posts.dart
                 Center(child: Text("Startups Page")), // TODO: Replace with StartupsPage() from feed/startups.dart
                // Center(child: Text("Investors Page")), // TODO: Replace with InvestorsPage() from feed/investors.dart
                // Center(child: Text("Mentors Page")), // TODO: Replace with MentorsPage() from feed/mentors.dart
                // Center(child: Text("Companies Page")), // TODO: Replace with CompaniesPage() from feed/companies.dart
              ],
            ),
            // Right-side handle
            Positioned(
              right: 6,
              top: MediaQuery.of(context).size.height * 0.25,
              child: GestureDetector(
                onTap: _openJobDrawer,
                child: Container(
                  width: 36,
                  height: 72,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.outline.withOpacity(0.26),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Center(
                      child: RotatedBox(
                          quarterTurns: 1,
                          child: Icon(Icons.arrow_forward_ios, size: 18, color: colorScheme.onSurface))),
                ),
              ),
            ),
          ],
        );
      case 1:
        return Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Welcome, $_username!', style: TextStyle(color: colorScheme.onSurface)),
                    Text('Email: $_email', style: TextStyle(color: colorScheme.onSurface)),
                    Text('Role: $_role', style: TextStyle(color: colorScheme.onSurface)),
                    if (_major != null) Text('Major: $_major', style: TextStyle(color: colorScheme.onSurface)),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to role-specific dashboard or features
                      },
                      child: const Text('Go to Features'),
                    ),
                  ],
                ),
        );
      case 3:
        return Center(child: Text('Alerts Page', style: TextStyle(color: colorScheme.onSurface)));
      case 4:
        return const SizedBox();
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = _buildColorScheme();

    final themeData = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
    );

    return Theme(
      data: themeData,
      child: Builder(
        builder: (context) {
          return Scaffold(
            key: _scaffoldKey,
            endDrawer: const JobDrawer(),
            endDrawerEnableOpenDragGesture: true,
            appBar: _buildAppBar(colorScheme),
            body: _buildBody(colorScheme),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                // Open post creation page createpost.dart
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreatePostPage()),
                );
              },
              backgroundColor: themeData.colorScheme.primary,
              child: const Icon(Icons.add, size: 28, color: Colors.white),
            ),
            bottomNavigationBar: BottomAppBar(
              color: themeData.colorScheme.surface,
              elevation: 8,
              shape: const CircularNotchedRectangle(),
              notchMargin: 6,
              child: SizedBox(
                height: 70,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _navButton(Icons.home_rounded, "Home", 0, colorScheme),
                    _navButton(Icons.work_outline, "Roles", 1, colorScheme),
                    const SizedBox(width: 60), // Space for the notch/FAB
                    _navButton(Icons.notifications_outlined, "Alerts", 3, colorScheme),
                    _navButton(Icons.settings_outlined, "Settings", 4, colorScheme),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _navButton(IconData icon, String label, int index, ColorScheme colorScheme) {
    bool active = _selectedIndex == index;
    return MaterialButton(
      minWidth: 70,
      onPressed: () {
        if (index == 4) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SettingsPage(onThemeChanged: _toggleTheme)),
          ).then((_) {
            _loadThemePreference();
          });
        } else {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 0) {
            _tabController.animateTo(0);
          }
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, 
              size: 26,
              color: active ? colorScheme.primary : colorScheme.onSurfaceVariant),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: active ? colorScheme.primary : colorScheme.onSurfaceVariant
              )),
        ],
      ),
    );
  }
}