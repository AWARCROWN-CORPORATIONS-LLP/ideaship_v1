import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shimmer/shimmer.dart'; 
import 'package:lottie/lottie.dart'; // Add lottie: ^3.1.2 to pubspec.yaml for Lottie animations

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
  });

  factory Thread.fromJson(Map<String, dynamic> json) {
    return Thread(
      id: json['thread_id'],
      title: json['title'],
      body: json['body'],
      category: json['category_name'],
      creator: json['creator_username'] ?? '',
      creatorRole: json['creator_role'] ?? '',
      inspiredCount: json['inspired_count'],
      commentCount: json['comment_count'],
      collabCount: json['collab_count'],
      tags: List<String>.from(json['tags'] ?? []),
      createdAt: DateTime.parse(json['created_at']),
    );
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

  factory Comment.fromJson(Map<String, dynamic> json, Map<int, List<Map<String, dynamic>>> commentMap) {
    final id = json['comment_id'];
    final repliesJson = commentMap[id] ?? [];
    final replies = repliesJson.map((r) => Comment.fromJson(r, commentMap)).toList();
    return Comment(
      id: id,
      parentId: json['parent_comment_id'],
      body: json['comment_body'],
      commenter: json['commenter_username'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      replies: replies,
    );
  }
}

class RoundTablePainter extends CustomPainter {
  final double rotation;

  RoundTablePainter({this.rotation = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final tableRadius = size.width / 2 - 4;

    // Save and rotate the canvas
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    // Draw round table
    final tablePaint = Paint()
      ..color = Colors.blue.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, tableRadius, tablePaint);

    // Draw table edge
    final edgePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, tableRadius, edgePaint);

    // Draw chairs around the table
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AnimatedRoundTableIcon extends StatefulWidget {
  final double size;
  final Color color;

  const AnimatedRoundTableIcon({
    Key? key,
    this.size = 24.0,
    this.color = Colors.blue,
  }) : super(key: key);

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

// Onboarding Tour Screen
class OnboardingTourScreen extends StatefulWidget {
  const OnboardingTourScreen({super.key});

  @override
  State<OnboardingTourScreen> createState() => _OnboardingTourScreenState();
}

class _OnboardingTourScreenState extends State<OnboardingTourScreen> with TickerProviderStateMixin {
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
              setState(() => currentPage = index);
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
                        child: AnimatedRoundTableIcon(size: 150),
                      ),
                    ),
                    SizedBox(height: 32),
                    Text('Gather \'Round!', style: Theme.of(context).textTheme.headlineMedium),
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
                        child: AnimatedRoundTableIcon(size: 150),
                      ),
                    ),
                    SizedBox(height: 32),
                    Text('Start Conversations', style: Theme.of(context).textTheme.headlineSmall),
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
                        child: AnimatedRoundTableIcon(size: 150),
                      ),
                    ),
                    SizedBox(height: 32),
                    Text('Pull Up a Chair', style: Theme.of(context).textTheme.headlineSmall),
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
              children: List.generate(3, (index) => AnimatedContainer(
                duration: Duration(milliseconds: 300),
                margin: EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: currentPage == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: currentPage == index ? Colors.blue : Colors.grey,
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
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('hasSeenOnboarding', true);
                if (context.mounted) Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => ThreadsScreen()),
                );
              },
              child: Icon(Icons.arrow_forward),
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

