
// ignore_for_file: unused_local_variable
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
class ExpandedText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final int maxLines;
  const ExpandedText({
    super.key,
    required this.text,
    required this.style,
    this.maxLines = 3,
  });
  @override
  State<ExpandedText> createState() => _ExpandedTextState();
}

//read more or less code 

class _ExpandedTextState extends State<ExpandedText> {
  bool _isExpanded = false;
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: widget.maxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final isOverflow = textPainter.didExceedMaxLines;
        if (!isOverflow) {
          return Text(widget.text, style: widget.style);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedCrossFade(
              firstChild: Text(
                widget.text,
                style: widget.style,
                maxLines: widget.maxLines,
                overflow: TextOverflow.ellipsis,
              ),
              secondChild: Text(widget.text, style: widget.style),
              crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Text(
                _isExpanded ? 'Read less' : 'Read more',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
//class for skeleton loading effect
class Skeleton extends StatefulWidget {
  final double height;
  final double width;
  final String type;
  const Skeleton({
    super.key,
    this.height = 20,
    this.width = 20,
    this.type = 'square',
  });
  @override
  State<Skeleton> createState() => _SkeletonState();
}
//skeleton loading effect state
class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> gradientPosition;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    gradientPosition = Tween<double>(begin: -3, end: 10).animate(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              : const [Colors.grey, Colors.grey, Colors.grey],
        ),
      ),
    );
  }
}
  //post skeleton widget
