import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lottie/lottie.dart';

class Thread {
  final int id;
  final String title;
  final String body;
  final String category;
  final String creator;
  final String creatorRole;
  int inspiredCount;
  final int commentCount;
  int collabCount;
  final List<String> tags;
  final DateTime createdAt;
  bool isInspiredByMe;
  final String visibility;
  final String? inviteCode;
  Thread({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.creator,
    required this.creatorRole,
    required this.inspiredCount,
    required this.commentCount,
    required this.collabCount,
    required this.tags,
    required this.createdAt,
    required this.isInspiredByMe,
    required this.visibility,
    this.inviteCode,
  });
  factory Thread.fromJson(Map<String, dynamic> json) {
    try {
      return Thread(
        id: json['thread_id'] ?? 0,
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        category: json['category_name'] ?? '',
        creator: json['creator_username'] ?? '',
        creatorRole: json['creator_role'] ?? '',
        inspiredCount: json['inspired_count'] ?? 0,
        commentCount: json['comment_count'] ?? 0,
        collabCount: json['collab_count'] ?? 0,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        isInspiredByMe: json['user_has_inspired'] ?? false,
        visibility: json['visibility'] ?? 'public',
        inviteCode: json['invite_code'],
      );
    } catch (e) {
      debugPrint('Error parsing Thread from JSON: $e');
      return Thread(
        id: 0,
        title: 'Error Loading Thread',
        body: 'Failed to load thread details.',
        category: 'Error',
        creator: 'Unknown',
        creatorRole: '',
        inspiredCount: 0,
        commentCount: 0,
        collabCount: 0,
        tags: [],
        createdAt: DateTime.now(),
        isInspiredByMe: false,
        visibility: 'public',
      );
    }
  }
}

class Comment {
  final int id;
  final int? parentId;
  final String body;
  final String commenter;
  final DateTime createdAt;
  final List<Comment> replies;
  Comment({
    required this.id,
    this.parentId,
    required this.body,
    required this.commenter,
    required this.createdAt,
    this.replies = const [],
  });
  factory Comment.fromJson(
      Map<String, dynamic> json, Map<int, List<Map<String, dynamic>>> commentMap) {
    try {
      final id = json['comment_id'] ?? 0;
      final repliesJson = commentMap[id] ?? [];
      final replies = <Comment>[];
      for (final r in repliesJson) {
        try {
          replies.add(Comment.fromJson(r, commentMap));
        } catch (e) {
          debugPrint('Error parsing reply comment: $e');
        }
      }
      return Comment(
        id: id,
        parentId: json['parent_comment_id'],
        body: json['comment_body'] ?? '',
        commenter: json['commenter_username'] ?? '',
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        replies: replies,
      );
    } catch (e) {
      debugPrint('Error parsing Comment from JSON: $e');
      return Comment(
        id: 0,
        body: 'Error loading comment.',
        commenter: 'Unknown',
        createdAt: DateTime.now(),
        replies: [],
      );
    }
  }
}

class RoundTablePainter extends CustomPainter {
  final double rotation;
  RoundTablePainter({this.rotation = 0.0});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final tableRadius = size.width / 2 - 4;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);
    // Draw round table
    final tablePaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, tableRadius, tablePaint);
    final edgePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, tableRadius, edgePaint);
    final chairPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final angle = (2 * pi / 8) * i;
      final chairRadius = 2.0;
      final chairDistance = tableRadius + 6;
      final chairX = center.dx + chairDistance * cos(angle);
      final chairY = center.dy + chairDistance * sin(angle);
      canvas.drawCircle(Offset(chairX, chairY), chairRadius, chairPaint);
    }
    canvas.restore();
  }
  @override
  bool shouldRepaint(covariant RoundTablePainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}

class AnimatedRoundTableIcon extends StatefulWidget {
  final double size;
  final Color color;
  const AnimatedRoundTableIcon({
    super.key,
    this.size = 54.0,
    this.color = Colors.blue,
  });
  @override
  State<AnimatedRoundTableIcon> createState() => _AnimatedRoundTableIconState();
}

class _AnimatedRoundTableIconState extends State<AnimatedRoundTableIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 2 * pi,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: RoundTablePainter(rotation: _rotationAnimation.value),
        );
      },
    );
  }
}

class OnboardingTourScreen extends StatefulWidget {
  const OnboardingTourScreen({super.key});
  @override
  State<OnboardingTourScreen> createState() => _OnboardingTourScreenState();
}

class _OnboardingTourScreenState extends State<OnboardingTourScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _tableController;
  late AnimationController _chairsController;
  late Animation<double> _tableAnimation;
  late Animation<double> _chairsAnimation;
  int currentPage = 0;
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _tableController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _chairsController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _tableAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _tableController, curve: Curves.easeInOut),
    );
    _chairsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _chairsController, curve: Curves.bounceOut),
    );
    _tableController.forward().then((_) => _chairsController.forward());
  }
  @override
  void dispose() {
    _pageController.dispose();
    _tableController.dispose();
    _chairsController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              if (mounted) {
                setState(() => currentPage = index);
              }
              _tableController.reset();
              _chairsController.reset();
              _tableController.forward().then((_) => _chairsController.forward());
            },
            children: [
              // Page 1: Welcome to Roundtable
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: _tableAnimation,
                      child: ScaleTransition(
                        scale: _tableAnimation,
                        child: const AnimatedRoundTableIcon(size: 150),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text('Gather \'Round!',
                        style: Theme.of(context).textTheme.headlineMedium),
                    Text('Join discussions like a virtual roundtable.'),
                  ],
                ),
              ),
              // Page 2: Create & Engage
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: _tableAnimation,
                      child: ScaleTransition(
                        scale: _tableAnimation,
                        child: const AnimatedRoundTableIcon(size: 150),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text('Start Conversations',
                        style: Theme.of(context).textTheme.headlineSmall),
                    Text('Create threads and watch ideas circle the table.'),
                  ],
                ),
              ),
              // Page 3: Collaborate
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: _tableAnimation,
                      child: ScaleTransition(
                        scale: _tableAnimation,
                        child: const AnimatedRoundTableIcon(size: 150),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text('Pull Up a Chair',
                        style: Theme.of(context).textTheme.headlineSmall),
                    Text('Join collabs with a simple tap.'),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  3,
                  (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        height: 8,
                        width: currentPage == index ? 24 : 8,
                        decoration: BoxDecoration(
                          color:
                              currentPage == index ? Colors.blue : Colors.grey,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )),
            ),
          ),
          Positioned(
            bottom: 100,
            right: 20,
            child: FloatingActionButton(
              onPressed: () async {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('hasSeenOnboarding', true);
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ThreadsScreen()),
                    );
                  }
                } catch (e) {
                  debugPrint('Error saving onboarding preference: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Error completing onboarding: $e')),
                    );
                  }
                }
              },
              child: const Icon(Icons.arrow_forward),
            ),
          ),
        ],
      ),
    );
  }
}

class ThreadsScreen extends StatefulWidget {
  const ThreadsScreen({super.key});
  @override
  _ThreadsScreenState createState() => _ThreadsScreenState();
}

