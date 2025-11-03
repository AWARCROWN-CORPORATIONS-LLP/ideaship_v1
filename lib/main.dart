import 'package:flutter/material.dart';
import 'package:ideaship/thr_project/thread_details.dart';
import 'dart:async';
import 'dart:io';  
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';  // New import
import 'auth/auth_log_reg.dart';
import 'role_selection/role.dart';
import 'dashboard.dart';
import 'feed/posts.dart';
import 'thr_project/threads.dart';
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
  debugPrint('Message data: ${message.data}');

  
  await _showLocalNotification(message);
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> _initializeLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');  

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
    onDidReceiveLocalNotification: null,  
  );

  const InitializationSettings initializationSettings =
      InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
   
      final data = response.payload != null ? json.decode(response.payload!) : <String, dynamic>{};
      _handleNotificationTap(data); 
    },
  );

 
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', 
    'High Importance Notifications', 
    description: 'Your app notifications',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('default'), 
  );

  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }
}


void _handleNotificationTap(Map<String, dynamic> data) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (navigatorKey.currentContext != null) {
      final threadId = int.tryParse(data['thread_id'] ?? '');
      if (threadId != null) {
       
        debugPrint('Navigating to thread: $threadId');
      }
    
    }
  });
}

Future<void> _showLocalNotification(RemoteMessage message) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    channelDescription: 'Your app notifications',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: false,
    icon: '@drawable/ic_notification',  
  );

  const DarwinNotificationDetails iOSPlatformChannelSpecifics =
      DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
    iOS: iOSPlatformChannelSpecifics,
  );

  final title = message.notification?.title ?? message.data['title'] ?? 'Notification';
  final body = message.notification?.body ?? message.data['body'] ?? '';

  await flutterLocalNotificationsPlugin.show(
    0, 
    title,
    body,
    platformChannelSpecifics,
    payload: json.encode(message.data),  
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await _initializeLocalNotifications();  
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