import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shimmer/shimmer.dart'; 

class Thread {
  final int id;
  final String title;
  final String body;
  final String category;
  final String creator;
  final String creatorRole;
  final int inspiredCount;
  final int commentCount;
  final int collabCount;
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

class ThreadsScreen extends StatefulWidget {
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
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _initializeData();
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
        setState(() {
          threads = data.map((json) => Thread.fromJson(json)).toList();
          isLoading = false;
        });
      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = 'Failed to fetch threads: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load threads: $e'),
            action: SnackBarAction(label: 'Retry', onPressed: _fetchThreads),
          ),
        );
      }
    }
  }

  Future<void> _createThread(String title, String body, String category, List<String> tags) async {
    if (userId == null || userId == 0 || username == null || username!.isEmpty) {
      if (mounted) {
        _showError('Please log in to create a thread');
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
        await _fetchThreads();
        if (mounted) Navigator.pop(context);
      } else {
        throw Exception('Failed to create thread: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to create thread: $e');
      }
    }
  }

  Future<void> _toggleInspire(int threadId) async {
    if (username == null || username!.isEmpty) return;
    try {
      final bodyData = json.encode({'type': 'inspired', 'username': username});
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/threads/inspire?id=$threadId'),
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchThreads();
      } else {
        throw Exception('Failed to toggle inspire: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to toggle inspire: $e');
      }
    }
  }

  Future<void> _sendCollab(int threadId, String message) async {
    if (username == null || username!.isEmpty) return;
    try {
      final bodyData = json.encode({'message': message, 'username': username});
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/threads/collab?id=$threadId'),
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        await _fetchThreads();
        if (mounted) {
          _showSuccess('Collab request sent!');
        }
      } else {
        throw Exception('Failed to send collab: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to send collab: $e');
      }
    }
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
          title: Row(children: [Icon(Icons.add, color: Colors.blue), SizedBox(width: 8), Text('Create Thread')]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleController, decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                )),
                SizedBox(height: 8),
                TextField(
                  controller: bodyController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Body',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
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
                    labelText: 'Add Tag (Enter to add)',
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
              child: Text('Create'),
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
              Icon(Icons.login, size: 80, color: Colors.grey[400]),
              SizedBox(height: 16),
              Text(
                'Please log in to view threads',
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
        title: Text('Threads', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0, // Material 3 flat
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.sort),
            onSelected: (value) {
              setState(() => sort = value);
              _fetchThreads();
            },
            itemBuilder: (context) => ['Recent', 'Trending', 'Innovative']
                .map((s) => PopupMenuItem(value: s.toLowerCase(), child: Text(s)))
                .toList(),
          ),
          IconButton(onPressed: _showCreateDialog, icon: Icon(Icons.add, color: Colors.blue)),
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
                                  Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
                                  SizedBox(height: 16),
                                  Text(
                                    'No threads available',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Be the first to create one!',
                                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                  ),
                                  SizedBox(height: 24),
                                  ElevatedButton.icon(
                                    onPressed: _showCreateDialog,
                                    icon: Icon(Icons.add),
                                    label: Text('Create Thread'),
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
                            return Hero(
                              tag: 'thread_${thread.id}', // For smooth navigation animation
                              child: Card(
                                margin: EdgeInsets.all(8),
                                elevation: 4,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ThreadDetailScreen(
                                        thread: thread,
                                        username: username ?? '',
                                        userId: userId ?? 0,
                                      ),
                                    ),
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      gradient: LinearGradient(
                                        colors: [Colors.white, Colors.blue[50]!], // Subtle gradient
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          thread.title,
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          thread.body,
                                          maxLines: 3,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                        SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Chip(
                                              label: Text(thread.category),
                                              backgroundColor: Colors.blue[100],
                                              padding: EdgeInsets.symmetric(horizontal: 8),
                                            ),
                                            ...thread.tags.take(2).map((t) => Padding(
                                              padding: EdgeInsets.only(left: 4),
                                              child: Chip(
                                                label: Text('#$t'),
                                                backgroundColor: Colors.green[100],
                                                padding: EdgeInsets.symmetric(horizontal: 4),
                                              ),
                                            )),
                                            if (thread.tags.length > 2)
                                              Padding(
                                                padding: EdgeInsets.only(left: 4),
                                                child: Chip(label: Text('+${thread.tags.length - 2} more'), backgroundColor: Colors.grey[200]),
                                              ),
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
                                                MaterialPageRoute(
                                                  builder: (context) => ThreadDetailScreen(
                                                    thread: thread,
                                                    username: username ?? '',
                                                    userId: userId ?? 0,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            _ActionButton(
                                              icon: Icons.people_outline,
                                              label: '${thread.collabCount}',
                                              onTap: () => _sendCollab(thread.id, 'Interested in collaborating!'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
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
        tooltip: 'Create Thread',
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
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

class _ThreadDetailScreenState extends State<ThreadDetailScreen> {
  List<Comment> comments = [];
  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
        await _loadComments(); // Refresh
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
    try {
      final bodyData = json.encode({'message': message, 'username': widget.username});
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/threads/collab?id=$threadId'),
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Collab request sent!')),
          );
        }
      } else {
        throw Exception('Failed to send collab: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send collab: $e')),
        );
      }
    }
  }

  Future<void> _toggleInspire(int threadId) async {
    if (widget.username.isEmpty) return;
    try {
      final bodyData = json.encode({'type': 'inspired', 'username': widget.username});
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/threads/inspire?id=$threadId'),
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      ).timeout(Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Optionally refresh thread data, but for now, just snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Inspired!')),
          );
        }
      } else {
        throw Exception('Failed to toggle inspire: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle inspire: $e')),
        );
      }
    }
  }

  Widget _buildCommentTree(Comment comment, {int level = 0}) {
    return Padding(
      padding: EdgeInsets.only(left: level * 16.0),
      child: Card(
        margin: EdgeInsets.symmetric(vertical: 4),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.blue[100],
                    child: Text(comment.commenter[0].toUpperCase(), style: TextStyle(fontSize: 12)),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(comment.commenter, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text(comment.createdAt.toString().split(' ')[1].substring(0, 5), style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(comment.body),
              if (comment.replies.isNotEmpty)
                ...comment.replies.map((reply) => _buildCommentTree(reply, level: level + 1)),
            ],
          ),
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
    } else if (comments.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.comment_outlined, size: 50, color: Colors.grey[400]),
              SizedBox(height: 8),
              Text('No comments yet'),
              SizedBox(height: 8),
              Text('Be the first to comment!'),
            ],
          ),
        ),
      );
    } else {
      return ListView.builder(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemCount: comments.length,
        itemBuilder: (context, index) => _buildCommentTree(comments[index]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(widget.thread.title),
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
                        Row(
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
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'By ${widget.thread.creator} • ${widget.thread.createdAt.toString().split(' ')[0]}',
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
                        onTap: () => _sendCollab(widget.thread.id, 'Interested!'),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Text('Comments (${widget.thread.commentCount})', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                                  hintText: 'Add a comment...',
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
                              onPressed: () {
                                if (_commentController.text.isNotEmpty) {
                                  _addComment(_commentController.text);
                                }
                              },
                              child: Icon(Icons.send),
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
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}