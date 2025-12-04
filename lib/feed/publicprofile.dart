import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ideaship/feed/posts.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:io' show SocketException;
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;


class PublicProfilePage extends StatefulWidget {
  final String targetUsername;
  const PublicProfilePage({super.key, required this.targetUsername});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> with TickerProviderStateMixin {
  Map<String, dynamic>? userInfo;
  List<dynamic> posts = [];
  bool isLoading = true;
  bool isFollowing = false;
  String currentUsername = '';
  String? errorMessage;
  String? postsError;
  bool hasMore = true;
  int? nextCursorId;
  final ScrollController _scrollController = ScrollController();
  Map<int, List<dynamic>> commentsMap = {};
  Map<int, bool> isLikingMap = {};
  Map<int, AnimationController> likeAnimationControllers = {};
  Map<int, bool> showHeartOverlay = {};
  Map<int, AnimationController> heartOverlayControllers = {};
  Map<int, bool> isFetchingComments = {};
  Timer? _scrollDebounceTimer;
  Map<int, bool> isFollowingMap = {};
  Map<int, bool> isProcessingFollow = {};
  int? _userId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _scrollController.addListener(_onScroll);
  }

  String _getErrorMessage(dynamic e) {
    if (e is SocketException) {
      return 'It seems you\'re not connected to the internet. Please check your connection.';
    } else if (e is TimeoutException) {
      return 'The connection is taking too long. Please try again in a moment.';
    } else if (e is http.ClientException) {
      return 'There was a problem connecting to the server. Please try again.';
    } else if (e is FormatException) {
      return 'Invalid response from server. Please try again.';
    } else {
      return 'Something unexpected happened. Please try again.';
    }
  }

