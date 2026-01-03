import 'package:flutter/material.dart';
import 'package:ideaship/thr_project/thread_details.dart';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// Removed unused app_links import
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'auth/auth_log_reg.dart';
import 'role_selection/role.dart';
import 'dashboard.dart';
import 'feed/posts.dart';
import 'thr_project/threads.dart';
import 'Market/marketplace.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
  debugPrint('Message data: ${message.data}');
  await _showLocalNotification(message);
}
Future<void> registerFcmTokenToServer() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');

    if (userId == null || userId == 0) {
      debugPrint("FCM: user_id not available yet");
      return;
    }

    // Request permission (Android 13+ safe)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) {
      debugPrint("FCM: token is null");
      return;
    }

    debugPrint("FCM TOKEN => $fcmToken");

    await http.post(
      Uri.parse(
        "https://server.awarcrown.com/notifications/register_device",
      ),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_id": userId,
        "fcm_token": fcmToken,
        "platform": Platform.operatingSystem,
      }),
    );
  } catch (e) {
    debugPrint("FCM register error: $e");
  }
}
void listenForFcmTokenRefresh() {
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    debugPrint("FCM TOKEN REFRESHED => $newToken");

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId == null || userId == 0) return;

    await http.post(
      Uri.parse(
        "https://server.awarcrown.com/notifications/register_device",
      ),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_id": userId,
        "fcm_token": newToken,
        "platform": Platform.operatingSystem,
      }),
    );
  });
}



Future<void> _initializeLocalNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const settings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await flutterLocalNotificationsPlugin.initialize(
    settings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      final data = response.payload != null
          ? json.decode(response.payload!)
          : <String, dynamic>{};
      _handleNotificationTap(data);
    },
  );

  const channel = AndroidNotificationChannel(
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

Future<void> _showLocalNotification(RemoteMessage message) async {
  const androidDetails = AndroidNotificationDetails(
    'high_importance_channel',
    'High Importance Notifications',
    channelDescription: 'Your app notifications',
    importance: Importance.max,
    priority: Priority.high,
    icon: '@drawable/ic_notification',
  );

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  const platformDetails = NotificationDetails(
    android: androidDetails,
    iOS: iosDetails,
  );

  final title =
      message.notification?.title ?? message.data['title'] ?? 'Notification';
  final body = message.notification?.body ?? message.data['body'] ?? '';

  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    platformDetails,
    payload: json.encode(message.data),
  );
}

void safeNavigate(Widget page) {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;

  Navigator.push(ctx, MaterialPageRoute(builder: (_) => page));
}

void safeReplace(Widget page) {
  final ctx = navigatorKey.currentContext;
  if (ctx == null) return;

  Navigator.pushReplacement(ctx, MaterialPageRoute(builder: (_) => page));
}

Future<bool> hasInternet() async {
  try {
    final lookup = await InternetAddress.lookup('google.com');
    return lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty;
  } catch (_) {
    return false;
  }
}

Future<http.Response?> retryRequest(Uri url, {int retries = 3}) async {
  for (int i = 0; i < retries; i++) {
    try {
      return await http.get(url).timeout(const Duration(seconds: 10));
    } catch (_) {
      await Future.delayed(const Duration(milliseconds: 400));
    }
  }
  return null;
}

