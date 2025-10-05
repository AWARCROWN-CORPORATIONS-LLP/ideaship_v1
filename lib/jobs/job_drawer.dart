import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class JobDrawer extends StatefulWidget {
  const JobDrawer({super.key});

  @override
  State<JobDrawer> createState() => _JobDrawerState();
}

class _JobDrawerState extends State<JobDrawer> {
  List<Map<String, dynamic>> allJobs = [];
  List<Map<String, dynamic>> filteredJobs = [];
  List<Map<String, dynamic>> filteredFavorites = [];
  Set<int> favoriteIds = {};  // In-memory favorites; persist with SharedPreferences if needed
  bool isLoading = true;
  String? errorMessage;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  int retryCount = 0;
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _fetchJobs();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchJobs() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Custom API endpoint for jobs
      final response = await http.get(
        Uri.parse('https://server.awarcrown.com/post/jobs.php'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> rawJobs = data['jobs'] ?? [];  // Assume response has 'jobs' array
        final fetchedJobs = rawJobs.map((item) => {
              'id': item['id'],
              'title': item['title'] ?? 'Untitled Job',
              'location': item['location'] ?? 'Unknown Location',
              'type': item['type'] ?? 'Unknown Type',
              // Add more fields as per your backend response (e.g., 'url', 'company')
            }).toList();

        setState(() {
          allJobs = fetchedJobs;
          favoriteIds = {};  // Reset favorites on fresh fetch, or load from storage
          _updateFilteredLists();
          retryCount = 0;  // Reset retry on success
        });
      } else {
        throw Exception('Failed to load jobs: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error fetching jobs: ${e.toString()}';
      });
      _scheduleRetry();
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _scheduleRetry() {
    if (retryCount < maxRetries) {
      retryCount++;
      Future.delayed(retryDelay * retryCount, () {
        if (mounted) {
          _fetchJobs();  // Recursive retry
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retrying fetch... (Attempt $retryCount/$maxRetries)'),
            duration: retryDelay * retryCount,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage!),
            action: SnackBarAction(label: 'Retry Now', onPressed: () {
              retryCount = 0;  // Reset on manual retry
              _fetchJobs();
            }),
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _updateFilteredLists();
    });
  }

  void _updateFilteredLists() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredJobs = allJobs.where((job) =>
          job['title']?.toLowerCase().contains(query) == true ||
          job['location']?.toLowerCase().contains(query) == true ||
          job['type']?.toLowerCase().contains(query) == true
      ).toList();

      filteredFavorites = allJobs
          .where((job) => favoriteIds.contains(job['id']))
          .where((job) =>
              job['title']?.toLowerCase().contains(query) == true ||
              job['location']?.toLowerCase().contains(query) == true ||
              job['type']?.toLowerCase().contains(query) == true
          )
          .toList();
    });
  }

  void _toggleFavorite(Map<String, dynamic> job) {
    final id = job['id'] as int;
    setState(() {
      if (favoriteIds.contains(id)) {
        favoriteIds.remove(id);
      } else {
        favoriteIds.add(id);
      }
      _updateFilteredLists();  // Re-filter after toggle
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(favoriteIds.contains(id) ? 'Added to favorites' : 'Removed from favorites')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Text(
                    "Jobs",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  Spacer(),
                  IconButton(
                    onPressed: () {
                      _searchController.clear();
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search jobs...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),
            SizedBox(height: 8),
            // Content
            Expanded(
              child: isLoading
                  ? Center(child: CircularProgressIndicator(color: Color(0xFF1268D1)))
                  : errorMessage != null && retryCount >= maxRetries
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text('Failed to load jobs', style: TextStyle(fontSize: 18)),
                              SizedBox(height: 8),
                              ElevatedButton(onPressed: () {
                                retryCount = 0;
                                _fetchJobs();
                              }, child: Text('Retry')),
                            ],
                          ),
                        )
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final hasSearchQuery = _searchController.text.isNotEmpty;
    return RefreshIndicator(
      onRefresh: () {
        retryCount = 0;
        return _fetchJobs();
      },
      color: Color(0xFF1268D1),
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            // All Jobs Section
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                hasSearchQuery ? 'Search Results' : 'All Jobs',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ...filteredJobs.map((job) => _buildJobTile(job)),
            if (!hasSearchQuery && filteredFavorites.isNotEmpty) ...[
              // Favorites Section (only show if no search and has favorites)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'Favorites',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              ...filteredFavorites.map((job) => _buildJobTile(job, isFavoriteSection: true)),
            ] else if (!hasSearchQuery && favoriteIds.isEmpty) ...[
              // Empty Favorites Placeholder
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  'Favorites',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text('No favorites yet. Tap the heart on a job to add it.'),
              ),
            ],
            SizedBox(height: 20),  // Extra space at bottom
          ],
        ),
      ),
    );
  }

  Widget _buildJobTile(Map<String, dynamic> job, {bool isFavoriteSection = false}) {
    final isFavorite = favoriteIds.contains(job['id']);
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        title: Text(job['title'] ?? 'Untitled Job'),
        subtitle: Text("${job['location'] ?? ''} • ${job['type'] ?? ''}"),
        leading: isFavoriteSection
            ? Icon(Icons.favorite, color: Colors.red, size: 20)
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _toggleFavorite(job),
              icon: Icon(
                isFavorite ? Icons.favorite : Icons.favorite_border,
                color: isFavorite ? Colors.red : Colors.grey,
                size: 20,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Applied to ${job['title']}')),
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1268D1),
                foregroundColor: Colors.white,
              ),
              child: Text("Apply"),
            ),
          ],
        ),
      ),
    );
  }
}