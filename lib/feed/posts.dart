import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class Skeleton extends StatefulWidget {
  final double height;
  final double width;
  final String type;
  const Skeleton(
      {super.key, this.height = 20, this.width = 20, this.type = 'square'});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation gradientPosition;

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
        setState(() {});
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
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
          borderRadius: widget.type == 'circle'
              ? BorderRadius.circular(50)
              : BorderRadius.circular(0),
          gradient: LinearGradient(
              begin: Alignment(gradientPosition.value, 0),
              end: const Alignment(-1, 0),
              colors: const [Colors.black12, Colors.black26, Colors.black12])),
    );
  }
}

class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Skeleton(height: 40, width: 40, type: 'circle'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Skeleton(height: 14, width: 120),
                      const SizedBox(height: 4),
                      const Skeleton(height: 12, width: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Caption
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                const Skeleton(height: 16, width: double.infinity),
                const SizedBox(height: 8),
                Skeleton(height: 16, width: screenWidth * 0.6),
              ],
            ),
          ),
          // Media
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: const Skeleton(height: 200, width: double.infinity),
          ),
          const SizedBox(height: 12),
          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    const Skeleton(height: 20, width: 100),
                    const Spacer(),
                    const Skeleton(height: 20, width: 20),
                  ],
                ),
                const SizedBox(height: 8),
                const Skeleton(height: 12, width: 60),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Skeleton(height: 32, width: 32, type: 'circle'),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Skeleton(height: 14, width: double.infinity),
                const SizedBox(height: 4),
                const Skeleton(height: 12, width: double.infinity),
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

class _PostsPageState extends State<PostsPage> {
  List<dynamic> posts = [];
  bool isLoading = false;
  bool hasMore = true;
  bool networkError = false;
  int? nextCursorId;
  final ScrollController _scrollController = ScrollController();

  // Comments
  Map<int, List<dynamic>> commentsMap = {};
  Map<int, bool> showCommentsMap = {};
  Map<int, TextEditingController> commentControllers = {};
  Map<int, FocusNode> commentFocusNodes = {};
  Map<int, bool> commentLoadingMap = {};

