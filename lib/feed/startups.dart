import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import '../auth/auth_utils.dart';
enum SortOption { none, mostLiked, mostFollowed, newest }

class StartupsPage extends StatefulWidget {
  const StartupsPage({super.key});

  @override
  _StartupsPageState createState() => _StartupsPageState();
}

class _StartupsPageState extends State<StartupsPage>
    with TickerProviderStateMixin {
  List<dynamic> startups = [];
  List<dynamic> filteredStartups = [];
  bool isLoading = false;
  bool hasError = false;
  bool isOffline = false;
  String errorMessage = '';
  final TextEditingController _searchController = TextEditingController();
  String? userId;
  String? selectedIndustry;
  bool showFavoritesOnly = false;
  List<String> favoritedStartups = [];
  final Map<String, bool> industryFilters = {};
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  SortOption _sortOption = SortOption.none;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _loadUserId();
    _loadFavorites();
    _searchController.addListener(_filterStartups);
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    if (username == null || username.isEmpty) {
      setState(() {
        hasError = true;
        errorMessage = 'Username not found. Please log in again.';
        isLoading = false;
      });
      return;
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://server.awarcrown.com/feed/get_user?username=${Uri.encodeComponent(username)}',
            ),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['error'] == null && data['user_id'] != null) {
          final fetchedUserId = data['user_id'].toString();
          await prefs.setString('user_id', fetchedUserId);
          setState(() {
            userId = fetchedUserId;
          });
          await fetchStartups();
          _animationController.forward();
        } else {
          setState(() {
            hasError = true;
            errorMessage = data['error'] ?? 'Failed to fetch user ID';
            isLoading = false;
          });
        }
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = 'Error fetching user ID: $e';
        isLoading = false;
      });
      await _loadCachedStartups();
    }
  }

  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      favoritedStartups = prefs.getStringList('favorited_startups') ?? [];
    });
  }

  Future<void> _loadCachedStartups() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('cached_startups');
    if (cachedData != null) {
      setState(() {
        isOffline = true;
        startups = json.decode(cachedData).map((startup) {
          if (startup['profile_picture'] != null &&
              startup['profile_picture'].isNotEmpty) {
            startup['full_logo_url'] =
                'https://server.awarcrown.com/accessprofile/uploads/${startup['profile_picture']}';
          } else {
            startup['full_logo_url'] = null;
          }
          startup['startup_id'] = startup['startup_id'].toString();
          startup['is_favorited'] = favoritedStartups.contains(
            startup['startup_id'],
          );
          return startup;
        }).toList();
        filteredStartups = List.from(startups);
        final Set<String> industries = startups
            .map((s) => s['industry'] as String?)
            .where((i) => i != null && i.isNotEmpty)
            .cast<String>()
            .toSet();
        for (String industry in industries) {
          industryFilters[industry] = true;
        }
        isLoading = false;
      });
      _showError('Offline mode: Showing cached data');
      _filterStartups();
    }
  }

  Future<void> fetchStartups() async {
    if (userId == null || userId!.isEmpty) {
      setState(() {
        hasError = true;
        errorMessage = 'User not authenticated.';
        isLoading = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
      hasError = false;
      isOffline = false;
    });

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://server.awarcrown.com/feed/stups/fetch_startups?user_id=${Uri.encodeComponent(userId!)}',
            ),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final List<dynamic> fetchedStartups = data['startups'] ?? [];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'cached_startups',
            json.encode(fetchedStartups),
          );
          setState(() {
            startups = fetchedStartups.map((startup) {
              if (startup['profile_picture'] != null &&
                  startup['profile_picture'].isNotEmpty) {
                startup['full_logo_url'] =
                    'https://server.awarcrown.com/accessprofile/uploads/${startup['profile_picture']}';
              } else {
                startup['full_logo_url'] = null;
              }
              startup['startup_id'] = startup['startup_id'].toString();
              startup['is_favorited'] = favoritedStartups.contains(
                startup['startup_id'],
              );
              return startup;
            }).toList();
            filteredStartups = List.from(startups);
            final Set<String> industries = startups
                .map((s) => s['industry'] as String?)
                .where((i) => i != null && i.isNotEmpty)
                .cast<String>()
                .toSet();
            for (String industry in industries) {
              industryFilters[industry] = true;
            }
            isLoading = false;
          });
          _filterStartups();
        } else {
          throw Exception(data['message'] ?? 'Failed to load startups');
        }
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = 'Error fetching startups: $e';
        isLoading = false;
      });
      await _loadCachedStartups();
    }
  }

  void _filterStartups() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      filteredStartups = startups.where((startup) {
        final name = startup['startup_name']?.toLowerCase() ?? '';
        final industry = startup['industry']?.toLowerCase() ?? '';
        final description = startup['description']?.toLowerCase() ?? '';
        bool matchesSearch =
            name.contains(query) ||
            industry.contains(query) ||
            description.contains(query);
        bool matchesIndustry =
            selectedIndustry == null || startup['industry'] == selectedIndustry;
        bool matchesFilter = industryFilters.entries.every(
          (entry) => entry.value || startup['industry'] != entry.key,
        );
        bool matchesFavorites =
            !showFavoritesOnly ||
            favoritedStartups.contains(startup['startup_id']);
        return matchesSearch &&
            matchesIndustry &&
            matchesFilter &&
            matchesFavorites;
      }).toList();

      switch (_sortOption) {
        case SortOption.mostLiked:
          filteredStartups.sort(
            (a, b) => (b['likes_count'] ?? 0).compareTo(a['likes_count'] ?? 0),
          );
          break;
        case SortOption.mostFollowed:
          filteredStartups.sort(
            (a, b) => (b['followers_count'] ?? 0).compareTo(
              a['followers_count'] ?? 0,
            ),
          );

          break;
        case SortOption.newest:
          filteredStartups.sort(
            (a, b) => DateTime.parse(
              b['created_at'] ?? '1970-01-01',
            ).compareTo(DateTime.parse(a['created_at'] ?? '1970-01-01')),
          );
          break;
        case SortOption.none:
          break;
      }
    });
  }

  void _updateIndustryFilter(String? industry, bool? value) {
    if (industry == null) {
      setState(() {
        selectedIndustry = null;
      });
    } else {
      setState(() {
        industryFilters[industry] = value ?? !industryFilters[industry]!;
        if (!industryFilters[industry]!) {
          selectedIndustry = null;
        } else {
          selectedIndustry ??= industry;
        }
      });
    }
    _filterStartups();
  }

  Future<void> _toggleFavorite(String startupId, bool isFavorited) async {
    final prefs = await SharedPreferences.getInstance();
    final bool oldIsFavorited = isFavorited;
    setState(() {
      if (oldIsFavorited) {
        favoritedStartups.remove(startupId);
      } else {
        favoritedStartups.add(startupId);
      }
      startups = startups.map((startup) {
        if (startup['startup_id'] == startupId) {
          startup['is_favorited'] = !oldIsFavorited;
        }
        return startup;
      }).toList();
    });
    await prefs.setStringList('favorited_startups', favoritedStartups);
    _filterStartups();

    if (isOffline) {
      _showSuccess(
        'Favorite ${oldIsFavorited ? 'removed' : 'added'} offline. Will sync when online.',
      );
      return;
    }

    try {
      final action = oldIsFavorited ? 'unfavorite' : 'favorite';
      final body =
          'user_id=${Uri.encodeComponent(userId!)}&startup_id=${Uri.encodeComponent(startupId)}&action=$action';
      final response = await http
          .post(
            Uri.parse(
              'https://server.awarcrown.com/feed/stups/favorite_startup',
            ),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!data['success']) {
          throw Exception(
            data['message'] ?? 'Failed to update favorite status',
          );
        }
        _showSuccess(oldIsFavorited ? 'Unfavorited' : 'Favorited');
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        if (oldIsFavorited) {
          favoritedStartups.add(startupId);
        } else {
          favoritedStartups.remove(startupId);
        }
        startups = startups.map((startup) {
          if (startup['startup_id'] == startupId) {
            startup['is_favorited'] = oldIsFavorited;
          }
          return startup;
        }).toList();
      });
      await prefs.setStringList('favorited_startups', favoritedStartups);
      _filterStartups();
      _showError('Failed to ${oldIsFavorited ? 'unfavorite' : 'favorite'}: $e');
    }
  }

  Future<void> _toggleFollow(String startupId, bool isFollowing) async {
    if (userId == null || userId!.isEmpty) {
      _showError('User not authenticated.');
      return;
    }

    final bool oldFollowing = isFollowing;
    setState(() {
      startups = startups.map((startup) {
        if (startup['startup_id'] == startupId) {
          startup['is_following'] = !oldFollowing;
          startup['followers_count'] =
              (startup['followers_count'] ?? 0) + (oldFollowing ? -1 : 1);
        }
        return startup;
      }).toList();
    });
    _filterStartups();

    if (isOffline) {
      _showSuccess('Follow action queued offline. Will sync when online.');

      return;
    }

    try {
      final action = oldFollowing ? 'unfollow' : 'follow';
      final body =
          'user_id=${Uri.encodeComponent(userId!)}&startup_id=${Uri.encodeComponent(startupId)}&action=$action';
      final response = await http
          .post(
            Uri.parse('https://server.awarcrown.com/feed/stups/follow_startup'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!data['success']) {
          throw Exception(data['message'] ?? 'Failed to update follow status');
        }
        _showSuccess(oldFollowing ? 'Unfollowed' : 'Followed');
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        startups = startups.map((startup) {
          if (startup['startup_id'] == startupId) {
            startup['is_following'] = oldFollowing;
            startup['followers_count'] =
                (startup['followers_count'] ?? 0) + (oldFollowing ? 1 : -1);
          }
          return startup;
        }).toList();
      });
      _filterStartups();
      _showError('Failed to ${oldFollowing ? 'unfollow' : 'follow'}: $e');
    }
  }

  Future<void> _toggleLike(String startupId, bool isLiked) async {
    if (userId == null || userId!.isEmpty) {
      _showError('User not authenticated.');
      return;
    }

    final bool oldLiked = isLiked;
    setState(() {
      startups = startups.map((startup) {
        if (startup['startup_id'] == startupId) {
          startup['is_liked'] = !oldLiked;
          startup['likes_count'] =
              (startup['likes_count'] ?? 0) + (oldLiked ? -1 : 1);
        }
        return startup;
      }).toList();
    });
    _filterStartups();

    if (isOffline) {
      _showSuccess('Like action queued offline. Will sync when online.');
      return;
    }

    try {
      final action = oldLiked ? 'unlike' : 'like';
      final body =
          'user_id=${Uri.encodeComponent(userId!)}&startup_id=${Uri.encodeComponent(startupId)}&action=$action';
      final response = await http
          .post(
            Uri.parse('https://server.awarcrown.com/feed/stups/like_startup'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!data['success']) {
          throw Exception(data['message'] ?? 'Failed to update like status');
        }
        _showSuccess(oldLiked ? 'Unliked' : 'Liked');
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        startups = startups.map((startup) {
          if (startup['startup_id'] == startupId) {
            startup['is_liked'] = oldLiked;
            startup['likes_count'] =
                (startup['likes_count'] ?? 0) + (oldLiked ? 1 : -1);
          }
          return startup;
        }).toList();
      });
      _filterStartups();
      _showError('Failed to ${oldLiked ? 'unlike' : 'like'}: $e');
    }
  }

  Future<String?> _getShareLink(String startupId) async {
    if (userId == null || userId!.isEmpty || isOffline) return null;

    try {
      final response = await http
          .post(
            Uri.parse('https://server.awarcrown.com/feed/stups/share_startup'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body:
                'startup_id=${Uri.encodeComponent(startupId)}&user_id=${Uri.encodeComponent(userId!)}',
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw http.ClientException("Server error ${response.statusCode}");
      }

      final data = json.decode(response.body);

      if (data['status'] == 'success' && data['share_url'] != null) {
        return data['share_url'];
      }

      _showError(data['message'] ?? "Failed to generate share link");
    } catch (e) {
      _showError("Failed to generate share link: ${_getErrorMessage(e)}");
    }

    return null;
  }

  String _getErrorMessage(dynamic e) {
    if (e is SocketException) return 'No internet connection.';
    if (e is TimeoutException) return 'Request timed out.';
    if (e is http.ClientException) return 'Network error.';
    return e.toString();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
    );
  }

  void _showShareSheet(dynamic startup) async {
    final startupId = startup['startup_id'];
    final shareUrl = await _getShareLink(startupId);

    if (shareUrl == null || shareUrl.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share this startup',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              SelectableText(
                shareUrl,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),

              const SizedBox(height: 20),

              // Copy Button (Full width)
              SizedBox(
                width: double.infinity,
                child: _AnimatedButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: shareUrl));
                    _showSuccess('Link copied!');
                    Navigator.pop(context);
                  },
                  icon: Icons.copy,
                  label: 'Copy Link',
                  color: colorScheme.primary,
                  textColor: Colors.white,
                ),
              ),

              const SizedBox(height: 12),

              // Share Externally Button (Full width)
              SizedBox(
                width: double.infinity,
                child: _AnimatedButton(
                  onPressed: () {
                    Share.share(
                      shareUrl,
                      subject: 'Check out this startup on Awarcrown',
                    );
                    Navigator.pop(context);
                  },
                  icon: Icons.share,
                  label: 'Share externally',
                  color: Colors.purple,
                  textColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _refreshStartups() async {
    await fetchStartups();
    if (!hasError && !isOffline) {
      _showSuccess('Startups refreshed successfully!');
    }
  }

  Widget _buildIndustryFilter() {
    final industries = industryFilters.keys.toList();
    if (industries.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: industries.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('All'),
                selected: selectedIndustry == null,
                onSelected: (_) => _updateIndustryFilter(null, null),
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                checkmarkColor: Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer,
              ),
            );
          } else if (index == 1) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('Favorites'),
                selected: showFavoritesOnly,
                onSelected: (selected) {
                  setState(() {
                    showFavoritesOnly = selected;
                  });
                  _filterStartups();
                },
                selectedColor: Theme.of(context).colorScheme.primaryContainer,
                checkmarkColor: Theme.of(
                  context,
                ).colorScheme.onPrimaryContainer,
              ),
            );
          }
          final industry = industries[index - 2];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(industry),
              selected: selectedIndustry == industry,
              onSelected: (selected) =>
                  _updateIndustryFilter(industry, selected),
              selectedColor: Theme.of(context).colorScheme.primaryContainer,
              checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          );
        },
      ),
    );
  }

  Widget _buildStartupCard(dynamic startup) {
    final colorScheme = Theme.of(context).colorScheme;
    final fullLogoUrl = startup['full_logo_url'];
    final isLiked = startup['is_liked'] ?? false;
    final isFollowing = startup['is_following'] ?? false;
    final isFavorited =
        startup['is_favorited'] ??
        favoritedStartups.contains(startup['startup_id']);
    final likeCount = startup['likes_count']?.toString() ?? '0';
    final followCount = startup['followers_count']?.toString() ?? '0';

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        elevation: 6,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.surface, colorScheme.surfaceContainerLow],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StartupDetailsPage(startup: startup),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'startup_logo_${startup['startup_id']}',
                    child: fullLogoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: CachedNetworkImage(
                              imageUrl: fullLogoUrl,
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Shimmer.fromColors(
                                baseColor: Colors.grey[300]!,
                                highlightColor: Colors.grey[100]!,
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  color: Colors.white,
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.business, size: 64),
                            ),
                          )
                        : const CircleAvatar(
                            radius: 32,
                            child: Icon(Icons.business, size: 32),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                startup['startup_name'] ?? 'Unnamed Startup',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                              ),
                            ),
                            _AnimatedButton(
                              icon: isFavorited
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: isFavorited ? Colors.blue : null,
                              onPressed: () => _toggleFavorite(
                                startup['startup_id'],
                                isFavorited,
                              ),
                              size: 24,
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'share') {
                                  _showShareSheet(startup);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'share',
                                  child: ListTile(
                                    leading: Icon(Icons.share),
                                    title: Text('Share'),
                                  ),
                                ),
                              ],
                              icon: const Icon(Icons.more_vert),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (startup['industry'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              startup['industry'],
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          startup['description'] ?? 'No description available',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _AnimatedButton(
                              icon: isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: isLiked
                                  ? const Color.fromARGB(255, 234, 234, 234)
                                  : null,
                              onPressed: () =>
                                  _toggleLike(startup['startup_id'], isLiked),
                              label: '$likeCount likes',
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '$followCount followers',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _AnimatedButton(
                                onPressed: () => _toggleFollow(
                                  startup['startup_id'],
                                  isFollowing,
                                ),
                                label: isFollowing ? 'Unfollow' : 'Follow',
                                color: isFollowing
                                    ? const Color.fromARGB(255, 45, 23, 169)
                                    : colorScheme.primary,
                                textColor: Colors.white,
                                icon: Icons.person,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildBody() {
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final paddingHeight = screenHeight * 0.3;

    if (isLoading) {
      return ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          SizedBox(height: paddingHeight),
          Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Column(
              children: List.generate(
                3,
                (index) => Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 8,
                  ),
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: paddingHeight),
        ],
      );
    } else if (hasError && startups.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          SizedBox(height: paddingHeight),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: TextStyle(color: colorScheme.error, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                _AnimatedButton(
                  onPressed: _loadUserId,
                  icon: Icons.refresh,
                  label: 'Retry',
                ),
              ],
            ),
          ),
          SizedBox(height: paddingHeight),
        ],
      );
    } else if (filteredStartups.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(8.0),
        children: [
          SizedBox(height: paddingHeight),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchController.text.isEmpty
                      ? 'No startups found'
                      : 'No matching startups',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
          SizedBox(height: paddingHeight),
        ],
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: filteredStartups.length,
        itemBuilder: (context, index) =>
            _buildStartupCard(filteredStartups[index]),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Startups'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          _AnimatedButton(
            icon: Icons.refresh,
            onPressed: _refreshStartups,
            size: 24,
          ),
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (SortOption option) {
              setState(() {
                _sortOption = option;
                _filterStartups();
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SortOption.none,
                child: Text('Default'),
              ),
              const PopupMenuItem(
                value: SortOption.mostLiked,
                child: Text('Most Liked'),
              ),
              const PopupMenuItem(
                value: SortOption.mostFollowed,
                child: Text('Most Followed'),
              ),
              const PopupMenuItem(
                value: SortOption.newest,
                child: Text('Newest'),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search startups...',
                        prefixIcon: Icon(
                          Icons.search,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainer,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildIndustryFilter(),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshStartups,
                  color: colorScheme.primary,
                  child: _buildBody(),
                ),
              ),
            ],
          ),
          if (isOffline)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.yellow[100],
                padding: const EdgeInsets.all(8),
                child: const Text(
                  'Offline Mode: Showing cached data',
                  style: TextStyle(color: Colors.black87, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
class _AnimatedButton extends StatefulWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String? label;
  final Color? color;        // Button background
  final Color? textColor;    // Text + icon color
  final double size;

  const _AnimatedButton({
    required this.onPressed,
    required this.icon,
    this.label,
    this.color,
    this.textColor,
    this.size = 20,
  });

  @override
  _AnimatedButtonState createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.94)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _effectiveTextColor =>
      widget.textColor ?? Colors.black87; // FIX: Always visible

  Color get _effectiveBackground =>
      widget.color ?? Colors.grey.shade200; // FIX: Default light grey

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.label != null
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _effectiveBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: widget.size, color: _effectiveTextColor),
                    const SizedBox(width: 6),

                    // FIX: Label ALWAYS visible
                    Text(
                      widget.label!,
                      style: TextStyle(
                        color: _effectiveTextColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            : IconButton(
                icon: Icon(
                  widget.icon,
                  size: widget.size,
                  color: _effectiveTextColor,
                ),
                onPressed: widget.onPressed,
              ),
      ),
    );
  }
}

