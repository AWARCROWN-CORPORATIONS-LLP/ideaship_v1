import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ideaship/feed/createpost.dart';
import 'package:ideaship/feed/posts.dart';
import 'package:ideaship/feed/startups.dart';
import 'package:ideaship/jobs/job_drawer.dart';
import 'package:ideaship/settings/usersettings.dart';
import 'package:ideaship/user/userprofile.dart';
import 'package:ideaship/thr_project/threads.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadUserData();
    _loadThemePreference();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_selectedIndex == 0) {
      setState(() {});
    }
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

  void _openJobDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _showMessageDialog() {
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

  void _handleSearchPress() {
    showSearch(
      context: context,
      delegate: PostSearchDelegate(),
    );
  }

  ColorScheme _buildColorScheme() {
    const primaryColor = Color(0xFF1268D1);
    return _isDarkMode
        ? ColorScheme.dark(
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
          )
        : ColorScheme.light(
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

  AppBar _buildAppBar(ColorScheme colorScheme) {
    List<Widget> actions = [
      IconButton(
        onPressed: _handleSearchPress,
        icon: const Icon(Icons.search, color: Colors.black87),
      ),
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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserProfile()),
          );
        },
        icon: Icon(Icons.account_circle, color: colorScheme.onSurface),
      ),
    ];

    if (_selectedIndex == 0) {
      return AppBar(
        elevation: 0.4,
        backgroundColor: colorScheme.surface,
        title: Text(
          "Ideaship",
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: colorScheme.primary,
            fontSize: 30,
            shadows: [
              Shadow(
                offset: const Offset(1, 1),
                blurRadius: 5,
                color: colorScheme.primary.withOpacity(0.5),
              ),
            ],
          ),
        ),
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
          title = 'Threads';
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
                PostsPage(),
                StartupsPage(),
              ],
            ),
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
                      child: Icon(Icons.arrow_forward_ios, size: 18, color: colorScheme.onSurface),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      case 1:
        return ThreadsScreen();
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
      scaffoldBackgroundColor: colorScheme.surface,
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
                    _navButton(Icons.article, "Threads", 1, colorScheme),
                    const SizedBox(width: 60),
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
            if (index == 0) {
              _tabController.animateTo(_tabController.index);
            }
          });
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 26,
            color: active ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: active ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class PostSearchDelegate extends SearchDelegate {
  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          title: Text('Search results for "$query"'),
          subtitle: const Text('TODO: Implement search functionality'),
        ),
      ],
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          title: Text('Suggestions for "$query"'),
          subtitle: const Text('TODO: Implement suggestions'),
        ),
      ],
    );
  }
}