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

enum SortOption { none, mostLiked, mostFollowed, newest }

class StartupsPage extends StatefulWidget {
  const StartupsPage({super.key});

  @override
  _StartupsPageState createState() => _StartupsPageState();
}

class _StartupsPageState extends State<StartupsPage> with TickerProviderStateMixin {
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
      final response = await http.get(
        Uri.parse('https://server.awarcrown.com/feed/get_user?username=${Uri.encodeComponent(username)}'),
      ).timeout(const Duration(seconds: 10));
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
          if (startup['logo_url'] != null && startup['logo_url'].isNotEmpty) {
            startup['full_logo_url'] = 'https://server.awarcrown.com/accessprofile/uploads/${startup['logo_url']}';
          } else {
            startup['full_logo_url'] = null;
          }
          startup['startup_id'] = startup['startup_id'].toString();
          startup['is_favorited'] = favoritedStartups.contains(startup['startup_id']);
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
      final response = await http.get(
        Uri.parse('https://server.awarcrown.com/feed/stups/fetch_startups?user_id=${Uri.encodeComponent(userId!)}'),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          final List<dynamic> fetchedStartups = data['startups'] ?? [];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_startups', json.encode(fetchedStartups));
          setState(() {
            startups = fetchedStartups.map((startup) {
              if (startup['logo_url'] != null && startup['logo_url'].isNotEmpty) {
                startup['full_logo_url'] = 'https://server.awarcrown.com/accessprofile/uploads/${startup['logo_url']}';
              } else {
                startup['full_logo_url'] = null;
              }
              startup['startup_id'] = startup['startup_id'].toString();
              startup['is_favorited'] = favoritedStartups.contains(startup['startup_id']);
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
        bool matchesSearch = name.contains(query) || industry.contains(query) || description.contains(query);
        bool matchesIndustry = selectedIndustry == null || startup['industry'] == selectedIndustry;
        bool matchesFilter = industryFilters.entries.every((entry) => entry.value || startup['industry'] != entry.key);
        bool matchesFavorites = !showFavoritesOnly || favoritedStartups.contains(startup['startup_id']);
        return matchesSearch && matchesIndustry && matchesFilter && matchesFavorites;
      }).toList();

      switch (_sortOption) {
        case SortOption.mostLiked:
          filteredStartups.sort((a, b) => (b['like_count'] ?? 0).compareTo(a['like_count'] ?? 0));
          break;
        case SortOption.mostFollowed:
          filteredStartups.sort((a, b) => (b['follow_count'] ?? 0).compareTo(a['follow_count'] ?? 0));
          break;
        case SortOption.newest:
          filteredStartups.sort((a, b) => DateTime.parse(b['created_at'] ?? '1970-01-01')
              .compareTo(DateTime.parse(a['created_at'] ?? '1970-01-01')));
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
      _showSuccess('Favorite ${oldIsFavorited ? 'removed' : 'added'} offline. Will sync when online.');
      return;
    }

    try {
      final action = oldIsFavorited ? 'unfavorite' : 'favorite';
      final body = 'user_id=${Uri.encodeComponent(userId!)}&startup_id=${Uri.encodeComponent(startupId)}&action=$action';
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/stups/favorite_startup'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (!data['success']) {
          throw Exception(data['message'] ?? 'Failed to update favorite status');
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
          startup['follow_count'] = (startup['follow_count'] ?? 0) + (oldFollowing ? -1 : 1);
        }
        return startup;
      }).toList();
    });
    _filterStartups();

    if (isOffline) {
      _showSuccess('Follow action queued offline. Will sync when online.');
      // Optionally store action in SharedPreferences for later syncing
      return;
    }

    try {
      final action = oldFollowing ? 'unfollow' : 'follow';
      final body = 'user_id=${Uri.encodeComponent(userId!)}&startup_id=${Uri.encodeComponent(startupId)}&action=$action';
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/stups/follow_startup'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      ).timeout(const Duration(seconds: 10));
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
            startup['follow_count'] = (startup['follow_count'] ?? 0) + (oldFollowing ? 1 : -1);
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
          startup['like_count'] = (startup['like_count'] ?? 0) + (oldLiked ? -1 : 1);
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
      final body = 'user_id=${Uri.encodeComponent(userId!)}&startup_id=${Uri.encodeComponent(startupId)}&action=$action';
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/stups/like_startup'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      ).timeout(const Duration(seconds: 10));
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
            startup['like_count'] = (startup['like_count'] ?? 0) + (oldLiked ? 1 : -1);
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
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/stups/share_startup'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: 'startup_id=${Uri.encodeComponent(startupId)}&user_id=${Uri.encodeComponent(userId!)}',
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['status'] == 'success') {
          return data['share_url'] ?? '';
        } else {
          _showError(data['message'] ?? 'Failed to generate share link');
        }
      } else {
        throw http.ClientException('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Failed to generate share link: ${_getErrorMessage(e)}');
    }
    return null;
  }

  String _getErrorMessage(dynamic e) {
    if (e is SocketException) {
      return 'No internet connection.';
    } else if (e is TimeoutException) {
      return 'Request timed out.';
    } else if (e is http.ClientException) {
      return 'Network error.';
    } else {
      return e.toString();
    }
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
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [colorScheme.surface, colorScheme.surfaceContainer],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share this startup',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                    child: _AnimatedButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: shareUrl));
                        _showSuccess('Link copied!');
                        Navigator.pop(context);
                      },
                      icon: Icons.copy,
                      label: 'Copy Link',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _AnimatedButton(
                      onPressed: () {
                        Share.share(shareUrl, subject: 'Check out this startup on Awarcrown');
                        Navigator.pop(context);
                      },
                      icon: Icons.share,
                      label: 'Share externally',
                      color: Colors.purple,
                    ),
                  ),
                ],
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
                checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
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
                checkmarkColor: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            );
          }
          final industry = industries[index - 2];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(industry),
              selected: selectedIndustry == industry,
              onSelected: (selected) => _updateIndustryFilter(industry, selected),
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
    final isFavorited = startup['is_favorited'] ?? favoritedStartups.contains(startup['startup_id']);
    final likeCount = startup['like_count']?.toString() ?? '0';
    final followCount = startup['follow_count']?.toString() ?? '0';

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
                              errorWidget: (context, url, error) => const Icon(Icons.business, size: 64),
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
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                              ),
                            ),
                            _AnimatedButton(
                              icon: isFavorited ? Icons.bookmark : Icons.bookmark_border,
                              color: isFavorited ? Colors.blue : null,
                              onPressed: () => _toggleFavorite(startup['startup_id'], isFavorited),
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              icon: isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : null,
                              onPressed: () => _toggleLike(startup['startup_id'], isLiked),
                              label: '$likeCount likes',
                            ),
                            const SizedBox(width: 16),
                            Text('$followCount followers', style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _AnimatedButton(
                                onPressed: () => _toggleFollow(startup['startup_id'], isFollowing),
                                label: isFollowing ? 'Unfollow' : 'Follow',
                                color: isFollowing ? const Color.fromARGB(255, 45, 23, 169) : colorScheme.primary,
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
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
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
                Icon(Icons.search_off, size: 64, color: colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  _searchController.text.isEmpty ? 'No startups found' : 'No matching startups',
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
        itemBuilder: (context, index) => _buildStartupCard(filteredStartups[index]),
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
              const PopupMenuItem(value: SortOption.none, child: Text('Default')),
              const PopupMenuItem(value: SortOption.mostLiked, child: Text('Most Liked')),
              const PopupMenuItem(value: SortOption.mostFollowed, child: Text('Most Followed')),
              const PopupMenuItem(value: SortOption.newest, child: Text('Newest')),
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
                        prefixIcon: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
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
  final Color? color;
  final Color? textColor;
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

class _AnimatedButtonState extends State<_AnimatedButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
            ? ElevatedButton.icon(
                onPressed: null,
                icon: Icon(widget.icon, size: widget.size, color: widget.textColor),
                label: Text(
                  widget.label!,
                  style: TextStyle(color: widget.textColor),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.color ?? colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              )
            : IconButton(
                icon: Icon(widget.icon, size: widget.size, color: widget.color),
                onPressed: null,
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
    if (widget.startup['logo_url'] != null && widget.startup['logo_url'].isNotEmpty) {
      widget.startup['full_logo_url'] = 'https://server.awarcrown.com/accessprofile/uploads/${widget.startup['logo_url']}';
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
        final response = await http.get(
          Uri.parse('https://server.awarcrown.com/feed/get_user?username=${Uri.encodeComponent(username)}'),
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['error'] == null && data['user_id'] != null) {
            setState(() {
              userId = data['user_id'].toString();
            });
          }
        }
      } catch (e) {
        // Handle error silently
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (userId == null) return;
    final startupId = widget.startup['startup_id'];
    final bool oldFollowing = isFollowing;
    setState(() {
      isFollowing = !oldFollowing;
      widget.startup['follow_count'] = (widget.startup['follow_count'] ?? 0) + (oldFollowing ? -1 : 1);
    });

    try {
      final action = oldFollowing ? 'unfollow' : 'follow';
      final body = 'user_id=${Uri.encodeComponent(userId!)}&startup_id=${Uri.encodeComponent(startupId)}&action=$action';
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/stups/follow_startup'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      ).timeout(const Duration(seconds: 10));
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
        widget.startup['follow_count'] = (widget.startup['follow_count'] ?? 0) + (oldFollowing ? 1 : -1);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update follow: $e')),
        );
      }
    }
  }

  Future<void> _toggleFavorite() async {
    if (userId == null) return;
    final startupId = widget.startup['startup_id'];
    final bool oldFavorited = isFavorited;
    final prefs = await SharedPreferences.getInstance();
    List<String> favoritedStartups = prefs.getStringList('favorited_startups') ?? [];

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
      final body = 'user_id=${Uri.encodeComponent(userId!)}&startup_id=${Uri.encodeComponent(startupId)}&action=$action';
      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/feed/stups/favorite_startup'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      ).timeout(const Duration(seconds: 10));
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

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch URL')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final startup = widget.startup;
    final fullLogoUrl = startup['full_logo_url'];

    return Scaffold(
      appBar: AppBar(
        title: Text(startup['startup_name'] ?? 'Startup Details'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
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
            onPressed: () {
              // Implement share sheet if needed
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Hero(
                tag: 'startup_logo_${startup['startup_id']}',
                child: fullLogoUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: CachedNetworkImage(
                          imageUrl: fullLogoUrl,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Shimmer.fromColors(
                            baseColor: Colors.grey[300]!,
                            highlightColor: Colors.grey[100]!,
                            child: Container(
                              width: 120,
                              height: 120,
                              color: Colors.white,
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(Icons.business, size: 120),
                        ),
                      )
                    : const CircleAvatar(
                        radius: 60,
                        child: Icon(Icons.business, size: 60),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                startup['startup_name'] ?? 'Unnamed Startup',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                startup['industry'] ?? '',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.primary,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Founders', startup['founders_names'] ?? 'Not specified'),
                    _buildInfoRow('Founded', startup['founding_date'] ?? 'Not specified'),
                    _buildInfoRow('Stage', startup['stage'] ?? 'Not specified'),
                    _buildInfoRow('Team Size', startup['team_size']?.toString() ?? 'Not specified'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSection('Description', startup['description'] ?? 'No description provided'),
            _buildSection('Business Vision', startup['business_vision'] ?? 'No vision provided'),
            _buildSection('Funding Goals', startup['funding_goals'] ?? 'No funding goals provided'),
            _buildSection('Mentorship Needs', startup['mentorship_needs'] ?? 'No mentorship needs provided'),
            const SizedBox(height: 24),
            _buildSectionTitle('Social Links'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (startup['linkedin'] != null && startup['linkedin'].isNotEmpty)
                  _AnimatedButton(
                    icon: Icons.link,
                    onPressed: () => _launchUrl(startup['linkedin']),
                    color: Colors.blue,
                  ),
                if (startup['instagram'] != null && startup['instagram'].isNotEmpty)
                  _AnimatedButton(
                    icon: Icons.camera_alt,
                    onPressed: () => _launchUrl(startup['instagram']),
                    color: Colors.pink,
                  ),
                if (startup['facebook'] != null && startup['facebook'].isNotEmpty)
                  _AnimatedButton(
                    icon: Icons.facebook,
                    onPressed: () => _launchUrl(startup['facebook']),
                    color: Colors.blue[800],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}