class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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
          AspectRatio(
            aspectRatio: 1.0,
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
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
//class for comment skeleton loading effect
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
//comment item widget
class CommentItem extends StatelessWidget {
  final dynamic comment;
  final int depth;
  final int postId;
  final Function(int, String) onReply;
  final Function(int, int) onLike;
  final Function(String)? onProfileTap;
  const CommentItem({
    super.key,
    required this.comment,
    required this.depth,
    required this.postId,
    required this.onReply,
    required this.onLike,
    this.onProfileTap,
  });
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLiked = comment['current_reaction'] != null;
    final leftPadding = 16.0 + (depth * 24.0);
    final username = comment['username'] ?? 'Unknown';
    return Padding(
      padding: EdgeInsets.only(left: leftPadding, top: 12.0, bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onProfileTap != null ? () => onProfileTap!(username) : null,
            child: CircleAvatar(
              radius: 18,
              backgroundImage: comment['profile_picture'] != null
                  ? NetworkImage('https://server.awarcrown.com/accessprofile/uploads/${comment['profile_picture']}')
                  : null,
              child: comment['profile_picture'] == null
                  ? Icon(Icons.person, size: 18, color: colorScheme.onSurfaceVariant)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: onProfileTap != null ? () => onProfileTap!(username) : null,
                      child: Text(
                        username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
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
                        onTap: () {
                          final id = int.tryParse(comment['comment_id'].toString()) ?? 0;
                          if (id > 0) {
                            onLike(id, postId);
                          }
                        },
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
                        onTap: () {
                          final id = int.tryParse(comment['comment_id'].toString()) ?? 0;
                          if (id > 0) {
                            onReply(id, comment['username'] ?? '');
                          }
                        },
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

//comments page widget
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
//comments page state
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
  final ValueNotifier<bool> _refreshNotifier = ValueNotifier(false);
  @override
  void initState() {
    super.initState();
    post = widget.post;
    _username = widget.username;
    _userId = widget.userId;
    comments = List.from(widget.comments); 
    _initializeUserId();
    _processLikeQueue();
    if (comments.isEmpty) {
      _fetchComments();
    }
  }
  List<dynamic> _parseComments(List<dynamic> rawComments) {
    return rawComments.map((c) {
      final comment = Map<String, dynamic>.from(c);
      // Parse key numeric fields to int; fallback to 0 if invalid
      comment['comment_id'] = int.tryParse(comment['comment_id'].toString()) ?? 0;
      comment['like_count'] = int.tryParse(comment['like_count'].toString()) ?? 0;
      comment['user_id'] = int.tryParse(comment['user_id'].toString()) ?? 0;
      // Add more fields if needed (e.g., 'parent_comment_id')
      comment['parent_comment_id'] = int.tryParse(comment['parent_comment_id'].toString());
      return comment;
    }).toList();
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
    _refreshNotifier.dispose();
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
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && mounted) {
          setState(() => comments = _parseComments(data['comments'] ?? []));
          _refreshNotifier.value = !_refreshNotifier.value; // Trigger rebuild for nested lists
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
    final commentIndex = comments.indexWhere((c) => int.tryParse(c['comment_id'].toString()) == commentId);
    if (commentIndex == -1) return;
    final comment = comments[commentIndex];
    final oldLiked = comment['current_reaction'] != null;
    final oldCount = comment['like_count'] ?? 0;
    final newLiked = !oldLiked;
    final newCount = oldCount + (newLiked ? 1 : -1);
    final action = newLiked ? 'like' : 'unlike';
    // Optimistic update
    if (mounted) {
      setState(() {
        comments[commentIndex]['current_reaction'] = newLiked ? 'like' : null;
        comments[commentIndex]['like_count'] = newCount;
      });
    }
    setState(() => commentIsReacting[commentId] = true);
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
        if (mounted) {
          setState(() {
            comments[commentIndex]['current_reaction'] = oldLiked ? 'like' : null;
            comments[commentIndex]['like_count'] = oldCount;
          });
        }
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
          setState(() {
            final newComment = _parseComments([data])[0]; // Parse just this one
            comments.insert(0, newComment);
            _refreshNotifier.value = !_refreshNotifier.value;
          });
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
  void _navigateToProfile(String username) {
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
        .where((c) => int.tryParse(c['parent_comment_id'].toString()) == int.tryParse(comment['comment_id'].toString()))
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
        .where((c) => int.tryParse(c['parent_comment_id'].toString()) == null)
        .toList()
      ..sort((a, b) => b['created_at'].compareTo(a['created_at']));
    for (var main in mainComments) {
      _addCommentsToFlat(flatComments, main, 0);
    }
    return ValueListenableBuilder<bool>(
      valueListenable: _refreshNotifier,
      builder: (context, _, __) => ListView.separated(
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
          return RepaintBoundary(
            child: CommentItem(
              key: ValueKey(comment['comment_id']),
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
              onProfileTap: _navigateToProfile,
            ),
          );
        },
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (value) {
                      final trimmed = value.trim();
                      if (trimmed.isNotEmpty) {
                        _postComment(trimmed, parentCommentId: replyToCommentId);
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
                            ? () => _postComment(text, parentCommentId: replyToCommentId)
                            : null,
                        borderRadius: BorderRadius.circular(24),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.send, color: Colors.white, size: 20),
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
//posts page widget
class PostsPage extends StatefulWidget {
  const PostsPage({super.key});
  @override
  State<PostsPage> createState() => _PostsPageState();
}
//posts page state
class _PostsPageState extends State<PostsPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  List<dynamic> posts = [];
  bool isLoading = false;
  bool hasMore = true;
  bool networkError = false;
  int? nextCursorId;
  final ScrollController _scrollController = ScrollController();
  Map<int, List<dynamic>> commentsMap = {};
  Map<int, bool> isLikingMap = {};
  final Map<int, AnimationController> likeAnimationControllers = {};
  final Map<int, bool> showHeartOverlay = {};
  final Map<int, AnimationController> heartOverlayControllers = {};
  final Map<int, bool> isFetchingComments = {};
  String _username = '';
  int? _userId;
  Timer? _scrollDebounceTimer;
  final Map<int, bool> isFollowingMap = {};
  final Map<int, bool> isProcessingFollow = {};
  final Map<int, bool> isSavingMap = {};
  final ValueNotifier<bool> _refreshNotifier = ValueNotifier(false);
  Set<int> _savedPosts = {};
  final Map<int, bool> isReportingMap = {};
  bool _isInitialized = false;
  DateTime? _lastRefreshTime;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && _isInitialized) {
      // Refresh when app comes back to foreground
      _refreshOnResume();
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when widget becomes visible again (e.g., navigating back from another screen)
    if (_isInitialized && mounted) {
      final now = DateTime.now();
      // Only refresh if it's been more than 2 seconds since last refresh to avoid excessive calls
      if (_lastRefreshTime == null || now.difference(_lastRefreshTime!).inSeconds > 2) {
        _refreshOnResume();
      }
    }
  }
  
  /// Public method to manually refresh posts (can be called from parent widget)
  Future<void> refreshPosts() async {
    await _refreshOnResume();
  }
  
  Future<void> _refreshOnResume() async {
    if (!mounted || isLoading) return;
    _lastRefreshTime = DateTime.now();
    // Process any queued like actions first
    await _processLikeQueue();
    // Do a full refresh: fetch fresh posts and update cache
    await _fullRefresh();
  }
  
  Future<void> _fullRefresh() async {
    if (_username.isEmpty) return;
    if (mounted) {
      setState(() {
      networkError = false;
      nextCursorId = null;
    });
    }
    // Fetch fresh posts from server (this will update cache via _fetchPosts)
    await _fetchPosts();
  }
  Future<void> _initializeData() async {
    await _loadUsername();
    await _loadSavedPosts();
    await _processLikeQueue();
    await _loadPostsFromCache();
    await _updateFollowStatuses();
    await _fetchPosts();
    _isInitialized = true;
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _scrollDebounceTimer?.cancel();
    for (final controller in likeAnimationControllers.values) {
      controller.dispose();
    }
    for (final controller in heartOverlayControllers.values) {
      controller.dispose();
    }
    _refreshNotifier.dispose();
    super.dispose();
  }
  double _getAspectRatio(dynamic post) {
    final w = (post['image_width'] ?? 1).toDouble();
    final h = (post['image_height'] ?? 1).toDouble();
    return w > 0 ? h / w : 1.0;
  }
  Future<void> _loadSavedPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('saved_posts');
      if (savedStr != null) {
        final List<dynamic> savedList = json.decode(savedStr);
        _savedPosts = savedList.map((e) => int.tryParse(e.toString()) ?? 0).where((id) => id > 0).toSet();
      }
    } catch (e) {
      debugPrint('Error loading saved posts: $e');
    }
  }
  // Save like state to SharedPreferences
  Future<void> _saveLikeState(int postId, bool isLiked, int likeCount) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final likesMapStr = prefs.getString('post_likes_map') ?? '{}';
      final likesCountMapStr = prefs.getString('post_like_counts_map') ?? '{}';
      
      final likesMap = Map<String, dynamic>.from(json.decode(likesMapStr));
      final likesCountMap = Map<String, dynamic>.from(json.decode(likesCountMapStr));
      
      likesMap[postId.toString()] = isLiked;
      likesCountMap[postId.toString()] = likeCount;
      
      await prefs.setString('post_likes_map', json.encode(likesMap));
      await prefs.setString('post_like_counts_map', json.encode(likesCountMap));
    } catch (e) {
      debugPrint('Error saving like state: $e');
    }
  }
  // Load like states from SharedPreferences
  Future<Map<String, dynamic>> _loadLikeStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final likesMapStr = prefs.getString('post_likes_map') ?? '{}';
      final likesCountMapStr = prefs.getString('post_like_counts_map') ?? '{}';
      
      final likesMap = Map<String, dynamic>.from(json.decode(likesMapStr));
      final likesCountMap = Map<String, dynamic>.from(json.decode(likesCountMapStr));
      
      return {
        'likes': likesMap,
        'counts': likesCountMap,
      };
    } catch (e) {
      debugPrint('Error loading like states: $e');
      return {'likes': {}, 'counts': {}};
    }
  }
  // Apply like states from SharedPreferences to posts
  Future<void> _applyLikeStatesToPosts() async {
    try {
      final likeStates = await _loadLikeStates();
      final likesMap = likeStates['likes'] as Map<String, dynamic>;
      final countsMap = likeStates['counts'] as Map<String, dynamic>;
      
      if (mounted) {
        setState(() {
          for (var post in posts) {
            final postId = _parseInt(post['post_id']);
            if (postId != null) {
              final postIdStr = postId.toString();
              if (likesMap.containsKey(postIdStr)) {
                post['is_liked'] = likesMap[postIdStr] == true;
              }
              if (countsMap.containsKey(postIdStr)) {
                final savedCount = countsMap[postIdStr];
                if (savedCount is int) {
                  post['like_count'] = savedCount;
                } else if (savedCount != null) {
                  post['like_count'] = int.tryParse(savedCount.toString()) ?? post['like_count'] ?? 0;
                }
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error applying like states: $e');
    }
  }
  Future<void> _saveSavedPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedList = _savedPosts.map((id) => id).toList();
      await prefs.setString('saved_posts', json.encode(savedList));
    } catch (e) {
      debugPrint('Error saving saved posts: $e');
    }
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
  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
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
        .where((p) => _parseInt(p['user_id']) != _userId)
        .map((p) => _parseInt(p['user_id'])!)
        .where((id) => id > 0)
        .toSet();
    if (uniqueFollowedIds.isEmpty) return;
    final futures = uniqueFollowedIds.map((id) => _getIsFollowing(id));
    final results = await Future.wait(futures);
    int idx = 0;
    bool hasChanges = false;
    for (final id in uniqueFollowedIds) {
      final isFollow = results[idx++];
      final current = isFollowingMap[id] ?? false;
      if (current != isFollow) {
        hasChanges = true;
        isFollowingMap[id] = isFollow;
        for (var post in posts) {
          final postId = _parseInt(post['user_id']);
          if (postId == id) {
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
        if (cacheAge < 3600000) { // 1 hour
          final parsedPosts = json.decode(cachedPostsJson);
          if (parsedPosts is List && mounted) {
            setState(() {
              posts = parsedPosts.cast<dynamic>();
              for (var post in posts) {
                final postId = _parseInt(post['post_id']);
                if (postId != null && _savedPosts.contains(postId)) {
                  post['is_saved'] = true;
                }
              }
            });
            // Apply like states from SharedPreferences after loading from cache
            await _applyLikeStatesToPosts();
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
      if (!_scrollController.hasClients) return;
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
        if (hasMore && !isLoading && !networkError) {
          _fetchMorePosts();
        }
      }
    });
  }
  Future<Map<String, dynamic>?> _fetchPostsData({int? cursorId}) async {
    if (_username.isEmpty) return null;
    try {
      final params = <String, String>{'username': _username};
      if (cursorId != null) params['cursorId'] = cursorId.toString();
      final queryString = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');
      final url = 'https://server.awarcrown.com/feed/fetch_posts?$queryString';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
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
            posts = List.from(newPosts);
          } else {
            final postsToAdd = newPosts.where((newPost) {
              final existingIds = posts.map((existing) => _parseInt(existing['post_id']) ?? 0).toSet();
              final newPostId = _parseInt(newPost['post_id']) ?? 0;
              return !existingIds.contains(newPostId);
            }).toList();
            posts.addAll(postsToAdd);
          }
          for (var post in posts) {
            final postId = _parseInt(post['post_id']);
            if (postId != null && _savedPosts.contains(postId)) {
              post['is_saved'] = true;
            }
          }
          nextCursorId = _parseInt(data['nextCursorId']);
          hasMore = nextCursorId != null;
        });
        // Apply like states from SharedPreferences
        await _applyLikeStatesToPosts();
        await _savePostsToCache();
        await _updateFollowStatuses();
        _refreshNotifier.value = !_refreshNotifier.value;
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
    final oldFirstId = _parseInt(posts[0]['post_id']) ?? 0;
    try {
      final data = await _fetchPostsData();
      if (data == null || !mounted) return;
      setState(() => networkError = false);
      final newPosts = data['posts'] ?? [];
      final newOnes = newPosts.where((p) {
        final pId = _parseInt(p['post_id']) ?? 0;
        return pId > oldFirstId;
      }).toList();
      if (newOnes.isNotEmpty && mounted) {
        setState(() {
          posts.insertAll(0, newOnes);
          for (var post in newOnes) {
            final postId = _parseInt(post['post_id']);
            if (postId != null && _savedPosts.contains(postId)) {
              post['is_saved'] = true;
            }
          }
        });
        // Apply like states from SharedPreferences
        await _applyLikeStatesToPosts();
        await _savePostsToCache();
        await _updateFollowStatuses();
        _showSuccess('${newOnes.length} new post${newOnes.length > 1 ? 's' : ''} loaded');
        _refreshNotifier.value = !_refreshNotifier.value;
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
    // Optimistic update
    if (mounted) {
      setState(() {
        posts[index]['is_liked'] = newLiked;
        posts[index]['like_count'] = optimisticCount;
      });
      // Save to SharedPreferences immediately
      await _saveLikeState(postId, newLiked, optimisticCount);
    }
    if (newLiked && !oldLiked) {
      final iconController = likeAnimationControllers.putIfAbsent(
        postId,
        () => AnimationController(
          duration: const Duration(milliseconds: 150),
          vsync: this,
        ),
      );
      if (iconController.isAnimating) {
        iconController.stop();
      }
      iconController.forward().then((_) => iconController.reverse());
      final hasImage = posts[index]['media_url'] != null && posts[index]['media_url'].isNotEmpty;
      if (hasImage && mounted) {
        setState(() => showHeartOverlay[postId] = true);
        final overlayController = AnimationController(
          duration: const Duration(milliseconds: 600),
          vsync: this,
        );
        heartOverlayControllers[postId] = overlayController;
        overlayController.forward().then((_) {
          if (mounted) {
            setState(() => showHeartOverlay[postId] = false);
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
          final serverLikeCount = data['like_count'] ?? optimisticCount;
          final serverIsLiked = data['is_liked'] ?? newLiked;
          setState(() {
            posts[index]['like_count'] = serverLikeCount;
            posts[index]['is_liked'] = serverIsLiked;
          });
          // Save server response to SharedPreferences
          await _saveLikeState(postId, serverIsLiked, serverLikeCount);
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
          // Reload like state from SharedPreferences to ensure consistency
          final likeStates = await _loadLikeStates();
          final likesMap = likeStates['likes'] as Map<String, dynamic>;
          final countsMap = likeStates['counts'] as Map<String, dynamic>;
          final postIdStr = postId.toString();
          
          setState(() {
            // Use SharedPreferences value if available, otherwise revert to old
            if (likesMap.containsKey(postIdStr)) {
              posts[index]['is_liked'] = likesMap[postIdStr] == true;
            } else {
              posts[index]['is_liked'] = oldLiked;
            }
            if (countsMap.containsKey(postIdStr)) {
              final savedCount = countsMap[postIdStr];
              if (savedCount is int) {
                posts[index]['like_count'] = savedCount;
              } else if (savedCount != null) {
                posts[index]['like_count'] = int.tryParse(savedCount.toString()) ?? oldCount;
              } else {
                posts[index]['like_count'] = oldCount;
              }
            } else {
              posts[index]['like_count'] = oldCount;
            }
          });
        }
        _showError('Failed to ${newLiked ? 'like' : 'unlike'} post: ${_getErrorMessage(e)}');
      }
    } finally {
      if (mounted) {
        setState(() => isLikingMap[postId] = false);
      }
    }
  }
  Future<void> _fetchComments(int postId) async {
    if (_username.isEmpty) return;
    if (isFetchingComments[postId] ?? false) return;
    setState(() => isFetchingComments[postId] = true);
    try {
      final url = 'https://server.awarcrown.com/feed/fetch_comments?post_id=$postId&username=${Uri.encodeComponent(_username)}';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
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
    } finally {
      if (mounted) {
        setState(() => isFetchingComments[postId] = false);
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
    // Optimistic update
    for (var i = 0; i < posts.length; i++) {
      final postUserId = _parseInt(posts[i]['user_id']);
      if (postUserId == followedUserId) {
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
      // Revert on error
      for (var i = 0; i < posts.length; i++) {
        final postUserId = _parseInt(posts[i]['user_id']);
        if (postUserId == followedUserId) {
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
  Future<void> _reportPost(int postId, String reason) async {
    if (_username.isEmpty || (isReportingMap[postId] ?? false)) return;
    setState(() => isReportingMap[postId] = true);
    final uri = Uri.parse('https://server.awarcrown.com/feed/report_posts');
    final bodyData = jsonEncode({
      'post_id': postId,
      'username': _username,
      'reason': reason,
    });
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: bodyData,
          )
          .timeout(const Duration(seconds: 10));
      debugPrint('Report Response: ${response.statusCode} -> ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['status'] == 'success') {
          _showSuccess(
            'Post reported for "$reason". Thank you for helping keep the community safe.',
          );
        } else {
          _showError(data['message'] ?? 'Failed to report post. Please try again.');
        }
      } else if (response.statusCode == 429) {
        _showError('You have already reported this post recently. Please wait before reporting again.');
      } else if (response.statusCode == 404) {
        _showError('Post not found or already removed.');
      } else if (response.statusCode == 400) {
        _showError('Invalid report data. Please check and try again.');
      } else if (response.statusCode >= 500) {
        _showError('Server error. Please try again later.');
      } else {
        _showError('Unexpected server response (${response.statusCode}).');
      }
    } on TimeoutException {
      _showError('Request timed out. Please try again.');
    } on SocketException {
      _showError('No internet connection. Please check your connection and try again.');
    } on FormatException {
      _showError('Invalid response format from server.');
    } catch (e) {
      _showError('Unexpected error while reporting: $e');
    } finally {
      if (mounted) setState(() => isReportingMap[postId] = false);
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
                        backgroundColor: const Color.fromARGB(255, 2, 0, 135),
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
    if (mounted) Navigator.pop(context);
  }
  Future<void> _deletePost(int postId) async {
    if (_username.isEmpty) return;
    final confirmed = await showDialog<bool>(
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
              child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade600, size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Post',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
          style: TextStyle(fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
    if (confirmed != true) return;
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/delete_post'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'post_id=$postId&username=${Uri.encodeComponent(_username)}',
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && mounted) {
        setState(() => posts.removeWhere((p) => _parseInt(p['post_id']) == postId));
        await _savePostsToCache();
        _savedPosts.remove(postId);
        await _saveSavedPosts();
        _showSuccess('Post deleted successfully');
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Failed to delete post: ${_getErrorMessage(e)}');
    }
  }
  Future<void> _toggleSave(int postId, int index) async {
    if (!mounted) return;
    if (_userId == null || _userId == 0) {
      await _fetchUserId();
      if (!mounted || _userId == null || _userId == 0) {
        _showError('User not authenticated. Please log in again.');
        return;
      }
    }
    if (isSavingMap[postId] ?? false) return;
    setState(() => isSavingMap[postId] = true);
    final post = posts[index];
    final oldSaved = post['is_saved'] ?? false;
    final newSaved = !oldSaved;
    // Update local cache
    if (newSaved) {
      _savedPosts.add(postId);
    } else {
      _savedPosts.remove(postId);
    }
    await _saveSavedPosts();
    // Optimistic update
    if (mounted) {
      setState(() {
        posts[index]['is_saved'] = newSaved;
      });
    }
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/save_post'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'post_id=$postId&username=${Uri.encodeComponent(_username)}',
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && mounted) {
          final serverSaved = data['saved'] ?? newSaved;
          setState(() {
            posts[index]['is_saved'] = serverSaved;
          });
          // Sync local cache with server
          if (serverSaved) {
            _savedPosts.add(postId);
          } else {
            _savedPosts.remove(postId);
          }
          await _saveSavedPosts();
          _showSuccess(serverSaved ? 'Post saved!' : 'Post unsaved');
        }
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // Revert on error, but keep local cache for offline
      if (mounted) {
        setState(() {
          posts[index]['is_saved'] = oldSaved;
        });
      }
      _showError('Failed to ${newSaved ? 'save' : 'unsave'} post: ${_getErrorMessage(e)}');
    } finally {
      if (mounted) {
        setState(() => isSavingMap[postId] = false);
      }
    }
  }
  void _navigateToProfile(String username) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicProfilePage(targetUsername: username),
      ),
    );
  }
  bool _isOwnPost(int postId, int index) {
    if (_userId == null || _userId == 0) return false;
    final postUserId = _parseInt(posts[index]['user_id']);
    return postUserId == _userId;
  }
  void _showImageViewer(String imageUrl) {
    showGeneralDialog(
      context: context,
      barrierLabel: 'Image Viewer',
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation1, animation2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  color: Colors.black,
                  width: double.infinity,
                  height: double.infinity,
                  child: Center(
                    child: InteractiveViewer(
                      panEnabled: true,
                      boundaryMargin: const EdgeInsets.all(20.0),
                      minScale: 0.8,
                      maxScale: 4.0,
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.error,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                right: 20,
                child: SafeArea(
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.feed_outlined,
                size: 64,
                color: const Color(0xFF4A90E2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No posts yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Follow users to see their posts here',
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
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
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
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
              'Failed to load posts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Check your connection and try again',
              style: TextStyle(
                fontSize: 15,
                color: colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _fetchPosts,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text(
                'Retry',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90E2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    String? label,
    bool isLoading = false,
    Animation<double>? animation,
    VoidCallback? onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    Widget iconWidget = Icon(icon, size: 24, color: iconColor);
    
    if (animation != null && !isLoading) {
      iconWidget = AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final scale = 1.0 + (0.3 * animation.value);
          return Transform.scale(
            scale: scale,
            child: Icon(icon, size: 24, color: iconColor),
          );
        },
      );
    }
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                      ),
                    )
                  : iconWidget,
              if (label != null) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostItem(int index) {
    final post = posts[index];
    final postId = _parseInt(post['post_id']) ?? 0;
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = post['media_url'] != null && post['media_url'].isNotEmpty
        ? 'https://server.awarcrown.com${post['media_url']}'
        : null;
    final isLiked = post['is_liked'] ?? false;
    final isLiking = isLikingMap[postId] ?? false;
    final isFetchingComment = isFetchingComments[postId] ?? false;
    final isSaved = post['is_saved'] ?? _savedPosts.contains(postId);
    final isSaving = isSavingMap[postId] ?? false;
    final isReporting = isReportingMap[postId] ?? false;
    final iconAnimation = likeAnimationControllers[postId] ?? const AlwaysStoppedAnimation(1.0);
    final overlayAnimation = heartOverlayControllers[postId] ?? const AlwaysStoppedAnimation(0.0);
    final userId = _parseInt(post['user_id']) ?? 0;
    final isFollowing = isFollowingMap[userId] ?? (post['is_following'] ?? false);
    final isProcessing = isProcessingFollow[userId] ?? false;
    final aspectRatio = _getAspectRatio(post);
    final screenWidth = MediaQuery.of(context).size.width;
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE5E9F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _navigateToProfile(post['username'] ?? ''),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF4A90E2).withOpacity(0.2),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.transparent,
                        backgroundImage: post['profile_picture'] != null
                            ? NetworkImage('https://server.awarcrown.com/accessprofile/uploads/${post['profile_picture']}')
                            : null,
                        child: post['profile_picture'] == null
                            ? Icon(Icons.person_rounded, color: colorScheme.onSurfaceVariant, size: 22)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => _navigateToProfile(post['username'] ?? ''),
                          child: Text(
                            post['username'] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTime(post['created_at']),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isOwnPost(postId, index) && !isFollowing)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      child: ElevatedButton(
                        onPressed: isProcessing ? null : () => _toggleFollow(userId, index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A90E2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          minimumSize: const Size(85, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
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
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  if (!_isOwnPost(postId, index))
                    Material(
                      color: Colors.transparent,
                      child: PopupMenuButton<String>(
                        enabled: !isReporting,
                        onSelected: (value) {
                          if (value == 'report') {
                            _showReportDialog(postId);
                          }
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'report',
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.flag_outlined, size: 18, color: Colors.orange.shade700),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Report',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.more_horiz_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  if (_isOwnPost(postId, index))
                    Material(
                      color: Colors.transparent,
                      child: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deletePost(postId);
                          }
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade700),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.more_horiz_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: () => _toggleLike(postId, index),
              onLongPress: imageUrl != null ? () => _showImageViewer(imageUrl) : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post['content'] != null && post['content'].isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: ExpandedText(
                        text: post['content'] as String,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: colorScheme.onSurface,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 3,
                      ),
                    ),
                  if (imageUrl != null)
                    Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: aspectRatio.clamp(0.5, 2.0),
                          child: CachedNetworkImage(
                            key: ValueKey(imageUrl),
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            fadeInDuration: const Duration(milliseconds: 200),
                            fadeOutDuration: const Duration(milliseconds: 200),
                            placeholder: (context, url) => Container(
                              color: colorScheme.surfaceContainerHighest,
                              child: const Skeleton(height: double.infinity, width: double.infinity),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: colorScheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.image_not_supported,
                                color: colorScheme.onSurfaceVariant,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                        if (showHeartOverlay[postId] ?? false)
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: overlayAnimation,
                              builder: (context, child) {
                                final scale = Curves.easeOut.transform(overlayAnimation.value) * 1.5;
                                final opacity = 1.0 - (overlayAnimation.value * 0.8);
                                return Transform.scale(
                                  scale: scale,
                                  alignment: Alignment.center,
                                  child: Opacity(
                                    opacity: opacity,
                                    child: const Icon(Icons.favorite, size: 100, color: Colors.red),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildActionButton(
                        icon: isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        iconColor: isLiked ? Colors.red : colorScheme.onSurface,
                        label: '${post['like_count'] ?? 0}',
                        isLoading: isLiking,
                        animation: iconAnimation,
                        onTap: () => _toggleLike(postId, index),
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        icon: Icons.mode_comment_outlined,
                        iconColor: colorScheme.onSurface,
                        label: '${post['comment_count'] ?? 0}',
                        isLoading: isFetchingComment,
                        onTap: isFetchingComment
                            ? null
                            : () async {
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
                              },
                      ),
                      const SizedBox(width: 8),
                      _buildActionButton(
                        icon: Icons.share_outlined,
                        iconColor: colorScheme.onSurface,
                        onTap: () => _sharePost(postId),
                      ),
                      const Spacer(),
                      _buildActionButton(
                        icon: isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        iconColor: isSaved ? const Color(0xFF4A90E2) : colorScheme.onSurfaceVariant,
                        isLoading: isSaving,
                        onTap: isSaving ? null : () => _toggleSave(postId, index),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showReportDialog(int postId) {
    final List<String> reasons = [
      'Spam or misleading',
      'Harassment or hate speech',
      'Inappropriate content',
      'Intellectual property violation',
      'Other',
    ];
    String? selectedReason;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.flag_outlined, color: Colors.orange.shade700, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Report Post',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please select a reason:',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: DropdownButton<String>(
                  value: selectedReason,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: reasons.map((reason) {
                    return DropdownMenuItem<String>(
                      value: reason,
                      child: Text(
                        reason,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedReason = value;
                    });
                  },
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
              onPressed: selectedReason != null
                  ? () {
                      Navigator.pop(context);
                      _reportPost(postId, selectedReason!);
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Report',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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
    return ValueListenableBuilder<bool>(
      valueListenable: _refreshNotifier,
      builder: (context, _, __) => ListView.builder(
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
          return _buildPostItem(index);
        },
      ),
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
                    border: Border(bottom: BorderSide(color: colorScheme.error, width: 1)),
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

class PostCardWrapper extends StatelessWidget {
  final dynamic post;

  const PostCardWrapper({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        try {
          // reuse existing class by attaching it into PostsPage logic
          return PostsPageStateHelper.buildSinglePost(context, post);
        } catch (_) {
          return const SizedBox();
        }
      },
    );
  }
}
class PostsPageStateHelper {
  static Widget buildSinglePost(BuildContext context, dynamic post) {
    final state = context.findAncestorStateOfType<_PostsPageState>();

    if (state == null) {
      return const SizedBox();
    }

    // Inject temporary list with one item
    final idx = state.posts.indexWhere(
      (p) => p['post_id'].toString() == post['post_id'].toString(),
    );

    if (idx == -1) {
      state.posts.add(post);
    }

    final index = state.posts.indexWhere(
      (p) => p['post_id'].toString() == post['post_id'].toString(),
    );

    return state._buildPostItem(index);
  }
}

