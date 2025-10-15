import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:io' show SocketException;
import 'dart:async' show TimeoutException;

class PublicProfilePage extends StatefulWidget {
  final String targetUsername;
  const PublicProfilePage({super.key, required this.targetUsername});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  Map<String, dynamic>? userInfo;
  List<dynamic> posts = [];
  bool isLoading = true;
  bool isFollowing = false;
  String currentUsername = '';
  String? errorMessage;
  String? postsError;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  String _getErrorMessage(dynamic e) {
    if (e is SocketException) {
      return 'It seems you\'re not connected to the internet. Please check your connection.';
    } else if (e is TimeoutException) {
      return 'The connection is taking too long. Please try again in a moment.';
    } else if (e is http.ClientException) {
      return 'There was a problem connecting to the server. Please try again.';
    } else {
      return 'Something unexpected happened. Please try again.';
    }
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

      await _fetchUserInfo();
      await _fetchUserPosts();
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = _getErrorMessage(e);
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchUserInfo() async {
    try {
      final response = await http
          .get(Uri.parse(
              'https://server.awarcrown.com/accessprofile/user_info?target_username=${Uri.encodeComponent(widget.targetUsername)}&username=${Uri.encodeComponent(currentUsername)}'))
          .timeout(const Duration(seconds: 20));

      String? specificError;
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data is! Map<String, dynamic>) {
            throw const FormatException('Invalid JSON structure');
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
          return;
        } on FormatException {
          specificError = 'The server sent invalid data. Please try again.';
        } catch (e) {
          rethrow;
        }
      } else {
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
      }

      if (specificError != null && mounted) {
        setState(() {
          errorMessage = specificError;
        });
      }
      if (specificError != null) {
        throw Exception(specificError);
      }
    } on TimeoutException {
      throw TimeoutException('Request timed out', const Duration(seconds: 20));
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = _getErrorMessage(e);
        });
      }
      rethrow;
    }
  }

  Future<void> _fetchUserPosts() async {
    try {
      final response = await http
          .get(Uri.parse(
              'https://server.awarcrown.com/accessprofile/fetch_user_posts?target_username=${Uri.encodeComponent(widget.targetUsername)}&username=${Uri.encodeComponent(currentUsername)}'))
          .timeout(const Duration(seconds: 20));

      String? specificError;
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data is! Map<String, dynamic>) {
            throw const FormatException('Invalid JSON structure');
          }
          if (mounted) {
            setState(() {
              posts = List<dynamic>.from(data['posts'] ?? []);
              postsError = null;
            });
          }
          return;
        } on FormatException {
          specificError = 'The server sent invalid data. Please try again.';
        } catch (e) {
          specificError = _getErrorMessage(e);
        }
      } else {
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
      }

      if (specificError != null && mounted) {
        setState(() {
          postsError = specificError;
          posts = [];
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          postsError = _getErrorMessage(TimeoutException('Request timed out', const Duration(seconds: 20)));
          posts = [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          postsError = _getErrorMessage(e);
          posts = [];
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    try {
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/follow_action'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body:
            'target_username=${Uri.encodeComponent(widget.targetUsername)}&username=${Uri.encodeComponent(currentUsername)}',
      ).timeout(const Duration(seconds: 10));

      String? specificError;
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);
          if (data is! Map<String, dynamic>) {
            throw const FormatException('Invalid JSON structure');
          }
          if (data['success'] == true) {
            if (mounted) {
              setState(() {
                isFollowing = !isFollowing;
                userInfo!['followers_count'] =
                    (userInfo!['followers_count'] ?? 0) + (isFollowing ? 1 : -1);
              });
            }
            return;
          } else {
            specificError = 'Follow action failed: ${data['message'] ?? 'Please try again.'}';
          }
        } on FormatException {
          specificError = 'The server sent invalid data. Please try again.';
        } catch (e) {
          specificError = _getErrorMessage(e);
        }
      } else {
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
      }

      if (specificError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(specificError),
            backgroundColor: Colors.red,
          ),
        );
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(TimeoutException('Request timed out', const Duration(seconds: 10)))),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_getErrorMessage(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const SkeletonLoader();

    if (errorMessage != null) {
      return Scaffold(
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
      return const Scaffold(body: Center(child: Text('User not found')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.targetUsername),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: _loadCurrentUser,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: userInfo!['profile_picture'] != null
                        ? NetworkImage(
                            'https://server.awarcrown.com/accessprofile/uploads/${userInfo!['profile_picture']}')
                        : null,
                    child: userInfo!['profile_picture'] == null
                        ? const Icon(Icons.person, size: 40)
                        : null,
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
            const Divider(),
            if (postsError != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(postsError!, style: const TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _fetchUserPosts,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else if (posts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: Text('No posts yet')),
              )
            else
              GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final imageUrl = posts[index]['media_url'];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        'https://server.awarcrown.com/feed/$imageUrl',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    );
                  }),
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
            // Posts grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 9,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemBuilder: (_, __) => Container(
                color: Colors.white,
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