void _handleNotificationTap(Map<String, dynamic> data) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final threadId = int.tryParse("${data['thread_id']}");
    final postId = int.tryParse("${data['post_id']}");

    if (threadId != null) {
      _MyAppState.globalInstance?.navigateToThread(threadId);
    } else if (postId != null) {
      _MyAppState.globalInstance?.navigateToPost(postId);
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    debugPrint("Flutter Error: ${details.exception}");
  };

  runZonedGuarded(
    () async {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      listenForFcmTokenRefresh();
      await _initializeLocalNotifications();
      runApp(const MyApp());
    },
    (error, stack) {
      debugPrint("Uncaught Error: $error\n$stack");
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static _MyAppState? globalInstance;

  // Removed AppLinks variable
  String? username;
  bool _isUserLoggedIn = false;
  // Removed _pendingDeepLink

  @override
  void initState() {
    super.initState();
    globalInstance = this;
    WidgetsBinding.instance.addObserver(this);
    _checkLoginStatus();
    Future.delayed(const Duration(seconds: 2), registerFcmTokenToServer);

    // Removed initDeepLinks() call
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Check if user is logged in
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final profileCompleted = prefs.getBool('profileCompleted') ?? false;
    username = prefs.getString('username') ?? "";
    _isUserLoggedIn = token != null && profileCompleted && username!.isNotEmpty;
  }

  // Reload username (called when user logs in)
  Future<void> loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('username') ?? "";
    _isUserLoggedIn = username!.isNotEmpty;
  }

  // Removed initDeepLinks() and handleDeepLink() methods

  // Kept navigateToPost and navigateToThread as they are used by Notifications
  Future<void> navigateToPost(int postId) async {
    if (username == null || username!.isEmpty) {
      debugPrint("Cannot navigate to post: username is empty");
      showError("Please log in to view posts");
      return;
    }

    if (!await hasInternet()) {
      showError("No internet connection. Please check your network.");
      return;
    }

    try {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
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
                Text('Loading post...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final url = Uri.parse(
        "https://server.awarcrown.com/feed/fetch_single_post?post_id=$postId&username=${Uri.encodeComponent(username!)}",
      );

      final response = await retryRequest(url);
      if (response == null || response.statusCode != 200) {
        if (response?.statusCode == 404) {
          showError("Post not found");
        } else {
          showError("Unable to load post. Please try again.");
        }
        return;
      }

      final data = jsonDecode(response.body);
      if (data['error'] != null) {
        showError(data['error']);
        return;
      }

      final post = data['post'];
      if (post == null || post.isEmpty) {
        showError("Post not found");
        return;
      }

      final commentsUrl = Uri.parse(
        "https://server.awarcrown.com/feed/fetch_comments?post_id=$postId&username=${Uri.encodeComponent(username!)}",
      );

      final commentsResponse = await retryRequest(commentsUrl);
      List<dynamic> comments = [];

      if (commentsResponse?.statusCode == 200) {
        final commentsData = jsonDecode(commentsResponse!.body);
        comments = commentsData['comments'] ?? [];
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 0;

      safeNavigate(
        CommentsPage(
          post: post,
          comments: comments,
          username: username!,
          userId: userId,
        ),
      );
    } catch (e) {
      debugPrint("Error navigating to post: $e");
      showError("Failed to load post: ${e.toString()}");
    }
  }

  Future<void> navigateToThread(int threadId) async {
    if (username == null || username!.isEmpty) {
      debugPrint("Cannot navigate to thread: username is empty");
      showError("Please log in to view threads");
      return;
    }

    if (!await hasInternet()) {
      showError("No internet connection. Please check your network.");
      return;
    }

    try {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.of(ctx).showSnackBar(
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

      final url = Uri.parse("https://server.awarcrown.com/threads/$threadId");
      final response = await retryRequest(url);

      if (response == null) {
        showError("Network error. Please check your connection.");
        return;
      }

      if (response.statusCode == 404) {
        showError("Thread not found");
        return;
      }

      if (response.statusCode != 200) {
        showError("Failed to load thread. Please try again.");
        return;
      }

      final data = jsonDecode(response.body);

      if (data['error'] != null) {
        showError(data['error']);
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
        showError("Invalid thread data received");
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id') ?? 0;

      safeNavigate(
        ThreadDetailScreen(thread: thread, username: username!, userId: userId),
      );
    } catch (e) {
      debugPrint("Error navigating to thread: $e");
      showError("Failed to load thread: ${e.toString()}");
    }
  }

  void showError(String msg) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(msg)),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> reloadUsername() async {
    await loadUsername();
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

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> scaleAnimation;
  late Animation<double> fadeAnimation;

  bool showLoader = false;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeOutBack));

    fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeIn));

    controller.forward();

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => showLoader = true);
            checkInitialRoute();
          }
        });
      }
    });
  }

  Future<void> checkInitialRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final profileCompleted = prefs.getBool('profileCompleted') ?? false;

      if (!mounted) return;

      if (token != null && profileCompleted) {
        _MyAppState.globalInstance?.reloadUsername();
        safeReplace(const DashboardPage());
      } else if (token != null) {
        _MyAppState.globalInstance?.reloadUsername();
        safeReplace(const RoleSelectionPage());
      } else {
        safeReplace(const AuthLogReg());
      }
    } catch (e) {
      safeReplace(const AuthLogReg());
    }
  }

  @override
  void dispose() {
    controller.dispose();
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
              showLoader
                  ? const CircularProgressIndicator(color: Colors.black)
                  : ScaleTransition(
                      scale: scaleAnimation,
                      child: FadeTransition(
                        opacity: fadeAnimation,
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
                        fontWeight: FontWeight.bold,
                      ),
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
