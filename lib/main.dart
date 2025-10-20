import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';  // For Platform.isAndroid
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// Remove flutter_local_notifications import (moved to dashboard)

// Import your screens
import 'auth/auth_log_reg.dart';
import 'role_selection/role.dart';
import 'dashboard.dart';
import 'feed/posts.dart';
import 'thr_project/threads.dart';

// Background message handler (now stores notification and shows local if possible)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
  debugPrint('Message data: ${message.data}');

  // Store notification (shared helper)
  await _storeNotification(message);

  // Show local notification in background (FCM shows system one, but customize)
  // Note: Local notif init is in dashboard, so this may not work in true background; rely on FCM system notif
}

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global helper to store notifications in SharedPreferences
Future<void> _storeNotification(RemoteMessage message) async {
  final prefs = await SharedPreferences.getInstance();
  List<String> notificationsJson = prefs.getStringList('notifications') ?? [];
  final now = DateTime.now().toIso8601String();

  final notifData = {
    'title': message.notification?.title ?? message.data['title'] ?? 'Notification',
    'body': message.notification?.body ?? message.data['body'] ?? '',
    'timestamp': now,
    'type': message.data['type'] ?? 'general',
    'thread_id': message.data['thread_id'],
    'post_id': message.data['post_id'],
    'read': false,
  };

  notificationsJson.add(json.encode(notifData));
  // Limit to last 100 notifications
  if (notificationsJson.length > 100) {
    notificationsJson = notificationsJson.sublist(notificationsJson.length - 100);
  }
  await prefs.setStringList('notifications', notificationsJson);
}

// Global tap handler (for local/FCM consistency; now stores and navigates to notifications page)
void _handleNotificationTap(Map<String, dynamic> data) {
  // Store if not already (for local taps)
  final notifData = {
    'title': data['title'] ?? 'Notification',
    'body': data['body'] ?? '',
    'timestamp': DateTime.now().toIso8601String(),
    'type': data['type'] ?? 'general',
    'thread_id': data['thread_id'],
    'post_id': data['post_id'],
    'read': false,
  };
  // Decode payload if from local notif
  if (data['payload'] != null) {
    try {
      final payload = json.decode(data['payload']);
      notifData.addAll(payload);
    } catch (e) {}
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (navigatorKey.currentContext != null) {
      // Navigate to notifications page
      final threadId = int.tryParse(notifData['thread_id'] ?? '');
      final postId = int.tryParse(notifData['post_id'] ?? '');
      if (threadId != null || postId != null) {
        // Direct nav if possible (as before)
        debugPrint('Direct navigating to ${threadId != null ? 'thread' : 'post'}: ${threadId ?? postId}');
      } else {
        // Default to notifications page
        navigatorKey.currentState!.pushNamed('/notifications');  // Or use pushReplacement if needed
      }
    }
  });
}

// Remove _showLocalNotification (moved to dashboard)
// Remove _initializeLocalNotifications (moved to dashboard)

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // Remove: await _initializeLocalNotifications();  // Moved to dashboard
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _appLinks = AppLinks();
  String? _username;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _initDeepLinks();
    // FCM setup moved to dashboard; local init done in main
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString('username') ?? '';
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) _handleDeepLink(initialLink);
    } catch (e) {
      debugPrint('Error getting initial deep link: $e');
    }

    _appLinks.uriLinkStream.listen(
      (uri) {
        try {
          _handleDeepLink(uri);
        } catch (e) {
          debugPrint('Error handling deep link: $e');
        }
      },
      onError: (error) {
        debugPrint('Deep link stream error: $error');
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'awarcrown' && uri.host == 'post') {
      final postId = int.tryParse(uri.pathSegments.first);
      if (postId != null) _fetchAndNavigateToPost(postId);
    } else if (uri.scheme == 'awarcrown' && uri.host == 'thread') {
      final threadId = int.tryParse(uri.pathSegments.first);
      if (threadId != null) _fetchAndNavigateToThread(threadId);
    } else if (uri.host == 'share.awarcrown.com' &&
        uri.pathSegments.isNotEmpty &&
        uri.pathSegments[0] == 'post_feature') {
      final token = uri.pathSegments.length > 1 ? uri.pathSegments[1] : '';
      if (token.isNotEmpty) _handleShareToken(token);
    } else {
      debugPrint('Unhandled deep link: $uri');
    }
  }

  // Navigation helpers
  void _navigateToPost(int postId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndNavigateToPost(postId);
    });
  }

  void _navigateToThread(int threadId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndNavigateToThread(threadId);
    });
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

          if (navigatorKey.currentState != null) {
            ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
              const SnackBar(content: Text('Opening post...')),
            );
            navigatorKey.currentState!.push(
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
          _showDeepLinkError('Post not found');
        }
      } else {
        _showDeepLinkError('Failed to load post');
      }
    } catch (e) {
      debugPrint('Error fetching post: $e');
      _showDeepLinkError('Error loading post: $e');
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

        if (navigatorKey.currentState != null) {
          ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
            const SnackBar(content: Text('Opening thread...')),
          );
          navigatorKey.currentState!.push(
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
        _showDeepLinkError('Failed to load thread');
      }
    } catch (e) {
      debugPrint('Error fetching thread: $e');
      _showDeepLinkError('Error loading thread: $e');
    }
  }

  Future<void> _handleShareToken(String token) async {
    try {
      final response = await http.get(
        Uri.parse('https://server.awarcrown.com/feed/post_feature?token=$token'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          final postId = data['post']['post_id'];
          _navigateToPost(postId);
        } else {
          _showDeepLinkError('Invalid share link: ${data['message']}');
        }
      } else {
        _showDeepLinkError('Failed to validate share link');
      }
    } catch (e) {
      debugPrint('Error handling share token: $e');
      _showDeepLinkError('Error processing share link: $e');
    }
  }

  void _showDeepLinkError(String message) {
    if (navigatorKey.currentContext != null) {
      ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      debugPrint('Deep link error (no context): $message');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const SplashScreen(),
    );
  }
}

// SplashScreen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  bool _showLoader = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _showLoader = true);
            _checkInitialRoute();
          }
        });
      }
    });
  }

  Future<void> _checkInitialRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final profileCompleted = prefs.getBool('profileCompleted') ?? false;

    if (mounted) {
      if (token != null && profileCompleted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
      } else if (token != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RoleSelectionPage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthLogReg()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          width: 390,
          height: 844,
          color: Colors.white,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(),
              _showLoader
                  ? const CircularProgressIndicator(color: Colors.black)
                  : ScaleTransition(
                      scale: _scaleAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Image.asset(
                          "assets/black_logo.png",
                          width: 150,
                          height: 150,
                        ),
                      ),
                    ),
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Powered by",
                      style: TextStyle(color: Colors.black54, fontSize: 14),
                    ),
                    Text(
                      "Awarcrown",
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 28,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}