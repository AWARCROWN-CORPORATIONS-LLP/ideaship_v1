import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ideaship/feed/createpost.dart';
import 'package:ideaship/feed/posts.dart';
import 'package:ideaship/feed/startups.dart';
import 'package:ideaship/jobs/job_drawer.dart';
import 'package:ideaship/main.dart';
import 'package:ideaship/settings/usersettings.dart';
import 'package:ideaship/user/userprofile.dart';
import 'package:ideaship/thr_project/threads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as lpn;  // Alias to avoid conflict

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
    _setupFCM();  // Centralized FCM setup here
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

  Future<void> _setupFCM() async {
    final fcm = FirebaseMessaging.instance;

    // Request permissions (existing)
    NotificationSettings settings = await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,  // For iOS critical alerts if needed
    );
    debugPrint('User granted permission: ${settings.authorizationStatus}');

    // Get token and send to backend (existing, with try-catch for FIS error)
    String? token;
    try {
      token = await fcm.getToken();
    } catch (e) {
      debugPrint('FCM Token Error: $e');
      // Retry logic if needed (as in previous fix)
    }
    if (token != null && _username != null && _username!.isNotEmpty) {
      try {
        await http.post(
          Uri.parse('https://server.awarcrown.com/threads/update_token'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'username': _username, 'token': token}),
        );
        debugPrint('FCM token sent to server: $token');
      } catch (e) {
        debugPrint('Error updating FCM token: $e');
      }
    }

    // Foreground: Show LOCAL notification (WhatsApp-style tray)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message: ${message.notification?.title}');
      _showLocalNotification(message);  // New: Use local plugin
    });

    // Background/Terminated tap: Navigate (FCM auto-shows system notif)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final data = message.data;
      _handleNotificationNavigation(data);
    });

    // Initial message (app opened from terminated notif)
    RemoteMessage? initialMessage = await fcm.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationNavigation(initialMessage.data);
    }
  }

  void _handleNotificationNavigation(Map<String, dynamic> data) {
    try {
      if (data['type'] == 'new_comment' ||
          data['type'] == 'inspired' ||
          data['type'] == 'collab_request') {
        final threadId = int.tryParse(data['thread_id'] ?? '');
        if (threadId != null) _fetchAndNavigateToThread(threadId);
      } else if (data['type'] == 'new_post_comment') {
        final postId = int.tryParse(data['post_id'] ?? '');
        if (postId != null) _fetchAndNavigateToPost(postId);
      } else {
        debugPrint('Unhandled notification type: ${data['type']}');
      }
    } catch (e) {
      debugPrint('Error handling notification navigation: $e');
    }
  }

  Future<void> _fetchAndNavigateToPost(int postId) async {
    if (_username == null || _username!.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse(
            'https://server.awarcrown.com/feed/fetch_single_post?post_id=$postId&username=${Uri.encodeComponent(_username!)}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final post = data['post'] ?? {};
        if (post.isNotEmpty) {
          final commentsResponse = await http.get(
            Uri.parse(
                'https://server.awarcrown.com/feed/fetch_comments?post_id=$postId&username=${Uri.encodeComponent(_username!)}'),
          ).timeout(const Duration(seconds: 10));

          List<dynamic> comments = [];
          if (commentsResponse.statusCode == 200) {
            final commentsData = json.decode(commentsResponse.body);
            comments = commentsData['comments'] ?? [];
          }

          final prefs = await SharedPreferences.getInstance();
          final userId = prefs.getInt('user_id');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Opening post...')),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CommentsPage(
                  post: post,
                  comments: comments,
                  username: _username!,
                  userId: userId,
                ),
              ),
            );
          }
        } else {
          _showErrorBanner('Post not found');
        }
      } else {
        _showErrorBanner('Failed to load post');
      }
    } catch (e) {
      debugPrint('Error fetching post: $e');
      _showErrorBanner('Error loading post: $e');
    }
  }

  Future<void> _fetchAndNavigateToThread(int threadId) async {
    if (_username == null || _username!.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse('https://server.awarcrown.com/threads/$threadId'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final thread = Thread.fromJson(data);

        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getInt('user_id');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opening thread...')),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ThreadDetailScreen(
                thread: thread,
                username: _username!,
                userId: userId ?? 0,
              ),
            ),
          );
        }
      } else {
        _showErrorBanner('Failed to load thread');
      }
    } catch (e) {
      debugPrint('Error fetching thread: $e');
      _showErrorBanner('Error loading thread: $e');
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    // Use the global plugin
    const lpn.AndroidNotificationDetails androidPlatformChannelSpecifics =
        lpn.AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'Your app notifications',
      importance: lpn.Importance.max,
      priority: lpn.Priority.high,
      showWhen: false,
      icon: '@drawable/ic_notification',  // Custom icon
    );

    const lpn.DarwinNotificationDetails iOSPlatformChannelSpecifics =
        lpn.DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const lpn.NotificationDetails platformChannelSpecifics = lpn.NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final title = message.notification?.title ?? message.data['title'] ?? 'Notification';
    final body = message.notification?.body ?? message.data['body'] ?? '';

    await flutterLocalNotificationsPlugin.show(
      0,  // ID
      title,
      body,
      platformChannelSpecifics,
      payload: json.encode(message.data),  // For tap handling
    );
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