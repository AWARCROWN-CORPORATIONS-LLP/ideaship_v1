// dashboard.dart
// ignore: unused_import
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ideaship/feed/createpost.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isLogoutActive = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Updated to 5 tabs
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 28, 25, 25),
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
        return AlertDialog(
          title: const Text('Messages Coming Soon!'),
          content: const Text(
            'We are building a larger community globally to connect. This is within weeks we will make this feature available.',
            style: TextStyle(fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Got it!'),
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

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
                if (mounted) {
                  setState(() {
                    _isLogoutActive = false;
                  });
                }
              },
            ),
            TextButton(
              child: const Text('Logout'),
              onPressed: () {
                Navigator.of(context).pop();
                _isLogoutActive = false;
                _performLogout();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthLogReg()),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorBanner('Logout failed: ${e.toString()}');
        _isLogoutActive = false;
      }
    }
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

  void _handleLogoutPress() {
    if (_isLogoutActive) return;
    setState(() {
      _isLogoutActive = true;
    });
    _showLogoutConfirmation();
  }

  AppBar _buildAppBar() {
    List<Widget> actions = [
      IconButton(
        onPressed: _isNotificationActive ? null : _handleNotificationPress,
        icon: Icon(
          Icons.notifications_outlined,
          color: _isNotificationActive ? Colors.grey : Colors.black87,
        ),
      ),
      IconButton(
        onPressed: _isMessageActive ? null : _handleMessagePress,
        icon: Icon(
          Icons.chat_bubble_outline,
          color: _isMessageActive ? Colors.grey : Colors.black87,
        ),
      ),
      IconButton(
        onPressed: _isLogoutActive ? null : _handleLogoutPress,
        icon: Icon(
          Icons.logout,
          color: _isLogoutActive ? Colors.grey : Colors.black87,
        ),
      ),
    ];

    if (_selectedIndex == 0) {
      return AppBar(
        elevation: 0.4,
        backgroundColor: Colors.white,
        title: const Text("Ideaship",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 50, 51, 52),
                fontSize: 25)),
        actions: actions,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1268D1),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF1268D1),
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
        title: Text(title),
        backgroundColor: Colors.white,
        elevation: 0.4,
        actions: actions,
      );
    }
  }

  Widget _buildBody() {
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                  ),
                  child: const Center(
                      child: RotatedBox(
                          quarterTurns: 1,
                          child: Icon(Icons.arrow_forward_ios, size: 18))),
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
        );
      case 3:
        return const Center(child: Text('Alerts Page'));
      case 4:
        return const SizedBox();
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: const JobDrawer(),
      endDrawerEnableOpenDragGesture: true,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Open post creation page createpost.dart
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostPage()),
          );
        },
        backgroundColor: const Color(0xFF1268D1),
        child: const Icon(Icons.add, size: 28),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Colors.white,
        elevation: 8,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navButton(Icons.home_rounded, "Home", 0),
              _navButton(Icons.work_outline, "Roles", 1),
              const SizedBox(width: 60), // Space for the notch/FAB
              _navButton(Icons.notifications_outlined, "Alerts", 3),
              _navButton(Icons.settings_outlined, "Settings", 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navButton(IconData icon, String label, int index) {
    bool active = _selectedIndex == index;
    return MaterialButton(
      minWidth: 70,
      onPressed: () {
        if (index == 4) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          );
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
              color: active ? const Color(0xFF1268D1) : Colors.grey[700]),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1268D1) // You can adjust this based on active
              )), // Note: Adjusted color logic if needed
        ],
      ),
    );
  }
}