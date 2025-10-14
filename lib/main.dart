import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:app_links/app_links.dart';

// import your auth screen
import 'auth/auth_log_reg.dart';
import 'role_selection/role.dart';
import 'dashboard.dart';
import 'feed/posts.dart'; // For CommentsPage

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    // Handle initial link if the app was opened via deep link
    final initialLink = await _appLinks.getInitialLink(); // This line is causing the error
    if (initialLink != null) {
      _handleDeepLink(initialLink);
    }

    // Listen for incoming links
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    // Handle custom scheme: awarcrown://post/{post_id}
    if (uri.scheme == 'awarcrown' && uri.host == 'post') {
      final postIdStr = uri.pathSegments.first;
      final postId = int.tryParse(postIdStr);
      if (postId != null) {
        _navigateToPost(postId);
      }
    }

    
    else if (uri.host == 'share.awarcrown.com' && uri.pathSegments[0] == 'post_feature') {
      final token = uri.pathSegments[1];
      _handleShareToken(token);
    }
  }

  void _navigateToPost(int postId) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndNavigateToPost(postId);
    });
  }

  Future<void> _fetchAndNavigateToPost(int postId) async {
    if (_username == null || _username!.isEmpty) return;

    try {
      // Fetch post by ID
      final response = await http.get(
        Uri.parse('https://server.awarcrown.com/feed/fetch_single_post?post_id=$postId&username=${Uri.encodeComponent(_username!)}'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final post = data['post'] ?? {};
        if (post.isNotEmpty) {
          // Fetch comments
          final commentsResponse = await http.get(
            Uri.parse('https://server.awarcrown.com/feed/fetch_comments?post_id=$postId&username=${Uri.encodeComponent(_username!)}'),
          ).timeout(const Duration(seconds: 10));

          List<dynamic> comments = [];
          if (commentsResponse.statusCode == 200) {
            final commentsData = json.decode(commentsResponse.body);
            comments = commentsData['comments'] ?? [];
          }

          // Navigate to CommentsPage
          final prefs = await SharedPreferences.getInstance();
          final userId = prefs.getInt('user_id');

          if (navigatorKey.currentState != null) {
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
        }
      }
    } catch (e) {
      debugPrint('Error fetching post: $e');
      // Optionally show error snackbar
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
          final post = data['post'];
          final postId = post['post_id'];
          _navigateToPost(postId);
        } else {
          // Handle error
          debugPrint('Invalid share link: ${data['message']}');
        }
      }
    } catch (e) {
      debugPrint('Error handling share token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
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

    // after animation finishes
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showLoader = true;
            });

            // Immediately check route after loader shows
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
        // Token exists and profile complete -> Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
      } else if (token != null) {
        // Token exists but profile incomplete -> Role Selection
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RoleSelectionPage()),
        );
      } else {
        // No token -> Login/Register
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
              // Logo first -> then loader
              _showLoader
                  ? const CircularProgressIndicator(
                      color: Colors.black,
                    )
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
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Times New Roman',
                    
                      ),
                    ),
                    Text(
                      "Awarcrown",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Lucida Console',

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