import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// ignore: unused_import
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PostsPage extends StatefulWidget {
  const PostsPage({super.key});

  @override
  _PostsPageState createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  List<dynamic> posts = [];
  bool isLoading = false;
  bool hasMore = true;
  int? nextCursorId;
  final ScrollController _scrollController = ScrollController();

  // For comments: map of post_id to list of comments
  Map<int, List<dynamic>> commentsMap = {};
  Map<int, bool> showCommentsMap = {};
  Map<int, TextEditingController> commentControllers = {};
  Map<int, FocusNode> commentFocusNodes = {};
  Map<int, bool> commentLoadingMap = {};
  Map<int, bool> hasMoreComments = {};
  Map<int, int?> nextCommentCursor = {};
  Map<int, ScrollController> commentScrollControllers = {};

  // Current user ID fetched from SharedPreferences
  int? currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _fetchPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Dispose controllers and focus nodes
    for (var c in commentControllers.values) {
      c.dispose();
    }
    for (var f in commentFocusNodes.values) {
      f.dispose();
    }
    for (var sc in commentScrollControllers.values) {
      sc.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        currentUserId = prefs.getInt('user_id') ?? 0;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (hasMore && !isLoading) {
        _fetchMorePosts();
      }
    }
  }

  Future<void> _fetchPosts({int? cursorId}) async {
    if (isLoading) return;
    setState(() => isLoading = true);

    try {
      String url = 'https://server.awarcrown.com/feed/fetch_posts';
      if (cursorId != null) {
        url += '?cursorId=$cursorId';
      }
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          if (cursorId == null) {
            posts = data['posts'] ?? [];
          } else {
            posts.addAll(data['posts'] ?? []);
          }
          nextCursorId = data['nextCursorId'];
          hasMore = nextCursorId != null;
        });
      } else {
        // Handle error, e.g., show snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch posts: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching posts: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchMorePosts() async {
    if (nextCursorId != null) {
      await _fetchPosts(cursorId: nextCursorId);
    }
  }

  Future<void> _toggleLike(int postId, int currentIndex) async {
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/like_action'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'post_id=$postId',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['like_count'] != null) {
          setState(() {
            posts[currentIndex]['like_count'] = data['like_count'];
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle like: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling like: $e')),
      );
    }
  }

  Future<void> _toggleCommentVisibility(int postId) async {
    if (showCommentsMap[postId] ?? false) {
      setState(() => showCommentsMap[postId] = false);
      return;
    }

    setState(() => showCommentsMap[postId] = true);

    if (!commentsMap.containsKey(postId)) {
      commentsMap[postId] = [];
      hasMoreComments[postId] = true;
      nextCommentCursor[postId] = null;
      commentLoadingMap[postId] = true;

      // Create scroll controller if not exists
      if (!commentScrollControllers.containsKey(postId)) {
        final sc = ScrollController();
        sc.addListener(() {
          if (sc.hasClients &&
              sc.position.pixels >= sc.position.maxScrollExtent - 200) {
            if ((hasMoreComments[postId] ?? false) &&
                !(commentLoadingMap[postId] ?? false)) {
              _fetchMoreComments(postId);
            }
          }
        });
        commentScrollControllers[postId] = sc;
      }
    }

    await _fetchComments(postId, cursorId: nextCommentCursor[postId]);

    if (mounted) {
      setState(() => commentLoadingMap[postId] = false);
    }
  }

  Future<void> _fetchComments(int postId, {int? cursorId}) async {
    setState(() => commentLoadingMap[postId] = true);

    try {
      String url = 'https://server.awarcrown.com/fetch_comments.php?post_id=$postId';
      if (cursorId != null) {
        url += '&cursorId=$cursorId';
      }
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newComments = data['comments'] ?? [];
        setState(() {
          if (cursorId == null) {
            commentsMap[postId] = newComments;
          } else {
            commentsMap[postId]!.addAll(newComments);
          }
          commentsMap[postId]!.sort((a, b) =>
              DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at'])));
          nextCommentCursor[postId] = data['nextCursorId'];
          hasMoreComments[postId] = nextCommentCursor[postId] != null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch comments: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching comments: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => commentLoadingMap[postId] = false);
      }
    }
  }

  Future<void> _fetchMoreComments(int postId) async {
    final cursor = nextCommentCursor[postId];
    if (cursor != null) {
      await _fetchComments(postId, cursorId: cursor);
    }
  }

  Future<void> _postComment(int postId, String commentText, {int? parentCommentId}) async {
    if (commentText.trim().isEmpty) return;

    final controller = commentControllers[postId];

    // Note: post_comment.php endpoint not provided in backend files.
    // Assuming it exists and handles POST with post_id, comment, parent_comment_id.
    // For now, simulate locally; replace with actual API call when available.
    try {
      // Uncomment and adjust when backend is ready:
      /*
      final body = {
        'post_id': postId.toString(),
        'comment': Uri.encodeComponent(commentText),
      };
      if (parentCommentId != null) {
        body['parent_comment_id'] = parentCommentId.toString();
      }
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/post_comment.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body.entries.map((e) => '${e.key}=${e.value}').join('&'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          // Refetch comments or add new one
          await _fetchComments(postId);
          // Update comment count
          final postIndex = posts.indexWhere((p) => p['post_id'] == postId);
          if (postIndex != -1) {
            setState(() {
              posts[postIndex]['comment_count'] = (posts[postIndex]['comment_count'] ?? 0) + 1;
            });
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to post comment');
        }
      } else {
        throw Exception('Failed to post comment: ${response.statusCode}');
      }
      */

      // Temporary simulation
      if (currentUserId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User not loaded')),
        );
        return;
      }
      final newComment = {
        'comment_id': DateTime.now().millisecondsSinceEpoch, // Temp ID
        'comment': commentText.trim(),
        'username': 'Current User', // From session
        'created_at': DateTime.now().toIso8601String(),
        'like_count': 0,
        'current_reaction': null,
        'user_id': currentUserId,
        'parent_comment_id': parentCommentId,
        'updated_at': null,
        'profile_picture': 'default-profile.png',
      };
      setState(() {
        if (!commentsMap.containsKey(postId)) {
          commentsMap[postId] = [];
        }
        commentsMap[postId]!.add(newComment);
        commentsMap[postId]!.sort((a, b) =>
            DateTime.parse(a['created_at']).compareTo(DateTime.parse(b['created_at'])));
        final postIndex = posts.indexWhere((p) => p['post_id'] == postId);
        if (postIndex != -1) {
          posts[postIndex]['comment_count'] = (posts[postIndex]['comment_count'] ?? 0) + 1;
        }
        if (parentCommentId == null) {
          controller?.clear();
        }
      });
      if (parentCommentId == null) {
        commentFocusNodes[postId]?.unfocus();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comment posted (API simulation)')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error posting comment: $e')),
      );
    }
  }

  Future<void> _sharePost(int postId) async {
    // Note: share_post.php endpoint not provided.
    // For now, placeholder.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Post shared (API pending)')),
    );
  }

  Future<void> _savePost(int postId) async {
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/saved_post.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'post_id=$postId',
      );

      if (response.statusCode == 200) {
        // Assuming success if no error message
        if (!response.body.contains('already saved') && !response.body.contains('Failed')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Post saved successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.body)),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save post: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving post: $e')),
      );
    }
  }

  Future<void> _deletePost(int postId) async {
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/delete_post.php'), // Assuming path based on filename
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'post_id=$postId',
      );

      if (response.statusCode == 200) {
        // Remove from list
        setState(() {
          posts.removeWhere((p) => p['post_id'] == postId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Post deleted successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete post: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting post: $e')),
      );
    }
  }

  Future<void> _toggleCommentLike(int commentId, int postId) async {
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/like_comment.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'comment_id=$commentId&action=set&reaction_type=like', // Assuming like reaction
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          // Refetch comments to update count
          await _fetchComments(postId);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle comment like: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error toggling comment like: $e')),
      );
    }
  }

  Future<void> _reportComment(int commentId) async {
    final reason = 'Inappropriate content'; // Placeholder; in real UI, prompt for reason
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/report_comment.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'comment_id=$commentId&reason=${Uri.encodeComponent(reason)}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Comment reported successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to report')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to report comment: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reporting comment: $e')),
      );
    }
  }

  Future<bool> _checkReportStatus(int commentId) async {
    try {
      final response = await http.get(
        Uri.parse('https://server.awarcrown.com/check_report_status.php?comment_id=$commentId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['alreadyReported'] ?? false;
      }
    } catch (e) {
      // Ignore error, assume not reported
    }
    return false;
  }

  Future<void> _editComment(int commentId, String newComment, int postId) async {
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/edit_comment.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'comment_id=$commentId&comment=${Uri.encodeComponent(newComment)}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          // Refetch comments
          await _fetchComments(postId);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Comment edited successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to edit')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to edit comment: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error editing comment: $e')),
      );
    }
  }

  Future<void> _deleteComment(int commentId, int postId) async {
    // Note: delete_comment.php endpoint not provided in backend files.
    // Assuming it exists and handles POST with comment_id.
    // For now, simulate locally; replace with actual API call when available.
    try {
      // Uncomment and adjust when backend is ready:
      /*
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/delete_comment.php'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'comment_id=$commentId',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          // Refetch comments
          await _fetchComments(postId);
          // Update comment count
          final postIndex = posts.indexWhere((p) => p['post_id'] == postId);
          if (postIndex != -1) {
            setState(() {
              posts[postIndex]['comment_count'] = (posts[postIndex]['comment_count'] ?? 0) - 1;
            });
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to delete comment');
        }
      } else {
        throw Exception('Failed to delete comment: ${response.statusCode}');
      }
      */

      // Temporary simulation
      setState(() {
        if (commentsMap.containsKey(postId)) {
          commentsMap[postId]!.removeWhere((c) => c['comment_id'] == commentId);
        }
        final postIndex = posts.indexWhere((p) => p['post_id'] == postId);
        if (postIndex != -1) {
          posts[postIndex]['comment_count'] = (posts[postIndex]['comment_count'] ?? 0) - 1;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comment deleted (API simulation)')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting comment: $e')),
      );
    }
  }

  void _showEditDialog(int commentId, String currentComment, int postId) {
    final TextEditingController editController = TextEditingController(text: currentComment);
    String? errorText;
    final FocusNode focusNode = FocusNode();
    bool listenerAdded = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!listenerAdded) {
            listenerAdded = true;
            editController.addListener(() {
              final text = editController.text.trim();
              errorText = text.isEmpty ? 'Comment cannot be empty' : (text.length > 500 ? 'Comment too long (max 500 chars)' : null);
              setDialogState(() {});
            });
          }
          // Initial validation
          final initialText = editController.text.trim();
          if (errorText == null) {
            errorText = initialText.isEmpty ? 'Comment cannot be empty' : (initialText.length > 500 ? 'Comment too long (max 500 chars)' : null);
          }
          return AlertDialog(
            title: Text('Edit Comment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: editController,
                  focusNode: focusNode,
                  maxLines: null,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Edit your comment...',
                    border: OutlineInputBorder(),
                    errorText: errorText,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: errorText != null ? null : () {
                  final newText = editController.text.trim();
                  Navigator.pop(context);
                  _editComment(commentId, newText, postId);
                },
                child: Text('Save'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      editController.dispose();
      focusNode.dispose();
    });
  }

  void _showReplyDialog(int parentCommentId, String? parentUsername, int postId) {
    final TextEditingController replyController = TextEditingController();
    final FocusNode focusNode = FocusNode();
    String? errorText;
    bool listenerAdded = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!listenerAdded) {
            listenerAdded = true;
            replyController.addListener(() {
              final text = replyController.text.trim();
              errorText = text.isEmpty ? 'Reply cannot be empty' : (text.length > 500 ? 'Reply too long (max 500 chars)' : null);
              setDialogState(() {});
            });
          }
          // Initial validation
          final initialText = replyController.text.trim();
          if (errorText == null) {
            errorText = initialText.isEmpty ? 'Reply cannot be empty' : (initialText.length > 500 ? 'Reply too long (max 500 chars)' : null);
          }
          return AlertDialog(
            title: Text('Reply to ${parentUsername ?? 'comment'}'),
            content: TextField(
              controller: replyController,
              focusNode: focusNode,
              maxLines: null,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Write a reply...',
                border: OutlineInputBorder(),
                errorText: errorText,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: errorText != null
                    ? null
                    : () {
                        Navigator.pop(context);
                        _postComment(postId, replyController.text.trim(), parentCommentId: parentCommentId);
                      },
                child: const Text('Reply'),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      replyController.dispose();
      focusNode.dispose();
    });
  }

  Widget _buildCommentWidget(dynamic comment, int postId, {required bool isTopLevel}) {
    final allComments = commentsMap[postId] ?? [];
    final commentId = comment['comment_id'];
    final isOwn = currentUserId != null && comment['user_id'] == currentUserId;
    final double leftPadding = isTopLevel ? 0.0 : 40.0;

    return Padding(
      padding: EdgeInsets.only(left: leftPadding, bottom: isTopLevel ? 8.0 : 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundImage: comment['profile_picture'] != null &&
                      comment['profile_picture'] != 'default-profile.png'
                  ? NetworkImage(
                      'https://server.awarcrown.com/${comment['profile_picture']}')
                  : null,
              backgroundColor: Colors.grey[300],
              child: comment['profile_picture'] == 'default-profile.png'
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(comment['username'] ?? 'Unknown'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment['comment'] ?? ''),
                if (comment['updated_at'] != null &&
                    comment['updated_at'] != comment['created_at'])
                  const Text('Edited',
                      style: TextStyle(fontSize: 10, color: Colors.grey)),
                Text(
                  _formatTime(comment['created_at']),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _toggleCommentLike(commentId, postId),
                  child: Row(
                    children: [
                      const Icon(Icons.thumb_up, size: 16),
                      const SizedBox(width: 4),
                      Text('${comment['like_count'] ?? 0}'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'report') {
                      final isReported =
                          await _checkReportStatus(commentId);
                      if (isReported) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Already reported')),
                        );
                      } else {
                        await _reportComment(commentId);
                      }
                    } else if (value == 'edit' && isOwn) {
                      _showEditDialog(
                          commentId, comment['comment'], postId);
                    } else if (value == 'delete' && isOwn) {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Comment'),
                          content: const Text(
                              'Are you sure you want to delete this comment?'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _deleteComment(commentId, postId);
                      }
                    } else if (value == 'reply') {
                      _showReplyDialog(
                          commentId, comment['username'], postId);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'reply', child: Text('Reply')),
                    if (isOwn)
                      const PopupMenuItem(
                          value: 'edit', child: Text('Edit')),
                    if (isOwn)
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete')),
                    const PopupMenuItem(
                        value: 'report', child: Text('Report')),
                  ],
                  child: const Icon(Icons.more_vert, size: 16),
                ),
              ],
            ),
            onLongPress: () => _showReplyDialog(
                commentId, comment['username'], postId),
          ),
          _buildCommentTree(allComments, postId, parentId: commentId),
        ],
      ),
    );
  }

  Widget _buildCommentTree(List<dynamic> comments, int postId, {int? parentId}) {
    final children =
        comments.where((c) => c['parent_comment_id'] == parentId).toList();

    if (children.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((comment) => _buildCommentWidget(comment, postId, isTopLevel: false)).toList(),
    );
  }

  Widget _buildCommentsList(int postId) {
    final allComments = commentsMap[postId] ?? [];
    final topLevel = allComments.where((c) => (c['parent_comment_id'] ?? 0) == 0).toList();
    final bool showLoadMore = (hasMoreComments[postId] ?? false) && !(commentLoadingMap[postId] ?? false);
    final ScrollController? sc = commentScrollControllers[postId];

    return ListView.builder(
      controller: sc,
      padding: EdgeInsets.zero,
      itemCount: topLevel.length + (showLoadMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == topLevel.length) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final comment = topLevel[index];
        return _buildCommentWidget(comment, postId, isTopLevel: true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Posts Feed')),
      body: ListView.builder(
        controller: _scrollController,
        itemCount: posts.length + (isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == posts.length) {
            return Center(child: CircularProgressIndicator());
          }
          final post = posts[index];
          final postId = post['post_id'];
          final isOwnPost = currentUserId != null && post['user_id'] == currentUserId;
          return Card(
            margin: EdgeInsets.all(8),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: post['profile_picture'] != null &&
                                post['profile_picture'] != 'default-profile.png'
                            ? NetworkImage('https://server.awarcrown.com/${post['profile_picture']}')
                            : null,
                        backgroundColor: Colors.grey[300],
                        child: post['profile_picture'] == 'default-profile.png'
                            ? Icon(Icons.person)
                            : null,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post['username'] ?? 'Unknown',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _formatTime(post['created_at']),
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton(
                        onSelected: (value) async {
                          switch (value) {
                            case 'edit':
                              // TODO: Implement edit post UI/API
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Edit post (API pending)')),
                              );
                              break;
                            case 'delete':
                              await _deletePost(postId);
                              break;
                            case 'save':
                              await _savePost(postId);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          if (isOwnPost)
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                          if (isOwnPost)
                            PopupMenuItem(value: 'delete', child: Text('Delete')),
                          PopupMenuItem(value: 'save', child: Text('Save')),
                        ],
                        child: Icon(Icons.more_vert),
                      ),
                    ],
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    post['content'] ?? '',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                // Media
                if (post['media_url'] != null && post['media_url'].isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(top: 10, bottom: 10),
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage('https://server.awarcrown.com${post['media_url']}'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                // Actions
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _toggleLike(postId, index),
                        child: Row(
                          children: [
                            Icon(Icons.favorite_border, size: 20, color: Colors.red),
                            SizedBox(width: 6),
                            Text('${post['like_count'] ?? 0} Likes'),
                          ],
                        ),
                      ),
                      SizedBox(width: 18),
                      GestureDetector(
                        onTap: () => _toggleCommentVisibility(postId),
                        child: Row(
                          children: [
                            Icon(Icons.mode_comment_outlined, size: 20),
                            SizedBox(width: 6),
                            Text('${post['comment_count'] ?? 0} Comments'),
                          ],
                        ),
                      ),
                      Spacer(),
                      GestureDetector(
                        onTap: () => _sharePost(postId),
                        child: Icon(Icons.share_outlined, size: 20),
                      ),
                    ],
                  ),
                ),
                // Comments Section
                if (showCommentsMap[postId] == true) ...[
                  Divider(),
                  SizedBox(
                    height: 300.0,
                    child: (commentLoadingMap[postId] ?? false)
                        ? const Center(child: CircularProgressIndicator())
                        : ((commentsMap[postId]?.isEmpty ?? true)
                            ? const Center(child: Text('No comments yet'))
                            : _buildCommentsList(postId)),
                  ),
                  // Add Comment Input
                  Padding(
                    padding: EdgeInsets.all(8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentControllers[postId] ??= TextEditingController(),
                            focusNode: commentFocusNodes[postId] ??= FocusNode(),
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            onSubmitted: (value) => _postComment(postId, value.trim()),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            final text = commentControllers[postId]?.text.trim() ?? '';
                            _postComment(postId, text);
                          },
                          icon: Icon(Icons.send),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 8),
              ],
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
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (e) {
      return timeString;
    }
  }
}