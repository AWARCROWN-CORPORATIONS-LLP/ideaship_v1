import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:ideaship/thr_project/thread_details.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lottie/lottie.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'create_roundtable_dialog.dart';

class Thread {
  final int id;
  final String title;
  final String body;
  final String category;
  final String creator;
  final String creatorRole;
  int inspiredCount;
  final int commentCount;
  final List<String> tags;
  final DateTime createdAt;
  bool isInspiredByMe;
  final String visibility;
  final String? inviteCode;
  final bool isFromCache;
  Thread({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.creator,
    required this.creatorRole,
    required this.inspiredCount,
    required this.commentCount,
    required this.tags,
    required this.createdAt,
    required this.isInspiredByMe,
    required this.visibility,
    this.inviteCode,
    this.isFromCache = false,
  });
  Thread copyWith({
    int? id,
    String? title,
    String? body,
    String? category,
    String? creator,
    String? creatorRole,
    int? inspiredCount,
    int? commentCount,
    List<String>? tags,
    DateTime? createdAt,
    bool? isInspiredByMe,
    String? visibility,
    String? inviteCode,
    bool? isFromCache,
  }) {
    return Thread(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      category: category ?? this.category,
      creator: creator ?? this.creator,
      creatorRole: creatorRole ?? this.creatorRole,
      inspiredCount: inspiredCount ?? this.inspiredCount,
      commentCount: commentCount ?? this.commentCount,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      isInspiredByMe: isInspiredByMe ?? this.isInspiredByMe,
      visibility: visibility ?? this.visibility,
      inviteCode: inviteCode ?? this.inviteCode,
      isFromCache: isFromCache ?? this.isFromCache,
    );
  }