  // Current user
  String _username = '';
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadUsername().then((_) {
      _fetchPosts();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (var c in commentControllers.values) {
      c.dispose();
    }
    for (var f in commentFocusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  // Load username from SharedPreferences
  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? '';
      _userId = prefs.getInt('user_id') ?? 0;
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (hasMore && !isLoading && !networkError) {
        _fetchMorePosts();
      }
    }
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
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch posts: ${response.statusCode}')),
          );
        }
        return null;
      }
    } catch (e) {
      if (e is SocketException) {
        if (mounted) {
          setState(() => networkError = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No internet connection')),
          );
        }
        return null;
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching posts: $e')),
          );
        }
        return null;
      }
    }
  }

  Future<void> _fetchPosts({int? cursorId}) async {
    if (isLoading) return;
    setState(() => isLoading = true);

    final data = await _fetchPostsData(cursorId: cursorId);
    if (data != null) {
      setState(() {
        networkError = false;
        if (cursorId == null) {
          posts = data['posts'] ?? [];
        } else {
          posts.addAll(data['posts'] ?? []);
        }
        nextCursorId = data['nextCursorId'];
        hasMore = nextCursorId != null;
      });
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _fetchMorePosts() async {
    if (nextCursorId != null) await _fetchPosts(cursorId: nextCursorId);
  }

  Future<void> _refreshPosts() async {
    if (_username.isEmpty) return;

    setState(() => networkError = false);

    if (posts.isEmpty) {
      await _fetchPosts();
      return;
    }

    final oldFirstId = posts[0]['post_id'] as int;

    final data = await _fetchPostsData();
    if (data == null) return;

    setState(() {
      networkError = false;
    });

    final newPosts = data['posts'] ?? [];
    final newOnes = newPosts.where((p) => (p['post_id'] as int) > oldFirstId).toList();

    if (newOnes.isNotEmpty) {
      setState(() {
        posts.insertAll(0, newOnes);
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No new posts found')),
        );
      }
    }
  }

  Future<void> _toggleLike(int postId, int index) async {
    if (_username.isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/like_action'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'post_id=$postId&username=${Uri.encodeComponent(_username)}',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted && data['like_count'] != null) {
          setState(() => posts[index]['like_count'] = data['like_count']);
        }
      }
    } catch (e) {
      if (e is SocketException) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No internet connection')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error toggling like: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleCommentVisibility(int postId) async {
    if (showCommentsMap[postId] ?? false) {
      if (mounted) setState(() => showCommentsMap[postId] = false);
      return;
    }

    if (mounted) setState(() => showCommentsMap[postId] = true);

    if (!commentsMap.containsKey(postId)) {
      commentsMap[postId] = [];
      commentLoadingMap[postId] = true;
      commentControllers[postId] ??= TextEditingController();
      commentFocusNodes[postId] ??= FocusNode();
      await _fetchComments(postId);
      if (mounted) setState(() => commentLoadingMap[postId] = false);
    }
  }

  Future<void> _fetchComments(int postId) async {
    if (commentLoadingMap[postId] ?? false || _username.isEmpty) return;
    setState(() => commentLoadingMap[postId] = true);

    try {
      final url =
          'https://server.awarcrown.com/feed/fetch_comments?post_id=$postId&username=${Uri.encodeComponent(_username)}';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted && data['comments'] != null) {
          setState(() => commentsMap[postId] = data['comments']);
        }
      }
    } catch (e) {
      if (e is SocketException) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No internet connection')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error fetching comments: $e')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => commentLoadingMap[postId] = false);
    }
  }

  Future<void> _postComment(int postId, String text) async {
    if (text.isEmpty || _username.isEmpty) return;
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/add_comment'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body:
            'post_id=$postId&username=${Uri.encodeComponent(_username)}&comment=${Uri.encodeComponent(text)}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          if (data['comment'] != null) commentsMap[postId]?.insert(0, data['comment']);
          final postIndex = posts.indexWhere((p) => p['post_id'] == postId);
          if (postIndex != -1) {
            posts[postIndex]['comment_count'] =
                (posts[postIndex]['comment_count'] ?? 0) + 1;
          }
          commentControllers[postId]?.clear();
        }
      }
    } catch (e) {
      if (e is SocketException) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No internet connection')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error posting comment: $e')),
          );
        }
      }
    }
  }

  Future<void> _sharePost(int postId) async {
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/share_post'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'post_id=$postId&username=${Uri.encodeComponent(_username)}',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Post shared! Count: ${data['share_count']}')),
          );
        }
      }
    } catch (e) {
      if (e is SocketException) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No internet connection')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error sharing post: $e')),
          );
        }
      }
    }
  }

  Future<void> _deletePost(int postId) async {
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/delete_post'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'post_id=$postId&username=${Uri.encodeComponent(_username)}',
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() => posts.removeWhere((p) => p['post_id'] == postId));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted successfully')),
          );
        }
      }
    } catch (e) {
      if (e is SocketException) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No internet connection')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting post: $e')),
          );
        }
      }
    }
  }

  Future<void> _savePost(int postId) async {
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/save_post'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'post_id=$postId&username=${Uri.encodeComponent(_username)}',
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['saved'] ? 'Post saved!' : 'Post unsaved')),
          );
        }
      }
    } catch (e) {
      if (e is SocketException) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No internet connection')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving post: $e')),
          );
        }
      }
    }
  }

  Widget _buildCommentsList(int postId) {
    final comments = commentsMap[postId] ?? [];
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
      itemBuilder: (context, index) {
        final comment = comments[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: comment['profile_picture'] != null
                    ? NetworkImage('https://server.awarcrown.com/${comment['profile_picture']}')
                    : null,
                child: comment['profile_picture'] == null ? const Icon(Icons.person, size: 16) : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style,
                        children: [
                          TextSpan(
                            text: '${comment['username'] ?? 'Unknown'} ',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          TextSpan(
                            text: _formatTime(comment['created_at']),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      comment['comment'] ?? '',
                      style: const TextStyle(fontSize: 14),
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

  bool _isOwnPost(int postId, int index) {
    if (_userId == null || _userId == 0) return false;
    return posts[index]['user_id'] == _userId;
  }

  Widget _buildList() {
    if (posts.isEmpty) {
      if (isLoading) {
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: 5,
          itemBuilder: (context, index) => const PostSkeleton(),
        );
      } else if (networkError) {
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: 10,
          itemBuilder: (context, index) => const PostSkeleton(),
        );
      } else {
        return const Center(child: Text('No posts available'));
      }
    } else {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _scrollController,
        itemCount: posts.length + (isLoading && hasMore && !networkError ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == posts.length) {
            return const PostSkeleton();
          }

          final post = posts[index];
          final postId = post['post_id'];

          return Card(
            elevation: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: post['profile_picture'] != null
                            ? NetworkImage('https://server.awarcrown.com/feed/${post['profile_picture']}')
                            : null,
                        child: post['profile_picture'] == null ? const Icon(Icons.person) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post['username'] ?? 'Unknown',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              _formatTime(post['created_at']),
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
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
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 20),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                          icon: const Icon(Icons.more_vert, size: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                    ],
                  ),
                ),
                // Caption
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    post['content'] ?? '',
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
                // Media
                if (post['media_url'] != null && post['media_url'].isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    child: AspectRatio(
                      aspectRatio: 16 / 9, // Auto-adjust based on common ratio; can be dynamic if API provides dimensions
                      child: Image.network(
                        'https://server.awarcrown.com${post['media_url']}',
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[200],
                            child: const Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 200,
                            color: Colors.grey[200],
                            child: const Icon(Icons.error),
                          );
                        },
                      ),
                    ),
                  ),
                // Actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => _toggleLike(postId, index),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.favorite_border, size: 24, color: Colors.red),
                                const SizedBox(width: 4),
                                Text('${post['like_count'] ?? 0}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 16),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _toggleCommentVisibility(postId),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.mode_comment_outlined, size: 24),
                                const SizedBox(width: 4),
                                Text('${post['comment_count'] ?? 0}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 16),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _sharePost(postId),
                            child: const Icon(Icons.share_outlined, size: 24),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _savePost(postId),
                            child: const Icon(Icons.bookmark_border, size: 24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${post['like_count'] ?? 0} likes',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                // Comments Section
                if (showCommentsMap[postId] == true) ...[
                  const Divider(height: 1),
                  SizedBox(
                    height: 300,
                    child: (commentLoadingMap[postId] ?? false)
                        ? ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: 3,
                            separatorBuilder: (context, index) => const Divider(height: 1, indent: 56),
                            itemBuilder: (context, index) => const CommentSkeleton(),
                          )
                        : ((commentsMap[postId]?.isEmpty ?? true)
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    networkError ? 'Cannot load comments due to network issue.' : 'No comments yet',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            : _buildCommentsList(postId)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentControllers[postId],
                            focusNode: commentFocusNodes[postId],
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: const BorderSide(color: Colors.blue),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                            onSubmitted: (value) => _postComment(postId, value.trim()),
                            maxLines: null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final text = commentControllers[postId]?.text.trim() ?? '';
                            if (text.isNotEmpty) _postComment(postId, text);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.send, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshPosts,
        child: Column(
          children: [
            if (networkError)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.red[50],
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'No internet connection. Some features may not work.',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
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
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return timeString;
    }
  }
}