import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ideaship/feed/publicprofile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'threads.dart';


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
  State<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
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
  final ScrollController _commentsScrollController = ScrollController();
  Timer? _commentsRetryTimer;
  int _commentsRetryCount = 0;
  static const int _commentsMaxRetries = 3;
  http.Client? _commentsHttpClient;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = false;
  final Set<int> _loadedCommentIds = <int>{};

  // UI State
  final Color _pageColor = const Color(0xFFFDFBF5);
  final Color _cardColor = Colors.white;
  final Color _primaryTextColor = const Color(0xFF1a2533);
  final Color _secondaryTextColor = const Color(0xFF6B7280);
  int? _replyToCommentId;
  final FocusNode _commentFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _commentsHttpClient = http.Client();
    _detailAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _detailFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _detailAnimationController, curve: Curves.easeInOut),
    );
    _detailAnimationController.forward();
    _initConnectivity();
    _loadComments();
    _syncInspireStatus();
  }
  
  
  void _navigateToProfile(String username) {
    if (username.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicProfilePage(targetUsername: username),
      ),
    );
  }
 

  void _addCommentIds(Comment comment) {
    _loadedCommentIds.add(comment.id);
    for (var reply in comment.replies) {
      _addCommentIds(reply);
    }
  }

  void _updateLoadedIdsForList(List<Comment> comList) {
    for (var c in comList) {
      _addCommentIds(c);
    }
  }

  Future<void> _initConnectivity() async {
    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    _isOnline = results.any((result) => result != ConnectivityResult.none);
    if (mounted) setState(() {});
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final wasOnline = _isOnline;
      _isOnline = results.any((result) => result != ConnectivityResult.none);
      if (mounted) setState(() {});
      if (mounted && _isOnline && !wasOnline) {
        _loadComments();
      }
    });
  }

  Future<bool> _isDeviceOnline() async {
    try {
      final connectivity = Connectivity();
      final results = await connectivity.checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  Future<void> _syncInspireStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'inspired_${widget.thread.id}';
    if (prefs.containsKey(key)) {
      widget.thread.isInspiredByMe = prefs.getBool(key) ?? false;
      if (mounted) setState(() {});
      return;
    }
    final bool online = await _isDeviceOnline();
    if (!online) return;
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

  @override
  void dispose() {
    _commentsRetryTimer?.cancel();
    _connectivitySubscription?.cancel();
    _commentsScrollController.dispose();
    _detailAnimationController.dispose();
    _commentController.dispose();
    _commentsHttpClient?.close();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
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

    if (mounted) {
      setState(() {
        isLoading = true;
        hasError = false;
      });
    }

    List<Comment> newComments = [];
    final bool online = await _isDeviceOnline();
    bool fetchSuccess = false;
    bool usingCache = false;

    if (online) {
      try {
        final code = await _getThreadCode(widget.thread.id);
        final uri = Uri.parse(
          'https://server.awarcrown.com/threads/comments'
          '?id=${widget.thread.id}'
          '&username=${Uri.encodeComponent(widget.username)}'
          '&limit=1000'
          '&offset=0'
          '${code != null ? '&code=${Uri.encodeComponent(code)}' : ''}',
        );

        final response = await (_commentsHttpClient ?? http.Client())
            .get(uri)
            .timeout(const Duration(seconds: 15));

        debugPrint('Comments response: ${response.body}');
        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = json.decode(response.body);
          final commentList = data['comments'] as List<dynamic>? ?? [];

          for (final dynamic c in commentList) {
            if (c is Map<String, dynamic>) {
              try {
                newComments.add(Comment.fromJson(c, isFromCache: false));
              } catch (e) {
                debugPrint('Error parsing comment: $e');
              }
            }
          }
          fetchSuccess = true;
        } else if (response.statusCode == 403) {
          _showError('Access denied. Invalid code for private thread.');
        } else if (response.statusCode == 404) {
          newComments = [];
        } else {
          throw Exception(
            'Failed to load comments: ${response.statusCode} - ${response.body}',
          );
        }
      } catch (e) {
        debugPrint('Load comments error: $e');
      }
    }

    if (!online || !fetchSuccess) {
      usingCache = true;
      newComments = List<Comment>.from(comments);
      if (newComments.isEmpty) {
        if (mounted) {
          setState(() {
            isLoading = false;
            hasError = true;
            errorMessage = 'No cached comments. Please connect to internet.';
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        comments = newComments;
        _loadedCommentIds.clear();
        _updateLoadedIdsForList(comments);
        isLoading = false;
        hasError = false;
        _commentsRetryCount = 0;
      });
    }

    if (usingCache && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Showing cached comments. Syncing when online.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _scheduleCommentsRetry() {
    if (_commentsRetryCount >= _commentsMaxRetries) return;
    _commentsRetryTimer?.cancel();
    _commentsRetryCount++;
    final delay = Duration(seconds: 2) * (1 << (_commentsRetryCount - 1));
    _commentsRetryTimer = Timer(delay, () async {
      final bool online = await _isDeviceOnline();
      if (mounted && !isLoading && online) {
        _loadComments();
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

  Future<void> _addComment(String body, {int? parentId}) async {
    final bool online = await _isDeviceOnline();
    if (!online) {
      _showError('Please connect to internet to add comment.');
      return;
    }
    if (widget.username.isEmpty) {
      if (mounted) _showError('Please log in to comment');
      return;
    }
    if (body.isEmpty) {
      if (mounted) _showError('Comment cannot be empty');
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
      final uri = Uri.parse('https://server.awarcrown.com/threads/comments?id=${widget.thread.id}');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: bodyData,
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 || response.statusCode == 201) {
        _commentController.clear();
        _commentFocusNode.unfocus();
        setState(() => _replyToCommentId = null);
        await _loadComments();
        _showSuccess('Comment added successfully!');
      } else {
        throw Exception('Failed to add comment: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) _showError('Failed to add comment: ${_getErrorMessage(e)}');
    }
  }

  void _submitComment() {
    if (_commentController.text.isNotEmpty) {
      _addComment(_commentController.text, parentId: _replyToCommentId);
    }
  }

  void _onReplyTapped(Comment comment) {
    setState(() {
      _replyToCommentId = comment.id;
      _commentController.text = '@${comment.commenter} ';
      _commentController.selection = TextSelection.fromPosition(
          TextPosition(offset: _commentController.text.length));
      _commentFocusNode.requestFocus();
    });
  }

  
  Future<void> _toggleInspire(int threadId) async {
    final bool online = await _isDeviceOnline();
    if (!online) {
      _showError('Please connect to internet to update inspiration.');
      return;
    }
    if (widget.username.isEmpty) return;
    final oldCount = widget.thread.inspiredCount;
    final oldInspired = widget.thread.isInspiredByMe;
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
      widget.thread.isInspiredByMe = oldInspired;
      widget.thread.inspiredCount = oldCount;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('inspired_$threadId', oldInspired);
      if (mounted) setState(() {});
      if (mounted) _showError('Failed to toggle inspire: ${_getErrorMessage(e)}');
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

  Widget _buildLinearCommentLayout() {
    final bool usingCache = comments.any((c) => c.isFromCache);
    return Column(
      children: [
        if (usingCache)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.orange.withOpacity(0.1),
            child: const Text(
              'Showing cached comments. Pull to refresh for latest.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ListView.builder(
          itemCount: comments.length,
          controller: _commentsScrollController,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemBuilder: (context, index) {
            final comment = comments[index];
            return _CommentCard(comment: comment, onReply: _onReplyTapped);
          },
        ),
      ],
    );
  }

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
            child: SizedBox(height: 80, child: Container(color: Colors.white)),
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
                onPressed: _loadComments,
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
              const Icon(Icons.comment_outlined, size: 60, color: Color(0xFF6B7280)),
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
      return _buildLinearCommentLayout();
    }
  }

  Widget _buildCommentInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.blue[100],
            child: Text(
              widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
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
                hintText: _replyToCommentId == null ? 'Pull up a chair...' : 'Replying...',
                hintStyle: TextStyle(color: _secondaryTextColor),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Color(0xFF4A90E2), width: 2),
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

  Widget _HeaderActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
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
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // --- MODIFIED _buildHeaderInfo ---
  Widget _buildHeaderInfo(BuildContext context) {
    return Row(
      children: [
        GestureDetector( // <-- WRAPPED
          onTap: () => _navigateToProfile(widget.thread.creator), // <-- ADDED
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withOpacity(0.3),
            child: Text(
              widget.thread.creator.isNotEmpty ? widget.thread.creator[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector( // <-- WRAPPED
          onTap: () => _navigateToProfile(widget.thread.creator), // <-- ADDED
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.thread.creator,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                '${widget.thread.creatorRole.isNotEmpty ? '${widget.thread.creatorRole} • ' : ''}${widget.thread.createdAt.toString().split(' ')[0]}',
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
              ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
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
  // --- END OF MODIFICATION ---

  Widget _buildTags() {
    if (widget.thread.tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: widget.thread.tags.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('#$t', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
            )).toList(),
      ),
    );
  }

  Future<void> _onRefresh() async {
    if (!_isOnline) {
      if (mounted) {
        _showError('Connect to internet to refresh.');
      }
      return;
    }
    await _loadComments();
  }

  @override
  Widget build(BuildContext context) {
    const Color gradientStart = Color(0xFF6A11CB); // Deep Purple
    const Color gradientMid = Color(0xFF2575FC); // Vibrant Blue
    const Color gradientEnd = Color(0xFF00C9FF); // Bright Cyan
    
    final bool isInspired = widget.thread.isInspiredByMe;
    final Color inspireColor = isInspired ? const Color(0xFFF59E0B) : const Color(0xFF90F0C0);
    final bool usingCache = widget.thread.isFromCache;
    return Scaffold(
      backgroundColor: _pageColor,
      body: Column(
        children: [
          if (usingCache)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.orange.withOpacity(0.1),
              child: const Text(
                'Data from cache. Pull to refresh for latest.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 450,
                  floating: false,
                  pinned: true,
                  elevation: 2,
                  backgroundColor: gradientStart, 
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    background: Hero(
                      tag: 'thread_${widget.thread.id}',
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              gradientStart,
                              gradientMid,
                              gradientEnd,
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 56, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, height: 1.6),
                              ),
                              _buildTags(),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _HeaderActionButton(
                                      icon: isInspired ? Icons.lightbulb : Icons.lightbulb_outline,
                                      label: '${widget.thread.inspiredCount}',
                                      color: inspireColor,
                                      onTap: () => _toggleInspire(widget.thread.id),
                                    ),
                                    _HeaderActionButton(
                                      icon: Icons.comment_outlined,
                                      label: '${widget.thread.commentCount}',
                                      color: const Color(0xFF90F0C0),
                                      onTap: () {},
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
                SliverToBoxAdapter(
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: FadeTransition(
                      opacity: _detailFadeAnimation,
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(20, 20, 12, 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Discussion',
                                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1a2533)),
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
                ),
              ],
            ),
          ),
          if (!isLoading && !hasError && widget.username.isNotEmpty) _buildCommentInputBar(),
        ],
      ),
    );
  }
}

class _CommentCard extends StatefulWidget {
  final Comment comment;
  final bool isReply;
  final Function(Comment) onReply;

  const _CommentCard({
    required this.comment,
    this.isReply = false,
    required this.onReply,
  });

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = false; // Start collapsed for better UX with replies
  }

  String get _timeAgo {
    final diff = DateTime.now().difference(widget.comment.createdAt);
    if (diff.inDays >= 1) {
      return '${diff.inDays}d';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes}m';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: widget.isReply ? 32.0 : 16.0, right: 16.0, top: 12.0, bottom: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // --- MODIFIED _CommentCard ---
              GestureDetector( // <-- WRAPPED
                onTap: () { // <-- ADDED
                  if (widget.comment.commenter.isEmpty) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PublicProfilePage(targetUsername: widget.comment.commenter),
                    ),
                  );
                },
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    widget.comment.commenter.isNotEmpty ? widget.comment.commenter[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector( // <-- WRAPPED
                      onTap: () { // <-- ADDED
                        if (widget.comment.commenter.isEmpty) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PublicProfilePage(targetUsername: widget.comment.commenter),
                          ),
                        );
                      },
                      child: Text(
                        widget.comment.commenter,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF1a2533)),
                      ),
                    ),
                    Text(
                      _timeAgo,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              // --- END OF MODIFICATION ---
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 42.0, top: 8, bottom: 4),
            child: Text(
              widget.comment.body,
              style: const TextStyle(fontSize: 15, color: Color(0xFF333D4B), height: 1.5),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 30.0),
            child: TextButton(
              onPressed: () => widget.onReply(widget.comment),
              child: const Text(
                'Reply',
                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4A90E2)),
              ),
            ),
          ),
          if (widget.comment.replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 30.0, top: 4.0),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, size: 16),
                label: Text(
                  _isExpanded
                      ? 'Hide replies'
                      : 'View ${widget.comment.replies.length} ${widget.comment.replies.length > 1 ? 'replies' : 'reply'}',
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4A90E2), fontSize: 13),
                ),
              ),
            ),
          if (widget.comment.replies.isNotEmpty && _isExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 12.0, top: 8.0),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Color(0xFFE5E9F0), width: 2.0)),
                ),
                child: Column(
                  children: widget.comment.replies
                      .map((reply) => _CommentCard(comment: reply, isReply: true, onReply: widget.onReply))
                      .toList(),
                ),
              ),
            ),
          if (widget.comment.isFromCache)
            Padding(
              padding: const EdgeInsets.only(left: 42.0, top: 4),
              child: Text('Cached', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ),
        ],
      ),
    );
  }
}