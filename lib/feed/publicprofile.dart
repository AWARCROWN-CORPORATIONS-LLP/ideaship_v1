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

class _PublicProfilePageState extends State<PublicProfilePage>
    with TickerProviderStateMixin {
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

  Future<T> _retryRequest<T>(
    Future<T> Function() request, {
    int maxRetries = 3,
  }) async {
    Exception? lastError;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await request();
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        if (attempt == maxRetries - 1) rethrow;
        final delay = Duration(
          milliseconds: (math.pow(2, attempt) * 1000).round(),
        );
        await Future.delayed(delay);
        debugPrint(
          'Retry attempt ${attempt + 1} after delay: ${delay.inMilliseconds}ms for error: $e',
        );
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
        final response = await http
            .get(
              Uri.parse(
                'https://server.awarcrown.com/feed/get_user?username=${Uri.encodeComponent(currentUsername)}',
              ),
            )
            .timeout(const Duration(seconds: 10));
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
            .get(
              Uri.parse(
                'https://server.awarcrown.com/accessprofile/user_info?target_username=${Uri.encodeComponent(widget.targetUsername)}&username=${Uri.encodeComponent(currentUsername)}',
              ),
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode != 200) {
          String specificError;
          switch (response.statusCode) {
            case 401:
              specificError = 'You need to log in to view this profile.';
              break;
            case 403:
              specificError =
                  'You don\'t have permission to view this profile.';
              break;
            case 404:
              specificError = 'This user doesn\'t exist.';
              break;
            case 500:
              specificError =
                  'The server is having issues. Please try again later.';
              break;
            default:
              specificError =
                  'There was a server issue (code ${response.statusCode}). Please try again.';
          }
          throw Exception(specificError);
        }

        final data = json.decode(response.body);
        if (data is! Map<String, dynamic>) {
          throw FormatException('Invalid JSON structure');
        }
        final processedData = Map<String, dynamic>.from(data);
        processedData['followers_count'] =
            int.tryParse(processedData['followers_count']?.toString() ?? '0') ??
            0;
        processedData['following_count'] =
            int.tryParse(processedData['following_count']?.toString() ?? '0') ??
            0;
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
        final params = {
          'target_username': widget.targetUsername,
          'username': currentUsername,
        };
        if (cursorId != null) params['cursorId'] = cursorId.toString();
        final queryString = params.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
            .join('&');
        final url =
            'https://server.awarcrown.com/accessprofile/fetch_user_posts?$queryString';
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
              specificError =
                  'The server is having issues. Please try again later.';
              break;
            default:
              specificError =
                  'There was a server issue (code ${response.statusCode}). Please try again.';
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
              final postsToAdd = newPosts
                  .where(
                    (newPost) => !posts.any(
                      (existing) => existing['post_id'] == newPost['post_id'],
                    ),
                  )
                  .toList();
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
        final response = await http
            .post(
              Uri.parse('https://server.awarcrown.com/feed/follow_action'),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body:
                  'target_username=${Uri.encodeComponent(widget.targetUsername)}&username=${Uri.encodeComponent(currentUsername)}',
            )
            .timeout(const Duration(seconds: 10));

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
              specificError =
                  'The server is having issues. Please try again later.';
              break;
            default:
              specificError =
                  'There was a server issue (code ${response.statusCode}). Please try again.';
          }
          throw Exception(specificError);
        }

        final data = json.decode(response.body);
        if (data is! Map<String, dynamic>) {
          throw FormatException('Invalid JSON structure');
        }
        if (data['success'] != true) {
          throw Exception(
            'Follow action failed: ${data['message'] ?? 'Please try again.'}',
          );
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
        final response = await http
            .get(
              Uri.parse(
                'https://server.awarcrown.com/feed/get_follower?follower_id=$_userId&followed_id=$followedId',
              ),
            )
            .timeout(const Duration(seconds: 5));
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
      final hasImage =
          posts[index]['media_url'] != null &&
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
        final response = await http
            .post(
              Uri.parse('https://server.awarcrown.com/feed/like_action'),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body: 'post_id=$postId&user_id=$_userId',
            )
            .timeout(const Duration(seconds: 10));
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
          _showError(
            'Failed to ${newLiked ? 'like' : 'unlike'} post: ${_getErrorMessage(e)}',
          );
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
        final url =
            'https://server.awarcrown.com/feed/fetch_comments?post_id=$postId&username=${Uri.encodeComponent(currentUsername)}';
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
        final response = await http
            .post(
              Uri.parse('https://server.awarcrown.com/feed/handle_followers'),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body:
                  'follower_id=$_userId&followed_id=$followedUserId&action=${newFollowing ? 'follow' : 'unfollow'}',
            )
            .timeout(const Duration(seconds: 10));
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
      _showError(
        'Failed to ${newFollowing ? 'follow' : 'unfollow'} user: ${_getErrorMessage(e)}',
      );
      debugPrint('Error in _toggleFollowUser: $e');
    } finally {
      if (mounted) {
        setState(() => isProcessingFollow[followedUserId] = false);
      }
    }
  }

  Future<void> _shareProfile() async {
    try {
      final profileUrl =
          'https://server.awarcrown.com/profile/${Uri.encodeComponent(widget.targetUsername)}';
      final shareText =
          'Check out ${widget.targetUsername}\'s profile on Ideaship - Awarcrown!\n$profileUrl';

      await Share.share(
        shareText,
        subject: '${widget.targetUsername}\'s Profile',
      );
    } catch (e) {
      debugPrint('Error sharing profile: $e');
      _showError('Failed to share profile');
    }
  }

  Future<void> _sharePost(int postId) async {
    if (currentUsername.isEmpty) return;
    try {
      await _retryRequest(() async {
        final response = await http
            .post(
              Uri.parse('https://server.awarcrown.com/feed/share_post'),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body:
                  'post_id=$postId&username=${Uri.encodeComponent(currentUsername)}',
            )
            .timeout(const Duration(seconds: 10));
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
        final response = await http
            .post(
              Uri.parse('https://server.awarcrown.com/feed/delete_post'),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body:
                  'post_id=$postId&username=${Uri.encodeComponent(currentUsername)}',
            )
            .timeout(const Duration(seconds: 10));
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
        final response = await http
            .post(
              Uri.parse('https://server.awarcrown.com/feed/save_post'),
              headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              body:
                  'post_id=$postId&username=${Uri.encodeComponent(currentUsername)}',
            )
            .timeout(const Duration(seconds: 10));
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

  Future<List<dynamic>> _fetchFollowersList() async {
    try {
      return await _retryRequest(() async {
        final response = await http
            .get(
              Uri.parse(
                'https://server.awarcrown.com/feed/get_followers?username=${Uri.encodeComponent(widget.targetUsername)}&current_username=${Uri.encodeComponent(currentUsername)}',
              ),
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw http.ClientException('Server returned ${response.statusCode}');
        }
        final data = json.decode(response.body);
        if (data is! Map<String, dynamic>) {
          throw FormatException('Invalid JSON structure');
        }
        // Check for error response
        if (data.containsKey('error')) {
          throw Exception(data['error'] ?? 'Failed to fetch followers');
        }
        final followers = data['followers'] ?? [];
        // Convert is_following from 0/1 to boolean and ensure user_id is int
        return followers.map((user) {
          final userMap = Map<String, dynamic>.from(user);
          // Ensure user_id is integer
          if (userMap['user_id'] != null) {
            userMap['user_id'] = int.tryParse(userMap['user_id'].toString()) ?? userMap['user_id'];
          }
          // Convert is_following from 0/1 to boolean
          if (userMap['is_following'] != null) {
            userMap['is_following'] = (userMap['is_following'] == 1 || userMap['is_following'] == true);
          }
          return userMap;
        }).toList();
      });
    } on Exception catch (e) {
      debugPrint('Error fetching followers: $e');
      _showError('Failed to load followers: ${_getErrorMessage(e)}');
      return [];
    }
  }

  Future<List<dynamic>> _fetchFollowingList() async {
    try {
      return await _retryRequest(() async {
        final response = await http
            .get(
              Uri.parse(
                'https://server.awarcrown.com/feed/get_following?username=${Uri.encodeComponent(widget.targetUsername)}&current_username=${Uri.encodeComponent(currentUsername)}',
              ),
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw http.ClientException('Server returned ${response.statusCode}');
        }
        final data = json.decode(response.body);
        if (data is! Map<String, dynamic>) {
          throw FormatException('Invalid JSON structure');
        }
        
        if (data.containsKey('error')) {
          throw Exception(data['error'] ?? 'Failed to fetch following');
        }
        final following = data['following'] ?? [];
        // Convert is_following from 0/1 to boolean
        return following.map((user) {
          final userMap = Map<String, dynamic>.from(user);
          if (userMap['is_following'] != null) {
            userMap['is_following'] = (userMap['is_following'] == 1 || userMap['is_following'] == true);
          }
          return userMap;
        }).toList();
      });
    } on Exception catch (e) {
      debugPrint('Error fetching following: $e');
      _showError('Failed to load following: ${_getErrorMessage(e)}');
      return [];
    }
  }

  void _showFollowersList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (context) => _FollowersFollowingSheet(
        title: 'Followers',
        fetchList: _fetchFollowersList,
        currentUsername: currentUsername,
        userId: _userId,
        targetUsername: widget.targetUsername,
      ),
    );
  }

  void _showFollowingList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (context) => _FollowersFollowingSheet(
        title: 'Following',
        fetchList: _fetchFollowingList,
        currentUsername: currentUsername,
        userId: _userId,
        targetUsername: widget.targetUsername,
      ),
    );
  }

  void _showProfileImage() {
    if (userInfo?['profile_picture'] == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.95),
      barrierDismissible: true,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: Hero(
              tag: 'profile_image_${userInfo!['profile_picture']}',
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: CachedNetworkImage(
                  imageUrl:
                      'https://server.awarcrown.com/accessprofile/uploads/${userInfo!['profile_picture']}',
                  fit: BoxFit.contain,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),
        );
      },
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
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(widget.targetUsername),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
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
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Oops! Something went wrong',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _loadCurrentUser,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (userInfo == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(widget.targetUsername),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'User not found',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          widget.targetUsername,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 22),
            onPressed: _shareProfile,
            tooltip: 'Share profile',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadCurrentUser,
        color: colorScheme.primary,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Profile Header
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: _showProfileImage,
                          child: Hero(
                            tag:
                                'profile_image_${userInfo!['profile_picture']}',
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 43,
                                backgroundImage:
                                    userInfo!['profile_picture'] != null
                                    ? NetworkImage(
                                        'https://server.awarcrown.com/accessprofile/uploads/${userInfo!['profile_picture']}',
                                      )
                                    : null,
                                backgroundColor: Colors.grey.shade100,
                                child: userInfo!['profile_picture'] == null
                                    ? Icon(
                                        Icons.person,
                                        size: 45,
                                        color: Colors.grey.shade400,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userInfo!['username'] ?? '',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A1A1A),
                                  letterSpacing: -0.5,
                                ),
                              ),

                              const SizedBox(height: 8),
                              if (userInfo!['role'] == 'student')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${userInfo!['major'] ?? 'Student'} at ${userInfo!['institution'] ?? 'Not specified'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                )
                              else if (userInfo!['role'] == 'Company/HR')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${userInfo!['contact_designation'] ?? 'HR'} at ${userInfo!['company_name'] ?? 'Not specified'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.purple.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              // Bio Section
                              if (userInfo!['bio'] != null &&
                                  userInfo!['bio'].toString().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  userInfo!['bio'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                    height: 1.5,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                              
                              if (userInfo!['website'] != null &&
                                  userInfo!['website']
                                      .toString()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: () {
                                    final url = userInfo!['website'].toString();
                                    final uri = url.startsWith('http')
                                        ? url
                                        : 'https://$url';
                                    // You can add url_launcher package to open links
                                    _showSuccess('Website: $uri');
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.link,
                                        size: 14,
                                        color: Colors.blue.shade600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        userInfo!['website'],
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blue.shade600,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (currentUsername != widget.targetUsername)
                          const SizedBox(width: 12),
                        if (currentUsername != widget.targetUsername)
                          _FollowButton(
                            isFollowing: isFollowing,
                            onTap: _toggleFollow,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _StatButton(
                            label: 'Posts',
                            count: posts.length,
                            onTap: () {},
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey.shade200,
                        ),
                        Expanded(
                          child: _StatButton(
                            label: 'Followers',
                            count: userInfo!['followers_count'] ?? 0,
                            onTap: () => _showFollowersList(),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey.shade200,
                        ),
                        Expanded(
                          child: _StatButton(
                            label: 'Following',
                            count: userInfo!['following_count'] ?? 0,
                            onTap: () => _showFollowingList(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Posts Section
            if (postsError != null)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        postsError!,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _fetchUserPosts(),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (posts.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Container(
                  color: const Color(0xFFF8F9FA),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.grid_off,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No posts yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'When ${widget.targetUsername} shares posts, they\'ll appear here',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == posts.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: PostSkeleton(),
                        );
                      }
                      return _buildPostCard(context, index, colorScheme);
                    },
                    childCount: posts.length + (hasMore ? 1 : 0),
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    addSemanticIndexes: false,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(
    BuildContext context,
    int index,
    ColorScheme colorScheme,
  ) {
    final post = posts[index];
    final postId = post['post_id'];
    final imageUrl = post['media_url'] != null && post['media_url'].isNotEmpty
        ? 'https://server.awarcrown.com/feed/${post['media_url']}'
        : null;
    final isLiked = post['is_liked'] ?? false;
    final isLiking = isLikingMap[postId] ?? false;
    final isFetchingComment = isFetchingComments[postId] ?? false;
    final iconAnimation =
        likeAnimationControllers[postId] ?? const AlwaysStoppedAnimation(1.0);
    final overlayAnimation =
        heartOverlayControllers[postId] ?? const AlwaysStoppedAnimation(0.0);
    final isFollowingUser =
        isFollowingMap[post['user_id']] ?? (post['is_following'] ?? false);
    final isProcessing = isProcessingFollow[post['user_id']] ?? false;
    const double aspectRatio = 1.0;
    final screenWidth = MediaQuery.of(context).size.width - 40;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          // Post Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PublicProfilePage(
                        targetUsername: post['username'] ?? '',
                      ),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 22,
                      backgroundImage: post['profile_picture'] != null
                          ? NetworkImage(
                              'https://server.awarcrown.com/accessprofile/uploads/${post['profile_picture']}',
                            )
                          : null,
                      backgroundColor: Colors.grey.shade100,
                      child: post['profile_picture'] == null
                          ? Icon(
                              Icons.person,
                              size: 22,
                              color: Colors.grey.shade400,
                            )
                          : null,
                    ),
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
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTime(post['created_at']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_isOwnPost(postId, index) && !isFollowingUser)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _SmallFollowButton(
                      isProcessing: isProcessing,
                      onTap: () => _toggleFollowUser(post['user_id'], index),
                    ),
                  ),
                if (_isOwnPost(postId, index))
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deletePost(postId, index);
                      }
                    },
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: Colors.grey.shade600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: Colors.red.shade400,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Post Content
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: () => _toggleLike(postId, index),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post['content'] != null && post['content'].isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      post['content'],
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w400,
                      ),
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
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              memCacheWidth:
                                  (screenWidth *
                                          MediaQuery.of(
                                            context,
                                          ).devicePixelRatio)
                                      .round(),
                              memCacheHeight:
                                  (screenWidth *
                                          aspectRatio *
                                          MediaQuery.of(
                                            context,
                                          ).devicePixelRatio)
                                      .round(),
                              maxWidthDiskCache:
                                  (screenWidth *
                                          MediaQuery.of(
                                            context,
                                          ).devicePixelRatio)
                                      .round(),
                              maxHeightDiskCache:
                                  (screenWidth *
                                          aspectRatio *
                                          MediaQuery.of(
                                            context,
                                          ).devicePixelRatio)
                                      .round(),
                              fadeInDuration: const Duration(milliseconds: 300),
                              fadeOutDuration: const Duration(
                                milliseconds: 200,
                              ),
                              placeholder: (context, url) => Container(
                                color: Colors.grey.shade100,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  Icons.image_not_supported,
                                  color: Colors.grey.shade400,
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
                              final scale =
                                  Curves.easeOut.transform(
                                    overlayAnimation.value,
                                  ) *
                                  1.5;
                              final opacity =
                                  1.0 - (overlayAnimation.value * 0.8);
                              return Transform.scale(
                                scale:
                                    scale *
                                    (showHeartOverlay[postId] == true
                                        ? 1.0
                                        : 0.0),
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
          // Post Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Row(
              children: [
                _ActionButton(
                  icon: isLiked ? Icons.favorite : Icons.favorite_border,
                  count: post['like_count'] ?? 0,
                  isActive: isLiked,
                  isLoading: isLiking,
                  animation: iconAnimation,
                  onTap: () => _toggleLike(postId, index),
                  activeColor: Colors.red,
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.mode_comment_outlined,
                  count: post['comment_count'] ?? 0,
                  isActive: false,
                  isLoading: isFetchingComment,
                  onTap: () async {
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
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  icon: Icons.share_outlined,
                  count: null,
                  isActive: false,
                  onTap: () => _sharePost(postId),
                ),
                const Spacer(),
                _ActionButton(
                  icon: Icons.bookmark_border,
                  count: null,
                  isActive: false,
                  onTap: () => _savePost(postId),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowersFollowingSheet extends StatefulWidget {
  final String title;
  final Future<List<dynamic>> Function() fetchList;
  final String currentUsername;
  final int? userId;
  final String targetUsername;

  const _FollowersFollowingSheet({
    required this.title,
    required this.fetchList,
    required this.currentUsername,
    required this.userId,
    required this.targetUsername,
  });

  @override
  State<_FollowersFollowingSheet> createState() =>
      _FollowersFollowingSheetState();
}

class _FollowersFollowingSheetState extends State<_FollowersFollowingSheet> {
  List<dynamic> _list = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final Map<int, bool> _isFollowingMap = {};
  final Map<int, bool> _isProcessingMap = {};

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadList() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await widget.fetchList();
      if (mounted) {
        setState(() {
          _list = list;
          _isLoading = false;
          // Initialize follow statuses
          for (var user in list) {
            final userId = user['user_id'];
            if (userId != null) {
              // Handle both boolean and 0/1 integer from backend
              final isFollowing = user['is_following'];
              if (isFollowing != null) {
                _isFollowingMap[userId] = isFollowing == true || isFollowing == 1;
              } else {
                _isFollowingMap[userId] = false;
              }
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow(int userId, String username) async {
    if (_isProcessingMap[userId] ?? false) return;
    setState(() => _isProcessingMap[userId] = true);

    final oldFollowing = _isFollowingMap[userId] ?? false;
    final newFollowing = !oldFollowing;

    setState(() {
      _isFollowingMap[userId] = newFollowing;
      for (var user in _list) {
        if (user['user_id'] == userId) {
          user['is_following'] = newFollowing;
        }
      }
    });

    try {
      final response = await http
          .post(
            Uri.parse('https://server.awarcrown.com/feed/handle_followers'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body:
                'follower_id=${widget.userId}&followed_id=$userId&action=${newFollowing ? 'follow' : 'unfollow'}',
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      if (data is! Map<String, dynamic>) {
        throw Exception('Invalid response format');
      }
      if (data['status'] == 'error') {
        throw Exception(data['message'] ?? 'Failed to process follow action');
      }
      if (data['status'] != 'success') {
        throw Exception('Failed to process follow action');
      }
    } catch (e) {
      // Revert on error
      setState(() {
        _isFollowingMap[userId] = oldFollowing;
        for (var user in _list) {
          if (user['user_id'] == userId) {
            user['is_following'] = oldFollowing;
          }
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${newFollowing ? 'follow' : 'unfollow'} user',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingMap[userId] = false);
      }
    }
  }

  List<dynamic> get _filteredList {
    if (_searchQuery.isEmpty) return _list;
    final query = _searchQuery.toLowerCase();
    return _list.where((user) {
      final username = (user['username'] ?? '').toString().toLowerCase();
      return username.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final colorScheme = Theme.of(context).colorScheme;
    final height = MediaQuery.of(context).size.height * 0.85;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      iconSize: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search bar - disabled while loading
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    enabled: !_isLoading,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: _isLoading 
                          ? 'Loading...' 
                          : 'Search ${widget.title.toLowerCase()}...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.grey.shade500,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // List
          Expanded(
            child: _isLoading
                ? _LoadingListSkeleton(title: widget.title)
                : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Failed to load ${widget.title.toLowerCase()}',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadList,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _searchQuery.isEmpty
                              ? Icons.people_outline
                              : Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty
                              ? 'No ${widget.title.toLowerCase()} yet'
                              : 'No results found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _filteredList.length,
                    itemBuilder: (context, index) {
                      final user = _filteredList[index];
                      final userId = user['user_id'];
                      final username = user['username'] ?? 'Unknown';
                      final profilePic = user['profile_picture'];
                      // Handle is_following - convert 0/1 to boolean if needed
                      final isFollowingValue = user['is_following'];
                      final isFollowing = _isFollowingMap[userId] ??
                          (isFollowingValue == true || isFollowingValue == 1);
                      final isProcessing = _isProcessingMap[userId] ?? false;
                      final isOwnProfile = username == widget.currentUsername;

                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PublicProfilePage(targetUsername: username),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 16),
                              // Profile Picture
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 38,
                                  backgroundImage: profilePic != null
                                      ? NetworkImage(
                                          'https://server.awarcrown.com/accessprofile/uploads/$profilePic',
                                        )
                                      : null,
                                  backgroundColor: Colors.grey.shade100,
                                  child: profilePic == null
                                      ? Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Colors.grey.shade400,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Username
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  username,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              
                             
                              const SizedBox(height: 12),
                              
                              if (!isOwnProfile)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: GestureDetector(
                                    onTap: () => _toggleFollow(userId, username),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isFollowing
                                            ? Colors.grey.shade100
                                            : const Color(0xFF007AFF),
                                        borderRadius: BorderRadius.circular(8),
                                        border: isFollowing
                                            ? Border.all(
                                                color: Colors.grey.shade300,
                                              )
                                            : null,
                                      ),
                                      child: isProcessing
                                          ? const SizedBox(
                                              height: 16,
                                              child: Center(
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Text(
                                              isFollowing ? 'Following' : 'Follow',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isFollowing
                                                    ? Colors.grey.shade800
                                                    : Colors.white,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(height: 8),
                              const Spacer(),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _LoadingListSkeleton extends StatelessWidget {
  final String title;
  const _LoadingListSkeleton({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Loading indicator at top with animation
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading ${title.toLowerCase()}...',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Skeleton grid items with shimmer
        Expanded(
          child: Shimmer.fromColors(
            baseColor: Colors.grey.shade200,
            highlightColor: Colors.grey.shade50,
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: 10,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      // Avatar skeleton
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Username skeleton
                      Container(
                        height: 14,
                        width: 80,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Button skeleton
                      Container(
                        height: 32,
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Container(
          height: 20,
          width: 120,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
      body: Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade50,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Profile header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 22,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 16,
                        width: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 20,
                        width: 180,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 80,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Stats row
            Row(
              children: [
                Expanded(child: _StatSkeleton()),
                Container(width: 1, height: 40, color: Colors.grey.shade200),
                Expanded(child: _StatSkeleton()),
                Container(width: 1, height: 40, color: Colors.grey.shade200),
                Expanded(child: _StatSkeleton()),
              ],
            ),
            const SizedBox(height: 24),
            // Posts list
            ...List.generate(3, (index) => const PostSkeleton()),
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
        Container(height: 16, width: 24, color: Colors.white),
        const SizedBox(height: 4),
        Container(height: 12, width: 32, color: Colors.white),
      ],
    );
  }
}

class _StatButton extends StatelessWidget {
  final String label;
  final int count;
  final VoidCallback? onTap;
  const _StatButton({required this.label, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatCount(count),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class _FollowButton extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onTap;
  const _FollowButton({required this.isFollowing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isFollowing ? Colors.grey.shade100 : const Color(0xFF007AFF),
          borderRadius: BorderRadius.circular(12),
          border: isFollowing ? Border.all(color: Colors.grey.shade300) : null,
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: TextStyle(
            color: isFollowing ? Colors.grey.shade800 : Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _SmallFollowButton extends StatelessWidget {
  final bool isProcessing;
  final VoidCallback onTap;
  const _SmallFollowButton({required this.isProcessing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isProcessing ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF007AFF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: isProcessing
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Follow',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final int? count;
  final bool isActive;
  final bool isLoading;
  final Color? activeColor;
  final Animation<double>? animation;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.count,
    this.isActive = false,
    this.isLoading = false,
    this.activeColor,
    this.animation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = isActive
        ? (activeColor ?? colorScheme.primary)
        : Colors.grey.shade700;
    final textColor = isActive
        ? (activeColor ?? colorScheme.primary)
        : Colors.grey.shade700;

    Widget iconWidget = Icon(icon, size: 24, color: iconColor);

    if (animation != null && isActive) {
      iconWidget = AnimatedBuilder(
        animation: animation!,
        builder: (context, child) {
          final scale = 1.0 + (0.3 * animation!.value);
          return Transform.scale(
            scale: scale,
            child: Icon(icon, size: 24, color: iconColor),
          );
        },
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                ),
              )
            else
              iconWidget,
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                _formatCount(count!),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}

class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width - 40;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              children: [
                const Skeleton(height: 44, width: 44, type: 'circle'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Skeleton(height: 15, width: 120),
                      SizedBox(height: 4),
                      Skeleton(height: 12, width: 80),
                    ],
                  ),
                ),
                const Skeleton(height: 28, width: 70),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: const [
                Skeleton(height: 16, width: double.infinity),
                SizedBox(height: 8),
                Skeleton(height: 16, width: double.infinity * 0.8),
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
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Row(
              children: const [
                Skeleton(height: 24, width: 60),
                SizedBox(width: 8),
                Skeleton(height: 24, width: 60),
                Spacer(),
                Skeleton(height: 24, width: 24),
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
  const Skeleton({
    super.key,
    this.height = 20,
    this.width = 20,
    this.type = 'square',
  });
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> gradientPosition;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    gradientPosition =
        Tween<double>(begin: -3, end: 10).animate(
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
              : const [Colors.grey, Colors.grey, Colors.grey],
        ),
      ),
    );
  }
}