class _ThreadsScreenState extends State<ThreadsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  bool isMyView = false;
  List<Thread> threads = [];
  List<Thread> searchResults = [];
  String? username;
  int? userId;
  String sort = 'recent';
  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;
  bool isLoadingMore = false;
  int offset = 0;
  final int limit = 20;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late AnimationController _staggerController;
  late Animation<double> _fadeAnimation;
  List<Animation<double>> _slideAnimations = [];
  Timer? _scrollDebounceTimer;
  Timer? _retryTimer;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryBaseDelay = Duration(seconds: 2);
  http.Client? _httpClient;
  bool _hasReachedMax = false;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  Map<int, Thread> _threadCache = {};
  DateTime? _lastFetchTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          isMyView = _tabController.index == 1;
        });
        _fetchThreads(reset: true);
      }
    });
    _httpClient = http.Client();
    _checkOnboarding();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _initializeData();
    _setupScrollListener();
  }
  void _setupScrollListener() {
    _scrollController.addListener(_onScroll);
  }
  void _onScroll() {
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.pixels >= position.maxScrollExtent - 200) {
        if (!isLoadingMore && !hasError && !_hasReachedMax) {
          if (_isSearching) {
            _searchMoreThreads(_searchController.text);
          } else {
            _fetchMoreThreads();
          }
        }
      }
    });
  }
  @override
  void dispose() {
    _searchController.dispose();
    _scrollDebounceTimer?.cancel();
    _retryTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _animationController.dispose();
    _staggerController.dispose();
    _tabController.dispose();
    _httpClient?.close();
    super.dispose();
  }
  Future<void> _checkOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool('hasSeenOnboarding') ?? false;
      if (!hasSeen && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingTourScreen()),
        );
      }
    } catch (e) {
      debugPrint('Error checking onboarding: $e');
    }
  }
  Future<void> _initializeData() async {
    try {
      await _loadUsernameAndUserId();
      await _setupFCM();
      await _fetchThreads(reset: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = _getErrorMessage(e);
        });
        _showError(errorMessage ?? 'Initialization failed');
      }
    }
  }
  Future<void> _loadUsernameAndUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      username = prefs.getString('username') ?? '';
      userId = prefs.getInt('user_id');
      if (userId == null || userId == 0) {
        await _fetchUserId();
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading username and user ID: $e');
      if (mounted) {
        _showError('Failed to load user info: $e');
      }
    }
  }
  Future<void> _fetchUserId() async {
    if (username == null || username!.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse(
            'https://server.awarcrown.com/feed/get_user?username=${Uri.encodeComponent(username!)}'),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['error'] == null) {
          dynamic userIdData = data['user_id'];
          int? parsedUserId;
          if (userIdData is int) {
            parsedUserId = userIdData;
          } else if (userIdData != null) {
            parsedUserId = int.tryParse(userIdData.toString());
          }
          if (parsedUserId != null && parsedUserId != 0) {
            userId = parsedUserId;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('user_id', userId!);
            if (mounted) setState(() {});
          } else {
            _showError('Failed to fetch valid user ID');
          }
        } else {
          _showError(data['error'] ?? 'Failed to fetch user ID');
        }
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showError(_getErrorMessage(e));
    }
  }
  Future<void> _setupFCM() async {
    try {
      await Firebase.initializeApp();
      final fcm = FirebaseMessaging.instance;
      NotificationSettings settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('User granted permission: ${settings.authorizationStatus}');
      String? token = await fcm.getToken();
      if (token != null && username != null) {
        await http.post(
          Uri.parse('https://server.awarcrown.com/threads/update_token'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'username': username, 'token': token}),
        ).timeout(const Duration(seconds: 10));
      }
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got foreground message: ${message.notification?.title}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '${message.notification?.title}: ${message.notification?.body}'),
              action: SnackBarAction(
                label: 'Refresh',
                onPressed: () => _fetchThreads(reset: true),
              ),
              backgroundColor: Colors.blue,
            ),
          );
        }
      });
    } catch (e) {
      debugPrint('Error setting up FCM: $e');
    }
  }
  String _getErrorMessage(dynamic e) {
    if (e is SocketException) {
      return 'No internet connection. Please check your connection and try again.';
    } else if (e is TimeoutException) {
      return 'Request timed out. Please check your connection and try again.';
    } else if (e is http.ClientException) {
      return 'Network error occurred. Please try again.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  Future<String?> _getThreadCode(int threadId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('code_$threadId');
  }
  Future<void> _setThreadCode(int threadId, String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('code_$threadId', code);
  }
  Future<void> _fetchThreads({bool reset = false}) async {
    if (username == null || username!.isEmpty) return;
    if (!reset &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheValidDuration) {
      return;
    }
    if (reset) {
      offset = 0;
      threads.clear();
      isLoadingMore = false;
      _hasReachedMax = false;
      _retryCount = 0;
    }
    if (mounted) {
      setState(() {
        if (reset) {
          isLoading = true;
          hasError = false;
          errorMessage = null;
        } else {
          isLoadingMore = true;
        }
      });
    }
    try {
      String uriStr = 'https://server.awarcrown.com/threads/list?sort=$sort&limit=$limit&offset=$offset';
      if (isMyView) {
        uriStr += '&username=${Uri.encodeComponent(username!)}';
      }
      final uri = Uri.parse(uriStr);
      final response = await (_httpClient ?? http.Client())
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final newThreads = <Thread>[];
        for (final jsonItem in data) {
          try {
            final thread = Thread.fromJson(jsonItem);
            newThreads.add(thread);
            _threadCache[thread.id] = thread;
          } catch (e) {
            debugPrint('Error parsing thread: $e');
          }
        }
        final prefs = await SharedPreferences.getInstance();
        for (final thread in newThreads) {
          thread.isInspiredByMe = prefs.getBool('inspired_${thread.id}') ?? false;
          if (isMyView) {
            thread.isInspiredByMe = true; // Assume creator has inspired their own
          }
        }
        if (mounted) {
          setState(() {
            if (reset) {
              threads = newThreads;
              isLoading = false;
            } else {
              threads.addAll(newThreads);
              isLoadingMore = false;
            }
            offset += newThreads.length;
            _hasReachedMax = newThreads.length < limit;
            _lastFetchTime = DateTime.now();
            _retryCount = 0;
          });
        }
        if (newThreads.isNotEmpty) {
          final startIndex = reset ? 0 : threads.length - newThreads.length;
          final newAnimations = List.generate(
              newThreads.length,
              (index) => Tween<double>(begin: -1.0, end: 0.0).animate(
                    CurvedAnimation(
                      parent: _staggerController,
                      curve: Interval((startIndex + index) * 0.05, 1.0,
                          curve: Curves.elasticOut),
                    ),
                  ));
          if (reset) {
            _slideAnimations = newAnimations;
          } else {
            _slideAnimations.addAll(newAnimations);
          }
          _staggerController.forward(from: 0.0);
        }
      } else if (response.statusCode == 404) {
        if (mounted) {
          setState(() {
            _hasReachedMax = true;
            isLoadingMore = false;
            if (reset) isLoading = false;
          });
        }
      } else {
        throw Exception(
            'Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (reset) {
            isLoading = false;
            hasError = true;
            errorMessage = 'Failed to fetch roundtables: ${_getErrorMessage(e)}';
          } else {
            isLoadingMore = false;
          }
        });
        if (reset) {
          _scheduleRetry(() => _fetchThreads(reset: true));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Failed to load roundtables: ${_getErrorMessage(e)}'),
              action: SnackBarAction(
                label: 'Retry Now',
                onPressed: () {
                  _retryCount = 0;
                  _fetchThreads(reset: true);
                },
              ),
            ),
          );
        } else {
          _showError('Failed to load more roundtables: ${_getErrorMessage(e)}');
        }
      }
    }
  }
  Future<void> _searchThreads(String query, {bool reset = false}) async {
    if (isMyView) return; // Search only in discover
    if (reset) {
      offset = 0;
      searchResults.clear();
      isLoadingMore = false;
      _hasReachedMax = false;
    }
    if (mounted) {
      setState(() {
        isLoading = true;
        _isSearching = true;
      });
    }
    try {
      final uri = Uri.parse(
          'https://server.awarcrown.com/threads/search?query=${Uri.encodeComponent(query)}&limit=$limit&offset=$offset');
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final newThreads = <Thread>[];
        for (final jsonItem in data) {
          try {
            final thread = Thread.fromJson(jsonItem);
            newThreads.add(thread);
          } catch (e) {
            debugPrint('Error parsing search thread: $e');
          }
        }
        final prefs = await SharedPreferences.getInstance();
        for (final thread in newThreads) {
          thread.isInspiredByMe = prefs.getBool('inspired_${thread.id}') ?? false;
        }
        if (mounted) {
          setState(() {
            searchResults = reset ? newThreads : [...searchResults, ...newThreads];
            isLoading = false;
            offset += newThreads.length;
            _hasReachedMax = newThreads.length < limit;
          });
        }
      } else {
        throw Exception('Search error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        _showError('Search failed: ${_getErrorMessage(e)}');
      }
    }
  }
  Future<void> _searchMoreThreads(String query) async {
    await _searchThreads(query, reset: false);
  }
  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        searchResults.clear();
      });
    } else {
      _searchThreads(query, reset: true);
    }
  }
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      searchResults.clear();
    });
  }
  Future<void> _joinWithCode() async {
    final TextEditingController codeController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Private Discussion'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'Enter Invite Code',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              await _joinPrivateThread(code);
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
  Future<void> _joinPrivateThread(String code) async {
    try {
      final response = await http.get(
        Uri.parse('https://server.awarcrown.com/threads/join-by-code?code=${Uri.encodeComponent(code)}'),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final thread = Thread.fromJson(data);
        await _setThreadCode(thread.id, code);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ThreadDetailScreen(
                thread: thread,
                username: username ?? '',
                userId: userId ?? 0,
              ),
            ),
          );
        }
      } else {
        _showError('Invalid code or thread not found');
      }
    } catch (e) {
      _showError('Failed to join: $_getErrorMessage(e)');
    }
  }
  void _scheduleRetry(Future<void> Function() retryFunction) {
    if (_retryCount >= _maxRetries) return;
    _retryTimer?.cancel();
    _retryCount++;
    final delay =
        _retryBaseDelay * (1 << (_retryCount - 1));
    _retryTimer = Timer(delay, () {
      if (mounted && !isLoading && !isLoadingMore) {
        retryFunction();
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Retrying... (Attempt $_retryCount/$_maxRetries)'),
          duration: delay,
        ),
      );
    }
  }
  Future<void> _fetchMoreThreads() async {
    await _fetchThreads(reset: false);
  }
  Future<void> _createThread(
      String title, String body, String category, List<String> tags, String visibility) async {
    if (userId == null || userId == 0 || username == null || username!.isEmpty) {
      if (mounted) {
        _showError('Please wait to create a roundtable');
      }
      return;
    }
    try {
      final bodyData = json.encode({
        'category': category,
        'title': title,
        'body': body,
        'username': username,
        'tags': tags,
        'visibility': visibility,
      });
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/threads/create'),
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('thread_id')) {
          final newId = data['thread_id'] as int;
          final inviteCode = data['invite_code'] as String?;
          final newThread = Thread(
            id: newId,
            title: title,
            body: body,
            category: category,
            creator: username!,
            creatorRole: '',
            inspiredCount: 0,
            commentCount: 0,
            collabCount: 0,
            tags: tags,
            createdAt: DateTime.now(),
            isInspiredByMe: true,
            visibility: visibility,
            inviteCode: inviteCode,
          );
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('inspired_$newId', true);
          if (visibility == 'private' && inviteCode != null) {
            await _setThreadCode(newId, inviteCode);
            _showPrivateThreadDialog(title, inviteCode);
          } else {
            _showSuccess('Roundtable created!');
          }
          if (mounted) {
            setState(() {
              threads.insert(0, newThread);
            });
          }
          if (isMyView) {
            // If in my view, refresh to ensure consistency
            _fetchThreads(reset: true);
          }
        } else {
          await _fetchThreads(reset: true);
        }
        if (mounted) Navigator.pop(context);
      } else {
        throw Exception('Failed to create roundtable: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to create roundtable: ${_getErrorMessage(e)}');
      }
    }
  }
  void _showPrivateThreadDialog(String title, String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Private Roundtable Created'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title: $title'),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.lock, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text('Invite Code: $code')),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code copied!')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
  Future<void> _toggleInspire(int threadId) async {
    if (username == null || username!.isEmpty) return;
    final threadIndex = threads.indexWhere((t) => t.id == threadId);
    if (threadIndex == -1) return;
    final thread = threads[threadIndex];
    final oldCount = thread.inspiredCount;
    final oldInspired = thread.isInspiredByMe;
    final newInspired = !oldInspired;
    thread.isInspiredByMe = newInspired;
    thread.inspiredCount += newInspired ? 1 : -1;
    if (mounted) setState(() {});
    try {
      final code = await _getThreadCode(threadId);
      final bodyData = json.encode({
        'type': newInspired ? 'inspired' : 'uninspired',
        'username': username,
        if (code != null) 'code': code,
      });
      final uri = Uri.parse('https://server.awarcrown.com/threads/inspire?id=$threadId');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      ).timeout(const Duration(seconds: 10));
      final prefs = await SharedPreferences.getInstance();
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (data.containsKey('inspired_count')) {
            thread.inspiredCount = data['inspired_count'];
          }
          if (data.containsKey('user_has_inspired')) {
            thread.isInspiredByMe = data['user_has_inspired'] as bool;
          }
          await prefs.setBool('inspired_$threadId', thread.isInspiredByMe);
          _showSuccess(data['message'] ?? (newInspired ? 'Inspired this discussion!' : 'Uninspired.'));
        } else {
          thread.isInspiredByMe = oldInspired;
          thread.inspiredCount = oldCount;
          await prefs.setBool('inspired_$threadId', oldInspired);
          if (mounted) setState(() {});
          _showSuccess(data['message'] ?? 'No change');
        }
      } else {
        throw Exception('Failed to toggle inspire: ${response.statusCode}');
      }
    } catch (e) {
      thread.isInspiredByMe = oldInspired;
      thread.inspiredCount = oldCount;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('inspired_$threadId', oldInspired);
      if (mounted) setState(() {});
      if (mounted) {
        _showError('Failed to toggle inspire: ${_getErrorMessage(e)}');
      }
    }
  }
  Future<void> _sendCollab(int threadId, String message) async {
    if (username == null || username!.isEmpty) return;
    final threadIndex = threads.indexWhere((t) => t.id == threadId);
    if (threadIndex == -1) return;
    final thread = threads[threadIndex];
    final oldCount = thread.collabCount;
    thread.collabCount++;
    if (mounted) setState(() {});
    try {
      final code = await _getThreadCode(threadId);
      final bodyData = json.encode({
        'message': message,
        'username': username,
        if (code != null) 'code': code,
      });
      final uri = Uri.parse('https://server.awarcrown.com/threads/collab?id=$threadId');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = json.decode(response.body);
          if (data is Map<String, dynamic> &&
              data.containsKey('collab_count')) {
            thread.collabCount = data['collab_count'];
          }
        } catch (_) {
          // Keep optimistic update
        }
        if (mounted) {
          _showJoinAnimation(context, threadId);
          _showSuccess('Joined the roundtable discussion!');
        }
      } else {
        throw Exception('Failed to join discussion: ${response.statusCode}');
      }
    } catch (e) {
      thread.collabCount = oldCount;
      if (mounted) setState(() {});
      if (mounted) {
        _showError('Failed to join discussion: ${_getErrorMessage(e)}');
      }
    }
  }
  void _showJoinAnimation(BuildContext context, int threadId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Timer(const Duration(milliseconds: 2000), () {
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            });
          });
          return Dialog(
            backgroundColor: Colors.transparent,
            child: Stack(
              children: [
                // Central table
                const Center(
                  child: AnimatedRoundTableIcon(size: 200),
                ),
                // Chair pull animation (using Lottie for simplicity; replace with Rive if preferred)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Lottie.asset(
                    'assets/chair_pull.json', // TODO: Ensure this Lottie asset exists in your project
                    width: 300,
                    height: 200,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 300,
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(Icons.error, color: Colors.grey),
                    ),
                  ),
                ),
                // Confetti (simple particle simulation or use confetti package)
                Align(
                  alignment: Alignment.topCenter,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 500),
                    builder: (context, value, child) => Opacity(
                      opacity: value,
                      child: Icon(Icons.party_mode,
                          size: 50 * value, color: Colors.yellow),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  void _showCreateDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    String selectedCategory = 'Idea';
    List<String> selectedTags = [];
    bool isPrivate = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: const [
            Icon(Icons.add, color: Colors.blue),
            SizedBox(width: 8),
            Text('Start Roundtable')
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Topic Title',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    )),
                const SizedBox(height: 8),
                TextField(
                  controller: bodyController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Opening Thoughts',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(
                      labelText: 'Theme', border: OutlineInputBorder()),
                  items: ['Idea', 'Problem', 'Build', 'Event', 'Collab']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedCategory = val!),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: const Text('Private Discussion'),
                  subtitle: const Text('Require invite code to join'),
                  value: isPrivate,
                  onChanged: (val) => setDialogState(() => isPrivate = val),
                ),
                const SizedBox(height: 8),
                TextField(
                  onSubmitted: (val) {
                    if (val.isNotEmpty) {
                      setDialogState(() => selectedTags.add(val));
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Add Topic Tag (Enter to add)',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (selectedTags.isNotEmpty)
                  Wrap(
                    spacing: 4,
                    children: selectedTags
                        .map((t) => Chip(
                              label: Text(t),
                              onDeleted: () =>
                                  setDialogState(() => selectedTags.remove(t)),
                            ))
                        .toList(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => _createThread(titleController.text,
                  bodyController.text, selectedCategory, selectedTags, isPrivate ? 'private' : 'public'),
              child: const Text('Start Discussion'),
            ),
          ],
        ),
      ),
    );
  }
  List<Thread> _getCurrentThreads() {
    if (_isSearching) return searchResults;
    return threads;
  }
  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isDesktop = screenSize.width > 1200;
    final padding = isDesktop ? 24.0 : isTablet ? 16.0 : 12.0;
    if (username == null || username!.isEmpty) {
      return Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final responsivePadding = EdgeInsets.symmetric(
              horizontal: constraints.maxWidth > 600 ? 48.0 : 24.0,
            );
            return Center(
              child: Padding(
                padding: responsivePadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedRoundTableIcon(
                      size: constraints.maxWidth > 600 ? 120 : 80,
                      color: Colors.grey,
                    ),
                    SizedBox(height: constraints.maxWidth > 600 ? 24 : 16),
                    Text(
                      'Please wait to join the roundtable',
                      style: TextStyle(
                        fontSize: constraints.maxWidth > 600 ? 22 : 18,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: constraints.maxWidth > 600 ? 12 : 8),
                    Text(
                      'Check your connection and try again',
                      style: TextStyle(
                        fontSize: constraints.maxWidth > 600 ? 16 : 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: constraints.maxWidth > 600 ? 32 : 24),
                    ElevatedButton.icon(
                      onPressed: _loadUsernameAndUserId,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
    // Modern color palette
    const primaryColor = Color(0xFF1E3A5F); // Deep navy blue
    const secondaryColor = Color(0xFF2D5AA0); // Medium blue
    const accentColor = Color(0xFF4A90E2); // Light blue
    const surfaceColor = Color(0xFFF8F9FA); // Light gray
    const cardColor = Colors.white;
    final currentThreads = _getCurrentThreads();
    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: _isSearching && !isMyView
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search threads...',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                  ),
                ),
                onSubmitted: _onSearchChanged,
                style: const TextStyle(color: Colors.white),
              )
            : TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: const [
                  Tab(text: 'Discover'),
                  Tab(text: 'My Roundtables'),
                ],
              ),
        elevation: 0,
        backgroundColor: primaryColor,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [primaryColor, secondaryColor],
            ),
          ),
        ),
        actions: [
          if (!_isSearching && !isMyView)
            IconButton(
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
              icon: const Icon(Icons.search, color: Colors.white),
            ),
          if (!_isSearching && !isMyView) ...[
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort, color: Colors.white),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {
                setState(() {
                  sort = value;
                });
                _fetchThreads(reset: true);
              },
              itemBuilder: (context) => ['Recent', 'Trending', 'Innovative']
                  .map((s) => PopupMenuItem(
                        value: s.toLowerCase(),
                        child: Text(s, style: const TextStyle(fontSize: 14)),
                      ))
                  .toList(),
            ),
            IconButton(
              onPressed: _showCreateDialog,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 20),
              ),
            ),
          ],
          IconButton(
            onPressed: _joinWithCode,
            icon: const Icon(Icons.lock_open, color: Colors.white),
            tooltip: 'Join Private Thread',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Discover Tab
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth =
                  isDesktop ? 1200.0 : isTablet ? 800.0 : double.infinity;
              return FadeTransition(
                opacity: _fadeAnimation,
                child: isLoading
                    ? RefreshIndicator(
                        onRefresh: () => _fetchThreads(reset: true),
                        color: const Color(0xFF4A90E2),
                        strokeWidth: 2.5,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding:
                              const EdgeInsets.only(bottom: 80), // Space for FAB
                          itemCount: 5,
                          itemBuilder: (context, index) => Shimmer.fromColors(
                            baseColor: Colors.grey[300]!,
                            highlightColor: Colors.grey[100]!,
                            child: Card(
                              margin: EdgeInsets.symmetric(
                                horizontal: padding,
                                vertical: 6,
                              ),
                              child: SizedBox(
                                  height: 120,
                                  child: Container(color: Colors.white)),
                            ),
                          ),
                        ),
                      )
                    : hasError
                        ? RefreshIndicator(
                            onRefresh: _initializeData, // Retry full load
                            color: Colors.blue,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline,
                                          size: 80, color: Colors.red[300]),
                                      const SizedBox(height: 16),
                                      Text(
                                        errorMessage ?? 'An unknown error occurred',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 24),
                                      ElevatedButton.icon(
                                        onPressed: _initializeData,
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        : currentThreads.isEmpty
                            ? RefreshIndicator(
                                onRefresh: () {
                                  if (_isSearching) {
                                    _onSearchChanged(_searchController.text);
                                    return Future.value();
                                  } else {
                                    return _fetchThreads(reset: true);
                                  }
                                },
                                color: Colors.blue,
                                child: SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const AnimatedRoundTableIcon(
                                              size: 80, color: Colors.grey),
                                          const SizedBox(height: 16),
                                          Text(
                                            _isSearching ? 'No results found' : 'No roundtables yet',
                                            style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _isSearching ? 'Try a different search term.' : 'Start the conversation!',
                                            style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey[600]),
                                          ),
                                          const SizedBox(height: 24),
                                          ElevatedButton.icon(
                                            onPressed: _isSearching ? _clearSearch : _showCreateDialog,
                                            icon: const Icon(Icons.add),
                                            label: Text(_isSearching ? 'Clear Search' : 'Start Roundtable'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () {
                                  if (_isSearching) {
                                    _onSearchChanged(_searchController.text);
                                    return Future.value();
                                  } else {
                                    return _fetchThreads(reset: true);
                                  }
                                },
                                color: Colors.blue,
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: maxWidth),
                                    child: ListView.builder(
                                        controller: _scrollController,
                                        padding: EdgeInsets.fromLTRB(
                                          padding,
                                          padding,
                                          padding,
                                          padding +
                                              80,
                                        ),
                                        itemCount: currentThreads.length +
                                            (isLoadingMore ? 1 : 0),
                                        itemBuilder: (context, index) {
                                          if (index == currentThreads.length) {
                                            return const Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(16),
                                                child: CircularProgressIndicator(),
                                              ),
                                            );
                                          }
                                          final thread = currentThreads[index];
                                          final slideAnimation =
                                              _slideAnimations.length > index
                                                  ? _slideAnimations[index]
                                                  : const AlwaysStoppedAnimation(
                                                      0.0);
                                          return AnimatedBuilder(
                                            animation: slideAnimation,
                                            builder: (context, child) {
                                              // Mobile-optimized padding
                                              final cardPadding = isDesktop
                                                  ? 24.0
                                                  : isTablet
                                                      ? 20.0
                                                      : 16.0;
                                              return Transform.translate(
                                                offset: Offset(
                                                    slideAnimation.value * 100, 0),
                                                child: Opacity(
                                                  opacity: (slideAnimation.value +
                                                          1.0)
                                                      .clamp(0.0, 1.0),
                                                  child: _buildThreadCard(
                                                    thread,
                                                    isDesktop,
                                                    isTablet,
                                                    cardPadding,
                                                    username ?? '',
                                                    cardColor,
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        }),
                                  ),
                                ),
                              ),
              );
            },
          ),
          // My Roundtables Tab
          LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth =
                  isDesktop ? 1200.0 : isTablet ? 800.0 : double.infinity;
              return FadeTransition(
                opacity: _fadeAnimation,
                child: isLoading
                    ? RefreshIndicator(
                        onRefresh: () => _fetchThreads(reset: true),
                        color: const Color(0xFF4A90E2),
                        strokeWidth: 2.5,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding:
                              const EdgeInsets.only(bottom: 80), // Space for FAB
                          itemCount: 5,
                          itemBuilder: (context, index) => Shimmer.fromColors(
                            baseColor: Colors.grey[300]!,
                            highlightColor: Colors.grey[100]!,
                            child: Card(
                              margin: EdgeInsets.symmetric(
                                horizontal: padding,
                                vertical: 6,
                              ),
                              child: SizedBox(
                                  height: 120,
                                  child: Container(color: Colors.white)),
                            ),
                          ),
                        ),
                      )
                    : hasError
                        ? RefreshIndicator(
                            onRefresh: _initializeData, // Retry full load
                            color: Colors.blue,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error_outline,
                                          size: 80, color: Colors.red[300]),
                                      const SizedBox(height: 16),
                                      Text(
                                        errorMessage ?? 'An unknown error occurred',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      const SizedBox(height: 24),
                                      ElevatedButton.icon(
                                        onPressed: _initializeData,
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        : currentThreads.isEmpty
                            ? RefreshIndicator(
                                onRefresh: () => _fetchThreads(reset: true),
                                color: Colors.blue,
                                child: SingleChildScrollView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const AnimatedRoundTableIcon(
                                              size: 80, color: Colors.grey),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'No roundtables created yet',
                                            style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Start your first discussion!',
                                            style: TextStyle(fontSize: 16,
                                                color: Colors.grey),
                                          ),
                                          const SizedBox(height: 24),
                                          ElevatedButton.icon(
                                            onPressed: _showCreateDialog,
                                            icon: const Icon(Icons.add),
                                            label: const Text('Create Roundtable'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: () => _fetchThreads(reset: true),
                                color: Colors.blue,
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: maxWidth),
                                    child: ListView.builder(
                                        controller: _scrollController,
                                        padding: EdgeInsets.fromLTRB(
                                          padding,
                                          padding,
                                          padding,
                                          padding +
                                              80,
                                        ),
                                        itemCount: currentThreads.length +
                                            (isLoadingMore ? 1 : 0),
                                        itemBuilder: (context, index) {
                                          if (index == currentThreads.length) {
                                            return const Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(16),
                                                child: CircularProgressIndicator(),
                                              ),
                                            );
                                          }
                                          final thread = currentThreads[index];
                                          final slideAnimation =
                                              _slideAnimations.length > index
                                                  ? _slideAnimations[index]
                                                  : const AlwaysStoppedAnimation(
                                                      0.0);
                                          return AnimatedBuilder(
                                            animation: slideAnimation,
                                            builder: (context, child) {
                                              // Mobile-optimized padding
                                              final cardPadding = isDesktop
                                                  ? 24.0
                                                  : isTablet
                                                      ? 20.0
                                                      : 16.0;
                                              return Transform.translate(
                                                offset: Offset(
                                                    slideAnimation.value * 100, 0),
                                                child: Opacity(
                                                  opacity: (slideAnimation.value +
                                                          1.0)
                                                      .clamp(0.0, 1.0),
                                                  child: _buildThreadCard(
                                                    thread,
                                                    isDesktop,
                                                    isTablet,
                                                    cardPadding,
                                                    username ?? '',
                                                    cardColor,
                                                    isMy: true,
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        }),
                                  ),
                                ),
                              ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: !isMyView
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A90E2), Color(0xFF2D5AA0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A90E2).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: _showCreateDialog,
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: const Icon(Icons.add, color: Colors.white, size: 28),
              ),
            )
          : null,
      extendBody: true, // Allow FAB to extend over body for mobile
    );
  }
  Widget _buildThreadCard(Thread thread, bool isDesktop, bool isTablet, double cardPadding, String currentUser, Color cardColor, {bool isMy = false}) {
    return Hero(
      tag: 'thread_${thread.id}', // For smooth navigation animation
      child: Card(
        margin: EdgeInsets.symmetric(
          horizontal: isDesktop
              ? 12
              : isTablet
                  ? 10
                  : 8,
          vertical: isDesktop
              ? 12
              : isTablet
                  ? 8
                  : 6,
        ),
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
                    isDesktop
                        ? 20
                        : 16)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius:
                BorderRadius.circular(
                    isDesktop
                        ? 20
                        : 16),
            splashColor:
                const Color(
                        0xFF4A90E2)
                    .withOpacity(0.1),
            highlightColor:
                const Color(
                        0xFF4A90E2)
                    .withOpacity(0.05),
            onTap: () =>
                Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context,
                        animation,
                        secondaryAnimation) =>
                    ThreadDetailScreen(
                  thread: thread,
                  username:
                      currentUser,
                  userId: userId ?? 0,
                ),
                transitionDuration:
                    const Duration(
                        milliseconds:
                            400),
                reverseTransitionDuration:
                    const Duration(
                        milliseconds:
                            300),
                transitionsBuilder:
                    (context,
                        animation,
                        secondaryAnimation,
                        child) {
                  return FadeTransition(
                    opacity:
                        animation,
                    child:
                        SlideTransition(
                      position: Tween<Offset>(
                        begin:
                            const Offset(
                                0.0,
                                0.1),
                        end: Offset
                            .zero,
                      ).animate(
                          CurvedAnimation(
                        parent:
                            animation,
                        curve: Curves
                            .easeOutCubic,
                      )),
                      child: child,
                    ),
                  );
                },
              ),
            ),
            child: Container(
              padding:
                  EdgeInsets.all(
                      cardPadding),
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius
                        .circular(isDesktop
                            ? 20
                            : 16),
                color: cardColor,
                border: Border.all(
                  color:
                      const Color(
                          0xFFE5E9F0),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                            0xFF1E3A5F)
                        .withOpacity(
                            0.08),
                    blurRadius: 20,
                    offset:
                        const Offset(
                            0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Container(
                        padding:
                            EdgeInsets.all(isDesktop
                                ? 10
                                : isTablet
                                    ? 9
                                    : 8),
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(0xFF4A90E2)
                                  .withOpacity(
                                      0.1),
                          borderRadius:
                              BorderRadius.circular(
                                  isDesktop
                                      ? 14
                                      : 12),
                        ),
                        child:
                            AnimatedRoundTableIcon(
                                size: isDesktop
                                    ? 28
                                    : isTablet
                                        ? 26
                                        : 24),
                      ),
                      SizedBox(
                          width:
                              isDesktop
                                  ? 16
                                  : isTablet
                                      ? 14
                                      : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    thread
                                        .title,
                                    style:
                                        TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: isDesktop ? 20 : isTablet ? 18 : 17,
                                      color:
                                          const Color(0xFF1E3A5F),
                                      height:
                                          1.3,
                                      letterSpacing:
                                          -0.3,
                                    ),
                                  ),
                                ),
                                if (thread.visibility == 'private')
                                  const Icon(Icons.lock, size: 16, color: Colors.grey),
                              ],
                            ),
                            SizedBox(height: isDesktop ? 10 : isTablet ? 9 : 8),
                            Text(
                              thread
                                  .body,
                              maxLines:
                                  isDesktop ? 4 : isTablet ? 3 : 3,
                              overflow:
                                  TextOverflow.ellipsis,
                              style:
                                  TextStyle(
                                color:
                                    const Color(0xFF6B7280),
                                fontSize: isDesktop ? 15 : isTablet ? 14 : 14,
                                height:
                                    1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                      height:
                          isDesktop
                              ? 16
                              : 14),
                  Wrap(
                    spacing: isDesktop
                        ? 10
                        : 6,
                    runSpacing:
                        isDesktop
                            ? 10
                            : 6,
                    children: [
                      Container(
                        padding: EdgeInsets
                            .symmetric(
                          horizontal:
                              isDesktop
                                  ? 14
                                  : 10,
                          vertical:
                              isDesktop
                                  ? 6
                                  : 4,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(0xFF4A90E2)
                                  .withOpacity(
                                      0.1),
                          borderRadius:
                              BorderRadius.circular(20),
                          border:
                              Border
                                  .all(
                            color:
                                const Color(0xFF4A90E2).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          thread
                              .category,
                          style:
                              TextStyle(
                            fontSize:
                                isDesktop
                                    ? 13
                                    : 11,
                            fontWeight:
                                FontWeight.w600,
                            color:
                                const Color(0xFF2D5AA0),
                          ),
                        ),
                      ),
                      ...thread.tags
                          .take(isDesktop
                              ? 3
                              : 2)
                          .map((t) =>
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isDesktop ? 12 : 8,
                                  vertical: isDesktop ? 6 : 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child:
                                    Text(
                                  '#$t',
                                  style:
                                      TextStyle(
                                    fontSize: isDesktop ? 12 : 10,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        const Color(0xFF059669),
                                  ),
                                ),
                              )),
                      if (thread.tags
                              .length >
                          (isDesktop
                              ? 3
                              : 2))
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 12 : 8,
                            vertical: isDesktop ? 6 : 4,
                          ),
                          decoration:
                              BoxDecoration(
                            color: const Color(
                                0xFFE5E9F0),
                            borderRadius:
                                BorderRadius.circular(20),
                          ),
                          child: Text(
                            '+${thread.tags.length - (isDesktop ? 3 : 2)}',
                            style:
                                TextStyle(
                              fontSize:
                                  isDesktop ? 12 : 10,
                              fontWeight:
                                  FontWeight.w500,
                              color:
                                  const Color(0xFF6B7280),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (isMy && thread.visibility == 'private' && thread.inviteCode != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Code: ${thread.inviteCode}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: thread.inviteCode!));
                                _showSuccess('Code copied!');
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(
                      height:
                          isDesktop
                              ? 16
                              : 12),
                  Row(
                    children: [
                      Icon(
                        Icons
                            .person_outline,
                        size:
                            isDesktop
                                ? 16
                                : 14,
                        color:
                            const Color(
                                0xFF9CA3AF),
                      ),
                      SizedBox(
                          width:
                              isDesktop
                                  ? 6
                                  : 4),
                      Text(
                        '${thread.creatorRole.isNotEmpty ? '${thread.creatorRole} • ' : ''}${thread.creator}',
                        style:
                            TextStyle(
                          fontSize:
                              isDesktop
                                  ? 13
                                  : 11,
                          color:
                              const Color(
                                  0xFF6B7280),
                          fontWeight:
                              FontWeight
                                  .w500,
                        ),
                      ),
                      SizedBox(
                          width:
                              isDesktop
                                  ? 12
                                  : 8),
                      Container(
                        width: 4,
                        height: 4,
                        decoration:
                            const BoxDecoration(
                          color: Color(
                              0xFFD1D5DB),
                          shape:
                              BoxShape
                                  .circle,
                        ),
                      ),
                      SizedBox(
                          width:
                              isDesktop
                                  ? 12
                                  : 8),
                      Icon(
                        Icons
                            .calendar_today_outlined,
                        size:
                            isDesktop
                                ? 14
                                : 12,
                        color:
                            const Color(
                                0xFF9CA3AF),
                      ),
                      SizedBox(
                          width:
                              isDesktop
                                  ? 6
                                  : 4),
                      Text(
                        thread
                            .createdAt
                            .toString()
                            .split(
                                ' ')[0],
                        style:
                            TextStyle(
                          fontSize:
                              isDesktop
                                  ? 13
                                  : 11,
                          color:
                              const Color(
                                  0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                      height:
                          isDesktop
                              ? 16
                              : 12),
                  
                  Padding(
                    padding: EdgeInsets.only(
                        top: isDesktop
                            ? 4
                            : isTablet
                                ? 3
                                : 2),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment
                              .spaceEvenly,
                      children: [
                        Expanded(
                          child:
                              _ActionButton(
                            icon: Icons
                                .lightbulb_outline,
                            label:
                                '${thread.inspiredCount}',
                            iconSize:
                                isDesktop ? 24 : isTablet ? 22 : 20,
                            fontSize:
                                isDesktop ? 14 : 13,
                            onTap: () =>
                                _toggleInspire(thread.id),
                          ),
                        ),
                        SizedBox(width: isDesktop ? 12 : isTablet ? 10 : 8),
                        Expanded(
                          child:
                              _ActionButton(
                            icon: Icons
                                .comment_outlined,
                            label:
                                '${thread.commentCount}',
                            iconSize:
                                isDesktop ? 24 : isTablet ? 22 : 20,
                            fontSize:
                                isDesktop ? 14 : 13,
                            onTap:
                                () =>
                                    Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) => ThreadDetailScreen(
                                  thread: thread,
                                  username: currentUser,
                                  userId: userId ?? 0,
                                ),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  return SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(1.0, 0.0),
                                      end: Offset.zero,
                                    ).animate(CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeInOut,
                                    )),
                                    child: child,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: isDesktop ? 12 : isTablet ? 10 : 8),
                        Expanded(
                          child:
                              _ActionButton(
                            icon: Icons
                                .people_outline,
                            label:
                                '${thread.collabCount}',
                            iconSize:
                                isDesktop ? 24 : isTablet ? 22 : 20,
                            fontSize:
                                isDesktop ? 14 : 13,
                            onTap: () =>
                                _sendCollab(thread.id, 'Interested in discussing!'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- No changes to this class ---
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final double? iconSize;
  final double? fontSize;
  final Color? iconColor;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconSize,
    this.fontSize,
    this.iconColor,
  });
  @override
  Widget build(BuildContext context) {
    final defaultIconColor = iconColor ?? const Color(0xFF6B7280);
    final isDesktop = MediaQuery.of(context).size.width > 1200;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 16 : 12,
            vertical: isDesktop ? 10 : 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFE5E9F0),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: iconSize ?? 18,
                color: defaultIconColor,
              ),
              SizedBox(width: iconSize != null && iconSize! > 20 ? 8 : 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: fontSize ?? 13,
                  fontWeight: FontWeight.w600,
                  color: defaultIconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ThreadDetailScreen extends StatefulWidget {
  final Thread thread;
  final String username;
  final int userId;
  const ThreadDetailScreen({
    super.key,
    required this.thread,
    required this.username,
    required this.userId,
  });
  @override
  _ThreadDetailScreenState createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends State<ThreadDetailScreen>
    with TickerProviderStateMixin {
  List<Comment> comments = [];
  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;
  final TextEditingController _commentController = TextEditingController();
  late AnimationController _detailAnimationController;
  late Animation<double> _detailFadeAnimation;
  late AnimationController _rotationController;
  double _rotationAngle = 0.0;
  final ScrollController _commentsScrollController = ScrollController();
  bool isLoadingMoreComments = false;
  int commentsOffset = 0;
  final int commentsLimit = 20;
  Timer? _commentsScrollDebounceTimer;
  Timer? _commentsRetryTimer;
  int _commentsRetryCount = 0;
  static const int _commentsMaxRetries = 3;
  http.Client? _commentsHttpClient;
  bool _hasReachedMaxComments = false;
  // --- New UI State ---
  final Color _pageColor = const Color(0xFFFDFBF5); // Parchment paper color
  final Color _cardColor = Colors.white;
  final Color _primaryTextColor = const Color(0xFF1a2533);
  final Color _secondaryTextColor = const Color(0xFF6B7280);
  bool _isRoundtable = true; // Toggles between circle and list view
  int? _replyToCommentId; // Tracks which comment we are replying to
  final FocusNode _commentFocusNode = FocusNode();
  @override
  void initState() {
    super.initState();
    _commentsHttpClient = http.Client();
    _detailAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _detailFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _detailAnimationController, curve: Curves.easeInOut),
    );
    _detailAnimationController.forward();
    _setupCommentsScrollListener();
    _loadComments(reset: true);
    _syncInspireStatus();
  }
  Future<void> _syncInspireStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'inspired_${widget.thread.id}';
    if (prefs.containsKey(key)) {
      widget.thread.isInspiredByMe = prefs.getBool(key) ?? false;
      if (mounted) setState(() {});
      return;
    }
    // Sync from server
    try {
      final code = await _getThreadCode(widget.thread.id);
      final uri = Uri.parse('https://server.awarcrown.com/threads/inspire?id=${widget.thread.id}');
      final body = json.encode({
        'type': 'check',
        'username': widget.username,
        if (code != null) 'code': code,
      });
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final bool inspired = data['user_has_inspired'] ?? false;
        await prefs.setBool(key, inspired);
        widget.thread.isInspiredByMe = inspired;
        widget.thread.inspiredCount = data['inspired_count'] ?? widget.thread.inspiredCount;
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to sync inspire status: $e');
    }
  }
  Future<String?> _getThreadCode(int threadId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('code_$threadId');
  }
  Future<void> _setThreadCode(int threadId, String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('code_$threadId', code);
  }
  void _setupCommentsScrollListener() {
    _commentsScrollController.addListener(_onCommentsScroll);
  }
  void _onCommentsScroll() {
    _commentsScrollDebounceTimer?.cancel();
    _commentsScrollDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!_commentsScrollController.hasClients) return;
      final position = _commentsScrollController.position;
      if (position.pixels >= position.maxScrollExtent - 200) {
        if (!isLoadingMoreComments && !hasError && !_hasReachedMaxComments) {
          _loadMoreComments();
        }
      }
    });
  }
  @override
  void dispose() {
    _commentsScrollDebounceTimer?.cancel();
    _commentsRetryTimer?.cancel();
    _commentsScrollController.removeListener(_onCommentsScroll);
    _commentsScrollController.dispose();
    _detailAnimationController.dispose();
    _rotationController.dispose();
    _commentController.dispose();
    _commentsHttpClient?.close();
    _commentFocusNode.dispose();
    super.dispose();
  }
  Future<void> _loadComments({bool reset = false}) async {
    if (widget.username.isEmpty) {
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = 'Please log in to view comments';
        });
        _showError('Please log in to view comments');
      }
      return;
    }
    if (reset) {
      commentsOffset = 0;
      comments.clear();
      isLoadingMoreComments = false;
    }
    if (mounted) {
      setState(() {
        if (reset) {
          isLoading = true;
          hasError = false;
        } else {
          isLoadingMoreComments = true;
        }
      });
    }
    try {
      final code = await _getThreadCode(widget.thread.id);
      final uri = Uri.parse(
          'https://server.awarcrown.com/threads/comments?id=${widget.thread.id}&username=${Uri.encodeComponent(widget.username)}&limit=$commentsLimit&offset=$commentsOffset${code != null ? '&code=${Uri.encodeComponent(code)}' : ''}');
      final response = await (_commentsHttpClient ?? http.Client())
          .get(uri)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final commentList = data['comments'] as List<dynamic>? ?? [];
        final commentMap = <int, List<Map<String, dynamic>>>{};
        for (var c in commentList) {
          if (c is Map<String, dynamic>) {
            final parentId = c['parent_comment_id'] as int?;
            if (parentId != null) {
              commentMap.putIfAbsent(parentId, () => []).add(c);
            }
          }
        }
        final topLevelComments = <Comment>[];
        for (final c in commentList) {
          if (c is Map<String, dynamic> && c['parent_comment_id'] == null) {
            try {
              topLevelComments.add(Comment.fromJson(c, commentMap));
            } catch (e) {
              debugPrint('Error parsing top-level comment: $e');
            }
          }
        }
        if (mounted) {
          setState(() {
            if (reset) {
              comments = topLevelComments;
              isLoading = false;
            } else {
              comments.addAll(topLevelComments);
              isLoadingMoreComments = false;
            }
            commentsOffset += topLevelComments.length;
            _hasReachedMaxComments = topLevelComments.length < commentsLimit;
            _commentsRetryCount = 0;
          });
        }
      } else if (response.statusCode == 403) {
        _showError('Access denied. Invalid code for private thread.');
      } else if (response.statusCode == 404) {
        if (mounted) {
          setState(() {
            _hasReachedMaxComments = true;
            isLoadingMoreComments = false;
            if (reset) isLoading = false;
          });
        }
      } else {
        throw Exception(
            'Failed to load comments: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (reset) {
            isLoading = false;
            hasError = true;
            errorMessage = 'Failed to load comments: ${_getErrorMessage(e)}';
          } else {
            isLoadingMoreComments = false;
          }
        });
        if (reset) {
          _scheduleCommentsRetry(() => _loadComments(reset: true));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load comments: ${_getErrorMessage(e)}'),
              action: SnackBarAction(
                label: 'Retry Now',
                onPressed: () {
                  _commentsRetryCount = 0;
                  _loadComments(reset: true);
                },
              ),
            ),
          );
        } else {
          _showError('Failed to load more comments: ${_getErrorMessage(e)}');
        }
      }
    }
  }
  void _scheduleCommentsRetry(Future<void> Function() retryFunction) {
    if (_commentsRetryCount >= _commentsMaxRetries) return;
    _commentsRetryTimer?.cancel();
    _commentsRetryCount++;
    final delay = Duration(seconds: 2) *
        (1 << (_commentsRetryCount - 1)); // Exponential backoff
    _commentsRetryTimer = Timer(delay, () {
      if (mounted && !isLoading && !isLoadingMoreComments) {
        retryFunction();
      }
    });
  }
  Future<void> _loadMoreComments() async {
    await _loadComments(reset: false);
  }
  String _getErrorMessage(dynamic e) {
    if (e is SocketException) {
      return 'No internet connection. Please check your connection and try again.';
    } else if (e is TimeoutException) {
      return 'Request timed out. Please check your connection and try again.';
    } else if (e is http.ClientException) {
      return 'Network error occurred. Please try again.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  // --- Modified to support replying to a specific parentId ---
  Future<void> _addComment(String body, {int? parentId}) async {
    if (widget.username.isEmpty) {
      if (mounted) {
        _showError('Please log in to comment');
      }
      return;
    }
    if (body.isEmpty) {
      if (mounted) {
        _showError('Comment cannot be empty');
      }
      return;
    }
    try {
      final code = await _getThreadCode(widget.thread.id);
      final bodyData = json.encode({
        'body': body,
        'parent_id': parentId ?? 0,
        'username': widget.username,
        if (code != null) 'code': code,
      });
      final uri = Uri.parse(
          'https://server.awarcrown.com/threads/comments?id=${widget.thread.id}');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        _commentController.clear();
        _commentFocusNode.unfocus();
        setState(() {
          _replyToCommentId = null;
        });
        await _loadComments(reset: true); // Refresh comments
      } else {
        throw Exception('Failed to add comment: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to add comment: ${_getErrorMessage(e)}');
      }
    }
  }
  // --- New helper function for the new comment bar ---
  void _submitComment() {
    if (_commentController.text.isNotEmpty) {
      _addComment(
        _commentController.text,
        parentId: _replyToCommentId,
      );
    }
  }
  // --- New helper function to handle reply-to ---
  void _onReplyTapped(Comment comment) {
    setState(() {
      _replyToCommentId = comment.id;
      _commentController.text = '@${comment.commenter} ';
      _commentController.selection = TextSelection.fromPosition(
          TextPosition(offset: _commentController.text.length));
      _commentFocusNode.requestFocus();
    });
  }
  Future<void> _sendCollab(int threadId, String message) async {
    if (widget.username.isEmpty) return;
    final oldCount = widget.thread.collabCount;
    widget.thread.collabCount++;
    if (mounted) setState(() {});
    try {
      final code = await _getThreadCode(threadId);
      final bodyData = json.encode({
        'message': message,
        'username': widget.username,
        if (code != null) 'code': code,
      });
      final uri = Uri.parse('https://server.awarcrown.com/threads/collab?id=$threadId');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = json.decode(response.body);
          if (data is Map<String, dynamic> &&
              data.containsKey('collab_count')) {
            widget.thread.collabCount = data['collab_count'];
          }
        } catch (_) {
          // Keep optimistic update
        }
        if (mounted) {
          _showSuccess('Joined the roundtable!');
        }
      } else {
        throw Exception('Failed to join roundtable: ${response.statusCode}');
      }
    } catch (e) {
      widget.thread.collabCount = oldCount;
      if (mounted) setState(() {});
      if (mounted) {
        _showError('Failed to join roundtable: ${_getErrorMessage(e)}');
      }
    }
  }
  Future<void> _toggleInspire(int threadId) async {
    if (widget.username.isEmpty) return;
    final oldCount = widget.thread.inspiredCount;
    final oldInspired = widget.thread.isInspiredByMe;
    // Toggle state optimistically
    final newInspired = !oldInspired;
    widget.thread.isInspiredByMe = newInspired;
    widget.thread.inspiredCount += newInspired ? 1 : -1;
    if (mounted) setState(() {});
    try {
      final code = await _getThreadCode(threadId);
      final bodyData = json.encode({
        'type': newInspired ? 'inspired' : 'uninspired',
        'username': widget.username,
        if (code != null) 'code': code,
      });
      final uri = Uri.parse('https://server.awarcrown.com/threads/inspire?id=$threadId');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      ).timeout(const Duration(seconds: 10));
      final prefs = await SharedPreferences.getInstance();
      final key = 'inspired_$threadId';
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (data.containsKey('inspired_count')) {
            widget.thread.inspiredCount = data['inspired_count'];
          }
          if (data.containsKey('user_has_inspired')) {
            widget.thread.isInspiredByMe = data['user_has_inspired'] as bool;
          }
          await prefs.setBool(key, widget.thread.isInspiredByMe);
          _showSuccess(data['message'] ?? (newInspired ? 'Inspired by this discussion!' : 'Uninspired.'));
        } else {
          // Revert optimistic update
          widget.thread.isInspiredByMe = oldInspired;
          widget.thread.inspiredCount = oldCount;
          await prefs.setBool(key, oldInspired);
          if (mounted) setState(() {});
          _showSuccess(data['message'] ?? 'No change');
        }
      } else {
        throw Exception('Failed to toggle inspire: ${response.statusCode}');
      }
    } catch (e) {
      // Revert optimistic update
      widget.thread.isInspiredByMe = oldInspired;
      widget.thread.inspiredCount = oldCount;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('inspired_$threadId', oldInspired);
      if (mounted) setState(() {});
      if (mounted) {
        _showError('Failed to toggle inspire: ${_getErrorMessage(e)}');
      }
    }
  }
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  // --- This is your original cool circular layout, unmodified ---
  Widget _buildCircularCommentLayout() {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;
    final isDesktop = screenSize.width > 1200;
    // For scalability, cap the circular view to first 20 comments; show "View more" for rest
    final displayComments = comments.take(20).toList();
    final hasMore = comments.length > 20 || !_hasReachedMaxComments;
    final ringRadius = isDesktop ? 160.0 : isTablet ? 140.0 : 120.0;
    // --- FIX: Use LayoutBuilder for robust centering ---
    return LayoutBuilder(builder: (context, constraints) {
      final center = Offset(
          constraints.maxWidth / 2, isDesktop ? 250.0 : isTablet ? 220.0 : 200.0);
      return Column(
        children: [
          GestureDetector(
            onPanUpdate: (details) {
              if (mounted) {
                setState(() {
                  _rotationAngle += details.delta.dx / 100;
                });
              }
            },
            child: SizedBox(
              height: isDesktop ? 600 : isTablet ? 550 : 500,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Central table
                  const AnimatedRoundTableIcon(size: 100),
                  // Comments in ring
                  ...displayComments.asMap().entries.map((entry) {
                    final index = entry.key;
                    final comment = entry.value;
                    final angle =
                        (2 * pi / displayComments.length * index) + _rotationAngle;
                    final x = center.dx + ringRadius * cos(angle);
                    final y = center.dy + ringRadius * sin(angle);
                    return Positioned(
                      left: x - 80, // Adjust for card width
                      top: y - 60, // Adjust for card height
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 600 + (index * 100)),
                        builder: (context, value, child) {
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001) // Perspective for 3D-ish
                              ..rotateY((1 - value) * pi / 4) // Flip in like cards
                              ..rotateZ(angle),
                            child: Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(
                                    0, (1 - value) * 50), // Rise from bottom
                                child: Card(
                                  child: Container(
                                    width: isDesktop
                                        ? 200
                                        : isTablet
                                            ? 180
                                            : 160,
                                    padding: EdgeInsets.all(
                                        isDesktop ? 12 : isTablet ? 10 : 8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          children: [
                                            CircleAvatar(
                                              radius: isDesktop
                                                  ? 14
                                                  : isTablet
                                                      ? 12
                                                      : 10,
                                              backgroundColor:
                                                  Colors.blue[100],
                                              child: Text(
                                                comment.commenter.isNotEmpty
                                                    ? comment.commenter[0]
                                                        .toUpperCase()
                                                    : '?',
                                                style: TextStyle(
                                                  fontSize: isDesktop
                                                      ? 14
                                                      : isTablet
                                                          ? 12
                                                          : 10,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: isDesktop ? 8 : 4),
                                            Expanded(
                                              child: Text(
                                                comment.commenter,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: isDesktop
                                                      ? 14
                                                      : isTablet
                                                          ? 13
                                                          : 12,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: isDesktop ? 6 : 4),
                                        Text(
                                          comment.body,
                                          style: TextStyle(
                                              fontSize: isDesktop
                                                  ? 13
                                                  : isTablet
                                                      ? 12
                                                      : 11),
                                          maxLines: isDesktop ? 4 : 3,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (comment.replies.isNotEmpty) ...[
                                          SizedBox(height: isDesktop ? 6 : 4),
                                          Text(
                                            '${comment.replies.length} replies',
                                            style: TextStyle(
                                              fontSize: isDesktop
                                                  ? 12
                                                  : isTablet
                                                      ? 11
                                                      : 10,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          if (hasMore)
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _loadMoreComments,
                icon: const Icon(Icons.expand_more),
                label: const Text('View More Comments'),
              ),
            ),
        ],
      );
    });
  }
  // --- New UI: A traditional list view for comments ---
  Widget _buildLinearCommentLayout() {
    return ListView.builder(
      itemCount: comments.length + (isLoadingMoreComments ? 1 : 0),
      controller: _commentsScrollController,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemBuilder: (context, index) {
        if (index == comments.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final comment = comments[index];
        return _CommentCard(
          comment: comment,
          onReply: _onReplyTapped,
        );
      },
    );
  }
  // --- New UI: Main comments section with view toggle ---
  Widget _buildCommentsSection() {
    if (isLoading) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        padding: EdgeInsets.zero,
        itemBuilder: (context, index) => Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child:
                SizedBox(height: 80, child: Container(color: Colors.white)),
          ),
        ),
      );
    } else if (hasError) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 50, color: Colors.red[300]),
              const SizedBox(height: 8),
              Text(errorMessage ?? 'Failed to load comments'),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _loadComments(reset: true),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    } else if (comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Center(
          child: Column(
            children: [
              AnimatedRoundTableIcon(size: 60, color: _secondaryTextColor),
              const SizedBox(height: 16),
              Text(
                'Be the first to comment',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _primaryTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Pull up a chair and share your thoughts!',
                style: TextStyle(fontSize: 14, color: _secondaryTextColor),
              ),
            ],
          ),
        ),
      );
    } else {
      // --- New UI: AnimatedSwitcher to toggle views ---
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: _isRoundtable
            ? _buildCircularCommentLayout()
            : _buildLinearCommentLayout(),
      );
    }
  }
  // --- New UI: Sticky comment input bar at the bottom ---
  Widget _buildCommentInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 +
          MediaQuery.of(context).padding.bottom), // Handle notch
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.blue[100],
            child: Text(
              widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: Colors.blue, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _commentController,
              focusNode: _commentFocusNode,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: _replyToCommentId == null
                    ? 'Pull up a chair...'
                    : 'Replying...',
                hintStyle: TextStyle(color: _secondaryTextColor),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide:
                      const BorderSide(color: Color(0xFF4A90E2), width: 2),
                ),
              ),
              onSubmitted: (_) => _submitComment(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Color(0xFF4A90E2)),
            onPressed: _submitComment,
          ),
        ],
      ),
    );
  }
  // --- New UI: Helper for action buttons in the header ---
  Widget _HeaderActionButton(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
  // --- New UI: Helper for creator info in the header ---
  Widget _buildHeaderInfo(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.white.withOpacity(0.3),
          child: Text(
            widget.thread.creator.isNotEmpty
                ? widget.thread.creator[0].toUpperCase()
                : '?',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.thread.creator,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${widget.thread.creatorRole.isNotEmpty ? '${widget.thread.creatorRole} • ' : ''}${widget.thread.createdAt.toString().split(' ')[0]}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            widget.thread.category.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }
  // --- New UI: Helper for tags in the header ---
  Widget _buildTags() {
    if (widget.thread.tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: widget.thread.tags
            .map((t) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '#$t',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1E3A5F);
    const secondaryColor = Color(0xFF2D5AA0);
    const accentColor = Color(0xFF4A90E2);
    final bool isInspired = widget.thread.isInspiredByMe;
    final Color inspireColor = isInspired ? const Color(0xFFF59E0B) : const Color(0xFF90F0C0);
    return Scaffold(
      // --- New UI: Page color and main Column layout ---
      backgroundColor: _pageColor,
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 450, // Made header larger for full content
                  floating: false,
                  pinned: true,
                  elevation: 2,
                  backgroundColor: primaryColor,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    // title: const Row(
                    // mainAxisSize: MainAxisSize.min,
                    // children: [
                    // AnimatedRoundTableIcon(size: 20, color: Colors.white),
                    // SizedBox(width: 8),
                    // Text(
                    // 'Roundtable',
                    // style: TextStyle(
                    // fontSize: 16, fontWeight: FontWeight.w600),
                    // ),
                    // ],
                    // ),
                    background: Hero(
                      tag: 'thread_${widget.thread.id}',
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [primaryColor, secondaryColor, accentColor],
                            stops: [0.0, 0.6, 1.0],
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                              16, MediaQuery.of(context).padding.top + 56, 16,
                              16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- New UI: All content moved to header ---
                              _buildHeaderInfo(context),
                              const SizedBox(height: 20),
                              Text(
                                widget.thread.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.thread.body,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 16,
                                  height: 1.6,
                                ),
                              ),
                              _buildTags(),
                              const Spacer(),
                              // --- New UI: Action buttons are now in header ---
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _HeaderActionButton(
                                      icon: isInspired ? Icons.lightbulb : Icons.lightbulb_outline,
                                      label: '${widget.thread.inspiredCount}',
                                      color: inspireColor,
                                      onTap: () =>
                                          _toggleInspire(widget.thread.id),
                                    ),
                                    _HeaderActionButton(
                                      icon: Icons.people_outline,
                                      label: '${widget.thread.collabCount}',
                                      color: const Color(0xFF81C7F5),
                                      onTap: () => _sendCollab(
                                          widget.thread.id,
                                          'Interested in joining!'),
                                    ),
                                    _HeaderActionButton(
                                      icon: Icons.comment_outlined,
                                      label: '${widget.thread.commentCount}',
                                      color: const Color(0xFF90F0C0),
                                      onTap: () {
                                        // Maybe scroll to comments?
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // --- New UI: Discussion card with toggle ---
                SliverToBoxAdapter(
                  child: FadeTransition(
                    opacity: _detailFadeAnimation,
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Discussion',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: _primaryTextColor,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    _isRoundtable
                                        ? Icons.view_list_rounded
                                        : Icons.track_changes_rounded,
                                    color: _secondaryTextColor,
                                  ),
                                  tooltip: _isRoundtable
                                      ? 'Show List View'
                                      : 'Show Roundtable View',
                                  onPressed: () {
                                    setState(() {
                                      _isRoundtable = !_isRoundtable;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          _buildCommentsSection(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // --- New UI: Sticky comment bar ---
          if (!isLoading && !hasError && widget.username.isNotEmpty)
            _buildCommentInputBar(),
        ],
      ),
    );
  }
}
// --- New UI: Card for List View comments ---
class _CommentCard extends StatelessWidget {
  final Comment comment;
  final bool isReply;
  final Function(Comment) onReply;
  const _CommentCard({
    required this.comment,
    this.isReply = false,
    required this.onReply,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: isReply ? 32.0 : 16.0, // Indent replies
        right: 16.0,
        top: 12.0,
        bottom: 4.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.blue[100],
                child: Text(
                  comment.commenter.isNotEmpty
                      ? comment.commenter[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.commenter,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Color(0xFF1a2533),
                      ),
                    ),
                    Text(
                      comment.createdAt.toString().split('.')[0],
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding:
                const EdgeInsets.only(left: 42.0, top: 8, bottom: 4),
            child: Text(
              comment.body, // Use _cardColor here
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF333D4B),
                height: 1.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30.0),
            child: TextButton(
              onPressed: () => onReply(comment),
              child: const Text(
                'Reply',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4A90E2),
                ),
              ),
            ),
          ),
        
          if (comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 12.0, top: 8.0),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: Color(0xFFE5E9F0),
                      width: 2.0,
                    ),
                  ),
                ),
                child: Column(
                  children: comment.replies
                      .map((reply) => _CommentCard(
                            comment: reply,
                            isReply: true,
                            onReply: onReply,
                          ))
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}