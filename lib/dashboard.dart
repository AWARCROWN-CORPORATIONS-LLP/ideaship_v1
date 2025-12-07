
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ideaship/feed/createpost.dart';
import 'package:ideaship/feed/posts.dart';
import 'package:ideaship/feed/startups.dart';

import 'package:ideaship/settings/usersettings.dart';
import 'package:ideaship/thr_project/thread_details.dart';
import 'package:ideaship/user/userprofile.dart';
import 'package:ideaship/thr_project/threads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ideaship/notify/notifications.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ideaship/feed/publicprofile.dart';
import 'package:shimmer/shimmer.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;
  late TabController _tabController;
  String? _username;
  String? _email;
  String? _role;
  String? _major;
  bool _isLoading = true;

  bool _isDarkMode = false;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadUserData();
    _loadThemePreference();
    _setupLocalNotifications();
    _setupFCM();
    _loadUnreadCount();
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

  Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final data = response.payload != null
            ? json.decode(response.payload!) as Map<String, dynamic>
            : <String, dynamic>{};
        _handleNotificationTap(data); // Use local handler
      },
    );

    // Android channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'Your app notifications',
      importance: Importance.max,
      playSound: true,
    );

    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }
  }

 
  Future<void> _setupFCM() async {
    final fcm = FirebaseMessaging.instance;

    NotificationSettings settings = await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('User granted permission: ${settings.authorizationStatus}');

    String? token = await fcm.getToken();
    if (_username != null) {
      await http.post(
        Uri.parse('https://server.awarcrown.com/threads/update_token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': _username, 'token': token}),
      );
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message: ${message.notification?.title}');
      _showLocalNotification(message);
      _storeNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _storeNotification(message);
      _handleNotificationNavigation(message.data);
      _markAllRead();
    });

    RemoteMessage? initialMessage = await fcm.getInitialMessage();
    if (initialMessage != null) {
      await _storeNotification(initialMessage);
      _handleNotificationNavigation(initialMessage.data);
    }
  }

  Future<void> _storeNotification(RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    final notifData = {
      'id':
          message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'title': message.notification?.title ?? message.data['title'] ?? '',
      'body': message.notification?.body ?? message.data['body'] ?? '',
      'data': message.data,
      'read': false,
      'timestamp': DateTime.now().toIso8601String(),
    };
    final notificationsJson = prefs.getStringList('notifications') ?? [];
    notificationsJson.insert(0, json.encode(notifData));
    await prefs.setStringList('notifications', notificationsJson);
    await _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getStringList('notifications') ?? [];
    final unread = notificationsJson.where((jsonStr) {
      final data = json.decode(jsonStr);
      return !(data['read'] ?? false);
    }).length;
    if (mounted) setState(() => _unreadCount = unread);
  }

  void _setUnreadCount(int count) {
    if (mounted) setState(() => _unreadCount = count);
  }

  Future<void> _markAllRead() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getStringList('notifications') ?? [];
    bool updated = false;
    for (int i = 0; i < notificationsJson.length; i++) {
      final data = json.decode(notificationsJson[i]);
      if (!(data['read'] ?? false)) {
        data['read'] = true;
        notificationsJson[i] = json.encode(data);
        updated = true;
      }
    }
    if (updated) {
      await prefs.setStringList('notifications', notificationsJson);
      await _loadUnreadCount();
    }
  }

  
  Future<void> _markAsReadById(String id) async {
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getStringList('notifications') ?? [];
    bool updated = false;
    for (int i = 0; i < notificationsJson.length; i++) {
      final notifData = json.decode(notificationsJson[i]);
      if (notifData['id'] == id && !(notifData['read'] ?? false)) {
        notifData['read'] = true;
        notificationsJson[i] = json.encode(notifData);
        updated = true;
        break;
      }
    }
    if (updated) {
      await prefs.setStringList('notifications', notificationsJson);
      await _loadUnreadCount();
    }
  }

  
  Future<void> _clearAllNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notifications');
    await _loadUnreadCount(); // Set count to 0
  }

  // Updated: Handle navigation (store first, then nav)
  Future<void> _handleNotificationNavigation(Map<String, dynamic> data) async {
    if (data['type'] == 'new_comment' ||
        data['type'] == 'inspired' ||
        data['type'] == 'collab_request') {
      final threadId = int.tryParse(data['thread_id'] ?? '');
      if (threadId != null) {
        await _fetchAndNavigateToThread(threadId);
        await _markAsReadById(data['id'] ?? '');
        return;
      }
    } else if (data['type'] == 'new_post_comment') {
      // Corrected type for post comments
      final postId = int.tryParse(data['post_id'] ?? '');
      if (postId != null) {
        await _fetchAndNavigateToPost(postId);
        await _markAsReadById(data['id'] ?? '');
        return;
      }
    }
    // Default: Nav to notifications page
    if (mounted) {
      Navigator.pushNamed(
        context,
        '/notifications',
      ); // Or push to NotificationsPage
    }
  }

  Future<void> _fetchAndNavigateToPost(int postId) async {
    if (_username == null || _username!.isEmpty) return;

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://server.awarcrown.com/feed/fetch_single_post?post_id=$postId&username=${Uri.encodeComponent(_username!)}',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final post = data['post'] ?? {};
        if (post.isNotEmpty) {
          final commentsResponse = await http
              .get(
                Uri.parse(
                  'https://server.awarcrown.com/feed/fetch_comments?post_id=$postId&username=${Uri.encodeComponent(_username!)}',
                ),
              )
              .timeout(const Duration(seconds: 10));

          List<dynamic> comments = [];
          if (commentsResponse.statusCode == 200) {
            final commentsData = json.decode(commentsResponse.body);
            comments = commentsData['comments'] ?? [];
          }

          final prefs = await SharedPreferences.getInstance();
          final userId = prefs.getInt('user_id');

          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Opening post...')));
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
    if (_username == null || _username!.isEmpty) {
      _showErrorBanner('Please log in to view threads');
      return;
    }

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Loading thread...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Use the same endpoint format as the app uses
      final response = await http
          .get(Uri.parse('https://server.awarcrown.com/threads/$threadId'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 404) {
        _showErrorBanner('Thread not found');
        return;
      }

      if (response.statusCode != 200) {
        _showErrorBanner('Failed to load thread. Please try again.');
        return;
      }

      final data = json.decode(response.body);

      
      if (data['error'] != null) {
        _showErrorBanner(data['error']);
        return;
      }

      final threadData = data is Map<String, dynamic>
          ? data
          : <String, dynamic>{};

    
      if (threadData['thread_id'] == null && threadData['id'] != null) {
        threadData['thread_id'] = threadData['id'];
      }
      if (threadData['category_name'] == null &&
          threadData['category'] != null) {
        threadData['category_name'] = threadData['category'];
      }
      if (threadData['creator_username'] == null &&
          threadData['creator'] != null) {
        threadData['creator_username'] = threadData['creator'];
      }
      if (threadData['creator_role'] == null && threadData['role'] != null) {
        threadData['creator_role'] = threadData['role'];
      }
      if (threadData['inspired_count'] == null) {
        threadData['inspired_count'] = 0;
      }
      if (threadData['comment_count'] == null) {
        threadData['comment_count'] = threadData['comments'] != null
            ? (threadData['comments'] as List).length
            : 0;
      }
      if (threadData['tags'] == null) {
        threadData['tags'] = [];
      }
      if (threadData['user_has_inspired'] == null) {
        threadData['user_has_inspired'] = false;
      }
      if (threadData['visibility'] == null) {
        threadData['visibility'] = 'public';
      }

      final thread = Thread.fromJson(threadData, isFromCache: false);

      if (thread.id == 0) {
        _showErrorBanner('Invalid thread data received');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 0;

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ThreadDetailScreen(
              thread: thread,
              username: _username!,
              userId: userId,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error fetching thread: $e');
      if (mounted) {
        _showErrorBanner('Error loading thread: ${e.toString()}');
      }
    }
  }

  // Updated: _showLocalNotification (now with payload for tap)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription: 'Your app notifications',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
        );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    final title =
        message.notification?.title ?? message.data['title'] ?? 'Notification';
    final body = message.notification?.body ?? message.data['body'] ?? '';

    final payloadData = {
      ...message.data,
      'id':
          message.messageId ??
          DateTime.now().millisecondsSinceEpoch
              .toString(), // Include ID for marking
    };

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000), // Unique ID
      title,
      body,
      details,
      payload: json.encode(payloadData), // Enhanced payload with ID
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 80,
          left: 20,
          right: 20,
        ),
        elevation: 8,
      ),
    );
  }

  // New: Handle notification tap (moved from main.dart)
  void _handleNotificationTap(Map<String, dynamic> data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final threadId = int.tryParse(data['thread_id'] ?? '');
      final postId = int.tryParse(data['post_id'] ?? '');
      final notifId = data['id'] ?? '';
      if (threadId != null) {
        _fetchAndNavigateToThread(threadId);
        _markAsReadById(notifId); // Now with ID
      } else if (postId != null) {
        _fetchAndNavigateToPost(postId);
        _markAsReadById(notifId); // Now with ID
      } else if (mounted) {
        Navigator.pushNamed(context, '/notifications');
      }
    });
  }



  void _handleNotificationPress() {
    setState(() => _selectedIndex = 3);
  }

  void _handleSearchPress() {
    showSearch(context: context, delegate: PostSearchDelegate());
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
        icon: Icon(Icons.search, color: colorScheme.onSurface),
      ),
      IconButton(
        onPressed: _handleNotificationPress,
        icon: Icon(Icons.notifications_outlined, color: colorScheme.onSurface),
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
        automaticallyImplyLeading: false,
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
                // ignore: deprecated_member_use
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
          title = 'RoundTable';
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
        automaticallyImplyLeading: false,
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
              children: const [PostsPage(), StartupsPage()],
            ),
           
              
          ],
        );
        
          
      case 1:
        return ThreadsScreen();
      case 3:
        return NotificationsPage(onUnreadChanged: _setUnreadCount);
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
           
           
            appBar: _buildAppBar(colorScheme),
            body: _buildBody(colorScheme),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreatePostPage(),
                  ),
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
                    _navButton(Icons.article, "Round ", 1, colorScheme),
                    const SizedBox(width: 60),
                    _navButton(
                      Icons.notifications_outlined,
                      "Alerts",
                      3,
                      colorScheme,
                    ),
                    _navButton(
                      Icons.settings_outlined,
                      "Settings",
                      4,
                      colorScheme,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _navButton(
    IconData icon,
    String label,
    int index,
    ColorScheme colorScheme,
  ) {
    bool active = _selectedIndex == index;
    Widget button = MaterialButton(
      minWidth: 70,
      onPressed: () {
        if (index == 4) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
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
              color: active
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
    if (index == 3 && _unreadCount > 0) {
      // Alerts index
      return Stack(
        children: [
          button,
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
              child: Text(
                '$_unreadCount',
                style: const TextStyle(color: Colors.white, fontSize: 8),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }
    return button;
  }
}

class PostSearchDelegate extends SearchDelegate with ChangeNotifier {
  Timer? _debounce;
  List<dynamic> _results = [];
  bool _loading = false;

  List<String> _recentSearches = [];

  
  PostSearchDelegate() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _recentSearches = prefs.getStringList("search_history") ?? [];
    notifyListeners();
  }

  
  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("search_history", _recentSearches);
  }

  void _addToHistory(String username) {
    if (!_recentSearches.contains(username)) {
      _recentSearches.insert(0, username);
      if (_recentSearches.length > 10) {
        _recentSearches.removeLast();
      }
    }

    _saveHistory();
    notifyListeners();
  }

  
  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("search_history");
    _recentSearches.clear();
    notifyListeners();
  }

  
  void _onQueryChanged(String query, BuildContext context) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchResults(query, context);
    });
  }


  Future<void> _fetchResults(String query, BuildContext context) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _results = [];
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      final url = Uri.parse(
        "https://server.awarcrown.com/accessprofile/search?username=$trimmed",
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _results = data["results"] ?? [];
      } else {
        _results = [];
      }
    } catch (e) {
      _results = [];
    }

    _loading = false;
    notifyListeners();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    _onQueryChanged(query, context);

    if (query.trim().isEmpty) {
      return _recentSearchList(context);
    }

    if (_loading) {
      return _shimmerLoader();
    }

    return _buildResultsList(context);
  }

  @override
  Widget buildResults(BuildContext context) {
    if (_loading) return _shimmerLoader();
    return _buildResultsList(context);
  }

 
  Widget _shimmerLoader() {
    return ListView.builder(
      itemCount: 6,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      },
    );
  }


  Widget _recentSearchList(BuildContext context) {
    if (_recentSearches.isEmpty) {
      return _emptyState("Search students or companies");
    }

    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Recent Searches",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(
              onPressed: _clearHistory,
              child: const Text("Clear"),
            )
          ],
        ),
        ..._recentSearches.map(
          (username) => ListTile(
            leading: const Icon(Icons.history),
            title: Text(username),
            onTap: () async {
              query = username;
              await _fetchResults(username, context);
              // ignore: use_build_context_synchronously
              showResults(context);
            },
          ),
        ),
      ],
    );
  }


  Widget _buildResultsList(BuildContext context) {
    if (_results.isEmpty) {
      return _emptyState("No users found");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final user = _results[index];

        return TweenAnimationBuilder(
          duration: const Duration(milliseconds: 250),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: _resultTile(context, user),
        );
      },
    );
  }

  
  Widget _resultTile(BuildContext context, dynamic user) {
    final username = user["username"];
    final profilePic = user["profile_picture"];

    return GestureDetector(
      onTap: () {
        _addToHistory(username);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PublicProfilePage(targetUsername: username),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 26, backgroundImage: NetworkImage(profilePic)),
            const SizedBox(width: 16),

            Expanded(
              child: RichText(
                text: TextSpan(
                  children: _highlightMatch(username),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            Icon(Icons.arrow_forward_ios_rounded,
                size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

 
  List<TextSpan> _highlightMatch(String username) {
    if (query.isEmpty) {
      return [TextSpan(text: "@$username")];
    }

    final lower = username.toLowerCase();
    final input = query.toLowerCase();
    final start = lower.indexOf(input);

    if (start == -1) {
      return [TextSpan(text: "@$username")];
    }

    return [
      TextSpan(text: "@${username.substring(0, start)}"),
      TextSpan(
        text: username.substring(start, start + input.length),
        style: const TextStyle(color: Colors.blue),
      ),
      TextSpan(text: username.substring(start + input.length)),
    ];
  }

  Widget _emptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          )
        ],
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
      onPressed: () => close(context, null),
    );
  }
}