  Future<T> _retryRequest<T>(Future<T> Function() request, {int maxRetries = 3}) async {
    Exception? lastError;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await request();
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt == maxRetries - 1) rethrow;
        final delay = Duration(milliseconds: (math.pow(2, attempt) * 1000).round());
        await Future.delayed(delay);
        debugPrint('Retry attempt ${attempt + 1} after delay: ${delay.inMilliseconds}ms for error: $e');
      }
    }
    throw lastError ?? Exception('Max retries exceeded without success');
  }

  Future<void> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      currentUsername = prefs.getString('username') ?? '';

      if (currentUsername.isEmpty) {
        if (mounted) {
          setState(() {
            isLoading = false;
            errorMessage = 'Please log in to view profiles.';
          });
        }
        return;
      }

      _userId = prefs.getInt('user_id');
      if (_userId == null || _userId == 0) {
        await _fetchUserId();
      }

      await _fetchUserInfo();
      await _fetchUserPosts();
      await _updateFollowStatuses();
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } on Exception catch (e) {
      debugPrint('Error in _loadCurrentUser: $e');
      if (mounted) {
        setState(() {
          errorMessage = _getErrorMessage(e);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Unexpected error in _loadCurrentUser: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'An unexpected error occurred. Please try again.';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchUserId() async {
    if (currentUsername.isEmpty) return;
    try {
      await _retryRequest(() async {
        final response = await http.get(
          Uri.parse('https://server.awarcrown.com/feed/get_user?username=${Uri.encodeComponent(currentUsername)}'),
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          throw http.ClientException('Server returned ${response.statusCode}');
        }
        final data = json.decode(response.body);
        if (data is! Map<String, dynamic> || data['error'] != null) {
          throw FormatException('Invalid user data response');
        }
        dynamic userIdData = data['user_id'];
        int? parsedUserId;
        if (userIdData is int) {
          parsedUserId = userIdData;
        } else if (userIdData != null) {
          parsedUserId = int.tryParse(userIdData.toString());
        }
        if (parsedUserId == null || parsedUserId == 0) {
          throw Exception('Invalid user ID received');
        }
        _userId = parsedUserId;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', _userId!);
        if (mounted) setState(() {});
      });
    } on Exception catch (e) {
      debugPrint('Error fetching user ID: $e');
    }
  }

  Future<void> _fetchUserInfo() async {
    try {
      await _retryRequest(() async {
        final response = await http
            .get(Uri.parse(
                'https://server.awarcrown.com/accessprofile/user_info?target_username=${Uri.encodeComponent(widget.targetUsername)}&username=${Uri.encodeComponent(currentUsername)}'))
            .timeout(const Duration(seconds: 20));

        if (response.statusCode != 200) {
          String specificError;
          switch (response.statusCode) {
            case 401:
              specificError = 'You need to log in to view this profile.';
              break;
            case 403:
              specificError = 'You don\'t have permission to view this profile.';
              break;
            case 404:
              specificError = 'This user doesn\'t exist.';
              break;
            case 500:
              specificError = 'The server is having issues. Please try again later.';
              break;
            default:
              specificError = 'There was a server issue (code ${response.statusCode}). Please try again.';
          }
          throw Exception(specificError);
        }

        final data = json.decode(response.body);
        if (data is! Map<String, dynamic>) {
          throw FormatException('Invalid JSON structure');
        }
        final processedData = Map<String, dynamic>.from(data);
        processedData['followers_count'] = int.tryParse(processedData['followers_count']?.toString() ?? '0') ?? 0;
        processedData['following_count'] = int.tryParse(processedData['following_count']?.toString() ?? '0') ?? 0;
        if (mounted) {
          setState(() {
            userInfo = processedData;
            isFollowing = data['is_following'] ?? false;
          });
        }
      });
    } on Exception catch (e) {
      debugPrint('Error in _fetchUserInfo: $e');
      if (mounted) {
        setState(() {
          errorMessage = _getErrorMessage(e);
        });
      }
      rethrow;
    }
  }

  Future<void> _fetchUserPosts({int? cursorId}) async {
    try {
      await _retryRequest(() async {
        final params = {'target_username': widget.targetUsername, 'username': currentUsername};
        if (cursorId != null) params['cursorId'] = cursorId.toString();
        final queryString = params.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
            .join('&');
        final url = 'https://server.awarcrown.com/accessprofile/fetch_user_posts?$queryString';
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 20));

        if (response.statusCode != 200) {
          String specificError;
          switch (response.statusCode) {
            case 401:
              specificError = 'You need to log in to view posts.';
              break;
            case 403:
              specificError = 'You don\'t have permission to view these posts.';
              break;
            case 404:
              specificError = 'No posts found for this user.';
              break;
            case 500:
              specificError = 'The server is having issues. Please try again later.';
              break;
            default:
              specificError = 'There was a server issue (code ${response.statusCode}). Please try again.';
          }
          throw Exception(specificError);
        }

        final data = json.decode(response.body);
        if (data is! Map<String, dynamic>) {
          throw FormatException('Invalid JSON structure');
        }
        if (mounted) {
          setState(() {
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
            postsError = null;
          });
        }
      });
    } on Exception catch (e) {
      debugPrint('Error in _fetchUserPosts: $e');
      if (mounted) {
        setState(() {
          postsError = _getErrorMessage(e);
          posts = [];
        });
      }
    }
  }

  void _onScroll() {
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients &&
          _scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 300) {
        if (hasMore && postsError == null) {
          _fetchMorePosts();
        }
      }
    });
  }

  Future<void> _fetchMorePosts() async {
    if (nextCursorId != null) {
      await _fetchUserPosts(cursorId: nextCursorId);
    }
  }

  Future<void> _toggleFollow() async {
    if (_userId == null || _userId == 0) {
      await _fetchUserId();
      if (_userId == null || _userId == 0) return;
    }
    try {
      await _retryRequest(() async {
        final response = await http.post(
          Uri.parse('https://server.awarcrown.com/feed/follow_action'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body:
              'target_username=${Uri.encodeComponent(widget.targetUsername)}&username=${Uri.encodeComponent(currentUsername)}',
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode != 200) {
          String specificError;
          switch (response.statusCode) {
            case 400:
              specificError = 'Invalid request. Please try again.';
              break;
            case 401:
              specificError = 'Please log in again.';
              break;
            case 403:
              specificError = 'You can\'t follow this user.';
              break;
            case 404:
              specificError = 'User not found.';
              break;
            case 500:
              specificError = 'The server is having issues. Please try again later.';
              break;
            default:
              specificError = 'There was a server issue (code ${response.statusCode}). Please try again.';
          }
          throw Exception(specificError);
        }

        final data = json.decode(response.body);
        if (data is! Map<String, dynamic>) {
          throw FormatException('Invalid JSON structure');
        }
        if (data['success'] != true) {
          throw Exception('Follow action failed: ${data['message'] ?? 'Please try again.'}');
        }
        if (mounted) {
          setState(() {
            isFollowing = !isFollowing;
            userInfo!['followers_count'] =
                (userInfo!['followers_count'] ?? 0) + (isFollowing ? 1 : -1);
          });
        }
      });
    } on Exception catch (e) {
      debugPrint('Error in _toggleFollow: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<bool> _getIsFollowing(int followedId) async {
    if (_userId == null) return false;
    try {
      return await _retryRequest(() async {
        final response = await http.get(
          Uri.parse('https://server.awarcrown.com/feed/get_follower?follower_id=$_userId&followed_id=$followedId'),
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode != 200) {
          throw http.ClientException('Server returned ${response.statusCode}');
        }
        final data = json.decode(response.body);
        if (data is! Map<String, dynamic>) {
          throw FormatException('Invalid JSON structure');
        }
        return data['is_following'] ?? false;
      });
    } on Exception catch (e) {
      debugPrint('Error fetching follow status: $e');
      return false;
    }
  }

  Future<void> _updateFollowStatuses() async {
    if (_userId == null || posts.isEmpty) return;
    try {
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
    } on Exception catch (e) {
      debugPrint('Error updating follow statuses: $e');
    }
  }

  Future<void> _toggleLike(int postId, int index) async {
    if (_userId == null || _userId == 0) {
      await _fetchUserId();
      if (_userId == null || _userId == 0) return;
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
      await _retryRequest(() async {
        final response = await http.post(
          Uri.parse('https://server.awarcrown.com/feed/like_action'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: 'post_id=$postId&user_id=$_userId',
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          throw http.ClientException('Server error: ${response.statusCode}');
        }
        final data = json.decode(response.body);
        if (data is! Map<String, dynamic>) {
          throw FormatException('Invalid JSON structure');
        }
        if (mounted) {
          setState(() {
            if (data['like_count'] != null) {
              posts[index]['like_count'] = data['like_count'];
            }
            if (data['is_liked'] != null) {
              posts[index]['is_liked'] = data['is_liked'];
            }
          });
        }
      });
    } on Exception catch (e) {
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
      debugPrint('Error in _toggleLike: $e');
    } finally {
      if (mounted) {
        setState(() => isLikingMap[postId] = false);
      }
    }
  }

  Future<void> _queueLikeAction(Map<String, dynamic> actionMap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<dynamic> queue = [];
      final queueStr = prefs.getString('like_queue');
      if (queueStr != null) {
        queue = json.decode(queueStr);
      }
      queue.add(actionMap);
      await prefs.setString('like_queue', json.encode(queue));
    } catch (e) {
      debugPrint('Error queuing like action: $e');
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

  Future<void> _fetchComments(int postId) async {
    if (currentUsername.isEmpty) return;
    try {
      await _retryRequest(() async {
        final url = 'https://server.awarcrown.com/feed/fetch_comments?post_id=$postId&username=${Uri.encodeComponent(currentUsername)}';
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          throw http.ClientException('Server error: ${response.statusCode}');
        }
        final data = json.decode(response.body);
        if (data is! Map<String, dynamic>) {
          throw FormatException('Invalid JSON structure');
        }
        if (mounted) {
          commentsMap[postId] = data['comments'] ?? [];
        }
      });
    } on Exception catch (e) {
      debugPrint('Error fetching comments: $e');
      _showError(_getErrorMessage(e));
    }
  }

  Future<void> _toggleFollowUser(int followedUserId, int index) async {
    if (_userId == null || _userId == 0) {
      await _fetchUserId();
      if (_userId == null || _userId == 0) return;
    }
    if (isProcessingFollow[followedUserId] ?? false) return;
    setState(() => isProcessingFollow[followedUserId] = true);
    final oldFollowing = isFollowingMap[followedUserId] ?? false;
    final newFollowing = !oldFollowing;
    for (var i = 0; i < posts.length; i++) {
      if (posts[i]['user_id'] == followedUserId) {
        posts[i]['is_following'] = newFollowing;
      }
    }
    isFollowingMap[followedUserId] = newFollowing;
    if (mounted) setState(() {});
    try {
      await _retryRequest(() async {
        final response = await http.post(
          Uri.parse('https://server.awarcrown.com/feed/handle_followers'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: 'follower_id=$_userId&followed_id=$followedUserId&action=${newFollowing ? 'follow' : 'unfollow'}',
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          throw http.ClientException('Server error: ${response.statusCode}');
        }
        final data = json.decode(response.body);
        if (data is! Map<String, dynamic>) {
          throw FormatException('Invalid JSON structure');
        }
        if (data['status'] != 'success') {
          throw Exception(data['message'] ?? 'Failed to process follow action');
        }
        _showSuccess(newFollowing ? 'Followed user' : 'Unfollowed user');
      });
    } on Exception catch (e) {
      for (var i = 0; i < posts.length; i++) {
        if (posts[i]['user_id'] == followedUserId) {
          posts[i]['is_following'] = oldFollowing;
        }
      }
      isFollowingMap[followedUserId] = oldFollowing;
      if (mounted) setState(() {});
      _showError('Failed to ${newFollowing ? 'follow' : 'unfollow'} user: ${_getErrorMessage(e)}');
      debugPrint('Error in _toggleFollowUser: $e');
    } finally {
      if (mounted) {
        setState(() => isProcessingFollow[followedUserId] = false);
      }
    }
  }

  Future<void> _sharePost(int postId) async {
    if (currentUsername.isEmpty) return;
    try {
      await _retryRequest(() async {
        final response = await http.post(
          Uri.parse('https://server.awarcrown.com/feed/share_post'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: 'post_id=$postId&username=${Uri.encodeComponent(currentUsername)}',
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          throw http.ClientException('Server error: ${response.statusCode}');
        }
        final data = json.decode(response.body);
        if (data is! Map<String, dynamic>) {
          throw FormatException('Invalid JSON structure');
        }
        if (data['status'] != 'success') {
          throw Exception(data['message'] ?? 'Failed to share post');
        }
        final shareUrl = data['share_url'] ?? '';
        if (shareUrl.isNotEmpty) {
          _showShareSheet(shareUrl);
        } else {
          _showSuccess('Post shared successfully!');
        }
      });
    } on Exception catch (e) {
      debugPrint('Error in _sharePost: $e');
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
        // ignore: unused_local_variable
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
                        backgroundColor: const Color.fromARGB(255, 7, 5, 113),
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
    try {
      await Share.share(shareUrl, subject: 'Check this post on Awarcrown');
    } catch (e) {
      debugPrint('Error sharing to external: $e');
      _showError('Failed to share externally');
    } finally {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _deletePost(int postId, int index) async {
    if (currentUsername.isEmpty) return;
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
      await _retryRequest(() async {
        final response = await http.post(
          Uri.parse('https://server.awarcrown.com/feed/delete_post'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: 'post_id=$postId&username=${Uri.encodeComponent(currentUsername)}',
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          throw http.ClientException('Server error: ${response.statusCode}');
        }
        if (mounted) {
          setState(() => posts.removeAt(index));
          _showSuccess('Post deleted successfully');
        }
      });
    } on Exception catch (e) {
      debugPrint('Error in _deletePost: $e');
      _showError('Failed to delete post: ${_getErrorMessage(e)}');
    }
  }

  Future<void> _savePost(int postId) async {
    if (currentUsername.isEmpty) return;
    try {
      await _retryRequest(() async {
        final response = await http.post(
          Uri.parse('https://server.awarcrown.com/feed/save_post'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: 'post_id=$postId&username=${Uri.encodeComponent(currentUsername)}',
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          throw http.ClientException('Server error: ${response.statusCode}');
        }
        final data = json.decode(response.body);
        if (data is! Map<String, dynamic>) {
          throw FormatException('Invalid JSON structure');
        }
        _showSuccess(data['saved'] == true ? 'Post saved!' : 'Post unsaved');
      });
    } on Exception catch (e) {
      debugPrint('Error in _savePost: $e');
      _showError('Failed to save post: ${_getErrorMessage(e)}');
    }
  }

  bool _isOwnProfile() {
    return currentUsername == widget.targetUsername;
  }

  bool _isOwnPost(int postId, int index) {
    if (_userId == null || _userId == 0) return false;
    return posts[index]['user_id'] == _userId;
  }

  void _showProfileImage() {
    if (userInfo?['profile_picture'] == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _showProfileImage,
              child: CircleAvatar(
                radius: 80,
                backgroundImage: NetworkImage(
                  'https://server.awarcrown.com/accessprofile/uploads/${userInfo!['profile_picture']}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String? timeString) {
  if (timeString == null || timeString.isEmpty) return 'Unknown';

  try {
    DateTime date = DateTime.parse(timeString).toLocal();
    Duration diff = DateTime.now().difference(date);

    if (diff.inSeconds < 0) return '0s';
    if (diff.inSeconds < 60) return '${diff.inSeconds}secs ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}mins ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}months ago';

    return '${(diff.inDays / 365).floor()}y';
  } catch (e) {
    return timeString;
  }
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const SkeletonLoader();

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: Text(widget.targetUsername)),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadCurrentUser,
                child: const Text('Retry'),
              )
            ],
          ),
        ),
      );
    }

    if (userInfo == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: Text('User not found'))
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.targetUsername),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: _loadCurrentUser,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _showProfileImage,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundImage: userInfo!['profile_picture'] != null
                            ? NetworkImage(
                                'https://server.awarcrown.com/accessprofile/uploads/${userInfo!['profile_picture']}')
                            : null,
                        child: userInfo!['profile_picture'] == null
                            ? const Icon(Icons.person, size: 40)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(userInfo!['username'] ?? '',
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                          if (userInfo!['full_name'] != null)
                            Text(userInfo!['full_name'],
                                style: const TextStyle(color: Colors.grey)),
                          if (userInfo!['role'] == 'student')
                            Text(
                              '${userInfo!['major'] ?? 'Student'} at ${userInfo!['institution'] ?? 'Not specified'}',
                              style: const TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic),
                            )
                          else if (userInfo!['role'] == 'Company/HR')
                            Text(
                              '${userInfo!['contact_designation'] ?? 'HR'} at ${userInfo!['company_name'] ?? 'Not specified'}',
                              style: const TextStyle(fontSize: 14, color: Colors.grey, fontStyle: FontStyle.italic),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _StatButton(
                                  label: 'posts',
                                  count: posts.length,
                                  onTap: () {}),
                              _StatButton(
                                  label: 'followers',
                                  count: userInfo!['followers_count'] ?? 0,
                                  onTap: () {}),
                              _StatButton(
                                  label: 'following',
                                  count: userInfo!['following_count'] ?? 0,
                                  onTap: () {}),
                            ],
                          )
                        ],
                      ),
                    ),
                    if (currentUsername != widget.targetUsername)
                      GestureDetector(
                        onTap: _toggleFollow,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            isFollowing ? 'Following' : 'Follow',
                            style: TextStyle(
                                color:
                                    isFollowing ? Colors.black : Colors.blueAccent,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: const Divider()),
            if (postsError != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(postsError!, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _fetchUserPosts(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (posts.isEmpty)
              SliverFillRemaining(
                child: const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: Text('No posts yet')),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    if (index == posts.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: PostSkeleton(),
                      );
                    }
                    final post = posts[index];
                    final postId = post['post_id'];
                    final imageUrl = post['media_url'] != null && post['media_url'].isNotEmpty
                        ? 'https://server.awarcrown.com/feed/${post['media_url']}'
                        : null;
                    final isLiked = post['is_liked'] ?? false;
                    final isLiking = isLikingMap[postId] ?? false;
                    final isFetchingComment = isFetchingComments[postId] ?? false;
                    final iconAnimation = likeAnimationControllers[postId] ??
                        const AlwaysStoppedAnimation(1.0);
                    final overlayAnimation = heartOverlayControllers[postId] ??
                        const AlwaysStoppedAnimation(0.0);
                    final isFollowingUser = isFollowingMap[post['user_id']] ?? (post['is_following'] ?? false);
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
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PublicProfilePage(targetUsername: post['username'] ?? ''),
                                    ),
                                  ),
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
      Text(
        post['username'] ?? 'Unknown',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      Text(
        _formatTime(post['created_at']),
        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
      ),
    ],
  ),
),

                                if (!_isOwnPost(postId, index) && !isFollowingUser)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: ElevatedButton(
                                      onPressed: isProcessing
                                          ? null
                                          : () => _toggleFollowUser(post['user_id'], index),
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
                                        _deletePost(postId, index);
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
                                                        username: currentUsername,
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
                  childCount: posts.length + (isLoading && hasMore ? 1 : 0),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton shimmer loader widget like Instagram profile
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile header row
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 16,
                        width: 120,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                // Follow button placeholder
                Container(
                  width: 70,
                  height: 32,
                  color: Colors.white,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Stats row
            Row(
              children: [
                Expanded(child: _StatSkeleton()),
                const SizedBox(width: 24),
                Expanded(child: _StatSkeleton()),
                const SizedBox(width: 24),
                Expanded(child: _StatSkeleton()),
              ],
            ),
            const SizedBox(height: 20),
            // Divider
            Container(
              height: 1,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            // Posts list
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 3,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Container(
                  height: 300,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatSkeleton extends StatelessWidget {
  const _StatSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 16,
          width: 24,
          color: Colors.white,
        ),
        const SizedBox(height: 4),
        Container(
          height: 12,
          width: 32,
          color: Colors.white,
        ),
      ],
    );
  }
}

class _StatButton extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback? onTap;
  const _StatButton({
    required this.label,
    required this.count,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Text(count.toString(),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
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