  factory Thread.fromJson(
    Map<String, dynamic> json, {
    bool isFromCache = false,
  }) {
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
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        createdAt:
            DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        isInspiredByMe: json['user_has_inspired'] ?? false,
        visibility: json['visibility'] ?? 'public',
        inviteCode: json['invite_code'],
        isFromCache: isFromCache,
      );
    } catch (e) {
      debugPrint('Error parsing Thread from JSON: $e');
      return Thread(
        id: 0,
        title: '',
        body: '',
        category: '',
        creator: '',
        creatorRole: '',
        inspiredCount: 0,
        commentCount: 0,
        tags: [],
        createdAt: DateTime.now(),
        isInspiredByMe: false,
        visibility: 'public',
        isFromCache: isFromCache,
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
  final bool isFromCache;
  final String? imageUrl;
  Comment({
    required this.id,
    this.parentId,
    required this.body,
    required this.commenter,
    required this.createdAt,
    this.replies = const [],
    this.isFromCache = false,
    this.imageUrl,
  });
  factory Comment.fromJson(
    Map<String, dynamic> json, {
    bool isFromCache = false,
  }) {
    try {
      // Recursively parse replies if present (nested structure from backend)
      final List<Comment> replyComments =
          (json['replies'] as List<dynamic>? ?? [])
              .map(
                (r) => Comment.fromJson(
                  r as Map<String, dynamic>,
                  isFromCache: isFromCache,
                ),
              )
              .toList();
      return Comment(
        id: json['comment_id'] as int? ?? 0,
        parentId: json['parent_comment_id'] as int?,
        body: json['comment_body'] as String? ?? '',
        commenter: json['commenter_username'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now(),
        replies: replyComments,
        isFromCache: isFromCache,
        imageUrl: json['image_url'] as String?,
      );
    } catch (e) {
      debugPrint('Error parsing Comment from JSON: $e');
      return Comment(
        id: 0,
        body: 'Error loading comment.',
        commenter: 'Unknown',
        createdAt: DateTime.now(),
        replies: [],
        isFromCache: isFromCache,
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
      // ignore: deprecated_member_use
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
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
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
              _tableController.forward().then(
                (_) => _chairsController.forward(),
              );
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
                        scale: Tween<double>(
                          begin: 0.6,
                          end: 1.0,
                        ).animate(_tableAnimation),
                        child: const AnimatedRoundTableIcon(size: 150),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Gather \'Round!',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
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
                        scale: Tween<double>(
                          begin: 0.6,
                          end: 1.0,
                        ).animate(_tableAnimation),
                        child: const AnimatedRoundTableIcon(size: 150),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Start Conversations',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text('Create threads and watch ideas circle the table.'),
                  ],
                ),
              ),

              // Page 3: Join Discussion
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: _tableAnimation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.6,
                          end: 1.0,
                        ).animate(_tableAnimation),
                        child: const AnimatedRoundTableIcon(size: 150),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Pull Up a Chair',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text('Join discussions with a simple tap.'),
                  ],
                ),
              ),
            ],
          ),

          // Page Indicator
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
                    color: currentPage == index ? Colors.blue : Colors.grey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),

          // Next Button
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
                        builder: (context) => const ThreadsScreen(),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error saving onboarding preference: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error completing onboarding: $e'),
                      ),
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
  // Discover
  List<Thread> discoverThreads = [];
  List<Thread> searchResults = [];
  int discoverOffset = 0;
  bool discoverLoading = true;
  bool discoverHasError = false;
  String? discoverErrorMessage;
  bool discoverLoadingMore = false;
  bool discoverHasReachedMax = false;
  List<Animation<double>> discoverSlideAnimations = [];
  DateTime? _discoverLastFetchTime;
  // My
  List<Thread> myThreads = [];
  int myOffset = 0;
  bool myLoading = false;
  bool myHasError = false;
  String? myErrorMessage;
  bool myLoadingMore = false;
  bool myHasReachedMax = false;
  List<Animation<double>> mySlideAnimations = [];
  DateTime? _myLastFetchTime;
  // Shared
  String? username;
  int? userId;
  String sort = 'recent';
  final int limit = 10;
  final ScrollController _discoverScrollController = ScrollController();
  final ScrollController _myScrollController = ScrollController();
  late AnimationController _animationController;
  late AnimationController _staggerController;
  late Animation<double> _fadeAnimation;
  Timer? _discoverScrollDebounceTimer;
  Timer? _myScrollDebounceTimer;
  Timer? _retryTimer;
  Timer? _autoUpdateTimer;
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryBaseDelay = Duration(seconds: 2);
  static const Duration _autoUpdateInterval = Duration(minutes: 2);
  http.Client? _httpClient;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final Map<int, Thread> _threadCache = {};
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = false;
  final Set<int> _deletingThreadIds = <int>{};
  final Set<int> _bookmarkedThreadIds = <int>{}; // Local bookmarks

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
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
    _loadBookmarks(); // Load saved bookmarks
    _initializeData();
    _setupScrollListeners();
    _startAutoUpdate();
    _initConnectivity();
  }

  // Load bookmarks from local storage
  Future<void> _loadBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarksStr = prefs.getString('bookmarked_threads');
      if (bookmarksStr != null) {
        final List<dynamic> bookmarks = json.decode(bookmarksStr);
        _bookmarkedThreadIds.addAll(
          bookmarks
              .map((id) => int.tryParse(id.toString()) ?? 0)
              .where((id) => id > 0),
        );
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading bookmarks: $e');
    }
  }

  // Save bookmarks to local storage
  Future<void> _saveBookmarks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookmarksList = _bookmarkedThreadIds.toList();
      await prefs.setString('bookmarked_threads', json.encode(bookmarksList));
    } catch (e) {
      debugPrint('Error saving bookmarks: $e');
    }
  }

  // Toggle bookmark
  Future<void> _toggleBookmark(int threadId) async {
    setState(() {
      if (_bookmarkedThreadIds.contains(threadId)) {
        _bookmarkedThreadIds.remove(threadId);
        _showSuccess('Removed from bookmarks');
      } else {
        _bookmarkedThreadIds.add(threadId);
        _showSuccess('Added to bookmarks');
      }
    });
    await _saveBookmarks();
  }

  // Share thread
  Future<void> _shareThread(Thread thread) async {
    try {
      final threadUrl = 'https://server.awarcrown.com/threads/${thread.id}';
      final shareText =
          'Check out this discussion: "${thread.title}"\n\n${thread.body.substring(0, thread.body.length > 100 ? 100 : thread.body.length)}...\n\n$threadUrl';
      await Share.share(shareText, subject: thread.title);
    } catch (e) {
      _showError('Failed to share thread');
    }
  }

  // Calculate reading time
  String _getReadingTime(String text) {
    final wordCount = text.split(RegExp(r'\s+')).length;
    final readingTime = (wordCount / 200).ceil();
    if (readingTime < 1) return '< 1 min';
    return '$readingTime min';
  }

  void _onTabChanged() {
    if (_tabController.index != _tabController.previousIndex) {
      final newIsMyView = _tabController.index == 1;
      if (newIsMyView != isMyView) {
        setState(() {
          isMyView = newIsMyView;
        });
        _loadTabDataIfNeeded(newIsMyView);
      }
    }
  }

  void _loadTabDataIfNeeded(bool isMy) {
    final isEmpty = isMy ? myThreads.isEmpty : discoverThreads.isEmpty;
    if (isEmpty) {
      _fetchThreads(reset: true, isMy: isMy);
    }
  }

  Future<void> _initConnectivity() async {
    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    _isOnline = results.any((result) => result != ConnectivityResult.none);
    if (mounted) setState(() {});
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final wasOnline = _isOnline;
      _isOnline = results.any((result) => result != ConnectivityResult.none);
      if (mounted && _isOnline && !wasOnline) {
        _fetchThreads(reset: true, isMy: false);
        _fetchThreads(reset: true, isMy: true);
      }
    });
  }

  bool get isOnline => _isOnline;
  Future<bool> _isDeviceOnline() async {
    try {
      final connectivity = Connectivity();
      final results = await connectivity.checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  void _startAutoUpdate() {
    _autoUpdateTimer = Timer.periodic(_autoUpdateInterval, (timer) async {
      if (mounted && isOnline) {
        await Future.wait([
          _fetchThreads(reset: true, isMy: false),
          _fetchThreads(reset: true, isMy: true),
        ]);
      }
    });
  }

  void _setupScrollListeners() {
    _discoverScrollController.addListener(_onDiscoverScroll);
    _myScrollController.addListener(_onMyScroll);
  }

  void _onDiscoverScroll() {
    _discoverScrollDebounceTimer?.cancel();
    _discoverScrollDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!_discoverScrollController.hasClients) return;
      final position = _discoverScrollController.position;
      if (position.pixels >= position.maxScrollExtent - 200) {
        if (!discoverLoadingMore &&
            !discoverHasError &&
            !discoverHasReachedMax) {
          if (_isSearching) {
            _searchMoreThreads(_searchController.text);
          } else {
            _fetchMoreThreads(isMy: false);
          }
        }
      }
    });
  }

  void _onMyScroll() {
    _myScrollDebounceTimer?.cancel();
    _myScrollDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!_myScrollController.hasClients) return;
      final position = _myScrollController.position;
      if (position.pixels >= position.maxScrollExtent - 200) {
        if (!myLoadingMore && !myHasError && !myHasReachedMax) {
          _fetchMoreThreads(isMy: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _discoverScrollDebounceTimer?.cancel();
    _myScrollDebounceTimer?.cancel();
    _retryTimer?.cancel();
    _autoUpdateTimer?.cancel();
    _connectivitySubscription?.cancel();
    _discoverScrollController.dispose();
    _myScrollController.dispose();
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
      await Future.wait([
        _fetchThreads(reset: true, isMy: false),
        _fetchThreads(reset: true, isMy: true),
      ]);
    } catch (e) {
      if (mounted) {
        setState(() {
          discoverLoading = false;
          discoverHasError = true;
          discoverErrorMessage = _getErrorMessage(e);
        });
        _showError(discoverErrorMessage ?? 'Initialization failed');
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
      final response = await http
          .get(
            Uri.parse(
              'https://server.awarcrown.com/feed/get_user?username=${Uri.encodeComponent(username!)}',
            ),
          )
          .timeout(const Duration(seconds: 10));
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
      if (username != null) {
        await http
            .post(
              Uri.parse('https://server.awarcrown.com/threads/update_token'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'username': username, 'token': token}),
            )
            .timeout(const Duration(seconds: 10));
      }
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        debugPrint('Got foreground message: ${message.notification?.title}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${message.notification?.title}: ${message.notification?.body}',
              ),
              action: SnackBarAction(
                label: 'Refresh',
                onPressed: () {
                  _fetchThreads(reset: true, isMy: false);
                  _fetchThreads(reset: true, isMy: true);
                },
              ),
              backgroundColor: Colors.blue,
            ),
          );
          if (isOnline) {
            _fetchThreads(reset: true, isMy: false);
          }
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

  Future<void> _fetchThreads({bool reset = false, required bool isMy}) async {
    if (username == null || username!.isEmpty) return;
    final bool online = await _isDeviceOnline();
    bool useCacheOnly = !online;
    DateTime? lastFetchTime = isMy ? _myLastFetchTime : _discoverLastFetchTime;
    if (!reset &&
        lastFetchTime != null &&
        DateTime.now().difference(lastFetchTime) < _cacheValidDuration &&
        !online) {
      if (mounted) {
        setState(() {
          if (isMy) {
            myLoading = false;
            myLoadingMore = false;
          } else {
            discoverLoading = false;
            discoverLoadingMore = false;
          }
        });
      }
      return;
    }
    // Set loading states
    if (mounted) {
      setState(() {
        if (reset) {
          if (isMy) {
            myLoading = true;
            myHasError = false;
            myErrorMessage = null;
          } else {
            discoverLoading = true;
            discoverHasError = false;
            discoverErrorMessage = null;
          }
        } else {
          if (isMy) {
            myLoadingMore = true;
          } else {
            discoverLoadingMore = true;
          }
        }
      });
    }
    // Get target vars
    List<Thread> targetThreads = isMy ? myThreads : discoverThreads;
    int targetOffset = isMy ? myOffset : discoverOffset;
    List<Animation<double>> targetAnimations = isMy
        ? mySlideAnimations
        : discoverSlideAnimations;
    if (reset) {
      targetOffset = 0;
      if (useCacheOnly) {
        targetThreads = targetThreads.where((t) => !t.isFromCache).toList();
      } else {
        targetThreads.clear();
      }
      targetAnimations.clear();
      if (isMy) {
        myLoadingMore = false;
        myHasReachedMax = false;
        myOffset = 0;
      } else {
        discoverLoadingMore = false;
        discoverHasReachedMax = false;
        discoverOffset = 0;
      }
      _retryCount = 0;
    }
    List<Thread> newThreads = [];
    bool fetchSuccess = false;
    if (!useCacheOnly) {
      try {
        String uriStr =
            'https://server.awarcrown.com/threads/list?sort=$sort&limit=$limit&offset=$targetOffset';
        if (isMy) {
          uriStr += '&username=${Uri.encodeComponent(username!)}';
        }
        final uri = Uri.parse(uriStr);
        final response = await (_httpClient ?? http.Client())
            .get(uri)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          for (final jsonItem in data) {
            final thread = Thread.fromJson(jsonItem, isFromCache: false);
            newThreads.add(thread);
            _threadCache[thread.id] = thread;
            lastFetchTime = DateTime.now();
          }
          fetchSuccess = true;
        } else if (response.statusCode == 404) {
          if (isMy) {
            myHasReachedMax = true;
          } else {
            discoverHasReachedMax = true;
          }
        } else {
          throw Exception(
            'Server error: ${response.statusCode} - ${response.body}',
          );
        }
      } catch (e) {
        debugPrint('Fetch error: $e');
        useCacheOnly = true;
      }
    }
    if (useCacheOnly || !fetchSuccess) {
      final cachedKeys = _threadCache.keys
          .skip(targetOffset)
          .take(limit)
          .toList();
      for (final key in cachedKeys) {
        final cachedThread = _threadCache[key];
        if (cachedThread != null) {
          newThreads.add(cachedThread.copyWith(isFromCache: true));
        }
      }
      if (newThreads.isEmpty && reset) {
        if (mounted) {
          setState(() {
            if (isMy) {
              myLoading = false;
              myHasError = true;
              myErrorMessage =
                  'No cached data available. Please connect to internet.';
            } else {
              discoverLoading = false;
              discoverHasError = true;
              discoverErrorMessage =
                  'No cached data available. Please connect to internet.';
            }
          });
        }
        return;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    for (final thread in newThreads) {
      thread.isInspiredByMe = prefs.getBool('inspired_${thread.id}') ?? false;
      if (isMy) {
        thread.isInspiredByMe = true;
      }
    }
    if (mounted) {
      setState(() {
        if (reset) {
          if (isMy) {
            myThreads = newThreads;
            myLoading = false;
          } else {
            discoverThreads = newThreads;
            discoverLoading = false;
          }
        } else {
          if (isMy) {
            myThreads.addAll(newThreads);
            myLoadingMore = false;
          } else {
            discoverThreads.addAll(newThreads);
            discoverLoadingMore = false;
          }
        }
        if (isMy) {
          myOffset += newThreads.length;
          myHasReachedMax = newThreads.length < limit;
        } else {
          discoverOffset += newThreads.length;
          discoverHasReachedMax = newThreads.length < limit;
        }
        _retryCount = 0;
      });
    }
    if (newThreads.isNotEmpty) {
      final startIndex = reset ? 0 : targetThreads.length - newThreads.length;
      final newAnimations = List.generate(newThreads.length, (index) {
        final beginValue = ((startIndex + index) * 0.05).clamp(0.0, 0.95);
        return Tween<double>(begin: -1.0, end: 0.0).animate(
          CurvedAnimation(
            parent: _staggerController,
            curve: Interval(beginValue, 1.0, curve: Curves.elasticOut),
          ),
        );
      });
      if (isMy) {
        if (reset) {
          mySlideAnimations = newAnimations;
        } else {
          mySlideAnimations.addAll(newAnimations);
        }
      } else {
        if (reset) {
          discoverSlideAnimations = newAnimations;
        } else {
          discoverSlideAnimations.addAll(newAnimations);
        }
      }
      _staggerController.forward(from: 0.0);
    }
    if (useCacheOnly && newThreads.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Showing cached data. Syncing when online.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    if (isMy) {
      _myLastFetchTime = lastFetchTime;
    } else {
      _discoverLastFetchTime = lastFetchTime;
    }
  }

  Future<void> _fetchMoreThreads({required bool isMy}) async {
    await _fetchThreads(reset: false, isMy: isMy);
  }

  Future<void> _searchThreads(String query, {bool reset = false}) async {
    if (isMyView) return;
    final bool online = await _isDeviceOnline();
    bool useCacheOnly = !online;
    if (reset) {
      discoverOffset = 0;
      if (useCacheOnly) {
        searchResults = searchResults.where((t) => !t.isFromCache).toList();
      } else {
        searchResults.clear();
      }
      discoverSlideAnimations.clear();
      discoverLoadingMore = false;
      discoverHasReachedMax = false;
    }
    if (mounted) {
      setState(() {
        discoverLoading = true;
        _isSearching = true;
      });
    }
    List<Thread> newThreads = [];
    bool fetchSuccess = false;
    if (!useCacheOnly) {
      try {
        final uri = Uri.parse(
          'https://server.awarcrown.com/threads/search?query=${Uri.encodeComponent(query)}&limit=$limit&offset=$discoverOffset',
        );
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          for (final jsonItem in data) {
            final thread = Thread.fromJson(jsonItem, isFromCache: false);
            newThreads.add(thread);
            _threadCache[thread.id] = thread;
          }
          fetchSuccess = true;
        } else {
          throw Exception('Search error: ${response.statusCode}');
        }
      } catch (e) {
        debugPrint('Search error: $e');
        useCacheOnly = true;
      }
    }
    if (useCacheOnly || !fetchSuccess) {
      final cachedThreads = _threadCache.values
          .where(
            (t) =>
                t.title.toLowerCase().contains(query.toLowerCase()) ||
                t.body.toLowerCase().contains(query.toLowerCase()),
          )
          .skip(discoverOffset)
          .take(limit)
          .toList();
      newThreads = cachedThreads
          .map((t) => t.copyWith(isFromCache: true))
          .toList();
    }
    final prefs = await SharedPreferences.getInstance();
    for (final thread in newThreads) {
      thread.isInspiredByMe = prefs.getBool('inspired_${thread.id}') ?? false;
    }
    if (mounted) {
      setState(() {
        searchResults = reset ? newThreads : [...searchResults, ...newThreads];
        discoverLoading = false;
        discoverOffset += newThreads.length;
        discoverHasReachedMax = newThreads.length < limit;
      });
    }
    if (newThreads.isNotEmpty) {
      final startIndex = reset ? 0 : searchResults.length - newThreads.length;
      final newAnimations = List.generate(newThreads.length, (index) {
        final beginValue = ((startIndex + index) * 0.05).clamp(0.0, 0.95);
        return Tween<double>(begin: -1.0, end: 0.0).animate(
          CurvedAnimation(
            parent: _staggerController,
            curve: Interval(beginValue, 1.0, curve: Curves.elasticOut),
          ),
        );
      });
      if (reset) {
        discoverSlideAnimations = newAnimations;
      } else {
        discoverSlideAnimations.addAll(newAnimations);
      }
      _staggerController.forward(from: 0.0);
    }
    if (useCacheOnly && newThreads.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Search results from cache. Connect for fresh data.',
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _searchMoreThreads(String query) async {
    await _searchThreads(query, reset: false);
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        searchResults.clear();
      });
    } else {
      await _searchThreads(query, reset: true);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.lock_open_rounded,
                color: Color(0xFF4A90E2),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Join Private Discussion',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: codeController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Enter Invite Code',
            hintText: 'e.g., ABC123',
            prefixIcon: const Icon(Icons.vpn_key_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final code = codeController.text.trim();
              if (code.isEmpty) return;
              await _joinPrivateThread(code);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Join',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinPrivateThread(String code) async {
    final bool online = await _isDeviceOnline();
    if (!online) {
      _showError('Please connect to internet to join private thread.');
      return;
    }
    try {
      final response = await http
          .get(
            Uri.parse(
              'https://server.awarcrown.com/threads/join-by-code?code=${Uri.encodeComponent(code)}',
            ),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final thread = Thread.fromJson(data, isFromCache: false);
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
    final delay = _retryBaseDelay * (1 << (_retryCount - 1));
    _retryTimer = Timer(delay, () async {
      final bool online = await _isDeviceOnline();
      if (mounted && online) {
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

  Future<bool> _createThread(
    String title,
    String body,
    String category,
    List<String> tags,
    String visibility,
  ) async {
    final bool online = await _isDeviceOnline();
    if (!online) {
      _showError('Please connect to internet to create a roundtable.');
      return false;
    }
    if (userId == null ||
        userId == 0 ||
        username == null ||
        username!.isEmpty) {
      if (mounted) {
        _showError('Please wait to create a roundtable');
      }
      return false;
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
      final response = await http
          .post(
            Uri.parse('https://server.awarcrown.com/threads/create'),
            headers: {'Content-Type': 'application/json'},
            body: bodyData,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Create response: ${response.body}');

        // Check for 'success' key *and* 'thread_id' key
        if (data is Map<String, dynamic> &&
            data['success'] == true &&
            data.containsKey('thread_id')) {
          // --- THIS IS THE FIX ---
          // Safely parse the thread_id, which might be a String ("72") or int (72)
          final int? newId = int.tryParse(data['thread_id'].toString());
          if (newId == null) {
            // If the ID is null or not a valid number, we can't proceed.
            throw Exception('Invalid thread_id format from server.');
          }
          // --- END OF FIX ---
          final inviteCode = data['invite_code'] as String?;
          final newThread = Thread(
            id: newId, // Use the new, safely parsed integer ID
            title: title,
            body: body,
            category: category,
            creator: username!,
            creatorRole: '',
            inspiredCount: 0,
            commentCount: 0,
            tags: tags,
            createdAt: DateTime.now(),
            isInspiredByMe: true,
            visibility: visibility,
            inviteCode: inviteCode,
            isFromCache: false,
          );
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('inspired_$newId', true);
          _threadCache[newId] = newThread;
          if (visibility == 'private' && inviteCode != null) {
            await _setThreadCode(newId, inviteCode);
            _showPrivateThreadDialog(title, inviteCode);
          }

          if (mounted) {
            setState(() {
              discoverThreads.insert(0, newThread);
              if (isMyView) myThreads.insert(0, newThread);
            });
          }
          if (isMyView) {
            _fetchThreads(reset: true, isMy: true);
          } else {
            _fetchThreads(reset: true, isMy: false);
          }
          return true; // Return success
        } else {
          // Handle cases where "success" is false or "thread_id" is missing
          final errorMsg = data['error'] ?? 'Invalid response from server';
          _showError('Failed to create roundtable: $errorMsg');
          return false; // Return failure
        }
      } else {
        // Handle non-200 server responses
        debugPrint(
          'Create failed with status: ${response.statusCode}, body: ${response.body}',
        );
        throw Exception('Failed to create roundtable: ${response.statusCode}');
      }
    } catch (e) {
      // Handle timeouts, JSON parsing errors, or the exception we threw above
      debugPrint('Create thread error: $e');
      if (mounted) {
        _showError('Failed to create roundtable: ${_getErrorMessage(e)}');
      }
      return false; // Return failure
    }
  }

  void _showPrivateThreadDialog(String title, String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Private Roundtable Created',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E9F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4A90E2).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: 20,
                    color: const Color(0xFF4A90E2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Invite Code',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          code,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E3A5F),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.copy_rounded,
                      color: const Color(0xFF4A90E2),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Code copied!'),
                          backgroundColor: const Color(0xFF4A90E2),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share this code with others to invite them to your private discussion.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A90E2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Got it',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleInspire(int threadId) async {
    final bool online = await _isDeviceOnline();
    if (!online) {
      _showError('Please connect to internet to update inspiration.');
      return;
    }
    if (username == null || username!.isEmpty) return;
    List<Thread> targetList = isMyView ? myThreads : discoverThreads;
    final threadIndex = targetList.indexWhere((t) => t.id == threadId);
    if (threadIndex == -1) return;
    final thread = targetList[threadIndex];
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
      final uri = Uri.parse(
        'https://server.awarcrown.com/threads/inspire?id=$threadId',
      );
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: bodyData,
          )
          .timeout(const Duration(seconds: 10));
      final prefs = await SharedPreferences.getInstance();
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (data.containsKey('inspired_count')) {
            thread.inspiredCount = data['inspired_count'];
            _threadCache[threadId]?.inspiredCount = data['inspired_count'];
          }
          if (data.containsKey('user_has_inspired')) {
            thread.isInspiredByMe = data['user_has_inspired'] as bool;
            _threadCache[threadId]?.isInspiredByMe =
                data['user_has_inspired'] as bool;
          }
          await prefs.setBool('inspired_$threadId', thread.isInspiredByMe);
          _showSuccess(
            data['message'] ??
                (newInspired ? 'Inspired this discussion!' : 'Uninspired.'),
          );
        } else {
          thread.isInspiredByMe = oldInspired;
          thread.inspiredCount = oldCount;
          _threadCache[threadId]?.isInspiredByMe = oldInspired;
          _threadCache[threadId]?.inspiredCount = oldCount;
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
      _threadCache[threadId]?.isInspiredByMe = oldInspired;
      _threadCache[threadId]?.inspiredCount = oldCount;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('inspired_$threadId', oldInspired);
      if (mounted) setState(() {});
      if (mounted) {
        _showError('Failed to toggle inspire: ${_getErrorMessage(e)}');
      }
    }
  }

  Future<bool> _deleteThread(int threadId) async {
    if (_deletingThreadIds.contains(threadId)) {
      return false; // Already deleting, avoid multiple calls
    }
    final bool online = await _isDeviceOnline();
    if (!online) {
      _showError('Please connect to internet to delete the roundtable.');
      return false;
    }
    if (userId == null ||
        userId == 0 ||
        username == null ||
        username!.isEmpty) {
      _showError('User authentication required to delete.');
      return false;
    }
    try {
      final bodyData = json.encode({
        'thread_id': threadId,
        'user_id': userId,
        'username': username,
      });
      final response = await http
          .post(
            Uri.parse('https://server.awarcrown.com/threads/delete'),
            headers: {'Content-Type': 'application/json'},
            body: bodyData,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          // Remove from local lists
          if (mounted) {
            setState(() {
              discoverThreads.removeWhere((t) => t.id == threadId);
              myThreads.removeWhere((t) => t.id == threadId);
              searchResults.removeWhere((t) => t.id == threadId);
              _deletingThreadIds.remove(threadId);
            });
          }
          // Remove from cache
          _threadCache.remove(threadId);
          // Clear local prefs if any
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('inspired_$threadId');
          await prefs.remove('code_$threadId');
          _showSuccess(data['message'] ?? 'Roundtable deleted successfully.');
          return true;
        } else {
          final errorMsg = data['error'] ?? 'Invalid response from server';
          _showError('Failed to delete roundtable: $errorMsg');
          if (mounted) {
            setState(() {
              _deletingThreadIds.remove(threadId);
            });
          }
          return false;
        }
      } else {
        throw Exception('Failed to delete roundtable: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Delete thread error: $e');
      _showError('Failed to delete roundtable: ${_getErrorMessage(e)}');
      if (mounted) {
        setState(() {
          _deletingThreadIds.remove(threadId);
        });
      }
      return false;
    }
  }

  void _showDeleteConfirmation(int threadId, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red.shade600,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Roundtable',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this roundtable? This action cannot be undone.',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E9F0)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (mounted) {
                setState(() {
                  _deletingThreadIds.add(threadId);
                });
              }
              await _deleteThread(threadId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateDialog() {
    showCreateRoundtableDialog(context: context, onCreate: _createThread);
  }

  List<Thread> _getCurrentThreads(bool isDiscover) {
    if (!isDiscover || !_isSearching)
      return isDiscover ? discoverThreads : myThreads;
    return searchResults;
  }

  bool _getCurrentLoading(bool isDiscover) {
    if (!isDiscover || !_isSearching)
      return isDiscover ? discoverLoading : myLoading;
    return discoverLoading;
  }

  bool _getCurrentHasError(bool isDiscover) {
    if (!isDiscover || !_isSearching)
      return isDiscover ? discoverHasError : myHasError;
    return discoverHasError;
  }

  String? _getCurrentErrorMessage(bool isDiscover) {
    if (!isDiscover || !_isSearching)
      return isDiscover ? discoverErrorMessage : myErrorMessage;
    return discoverErrorMessage;
  }

  bool _getCurrentLoadingMore(bool isDiscover) {
    if (!isDiscover || !_isSearching)
      return isDiscover ? discoverLoadingMore : myLoadingMore;
    return discoverLoadingMore;
  }

  bool _getCurrentHasReachedMax(bool isDiscover) {
    if (!isDiscover || !_isSearching)
      return isDiscover ? discoverHasReachedMax : myHasReachedMax;
    return discoverHasReachedMax;
  }

  List<Animation<double>> _getCurrentSlideAnimations(bool isDiscover) {
    if (!isDiscover || !_isSearching)
      return isDiscover ? discoverSlideAnimations : mySlideAnimations;
    return discoverSlideAnimations;
  }

  ScrollController _getCurrentScrollController(bool isDiscover) {
    return isDiscover ? _discoverScrollController : _myScrollController;
  }

  @override
  Widget build(BuildContext context) {
    final padding = 16.0;
    if (username == null || username!.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
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
                      color: const Color(0xFF4A90E2),
                    ),
                    SizedBox(height: constraints.maxWidth > 600 ? 32 : 24),
                    Text(
                      'Please wait to join the roundtable',
                      style: TextStyle(
                        fontSize: constraints.maxWidth > 600 ? 24 : 20,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E3A5F),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: constraints.maxWidth > 600 ? 16 : 12),
                    Text(
                      'Check your connection and try again',
                      style: TextStyle(
                        fontSize: constraints.maxWidth > 600 ? 16 : 14,
                        color: const Color(0xFF6B7280),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: constraints.maxWidth > 600 ? 40 : 32),
                    ElevatedButton.icon(
                      onPressed: _loadUsernameAndUserId,
                      icon: const Icon(Icons.refresh, size: 20),
                      label: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A90E2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }
    const primaryColor = Color(0xFF1E3A5F);
    const secondaryColor = Color(0xFF2D5AA0);
    const accentColor = Color(0xFF4A90E2);
    const surfaceColor = Color(0xFFF5F7FA);
    const cardColor = Colors.white;
    final bool usingCache = (isMyView ? myThreads : discoverThreads).any(
      (t) => t.isFromCache,
    );
    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: _isSearching && !isMyView
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search discussions...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: _clearSearch,
                    color: Colors.white,
                  ),
                ),
                onSubmitted: _onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              )
            : TabBar(
                controller: _tabController,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white.withOpacity(0.7),
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
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
          if (!_isSearching && !isMyView) ...[
            IconButton(
              onPressed: () async {
                await _fetchThreads(reset: true, isMy: false);
                await _fetchThreads(reset: true, isMy: true);
              },
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 22,
              ),
              tooltip: 'Refresh',
            ),
            IconButton(
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
              icon: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 22,
              ),
              tooltip: 'Search',
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.tune_rounded,
                color: Colors.white,
                size: 22,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.white,
              onSelected: (value) {
                setState(() {
                  sort = value;
                });
                _fetchThreads(reset: true, isMy: false);
              },
              itemBuilder: (context) => ['Recent', 'Trending', 'Innovative']
                  .map(
                    (s) => PopupMenuItem(
                      value: s.toLowerCase(),
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: _showCreateDialog,
                icon: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                tooltip: 'Create Roundtable',
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: IconButton(
              onPressed: _joinWithCode,
              icon: const Icon(
                Icons.lock_open_rounded,
                color: Colors.white,
                size: 22,
              ),
              tooltip: 'Join Private Thread',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (usingCache)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.orange.shade200, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 16,
                    color: Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Showing cached data. Pull to refresh for latest.',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Discover Tab
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildTabContent(
                    isDiscover: true,
                    padding: padding,
                    cardColor: cardColor,
                    isMyView: isMyView,
                  ),
                ),
                // My Roundtables Tab
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildTabContent(
                    isDiscover: false,
                    padding: padding,
                    cardColor: cardColor,
                    isMyView: isMyView,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: !isMyView
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  colors: [accentColor, secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FloatingActionButton(
                onPressed: _showCreateDialog,
                backgroundColor: Colors.transparent,
                elevation: 0,
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            )
          : null,
      extendBody: true,
    );
  }

  Widget _buildTabContent({
    required bool isDiscover,
    required double padding,
    required Color cardColor,
    required bool isMyView,
  }) {
    final bool localIsSearching = !isDiscover && _isSearching;
    final List<Thread> localThreads = _getCurrentThreads(isDiscover);
    final bool localLoading = _getCurrentLoading(isDiscover);
    final bool localHasError = _getCurrentHasError(isDiscover);
    final String? localError = _getCurrentErrorMessage(isDiscover);
    final bool localLoadingMore = _getCurrentLoadingMore(isDiscover);
    _getCurrentHasReachedMax(isDiscover);
    final List<Animation<double>> localSlideAnimations =
        _getCurrentSlideAnimations(isDiscover);
    final ScrollController localScrollController = _getCurrentScrollController(
      isDiscover,
    );
    localThreads.any((t) => t.isFromCache);

    Future<void> onRefresh() async {
      if (localIsSearching) {
        await _onSearchChanged(_searchController.text);
        return;
      }
      await _fetchThreads(reset: true, isMy: !isDiscover);
    }

    return localLoading
        ? RefreshIndicator(
            onRefresh: onRefresh,
            color: const Color(0xFF4A90E2),
            strokeWidth: 3,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                padding,
                padding,
                padding,
                padding + 80,
              ),
              itemCount: 6,
              itemBuilder: (context, index) => Shimmer.fromColors(
                baseColor: Colors.grey[200]!,
                highlightColor: Colors.grey[50]!,
                child: Container(
                  margin: EdgeInsets.only(bottom: padding),
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : localHasError
        ? RefreshIndicator(
            onRefresh: () => _initializeData(),
            color: const Color(0xFF4A90E2),
            strokeWidth: 3,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.error_outline_rounded,
                          size: 64,
                          color: Colors.red.shade400,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        localError ?? 'An unknown error occurred',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _initializeData,
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        label: const Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90E2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : localThreads.isEmpty
        ? RefreshIndicator(
            onRefresh: onRefresh,
            color: const Color(0xFF4A90E2),
            strokeWidth: 3,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AnimatedRoundTableIcon(
                        size: 100,
                        color: Color(0xFF4A90E2),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        localIsSearching
                            ? 'No results found'
                            : (!isDiscover
                                  ? 'No roundtables created yet'
                                  : 'No roundtables yet'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A5F),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        localIsSearching
                            ? 'Try a different search term.'
                            : (!isDiscover
                                  ? 'Start your first discussion!'
                                  : 'Start the conversation!'),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF6B7280),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: localIsSearching
                            ? _clearSearch
                            : _showCreateDialog,
                        icon: Icon(
                          localIsSearching
                              ? Icons.clear_rounded
                              : Icons.add_rounded,
                          size: 20,
                        ),
                        label: Text(
                          localIsSearching
                              ? 'Clear Search'
                              : 'Create Roundtable',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90E2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: onRefresh,
            color: const Color(0xFF4A90E2),
            strokeWidth: 3,
            child: ListView.builder(
              controller: localScrollController,
              padding: EdgeInsets.fromLTRB(
                padding,
                padding,
                padding,
                padding + 100,
              ),
              itemCount: localThreads.length + (localLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == localThreads.length) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFF4A90E2),
                        ),
                        strokeWidth: 3,
                      ),
                    ),
                  );
                }
                final thread = localThreads[index];
                final slideAnimation = localSlideAnimations.length > index
                    ? localSlideAnimations[index]
                    : const AlwaysStoppedAnimation(0.0);
                return AnimatedBuilder(
                  animation: slideAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: (slideAnimation.value + 1.0).clamp(0.4, 1.0),
                      child: Transform.translate(
                        offset: Offset(
                          (slideAnimation.value * 50).clamp(-50.0, 0.0),
                          0,
                        ),
                        child: _buildThreadCard(
                          thread,
                          username ?? '',
                          cardColor,
                          isMy: !isDiscover,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
  }

  Widget _buildThreadCard(
    Thread thread,
    String currentUser,
    Color cardColor, {
    required bool isMy,
  }) {
    final isDeleting = _deletingThreadIds.contains(thread.id);
    final cardWidget = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        splashColor: const Color(0xFF4A90E2).withOpacity(0.08),
        highlightColor: const Color(0xFF4A90E2).withOpacity(0.04),
        onTap: isDeleting
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ThreadDetailScreen(
                    thread: thread,
                    username: currentUser,
                    userId: userId ?? 0,
                  ),
                ),
              ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E9F0), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with icon and title
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A90E2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const AnimatedRoundTableIcon(
                            size: 24,
                            color: Color(0xFF4A90E2),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      thread.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 18,
                                        color: Color(0xFF1E3A5F),
                                        height: 1.3,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (thread.visibility == 'private')
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.lock_rounded,
                                            size: 12,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Private',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                thread.body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 14,
                                  height: 1.5,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Tags and category
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A90E2).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            thread.category,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2D5AA0),
                            ),
                          ),
                        ),
                        ...thread.tags
                            .take(3)
                            .map(
                              (t) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF10B981,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '#$t',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ),
                            ),
                        if (thread.tags.length > 3)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '+${thread.tags.length - 3}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (isMy &&
                        thread.visibility == 'private' &&
                        thread.inviteCode != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E9F0)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 18,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Invite Code: ${thread.inviteCode}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.copy_rounded,
                                size: 18,
                                color: const Color(0xFF4A90E2),
                              ),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: thread.inviteCode ?? ''),
                                );
                                _showSuccess('Code copied!');
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Footer with metadata
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_outline_rounded,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                thread.creator,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getReadingTime(thread.body),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatDate(thread.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons
              Positioned(
                top: 12,
                right: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isMy || !isDeleting) ...[
                      _buildActionButton(
                        icon: _bookmarkedThreadIds.contains(thread.id)
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: _bookmarkedThreadIds.contains(thread.id)
                            ? Colors.amber.shade600
                            : Colors.grey.shade600,
                        onTap: () => _toggleBookmark(thread.id),
                      ),
                      const SizedBox(width: 6),
                      _buildActionButton(
                        icon: Icons.share_rounded,
                        color: const Color(0xFF4A90E2),
                        onTap: () => _shareThread(thread),
                      ),
                    ],
                    if (isMy && !isDeleting) ...[
                      const SizedBox(width: 6),
                      _buildActionButton(
                        icon: Icons.delete_outline_rounded,
                        color: Colors.red.shade600,
                        onTap: () =>
                            _showDeleteConfirmation(thread.id, thread.title),
                      ),
                    ],
                  ],
                ),
              ),
              if (isDeleting)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.red.shade600,
                        ),
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ),
              if (thread.isFromCache)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 12,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Cached',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    return isMy
        ? cardWidget
        : Hero(tag: 'thread_${thread.id}', child: cardWidget);
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

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
    // ignore: unused_element_parameter
    this.iconColor,
    this.iconSize,
    this.fontSize,
  });
  @override
  Widget build(BuildContext context) {
    final defaultIconColor = iconColor ?? const Color(0xFF6B7280);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E9F0), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize ?? 18, color: defaultIconColor),
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