class StartupDetailsPage extends StatefulWidget {
  final dynamic startup;

  const StartupDetailsPage({super.key, required this.startup});

  @override
  State<StartupDetailsPage> createState() => _StartupDetailsPageState();
}

class _StartupDetailsPageState extends State<StartupDetailsPage> {
  String? userId;
  bool isFollowing = false;
  bool isFavorited = false;

  @override
  void initState() {
    super.initState();
    _loadUserId();
    if (widget.startup['logo_url'] != null &&
        widget.startup['logo_url'].isNotEmpty) {
      widget.startup['full_logo_url'] =
          'https://server.awarcrown.com/accessprofile/uploads/${widget.startup['logo_url']}';
    }
    widget.startup['startup_id'] = widget.startup['startup_id'].toString();
    isFollowing = widget.startup['is_following'] ?? false;
    isFavorited = widget.startup['is_favorited'] ?? false;
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('username');
    if (username != null && username.isNotEmpty) {
      try {
        final response = await http
            .get(
              Uri.parse(
                'https://server.awarcrown.com/feed/get_user?username=${Uri.encodeComponent(username)}',
              ),
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['error'] == null && data['user_id'] != null) {
            setState(() {
              userId = data['user_id'].toString();
            });
          }
        }
      } catch (e) {
        // Ignore errors here; userId will remain null
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (userId == null) return;
    final startupId = widget.startup['startup_id'];
    final bool oldFollowing = isFollowing;
    setState(() {
      isFollowing = !oldFollowing;
      widget.startup['follow_count'] =
          (widget.startup['follow_count'] ?? 0) + (oldFollowing ? -1 : 1);
    });

    try {
      final action = oldFollowing ? 'unfollow' : 'follow';
      final body =
          'user_id=${Uri.encodeComponent(userId!)}&startup_id=${Uri.encodeComponent(startupId)}&action=$action';
      final response = await http
          .post(
            Uri.parse('https://server.awarcrown.com/feed/stups/follow_startup'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
      final data = json.decode(response.body);
      if (!data['success']) {
        throw Exception(data['message'] ?? 'Failed to update follow status');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(!oldFollowing ? 'Followed' : 'Unfollowed')),
        );
      }
    } catch (e) {
      setState(() {
        isFollowing = oldFollowing;
        widget.startup['follow_count'] =
            (widget.startup['follow_count'] ?? 0) + (oldFollowing ? 1 : -1);
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update follow: $e')));
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (userId == null) return;
    final startupId = widget.startup['startup_id'];
    final bool oldFavorited = isFavorited;
    final prefs = await SharedPreferences.getInstance();
    List<String> favoritedStartups =
        prefs.getStringList('favorited_startups') ?? [];

    setState(() {
      isFavorited = !oldFavorited;
      widget.startup['is_favorited'] = isFavorited;
      if (isFavorited) {
        favoritedStartups.add(startupId);
      } else {
        favoritedStartups.remove(startupId);
      }
    });
    await prefs.setStringList('favorited_startups', favoritedStartups);

    try {
      final action = oldFavorited ? 'unfavorite' : 'favorite';
      final body =
          'user_id=${Uri.encodeComponent(userId!)}&startup_id=${Uri.encodeComponent(startupId)}&action=$action';
      final response = await http
          .post(
            Uri.parse(
              'https://server.awarcrown.com/feed/stups/favorite_startup',
            ),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
      final data = json.decode(response.body);
      if (!data['success']) {
        throw Exception(data['message'] ?? 'Failed to update favorite status');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isFavorited ? 'Favorited' : 'Unfavorited')),
        );
      }
    } catch (e) {
      setState(() {
        isFavorited = oldFavorited;
        widget.startup['is_favorited'] = oldFavorited;
        if (oldFavorited) {
          favoritedStartups.add(startupId);
        } else {
          favoritedStartups.remove(startupId);
        }
      });
      await prefs.setStringList('favorited_startups', favoritedStartups);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update favorite: $e')),
        );
      }
    }
  }