class _ThreadsScreenState extends State<ThreadsScreen> with TickerProviderStateMixin {
  List<Thread> threads = [];
  String? username;
  int? userId;
  String sort = 'recent';
  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;
  late AnimationController _animationController;
  late AnimationController _staggerController;
  late Animation<double> _fadeAnimation;
  List<Animation<double>> _slideAnimations = [];

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _staggerController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _initializeData();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('hasSeenOnboarding') ?? false;
    if (!hasSeen && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => OnboardingTourScreen()),
      );
    }
  }

  Future<void> _initializeData() async {
    await _loadUsernameAndUserId();
    await _setupFCM();
    await _fetchThreads();
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
    }
  }

  Future<void> _fetchUserId() async {
    if (username == null || username!.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('https://server.awarcrown.com/feed/get_user?username=${Uri.encodeComponent(username!)}'),
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
    final fcm = FirebaseMessaging.instance;
    NotificationSettings settings = await fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    print('User granted permission: ${settings.authorizationStatus}');

    // Get token and send to backend
    String? token = await fcm.getToken();
    if (token != null && username != null) {
      try {
        await http.post(
          Uri.parse('https://server.awarcrown.com/threads/update_token'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'username': username, 'token': token}),
        ).timeout(Duration(seconds: 10));
      } catch (e) {
        print('Failed to update FCM token: $e');
      }
    }

    // Foreground message handling
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got foreground message: ${message.notification?.title}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${message.notification?.title}: ${message.notification?.body}'),
            action: SnackBarAction(
              label: 'Refresh',
              onPressed: () => _fetchThreads(),
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
    });
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

  Future<void> _fetchThreads() async {
    if (username == null || username!.isEmpty) return;
    setState(() {
      isLoading = true;
      hasError = false;
    });
    try {
      final uri = Uri.parse('https://server.awarcrown.com/threads/list?sort=$sort&limit=20&offset=0');
      final response = await http.get(uri).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final newThreads = data.map((json) => Thread.fromJson(json)).toList();
        setState(() {
          threads = newThreads;
          isLoading = false;
        });
        // Staggered animation for new threads
        _slideAnimations = List.generate(threads.length, (index) => 
          Tween<double>(begin: -1.0, end: 0.0).animate(
            CurvedAnimation(
              parent: _staggerController,
              curve: Interval(index * 0.1, 1.0, curve: Curves.elasticOut),
            ),
          )
        );
        _staggerController.forward(from: 0.0);
      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Failed to fetch roundtables: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load roundtables: $e'),
            action: SnackBarAction(label: 'Retry', onPressed: _fetchThreads),
          ),
        );
      }
    }
  }

  Future<void> _createThread(String title, String body, String category, List<String> tags) async {
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
        'visibility': 'public',
      });
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/threads/create'),
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data is Map<String, dynamic> && data.containsKey('thread_id')) {
            final newThread = Thread.fromJson(data);
            if (mounted) {
              setState(() {
                threads.insert(0, newThread);
              });
              _showSuccess('Roundtable created!');
            }
          } else {
            await _fetchThreads();
          }
        } catch (parseError) {
          await _fetchThreads();
        }
        if (mounted) Navigator.pop(context);
      } else {
        throw Exception('Failed to create roundtable: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to create roundtable: $e');
      }
    }
  }

  Future<void> _toggleInspire(int threadId) async {
    if (username == null || username!.isEmpty) return;
    final threadIndex = threads.indexWhere((t) => t.id == threadId);
    if (threadIndex == -1) return;
    final thread = threads[threadIndex];
    final oldCount = thread.inspiredCount;
    thread.inspiredCount++;
    if (mounted) setState(() {});
    try {
      final bodyData = json.encode({'type': 'inspired', 'username': username});
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/threads/inspire?id=$threadId'),
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = json.decode(response.body);
          if (data is Map<String, dynamic> && data.containsKey('inspired_count')) {
            thread.inspiredCount = data['inspired_count'];
          }
        } catch (_) {
          // Keep optimistic update
        }
        _showSuccess('Inspired this discussion!');
      } else {
        throw Exception('Failed to toggle inspire: ${response.statusCode}');
      }
    } catch (e) {
      thread.inspiredCount = oldCount;
      if (mounted) setState(() {});
      if (mounted) {
        _showError('Failed to toggle inspire: $e');
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
      final bodyData = json.encode({'message': message, 'username': username});
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/threads/collab?id=$threadId'),
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = json.decode(response.body);
          if (data is Map<String, dynamic> && data.containsKey('collab_count')) {
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
        _showError('Failed to join discussion: $e');
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
              Navigator.of(dialogContext).pop();
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
                    'assets/chair_pull.json', // Assume you have a Lottie file for chair animation
                    width: 300,
                    height: 200,
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
                      child: Icon(Icons.party_mode, size: 50 * value, color: Colors.yellow),
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

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [Icon(Icons.add, color: Colors.blue), SizedBox(width: 8), Text('Start Roundtable')]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: InputDecoration(
                  labelText: 'Topic Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                )),
                SizedBox(height: 8),
                TextField(
                  controller: bodyController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Opening Thoughts',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(labelText: 'Theme', border: OutlineInputBorder()),
                  items: ['Idea', 'Problem', 'Build', 'Event', 'Collab']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedCategory = val!),
                ),
                SizedBox(height: 8),
                TextField(
                  onSubmitted: (val) {
                    if (val.isNotEmpty) {
                      setDialogState(() => selectedTags.add(val));
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Add Topic Tag (Enter to add)',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (selectedTags.isNotEmpty) Wrap(
                  spacing: 4,
                  children: selectedTags.map((t) => Chip(
                    label: Text(t),
                    onDeleted: () => setDialogState(() => selectedTags.remove(t)),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
            ElevatedButton(
              onPressed: () => _createThread(titleController.text, bodyController.text, selectedCategory, selectedTags),
              child: Text('Start Discussion'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (username == null || username!.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedRoundTableIcon(size: 80, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Please wait to join the roundtable',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 8),
              Text(
                'Check your connection and try again',
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadUsernameAndUserId,
                icon: Icon(Icons.refresh),
                label: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            AnimatedRoundTableIcon(size: 24, color: Colors.white),
            SizedBox(width: 8),
            Text('Roundtable', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.blue,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.sort, color: Colors.white),
            onSelected: (value) {
              setState(() => sort = value);
              _fetchThreads();
            },
            itemBuilder: (context) => ['Recent', 'Trending', 'Innovative']
                .map((s) => PopupMenuItem(value: s.toLowerCase(), child: Text(s)))
                .toList(),
          ),
          IconButton(onPressed: _showCreateDialog, icon: Icon(Icons.add, color: Colors.white)),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: isLoading
            ? RefreshIndicator(
                onRefresh: _fetchThreads,
                color: Colors.blue,
                child: ListView.builder(
                  physics: AlwaysScrollableScrollPhysics(),
                  itemCount: 5,
                  itemBuilder: (context, index) => Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Card(
                      margin: EdgeInsets.all(8),
                      child: SizedBox(height: 100, child: Container(color: Colors.white)),
                    ),
                  ),
                ),
              )
            : hasError
                ? RefreshIndicator(
                    onRefresh: _initializeData, // Retry full load
                    color: Colors.blue,
                    child: SingleChildScrollView(
                      physics: AlwaysScrollableScrollPhysics(),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
                              SizedBox(height: 16),
                              Text(
                                errorMessage ?? 'An unknown error occurred',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16),
                              ),
                              SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _initializeData,
                                icon: Icon(Icons.refresh),
                                label: Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : threads.isEmpty
                    ? RefreshIndicator(
                        onRefresh: _fetchThreads,
                        color: Colors.blue,
                        child: SingleChildScrollView(
                          physics: AlwaysScrollableScrollPhysics(),
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AnimatedRoundTableIcon(size: 80, color: Colors.grey),
                                  SizedBox(height: 16),
                                  Text(
                                    'No roundtables yet',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Start the conversation!',
                                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                  ),
                                  SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: _showCreateDialog,
                                    icon: Icon(Icons.add),
                                    label: Text('Start Roundtable'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchThreads,
                        color: Colors.blue,
                        child: ListView.builder(
                          itemCount: threads.length,
                          itemBuilder: (context, index) {
                            final thread = threads[index];
                            final slideAnimation = _slideAnimations.length > index ? _slideAnimations[index] : const AlwaysStoppedAnimation(0.0);
                            return AnimatedBuilder(
                              animation: slideAnimation,
                              builder: (context, child) {
                                return Transform.translate(
                                  // ignore: unnecessary_null_comparison
                                  offset: slideAnimation != null ? Offset(slideAnimation.value * 100, 0) : Offset.zero,
                                  child: Opacity(
                                    // ignore: unnecessary_null_comparison
                                    opacity: slideAnimation != null ? (slideAnimation.value + 1.0).clamp(0.0, 1.0) : 1.0,
                                    child: Hero(
                                      tag: 'thread_${thread.id}', // For smooth navigation animation
                                      child: Card(
                                        margin: EdgeInsets.all(8),
                                        elevation: 4,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(12),
                                          onTap: () => Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              pageBuilder: (context, animation, secondaryAnimation) => ThreadDetailScreen(
                                                thread: thread,
                                                username: username ?? '',
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
                                          child: Container(
                                            padding: EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              gradient: LinearGradient(
                                                colors: [Colors.white, Colors.blue[50]!],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    AnimatedRoundTableIcon(size: 20),
                                                    SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        thread.title,
                                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  thread.body,
                                                  maxLines: 3,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(color: Colors.grey[600]),
                                                ),
                                                SizedBox(height: 12),
                                                Wrap(
                                                  spacing: 4,
                                                  children: [
                                                    Chip(
                                                      label: Text(thread.category),
                                                      backgroundColor: Colors.blue[100],
                                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                                    ),
                                                    ...thread.tags.take(2).map((t) => Chip(
                                                      label: Text('#$t'),
                                                      backgroundColor: Colors.green[100],
                                                      padding: EdgeInsets.symmetric(horizontal: 4),
                                                    )),
                                                    if (thread.tags.length > 2)
                                                      Chip(label: Text('+${thread.tags.length - 2} more'), backgroundColor: Colors.grey[200]),
                                                  ],
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  '${thread.creatorRole.isNotEmpty ? '${thread.creatorRole} • ' : ''}${thread.creator} • ${thread.createdAt.toString().split(' ')[0]}',
                                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                                ),
                                                SizedBox(height: 12),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                                  children: [
                                                    _ActionButton(
                                                      icon: Icons.lightbulb_outline,
                                                      label: '${thread.inspiredCount}',
                                                      onTap: () => _toggleInspire(thread.id),
                                                    ),
                                                    _ActionButton(
                                                      icon: Icons.comment_outlined,
                                                      label: '${thread.commentCount}',
                                                      onTap: () => Navigator.push(
                                                        context,
                                                        PageRouteBuilder(
                                                          pageBuilder: (context, animation, secondaryAnimation) => ThreadDetailScreen(
                                                            thread: thread,
                                                            username: username ?? '',
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
                                                    _ActionButton(
                                                      icon: Icons.people_outline,
                                                      label: '${thread.collabCount}',
                                                      onTap: () => _sendCollab(thread.id, 'Interested in discussing!'),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        backgroundColor: Colors.blue,
        // ignore: sort_child_properties_last
        child: Icon(Icons.add),
        tooltip: 'Start Roundtable',
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _staggerController.dispose();
    super.dispose();
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class ThreadDetailScreen extends StatefulWidget {
  final Thread thread;
  final String username;
  final int userId;

  // ignore: use_super_parameters
  const ThreadDetailScreen({
    Key? key,
    required this.thread,
    required this.username,
    required this.userId,
  }) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _ThreadDetailScreenState createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends State<ThreadDetailScreen> with TickerProviderStateMixin {
  List<Comment> comments = [];
  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;
  final TextEditingController _commentController = TextEditingController();
  late AnimationController _detailAnimationController;
  late Animation<double> _detailFadeAnimation;
  late AnimationController _rotationController;
  double _rotationAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _detailAnimationController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _rotationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _detailFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _detailAnimationController, curve: Curves.easeInBack),
    );
    _detailAnimationController.forward();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });
    try {
      final response = await http.get(
        Uri.parse('https://server.awarcrown.com/threads/comments?id=${widget.thread.id}')
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final commentList = data['comments'] as List;
        final commentMap = <int, List<Map<String, dynamic>>>{};
        for (var c in commentList) {
          final parentId = c['parent_comment_id'] as int?;
          if (parentId != null) {
            commentMap.putIfAbsent(parentId, () => []).add(c);
          }
        }
        setState(() {
          comments = commentList
              .where((c) => c['parent_comment_id'] == null)
              .map((c) => Comment.fromJson(c, commentMap))
              .toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load comments: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Failed to load comments: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load comments: $e'),
            action: SnackBarAction(label: 'Retry', onPressed: _loadComments),
          ),
        );
      }
    }
  }

  Future<void> _addComment(String body, {int? parentId}) async {
    if (widget.username.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to comment')),
        );
      }
      return;
    }
    try {
      final bodyData = json.encode({
        'body': body,
        'parent_id': parentId ?? 0,
        'username': widget.username,
      });
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/threads/comment?id=${widget.thread.id}'),
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        _commentController.clear();
        await _loadComments(); // Refresh comments
      } else {
        throw Exception('Failed to add comment: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add comment: $e')),
        );
      }
    }
  }

  Future<void> _sendCollab(int threadId, String message) async {
    if (widget.username.isEmpty) return;
    final oldCount = widget.thread.collabCount;
    widget.thread.collabCount++;
    if (mounted) setState(() {});
    try {
      final bodyData = json.encode({'message': message, 'username': widget.username});
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/threads/collab?id=$threadId'),
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = json.decode(response.body);
          if (data is Map<String, dynamic> && data.containsKey('collab_count')) {
            widget.thread.collabCount = data['collab_count'];
          }
        } catch (_) {
          // Keep optimistic update
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Joined the roundtable!')),
          );
        }
      } else {
        throw Exception('Failed to join roundtable: ${response.statusCode}');
      }
    } catch (e) {
      widget.thread.collabCount = oldCount;
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join roundtable: $e')),
        );
      }
    }
  }

  Future<void> _toggleInspire(int threadId) async {
    if (widget.username.isEmpty) return;
    final oldCount = widget.thread.inspiredCount;
    widget.thread.inspiredCount++;
    if (mounted) setState(() {});
    try {
      final bodyData = json.encode({'type': 'inspired', 'username': widget.username});
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/threads/inspire?id=$threadId'),
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = json.decode(response.body);
          if (data is Map<String, dynamic> && data.containsKey('inspired_count')) {
            widget.thread.inspiredCount = data['inspired_count'];
          }
        } catch (_) {
          // Keep optimistic update
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Inspired by this discussion!')),
          );
        }
      } else {
        throw Exception('Failed to toggle inspire: ${response.statusCode}');
      }
    } catch (e) {
      widget.thread.inspiredCount = oldCount;
      if (mounted) setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle inspire: $e')),
        );
      }
    }
  }

  Widget _buildCircularCommentLayout() {
    if (comments.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              AnimatedRoundTableIcon(size: 50),
              SizedBox(height: 8),
              Text('No comments yet'),
              SizedBox(height: 8),
              Text('Join the discussion around the table!'),
            ],
          ),
        ),
      );
    }

    final ringRadius = 120.0;
    final center = Offset(MediaQuery.of(context).size.width / 2, 200.0);

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _rotationAngle += details.delta.dx / 100;
        });
      },
      child: Container(
        height: 500,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Central table
            AnimatedRoundTableIcon(size: 100),
            // Comments in ring
            ...comments.asMap().entries.map((entry) {
              final index = entry.key;
              final comment = entry.value;
              final angle = (2 * pi / comments.length * index) + _rotationAngle;
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
                        ..rotateY((1 - value) * pi / 4) // Flip in like dealing cards
                        ..rotateZ(angle),
                      child: Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1 - value) * 50), // Rise from bottom
                          child: Card(
                            child: Container(
                              width: 160,
                              padding: EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 10,
                                        backgroundColor: Colors.blue[100],
                                        child: Text(comment.commenter[0].toUpperCase(), style: TextStyle(fontSize: 10, color: Colors.blue)),
                                      ),
                                      SizedBox(width: 4),
                                      Expanded(child: Text(comment.commenter, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    ],
                                  ),
                                  SizedBox(height: 4),
                                  Text(comment.body, style: TextStyle(fontSize: 11), maxLines: 3, overflow: TextOverflow.ellipsis),
                                  if (comment.replies.isNotEmpty) ...[
                                    SizedBox(height: 4),
                                    Text('${comment.replies.length} replies', style: TextStyle(fontSize: 10, color: Colors.grey)),
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
            // Replies as spokes (simplified: show count or mini previews outward)
            ...comments.expand((comment) => comment.replies.map((reply) {
              // Position replies further out; for brevity, add as small badges
              return Positioned(
                // Calculate position based on parent angle + offset
                child: Container(), // Placeholder for reply spokes
              );
            })).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsSection() {
    if (isLoading) {
      return ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: 3,
        itemBuilder: (context, index) => Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            margin: EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(height: 80, child: Container(color: Colors.white)),
          ),
        ),
      );
    } else if (hasError) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 50, color: Colors.red[300]),
              SizedBox(height: 8),
              Text(errorMessage ?? 'Failed to load comments'),
              SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loadComments,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    } else {
      return _buildCircularCommentLayout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _detailFadeAnimation,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                title: Row(
                  children: [
                    AnimatedRoundTableIcon(size: 20, color: Colors.white),
                    SizedBox(width: 4),
                    Flexible(child: Text(widget.thread.title)),
                  ],
                ),
                background: Hero(
                  tag: 'thread_${widget.thread.id}',
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[600]!, Colors.blue[800]!],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.thread.title,
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 8),
                          Text(
                            widget.thread.body,
                            style: TextStyle(color: Colors.white70),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 16),
                          Wrap(
                            spacing: 4,
                            children: [
                              Chip(label: Text(widget.thread.category), backgroundColor: Colors.white24),
                              SizedBox(width: 8),
                              ...widget.thread.tags.take(3).map((t) => Chip(
                                label: Text('#$t'),
                                backgroundColor: Colors.white24,
                                padding: EdgeInsets.symmetric(horizontal: 4),
                              )),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              backgroundColor: Colors.blue,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hosted by ${widget.thread.creator} • ${widget.thread.createdAt.toString().split(' ')[0]}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 16),
                    Text(
                      widget.thread.body,
                      style: TextStyle(fontSize: 16, height: 1.5),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ActionButton(
                          icon: Icons.lightbulb_outline,
                          label: '${widget.thread.inspiredCount}',
                          onTap: () => _toggleInspire(widget.thread.id),
                        ),
                        _ActionButton(
                          icon: Icons.people_outline,
                          label: '${widget.thread.collabCount}',
                          onTap: () => _sendCollab(widget.thread.id, 'Interested in joining!'),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(Icons.comment, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('Discussion (${widget.thread.commentCount})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    _buildCommentsSection(),
                    SizedBox(height: 16),
                    if (!isLoading && !hasError)
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commentController,
                                  decoration: InputDecoration(
                                    hintText: 'Share your thoughts...',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  ),
                                  onSubmitted: (text) {
                                    if (text.isNotEmpty) {
                                      _addComment(text);
                                    }
                                  },
                                ),
                              ),
                              SizedBox(width: 8),
                              FloatingActionButton(
                                mini: true,
                                backgroundColor: Colors.blue,
                                onPressed: () {
                                  if (_commentController.text.isNotEmpty) {
                                    _addComment(_commentController.text);
                                  }
                                },
                                child: Icon(Icons.send, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _detailAnimationController.dispose();
    _rotationController.dispose();
    _commentController.dispose();
    super.dispose();
  }
}