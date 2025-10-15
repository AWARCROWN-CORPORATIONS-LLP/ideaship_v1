import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'publicprofile.dart';
class Skeleton extends StatefulWidget {
  final double height;
  final double width;
  final String type;
  const Skeleton(
      {super.key, this.height = 20, this.width = 20, this.type = 'square'});
  @override
  State<Skeleton> createState() => _SkeletonState();
}
class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> gradientPosition;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 1500), vsync: this);
    gradientPosition = Tween<double>(
      begin: -3,
      end: 10,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    _controller.repeat();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
          borderRadius: widget.type == 'circle'
              ? BorderRadius.circular(50)
              : BorderRadius.circular(4),
          gradient: LinearGradient(
              begin: Alignment(gradientPosition.value, 0.0),
              end: const Alignment(-1.0, 0.0),
              colors: isDark
                  ? const [Colors.white10, Colors.white24, Colors.white10]
                  : const [Colors.grey, Colors.grey, Colors.grey])),
    );
  }
}
class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width - 32;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Skeleton(height: 40, width: 40, type: 'circle'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Skeleton(height: 14, width: 120),
                      SizedBox(height: 4),
                      Skeleton(height: 12, width: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                const Skeleton(height: 16, width: double.infinity),
                const SizedBox(height: 8),
                Skeleton(height: 16, width: double.infinity),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                width: screenWidth,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: const [
                Row(
                  children: [
                    Skeleton(height: 20, width: 100),
                    Spacer(),
                    Skeleton(height: 20, width: 20),
                  ],
                ),
                SizedBox(height: 8),
                Skeleton(height: 12, width: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class CommentSkeleton extends StatelessWidget {
  const CommentSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(height: 32, width: 32, type: 'circle'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class CommentItem extends StatelessWidget {
  final dynamic comment;
  final int depth;
  final int postId;
  final Function(int, String) onReply;
  final Function(int, int) onLike;
  const CommentItem({
    super.key,
    required this.comment,
    required this.depth,
    required this.postId,
    required this.onReply,
    required this.onLike,
  });
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiked = comment['current_reaction'] != null;
    final leftPadding = 16.0 + (depth * 24.0);
    return Padding(
      padding: EdgeInsets.only(left: leftPadding, top: 12.0, bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: comment['profile_picture'] != null
                ? NetworkImage('https://server.awarcrown.com/accessprofile/uploads/${comment['profile_picture']}')
                : null,
            child: comment['profile_picture'] == null
                ? Icon(Icons.person, size: 18, color: colorScheme.onSurfaceVariant)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment['username'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTimeStatic(comment['created_at']),
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment['comment'] ?? '',
                  style: TextStyle(fontSize: 14, height: 1.4, color: colorScheme.onSurface),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => onLike(comment['comment_id'], postId),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              size: 18,
                              color: isLiked ? Colors.red : null,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${comment['like_count'] ?? 0}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isLiked ? Colors.red : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: () => onReply(comment['comment_id'], comment['username'] ?? ''),
                        child: Text(
                          'Reply',
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  static String _formatTimeStatic(String? timeString) {
    if (timeString == null) return 'Unknown';
    try {
      final date = DateTime.parse(timeString);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays > 365) {
        return '${(diff.inDays / 365).floor()}y ago';
      } else if (diff.inDays > 30) {
        return '${(diff.inDays / 30).floor()}mo ago';
      } else if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (_) {
      return timeString;
    }
  }
}
class CommentsPage extends StatefulWidget {
  final dynamic post;
  final List<dynamic> comments;
  final String username;
  final int? userId;
  const CommentsPage({
    super.key,
    required this.post,
    required this.comments,
    required this.username,
    required this.userId,
  });
  @override
  State<CommentsPage> createState() => _CommentsPageState();
}
class _CommentsPageState extends State<CommentsPage> {
  late dynamic post;
  late String _username;
  late int? _userId;
  List<dynamic> comments = [];
  bool commentLoading = false;
  final TextEditingController commentController = TextEditingController();
  final FocusNode focusNode = FocusNode();
  int? replyToCommentId;
  String replyToUsername = '';
  final Map<int, bool> commentIsReacting = {};
  @override
  void initState() {
    super.initState();
    post = widget.post;
    _username = widget.username;
    _userId = widget.userId;
    comments = widget.comments;
    _initializeUserId();
    _processLikeQueue();
    if (comments.isEmpty) {
      _fetchComments();
    }
  }
  Future<void> _initializeUserId() async {
    if (_userId == null || _userId == 0) {
      await _fetchUserId();
    }
  }
  Future<void> _fetchUserId() async {
    if (_username.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('https://server.awarcrown.com/feed/get_user?username=${Uri.encodeComponent(_username)}'),
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
            _userId = parsedUserId;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('user_id', _userId!);
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
  @override
  void dispose() {
    commentController.dispose();
    focusNode.dispose();
    super.dispose();
  }
  Future<void> _queueLikeAction(Map<String, dynamic> actionMap) async {
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> queue = [];
    final queueStr = prefs.getString('like_queue');
    if (queueStr != null) {
      queue = json.decode(queueStr);
    }
    queue.add(actionMap);
    await prefs.setString('like_queue', json.encode(queue));
  }
  Future<void> _processLikeQueue() async {
    if (_userId == null || _userId == 0) {
      await _fetchUserId();
      if (_userId == null || _userId == 0) return;
    }
    final prefs = await SharedPreferences.getInstance();
    final queueStr = prefs.getString('like_queue');
    if (queueStr == null || queueStr.isEmpty) {
      await prefs.remove('like_queue');
      return;
    }
    List<dynamic> queue = json.decode(queueStr);
    if (queue.isEmpty) {
      await prefs.remove('like_queue');
      return;
    }
    bool allSuccess = true;
    for (var item in List.from(queue)) {
      try {
        String endpoint;
        String body;
        if (item['type'] == 'post') {
          endpoint = 'https://server.awarcrown.com/feed/like_action';
          body = 'post_id=${item['id']}&user_id=$_userId';
        } else if (item['type'] == 'comment') {
          endpoint = 'https://server.awarcrown.com/feed/comment_reaction';
          body = 'comment_id=${item['id']}&user_id=$_userId&action=${item['action']}';
        } else {
          continue;
        }
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: body,
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          throw http.ClientException('Server error: ${response.statusCode}');
        }
      } catch (e) {
        allSuccess = false;
        break;
      }
    }
    if (allSuccess) {
      await prefs.remove('like_queue');
      if (mounted) {
        _showSuccess('Synced offline actions');
        _fetchComments();
      }
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
  Future<void> _fetchComments() async {
    await _processLikeQueue();
    if (commentLoading || _username.isEmpty) return;
    if (mounted) setState(() => commentLoading = true);
    try {
      final url = 'https://server.awarcrown.com/feed/fetch_comments?post_id=${post['post_id']}&username=${Uri.encodeComponent(_username)}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && mounted) {
          setState(() => comments = data['comments'] ?? []);
        }
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        _showError(_getErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => commentLoading = false);
    }
  }
  Future<void> _toggleCommentReaction(int commentId) async {
    if (!mounted) return;
    if (_userId == null || _userId == 0) {
      await _fetchUserId();
      if (!mounted || _userId == null || _userId == 0) {
        _showError('User not authenticated. Please log in again.');
        return;
      }
    }
    if (commentIsReacting[commentId] ?? false) return;
    final commentIndex = comments.indexWhere((c) => c['comment_id'] == commentId);
    if (commentIndex == -1) return;
    setState(() => commentIsReacting[commentId] = true);
    final comment = comments[commentIndex];
    final oldLiked = comment['current_reaction'] != null;
    final oldCount = comment['like_count'] ?? 0;
    final newLiked = !oldLiked;
    final newCount = oldCount + (newLiked ? 1 : -1);
    setState(() {
      comments[commentIndex]['current_reaction'] = newLiked ? 'like' : null;
      comments[commentIndex]['like_count'] = newCount;
    });
    final action = newLiked ? 'like' : 'unlike';
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/comment_reaction'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'comment_id=$commentId&user_id=$_userId&action=$action',
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && mounted) {
          setState(() {
            if (data['like_count'] != null) {
              comments[commentIndex]['like_count'] = data['like_count'];
            }
            if (data['is_liked'] != null) {
              comments[commentIndex]['current_reaction'] = data['is_liked'] ? 'like' : null;
            }
          });
        }
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      final isOfflineError = e is SocketException || e is TimeoutException;
      if (isOfflineError) {
        await _queueLikeAction({'type': 'comment', 'id': commentId, 'action': action});
        _showSuccess('Like action queued offline');
      } else {
        setState(() {
          comments[commentIndex]['current_reaction'] = oldLiked ? 'like' : null;
          comments[commentIndex]['like_count'] = oldCount;
        });
        _showError('Failed to ${newLiked ? 'like' : 'unlike'} comment: ${_getErrorMessage(e)}');
      }
    } finally {
      if (mounted) {
        setState(() => commentIsReacting[commentId] = false);
      }
    }
  }
  Future<void> _postComment(String text, {int? parentCommentId}) async {
    if (text.isEmpty || _username.isEmpty) return;
    try {
      String body = 'post_id=${post['post_id']}&username=${Uri.encodeComponent(_username)}&comment=${Uri.encodeComponent(text)}';
      if (parentCommentId != null) {
        body += '&parent_comment_id=$parentCommentId';
      }
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/submit_comment'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['status'] == 'success' && mounted) {
          comments.insert(0, data);
          commentController.clear();
          setState(() {
            replyToCommentId = null;
            replyToUsername = '';
          });
          final message = parentCommentId != null ? 'Reply posted' : 'Comment posted';
          _showSuccess(message);
        } else if (data is Map<String, dynamic> && data['status'] == 'error') {
          _showError(data['message'] ?? 'Failed to post comment');
        } else {
          _showError('Failed to post comment');
        }
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Failed to post comment: ${_getErrorMessage(e)}');
    }
  }
  void _navigateToProfile(String username, int userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicProfilePage(targetUsername: username),
      ),
    );
  }
  void _addCommentsToFlat(List<dynamic> flat, dynamic comment, int depth) {
    (comment as Map<String, dynamic>)['_depth'] = depth;
    flat.add(comment);
    final children = comments
        .where((c) => c['parent_comment_id'] == comment['comment_id'])
        .toList()
        ..sort((a, b) => b['created_at'].compareTo(a['created_at']));
    for (var child in children) {
      _addCommentsToFlat(flat, child, depth + 1);
    }
  }
  Widget _buildCommentsList() {
    final allComments = comments;
    if (allComments.isEmpty) {
      return ListView(
        physics: const BouncingScrollPhysics(),
        cacheExtent: 1000.0,
        children: [
          const SizedBox(height: 200),
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'No comments yet. Be the first to comment!',
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 200),
        ],
      );
    }
    final flatComments = <dynamic>[];
    final mainComments = allComments
        .where((c) => c['parent_comment_id'] == null)
        .toList()
        ..sort((a, b) => b['created_at'].compareTo(a['created_at']));
    for (var main in mainComments) {
      _addCommentsToFlat(flatComments, main, 0);
    }
    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      shrinkWrap: false,
      cacheExtent: 1000.0,
      itemCount: flatComments.length,
      separatorBuilder: (context, index) {
        final depth = flatComments[index]['_depth'] as int;
        return Divider(
          height: 1,
          indent: 16.0 + (depth * 24.0),
          color: Theme.of(context).colorScheme.outline,
        );
      },
      itemBuilder: (context, index) {
        final comment = flatComments[index];
        final depth = comment['_depth'] as int;
        return CommentItem(
          comment: comment,
          depth: depth,
          postId: post['post_id'],
          onReply: (parentId, username) {
            setState(() {
              replyToCommentId = parentId;
              replyToUsername = username;
            });
            focusNode.requestFocus();
          },
          onLike: (commentId, postId) => _toggleCommentReaction(commentId),
        );
      },
    );
  }
  String _formatTime(String? timeString) {
    if (timeString == null) return 'Unknown';
    try {
      final date = DateTime.parse(timeString);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays > 365) {
        return '${(diff.inDays / 365).floor()}y ago';
      } else if (diff.inDays > 30) {
        return '${(diff.inDays / 30).floor()}mo ago';
      } else if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (_) {
      return timeString;
    }
  }
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final postId = post['post_id'];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Comments', style: TextStyle(color: colorScheme.onSurface)),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Divider(height: 1, color: colorScheme.outline),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchComments,
              color: colorScheme.primary,
              child: commentLoading
                  ? ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      cacheExtent: 1000.0,
                      itemCount: 10,
                      itemBuilder: (context, index) => const CommentSkeleton(),
                    )
                  : _buildCommentsList(),
            ),
          ),
          Container(
            color: colorScheme.surface,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (replyToUsername.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() {
                      replyToCommentId = null;
                      replyToUsername = '';
                    }),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '@$replyToUsername',
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.close,
                            size: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: commentController,
                    focusNode: focusNode,
                    style: TextStyle(color: colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: replyToCommentId != null
                          ? 'Write a reply...'
                          : 'Add a comment...',
                      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: colorScheme.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (value) {
                      final trimmed = value.trim();
                      if (trimmed.isNotEmpty) {
                        _postComment(
                          trimmed,
                          parentCommentId: replyToCommentId,
                        );
                      }
                    },
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: commentController,
                  builder: (context, value, child) {
                    final text = value.text.trim();
                    final isEnabled = text.isNotEmpty;
                    return Material(
                      color: isEnabled ? colorScheme.primary : colorScheme.onSurfaceVariant,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        onTap: isEnabled
                            ? () {
                                _postComment(
                                  text,
                                  parentCommentId: replyToCommentId,
                                );
                              }
                            : null,
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class PostsPage extends StatefulWidget {
  const PostsPage({super.key});
  @override
  _PostsPageState createState() => _PostsPageState();
}
class _PostsPageState extends State<PostsPage> with TickerProviderStateMixin {
  List<dynamic> posts = [];
  bool isLoading = false;
  bool hasMore = true;
  bool networkError = false;
  int? nextCursorId;
  final ScrollController _scrollController = ScrollController();
  Map<int, List<dynamic>> commentsMap = {};
  Map<int, bool> isLikingMap = {};
  Map<int, AnimationController> likeAnimationControllers = {};
  Map<int, bool> showHeartOverlay = {};
  Map<int, AnimationController> heartOverlayControllers = {};
  Map<int, bool> isFetchingComments = {};
  String _username = '';
  int? _userId;
  Timer? _scrollDebounceTimer;
  Map<int, bool> isFollowingMap = {};
  Map<int, bool> isProcessingFollow = {};
  @override
  void initState() {
    super.initState();
    _initializeData();
    _scrollController.addListener(_onScroll);
  }
  Future<void> _initializeData() async {
    await _loadUsername();
    await _processLikeQueue();
    await _loadPostsFromCache();
    await _updateFollowStatuses();
    await _fetchPosts();
  }
  @override
  void dispose() {
    _scrollController.dispose();
    _scrollDebounceTimer?.cancel();
    for (var c in likeAnimationControllers.values) {
      c.dispose();
    }
    for (var c in heartOverlayControllers.values) {
      c.dispose();
    }
    super.dispose();
  }
  Future<void> _queueLikeAction(Map<String, dynamic> actionMap) async {
    final prefs = await SharedPreferences.getInstance();
    List<dynamic> queue = [];
    final queueStr = prefs.getString('like_queue');
    if (queueStr != null) {
      queue = json.decode(queueStr);
    }
    queue.add(actionMap);
    await prefs.setString('like_queue', json.encode(queue));
  }
  Future<void> _processLikeQueue() async {
    if (_userId == null || _userId == 0) {
      await _fetchUserId();
      if (_userId == null || _userId == 0) return;
    }
    final prefs = await SharedPreferences.getInstance();
    final queueStr = prefs.getString('like_queue');
    if (queueStr == null || queueStr.isEmpty) {
      await prefs.remove('like_queue');
      return;
    }
    List<dynamic> queue = json.decode(queueStr);
    if (queue.isEmpty) {
      await prefs.remove('like_queue');
      return;
    }
    bool allSuccess = true;
    for (var item in List.from(queue)) {
      try {
        String endpoint;
        String body;
        if (item['type'] == 'post') {
          endpoint = 'https://server.awarcrown.com/feed/like_action';
          body = 'post_id=${item['id']}&user_id=$_userId';
        } else if (item['type'] == 'comment') {
          endpoint = 'https://server.awarcrown.com/feed/comment_reaction';
          body = 'comment_id=${item['id']}&user_id=$_userId&action=${item['action']}';
        } else {
          continue;
        }
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: body,
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          throw http.ClientException('Server error: ${response.statusCode}');
        }
      } catch (e) {
        allSuccess = false;
        break;
      }
    }
    if (allSuccess) {
      await prefs.remove('like_queue');
      if (mounted) {
        _showSuccess('Synced offline actions');
        await _refreshPosts();
      }
    }
  }
  Future<bool> _getIsFollowing(int followedId) async {
    if (_userId == null) return false;
    try {
      final response = await http.get(
        Uri.parse('https://server.awarcrown.com/feed/get_follower?follower_id=$_userId&followed_id=$followedId'),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          return data['is_following'] ?? false;
        }
      }
    } catch (e) {
      debugPrint('Error fetching follow status: $e');
    }
    return false;
  }
  Future<void> _updateFollowStatuses() async {
    if (_userId == null || posts.isEmpty) return;
    final uniqueFollowedIds = posts
        .where((p) => (p['user_id'] as int?) != _userId)
        .map((p) => p['user_id'] as int)
        .toSet();
    if (uniqueFollowedIds.isEmpty) return;
    final futures = uniqueFollowedIds.map((id) => _getIsFollowing(id));
    final results = await Future.wait(futures);
    int idx = 0;
    bool hasChanges = false;
    for (var id in uniqueFollowedIds) {
      final isFollow = results[idx++];
      final current = isFollowingMap[id] ?? false;
      if (current != isFollow) {
        hasChanges = true;
        isFollowingMap[id] = isFollow;
        for (var post in posts) {
          if (post['user_id'] == id) {
            post['is_following'] = isFollow;
          }
        }
      }
    }
    if (hasChanges && mounted) {
      setState(() {});
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
  Future<void> _savePostsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_posts', json.encode(posts));
      await prefs.setInt('cache_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Error saving posts to cache: $e');
    }
  }
  Future<void> _loadPostsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? cachedPostsJson = prefs.getString('cached_posts');
      final int? timestamp = prefs.getInt('cache_timestamp');
      if (cachedPostsJson != null && timestamp != null) {
        final cacheAge = DateTime.now().millisecondsSinceEpoch - timestamp;
        if (cacheAge < 3600000) {
          final parsedPosts = json.decode(cachedPostsJson);
          if (parsedPosts is List && mounted) {
            setState(() {
              posts = parsedPosts.cast<dynamic>();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading posts from cache: $e');
    }
  }
  Future<void> _loadUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _username = prefs.getString('username') ?? '';
          _userId = prefs.getInt('user_id');
        });
      }
      if (_userId == null || _userId == 0) {
        await _fetchUserId();
      }
    } catch (e) {
      debugPrint('Error loading username: $e');
    }
  }
  Future<void> _fetchUserId() async {
    if (_username.isEmpty) return;
    try {
      final response = await http.get(
        Uri.parse('https://server.awarcrown.com/feed/get_user?username=${Uri.encodeComponent(_username)}'),
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
            _userId = parsedUserId;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('user_id', _userId!);
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
  void _onScroll() {
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients &&
          _scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 300) {
        if (hasMore && !isLoading && !networkError) {
          _fetchMorePosts();
        }
      }
    });
  }
  Future<Map<String, dynamic>?> _fetchPostsData({int? cursorId}) async {
    if (_username.isEmpty) return null;
    try {
      final params = {'username': _username};
      if (cursorId != null) params['cursorId'] = cursorId.toString();
      final queryString = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final url = 'https://server.awarcrown.com/feed/fetch_posts?$queryString';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final parsed = json.decode(response.body);
        if (parsed is Map<String, dynamic>) {
          return parsed;
        } else {
          throw Exception('Invalid JSON structure');
        }
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
  Future<void> _fetchPosts({int? cursorId}) async {
    await _processLikeQueue();
    if (isLoading || _username.isEmpty) return;
    if (mounted) setState(() => isLoading = true);
    try {
      final data = await _fetchPostsData(cursorId: cursorId);
      if (data != null && mounted) {
        setState(() {
          networkError = false;
          final newPosts = data['posts'] ?? [];
          if (cursorId == null) {
            posts = newPosts;
          } else {
            final postsToAdd = newPosts.where((newPost) =>
                !posts.any((existing) => existing['post_id'] == newPost['post_id'])).toList();
            posts.addAll(postsToAdd);
          }
          nextCursorId = data['nextCursorId'];
          hasMore = nextCursorId != null;
        });
        await _savePostsToCache();
        await _updateFollowStatuses();
      }
    } catch (e) {
      if (mounted) {
        setState(() => networkError = true);
        _showError(_getErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
  Future<void> _fetchMorePosts() async {
    if (nextCursorId != null) {
      await _fetchPosts(cursorId: nextCursorId);
    }
  }
  Future<void> _refreshPosts() async {
    await _processLikeQueue();
    if (_username.isEmpty) return;
    setState(() {
      networkError = false;
      nextCursorId = null;
    });
    if (posts.isEmpty) {
      await _fetchPosts();
      return;
    }
    final oldFirstId = posts[0]['post_id'] as int;
    try {
      final data = await _fetchPostsData();
      if (data == null || !mounted) return;
      setState(() => networkError = false);
      final newPosts = data['posts'] ?? [];
      final newOnes = newPosts
          .where((p) => (p['post_id'] as int) > oldFirstId)
          .toList();
      if (newOnes.isNotEmpty && mounted) {
        setState(() {
          posts.insertAll(0, newOnes);
        });
        await _savePostsToCache();
        await _updateFollowStatuses();
        _showSuccess('${newOnes.length} new post${newOnes.length > 1 ? 's' : ''} loaded');
      }
    } catch (e) {
      if (mounted) {
        setState(() => networkError = true);
        _showError(_getErrorMessage(e));
      }
    }
  }
  Future<void> _toggleLike(int postId, int index) async {
    if (!mounted) return;
    if (_userId == null || _userId == 0) {
      await _fetchUserId();
      if (!mounted || _userId == null || _userId == 0) {
        _showError('User not authenticated. Please log in again.');
        return;
      }
    }
    if (isLikingMap[postId] ?? false) return;
    setState(() => isLikingMap[postId] = true);
    final oldLiked = posts[index]['is_liked'] ?? false;
    final oldCount = posts[index]['like_count'] ?? 0;
    final newLiked = !oldLiked;
    final optimisticCount = oldCount + (newLiked ? 1 : -1);
    if (mounted) {
      setState(() {
        posts[index]['is_liked'] = newLiked;
        posts[index]['like_count'] = optimisticCount;
      });
    }
    if (newLiked && !oldLiked) {
      final iconController = likeAnimationControllers.putIfAbsent(
        postId,
        () => AnimationController(
          duration: const Duration(milliseconds: 150),
          vsync: this,
        ),
      );
      iconController.forward().then((_) => iconController.reverse());
      final hasImage = posts[index]['media_url'] != null &&
          posts[index]['media_url'].isNotEmpty;
      if (hasImage && mounted) {
        setState(() => showHeartOverlay[postId] = true);
        final overlayController = AnimationController(
          duration: const Duration(milliseconds: 600),
          vsync: this,
        );
        heartOverlayControllers[postId] = overlayController;
        overlayController.forward().then((_) {
          if (mounted) {
            setState(() {
              showHeartOverlay[postId] = false;
            });
          }
          overlayController.dispose();
          heartOverlayControllers.remove(postId);
        });
      }
    }
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/like_action'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'post_id=$postId&user_id=$_userId',
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && mounted) {
          setState(() {
            if (data['like_count'] != null) {
              posts[index]['like_count'] = data['like_count'];
            }
            if (data['is_liked'] != null) {
              posts[index]['is_liked'] = data['is_liked'];
            }
          });
        }
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      final isOfflineError = e is SocketException || e is TimeoutException;
      if (isOfflineError) {
        await _queueLikeAction({'type': 'post', 'id': postId});
        _showSuccess('Like action queued offline');
      } else {
        if (mounted) {
          setState(() {
            posts[index]['is_liked'] = oldLiked;
            posts[index]['like_count'] = oldCount;
          });
          _showError('Failed to ${newLiked ? 'like' : 'unlike'} post: ${_getErrorMessage(e)}');
        }
      }
    } finally {
      if (mounted) {
        setState(() => isLikingMap[postId] = false);
      }
    }
  }
  Future<void> _fetchComments(int postId) async {
    if (_username.isEmpty) return;
    try {
      final url = 'https://server.awarcrown.com/feed/fetch_comments?post_id=$postId&username=${Uri.encodeComponent(_username)}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && mounted) {
          commentsMap[postId] = data['comments'] ?? [];
        }
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        _showError(_getErrorMessage(e));
      }
    }
  }
  Future<void> _toggleFollow(int followedUserId, int index) async {
    if (!mounted) return;
    if (_userId == null || _userId == 0) {
      await _fetchUserId();
      if (!mounted || _userId == null || _userId == 0) {
        _showError('User not authenticated. Please log in again.');
        return;
      }
    }
    if (isProcessingFollow[followedUserId] ?? false) return;
    setState(() => isProcessingFollow[followedUserId] = true);
    final oldFollowing = isFollowingMap[followedUserId] ?? false;
    final newFollowing = !oldFollowing;
    // Update local state for all posts by this user
    for (var i = 0; i < posts.length; i++) {
      if (posts[i]['user_id'] == followedUserId) {
        posts[i]['is_following'] = newFollowing;
      }
    }
    isFollowingMap[followedUserId] = newFollowing;
    if (mounted) setState(() {});
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/handle_followers'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'follower_id=$_userId&followed_id=$followedUserId&action=${newFollowing ? 'follow' : 'unfollow'}',
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          if (data['status'] == 'success') {
            _showSuccess(newFollowing ? 'Followed user' : 'Unfollowed user');
          } else {
            throw Exception(data['message'] ?? 'Failed to process follow action');
          }
        }
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // Revert local changes on error
      for (var i = 0; i < posts.length; i++) {
        if (posts[i]['user_id'] == followedUserId) {
          posts[i]['is_following'] = oldFollowing;
        }
      }
      isFollowingMap[followedUserId] = oldFollowing;
      if (mounted) setState(() {});
      _showError('Failed to ${newFollowing ? 'follow' : 'unfollow'} user: ${_getErrorMessage(e)}');
    } finally {
      if (mounted) {
        setState(() => isProcessingFollow[followedUserId] = false);
      }
    }
  }
  Future<void> _sharePost(int postId) async {
    if (_username.isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/share_post'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'post_id=$postId&username=${Uri.encodeComponent(_username)}',
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['status'] == 'success') {
          final shareUrl = data['share_url'] ?? '';
          if (shareUrl.isNotEmpty) {
            _showShareSheet(shareUrl);
          } else {
            _showSuccess('Post shared successfully!');
          }
        } else {
          _showError(data['message'] ?? 'Failed to share post');
        }
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Failed to share post: ${_getErrorMessage(e)}');
    }
  }
  void _showShareSheet(String shareUrl) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share this post',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              SelectableText(
                shareUrl,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareUrl));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Link copied!')),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Link'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _shareToInstagram(shareUrl),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Share externally'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
  Future<void> _shareToInstagram(String shareUrl) async {
    await Share.share(shareUrl, subject: 'Check this post on Awarcrown');
    Navigator.pop(context);
  }
  Future<void> _deletePost(int postId) async {
    if (_username.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/delete_post'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'post_id=$postId&username=${Uri.encodeComponent(_username)}',
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && mounted) {
        setState(() => posts.removeWhere((p) => p['post_id'] == postId));
        await _savePostsToCache();
        _showSuccess('Post deleted successfully');
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Failed to delete post: ${_getErrorMessage(e)}');
    }
  }
  Future<void> _savePost(int postId) async {
    if (_username.isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/save_post'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'post_id=$postId&username=${Uri.encodeComponent(_username)}',
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && mounted) {
          _showSuccess(data['saved'] == true ? 'Post saved!' : 'Post unsaved');
        }
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Failed to save post: ${_getErrorMessage(e)}');
    }
  }
  void _navigateToProfile(String username, int userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicProfilePage(targetUsername: username),
      ),
    );
  }
  bool _isOwnPost(int postId, int index) {
    if (_userId == null || _userId == 0) return false;
    return posts[index]['user_id'] == _userId;
  }
  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.feed_outlined, size: 80, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              'No posts yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow users to see their posts here',
              style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildErrorState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            const Text(
              'Failed to load posts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchPosts,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildList() {
    if (posts.isEmpty) {
      if (isLoading) {
        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          cacheExtent: 1000.0,
          itemCount: 5,
          itemBuilder: (context, index) => const PostSkeleton(),
        );
      } else if (networkError) {
        return _buildErrorState();
      } else {
        return _buildEmptyState();
      }
    }
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      controller: _scrollController,
      cacheExtent: 1000.0,
      itemCount: posts.length + (isLoading && hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == posts.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: PostSkeleton(),
          );
        }
        final post = posts[index];
        final postId = post['post_id'];
        final colorScheme = Theme.of(context).colorScheme;
        final imageUrl = post['media_url'] != null && post['media_url'].isNotEmpty
            ? 'https://server.awarcrown.com${post['media_url']}'
            : null;
        final isLiked = post['is_liked'] ?? false;
        final isLiking = isLikingMap[postId] ?? false;
        final isFetchingComment = isFetchingComments[postId] ?? false;
        final iconAnimation = likeAnimationControllers[postId] ??
            const AlwaysStoppedAnimation(1.0);
        final overlayAnimation = heartOverlayControllers[postId] ??
            const AlwaysStoppedAnimation(0.0);
        final isFollowing = isFollowingMap[post['user_id']] ?? (post['is_following'] ?? false);
        final isProcessing = isProcessingFollow[post['user_id']] ?? false;
        const double aspectRatio = 1.0;
        final screenWidth = MediaQuery.of(context).size.width - 32;
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _navigateToProfile(
                          post['username'] ?? '', post['user_id'] ?? 0),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundImage: post['profile_picture'] != null
                            ? NetworkImage(
                                'https://server.awarcrown.com/accessprofile/uploads/${post['profile_picture']}')
                            : null,
                        child: post['profile_picture'] == null
                            ? Icon(Icons.person, color: colorScheme.onSurfaceVariant)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => _navigateToProfile(
                                post['username'] ?? '', post['user_id'] ?? 0),
                            child: Text(
                              post['username'] ?? 'Unknown',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(post['created_at']),
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    if (!_isOwnPost(postId, index) && !isFollowing)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ElevatedButton(
                          onPressed: isProcessing
                              ? null
                              : () => _toggleFollow(post['user_id'], index),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: const Size(80, 32),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isProcessing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Follow',
                                  style: TextStyle(fontSize: 12),
                                ),
                        ),
                      ),
                    if (_isOwnPost(postId, index))
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deletePost(postId);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                const SizedBox(width: 8),
                                const Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                        icon: Icon(Icons.more_vert, size: 20, color: colorScheme.onSurfaceVariant),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: () => _toggleLike(postId, index),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post['content'] != null && post['content'].isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text(
                          post['content'],
                          style: TextStyle(fontSize: 14, height: 1.4, color: colorScheme.onSurface),
                        ),
                      ),
                    if (imageUrl != null)
                      Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            child: AspectRatio(
                              aspectRatio: aspectRatio,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth: (screenWidth * MediaQuery.of(context).devicePixelRatio).round(),
                                  memCacheHeight: (screenWidth * aspectRatio * MediaQuery.of(context).devicePixelRatio).round(),
                                  maxWidthDiskCache: (screenWidth * MediaQuery.of(context).devicePixelRatio).round(),
                                  maxHeightDiskCache: (screenWidth * aspectRatio * MediaQuery.of(context).devicePixelRatio).round(),
                                  fadeInDuration: const Duration(milliseconds: 200),
                                  fadeOutDuration: const Duration(milliseconds: 200),
                                  placeholder: (context, url) => const Skeleton(
                                    height: double.infinity,
                                    width: double.infinity,
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: colorScheme.onSurfaceVariant,
                                      size: 48,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (showHeartOverlay[postId] ?? false)
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: overlayAnimation,
                                builder: (context, child) {
                                  final scale = Curves.easeOut.transform(
                                      overlayAnimation.value) * 1.5;
                                  final opacity = 1.0 - (overlayAnimation.value * 0.8);
                                  return Transform.scale(
                                    scale: scale * (showHeartOverlay[postId] == true ? 1.0 : 0.0),
                                    alignment: Alignment.center,
                                    child: Opacity(
                                      opacity: opacity,
                                      child: const Icon(
                                        Icons.favorite,
                                        size: 100,
                                        color: Colors.red,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                color: colorScheme.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: () => _toggleLike(postId, index),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                isLiking
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                              Colors.red),
                                        ),
                                      )
                                    : AnimatedBuilder(
                                        animation: iconAnimation,
                                        builder: (context, child) {
                                          final scale = 1.0 + (0.4 * iconAnimation.value);
                                          return Transform.scale(
                                            scale: scale,
                                            child: Icon(
                                              isLiked
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              size: 24,
                                              color: isLiked ? Colors.red : colorScheme.onSurface,
                                            ),
                                          );
                                        },
                                      ),
                                const SizedBox(width: 6),
                                Text(
                                  '${post['like_count'] ?? 0}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isLiked ? Colors.red : colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: isFetchingComment
                              ? null
                              : () async {
                                  if (isFetchingComments[postId] ?? false) return;
                                  setState(() => isFetchingComments[postId] = true);
                                  try {
                                    await _fetchComments(postId);
                                    if (mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => CommentsPage(
                                            post: post,
                                            comments: commentsMap[postId] ?? [],
                                            username: _username,
                                            userId: _userId,
                                          ),
                                        ),
                                      );
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => isFetchingComments[postId] = false);
                                    }
                                  }
                                },
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                isFetchingComment
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                              Colors.blue),
                                        ),
                                      )
                                    : Icon(
                                        Icons.mode_comment_outlined,
                                        size: 24,
                                        color: colorScheme.onSurface,
                                      ),
                                const SizedBox(width: 6),
                                Text(
                                  '${post['comment_count'] ?? 0}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () => _sharePost(postId),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              Icons.share_outlined,
                              size: 24,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () => _savePost(postId),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              Icons.bookmark_border,
                              size: 24,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        color: colorScheme.primary,
        child: Column(
          children: [
            if (networkError && posts.isNotEmpty)
              Material(
                elevation: 2,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    border: Border(
                      bottom: BorderSide(color: colorScheme.error, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off, color: colorScheme.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Showing cached posts. Pull to refresh.',
                          style: TextStyle(
                            color: colorScheme.onErrorContainer,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(child: _buildList()),
          ],
        ),
      ),
    );
  }
  String _formatTime(String? timeString) {
    if (timeString == null) return 'Unknown';
    try {
      final date = DateTime.parse(timeString);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays > 365) {
        return '${(diff.inDays / 365).floor()}y ago';
      } else if (diff.inDays > 30) {
        return '${(diff.inDays / 30).floor()}mo ago';
      } else if (diff.inDays > 0) {
        return '${diff.inDays}d ago';
      } else if (diff.inHours > 0) {
        return '${diff.inHours}h ago';
      } else if (diff.inMinutes > 0) {
        return '${diff.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (_) {
      return timeString;
    }
  }
}