  String _normalizeUrl(String url) {
    if (url.isEmpty) return url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      return 'https://$url';
    }
    return url;
  }

  Future<void> _launchUrl(String url) async {
    final normalized = _normalizeUrl(url);
    final uri = Uri.parse(normalized);

    try {
      // Try open externally (Instagram / LinkedIn app)
      bool openedExternal = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (openedExternal) return;

      // Fallback: open in-app browser
      bool openedWebView = await launchUrl(uri, mode: LaunchMode.inAppWebView);

      if (!openedWebView && mounted) {
        _showError("Unable to open link");
      }
    } catch (e) {
      if (!mounted) return;
      _showError("Failed to open URL");
    }
  }

  Future<String?> _getShareLink(String startupId) async {
    if (userId == null || userId!.isEmpty) return null;

    try {
      final response = await http
          .post(
            Uri.parse('https://server.awarcrown.com/feed/stups/share_startup'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body:
                'startup_id=${Uri.encodeComponent(startupId)}&user_id=${Uri.encodeComponent(userId!)}',
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw http.ClientException("Server error ${response.statusCode}");
      }

      final data = json.decode(response.body);

      if (data['status'] == 'success' && data['share_url'] != null) {
        return data['share_url'];
      }

      _showError(data['message'] ?? "Failed to generate share link");
    } catch (e) {
      _showError("Failed to generate share link: ${_getErrorMessage(e)}");
    }

    return null;
  }

  String _getErrorMessage(dynamic e) {
    if (e is SocketException) return 'No internet connection.';
    if (e is TimeoutException) return 'Request timed out.';
    if (e is http.ClientException) return 'Network error.';
    return e.toString();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
    );
  }

  void _showShareSheet(dynamic startup) async {
    final startupId = startup['startup_id'];
    final shareUrl = await _getShareLink(startupId);

    if (shareUrl == null || shareUrl.isEmpty) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        final colorScheme = Theme.of(context).colorScheme;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share this startup',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 16),

              SelectableText(
                shareUrl,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: _AnimatedButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: shareUrl));
                    _showSuccess('Link copied!');
                    Navigator.pop(context);
                  },
                  icon: Icons.copy,
                  label: 'Copy Link',
                  color: colorScheme.primary,
                  textColor: Colors.white,
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: _AnimatedButton(
                  onPressed: () {
                    Share.share(
                      shareUrl,
                      subject: 'Check out this startup on Awarcrown',
                    );
                    Navigator.pop(context);
                  },
                  icon: Icons.share,
                  label: 'Share externally',
                  color: Colors.purple,
                  textColor: Colors.white,
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
    final startup = widget.startup;
    final fullLogoUrl = startup['full_logo_url'];
    final likeCount = startup['likes_count']?.toString() ?? '0';
    final followCount = startup['followers_count']?.toString() ?? '0';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Startup Details'),
        elevation: 0,
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.surface.withOpacity(0.95),
                colorScheme.surface.withOpacity(0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        actions: [
          if (userId != null)
            _AnimatedButton(
              icon: isFollowing ? Icons.person_remove : Icons.person_add,
              onPressed: _toggleFollow,
              color: isFollowing ? Colors.grey : colorScheme.primary,
            ),
          _AnimatedButton(
            icon: isFavorited ? Icons.bookmark : Icons.bookmark_border,
            onPressed: _toggleFavorite,
            color: isFavorited ? Colors.blue : null,
          ),
          _AnimatedButton(
            icon: Icons.share,
            onPressed: () => _showShareSheet(startup),
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============================
            // HEADER SECTION
            // ============================
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primaryContainer,
                    colorScheme.secondaryContainer.withOpacity(0.6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.only(
                top: 100,
                bottom: 36,
                left: 20,
                right: 20,
              ),
              child: Column(
                children: [
                  // LOGO
                  Hero(
                    tag: 'startup_logo_${startup['startup_id']}',
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 25,
                              spreadRadius: 3,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(80),
                          child: CachedNetworkImage(
                            imageUrl: fullLogoUrl ?? "",
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.business,
                                size: 70,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // TITLE
                  Text(
                    startup['startup_name'] ?? 'Unnamed Startup',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // INDUSTRY TAG
                  if (startup['industry'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        startup['industry'],
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.primary,
                            ),
                      ),
                    ),

                  const SizedBox(height: 26),

                  // LIKE + FOLLOW STATS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 130,
                        height: 125,
                        child: _buildStatCard(
                          context,
                          Icons.favorite,
                          likeCount,
                          "Likes",
                          Colors.red,
                        ),
                      ),
                      const SizedBox(width: 22),
                      SizedBox(
                        width: 130,
                        height: 125,
                        child: _buildStatCard(
                          context,
                          Icons.people,
                          followCount,
                          "Followers",
                          colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ============================
            // CONTENT SECTION
            // ============================
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCardGrid(context, startup),

                  const SizedBox(height: 26),

                  _buildSectionCard(
                    context,
                    Icons.description,
                    'Description',
                    startup['description'] ?? 'No description provided',
                    colorScheme.primary,
                  ),

                  const SizedBox(height: 18),

                 

               
                 
                  const SizedBox(height: 26),

                  if ((startup['linkedin']?.isNotEmpty ?? false) ||
                      (startup['instagram']?.isNotEmpty ?? false) ||
                      (startup['facebook']?.isNotEmpty ?? false))
                    _buildSocialLinksSection(context, startup),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCardGrid(BuildContext context, dynamic startup) {
    final colorScheme = Theme.of(context).colorScheme;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        switch (index) {
          case 0:
            return _buildFormalInfoCard(
              context,
              Icons.person_outline,
              'Founders',
              startup['founders_names'] ?? 'Not specified',
              colorScheme.primary,
            );
          case 1:
            return _buildFormalInfoCard(
              context,
              Icons.calendar_month_outlined,
              'Founded',
              startup['founding_date'] ?? 'Not specified',
              colorScheme.secondary,
            );
          case 2:
            return _buildFormalInfoCard(
              context,
              Icons.trending_up_outlined,
              'Stage',
              startup['stage'] ?? 'Not specified',
              Colors.green,
            );
          case 3:
            return _buildFormalInfoCard(
              context,
              Icons.groups_3_outlined,
              'Team Size',
              startup['team_size']?.toString() ?? 'Not specified',
              Colors.orange,
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  Widget _buildFormalInfoCard(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color accentColor,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    IconData icon,
    String title,
    String content,
    Color color,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colorScheme.surface, colorScheme.surfaceContainerLow],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLinksSection(BuildContext context, dynamic startup) {
    final scheme = Theme.of(context).colorScheme;
    final List<Map<String, dynamic>> socialLinks = [];

    void addLink(String? value, IconData icon, String label, Color color) {
      if (value != null && value.isNotEmpty) {
        socialLinks.add({
          "icon": icon,
          "label": label,
          "url": value,
          "color": color,
        });
      }
    }

    addLink(
      startup['linkedin'],
      Icons.business,
      "LinkedIn",
      const Color(0xFF0077B5),
    );
    addLink(
      startup['instagram'],
      Icons.camera_alt,
      "Instagram",
      const Color(0xFFE4405F),
    );
    addLink(
      startup['facebook'],
      Icons.facebook,
      "Facebook",
      const Color(0xFF1877F2),
    );
    addLink(startup['company_website'], Icons.link, "Website", Colors.teal);

    if (socialLinks.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [scheme.surface, scheme.surfaceContainerLow],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.share, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Text(
                  "Social Links",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: socialLinks.map((link) {
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _launchUrl(link['url']),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: (link['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: (link['color'] as Color).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(link['icon'], color: link['color'], size: 22),
                        const SizedBox(width: 8),
                        Text(
                          link['label'],
                          style: TextStyle(
                            color: link['color'],
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
