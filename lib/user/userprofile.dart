
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import '../feed/publicprofile.dart';
import '../feed/posts.dart';

class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> with TickerProviderStateMixin {
  String? _username;
  String? _email;
  String? _role;
  String? _profilePicture;
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;
  bool _isEditing = false;
  int _selectedTab = 0;
  
  // Posts data
  List<dynamic> _myPosts = [];
  List<dynamic> _savedPosts = [];
  bool _isLoadingPosts = false;
  bool _isLoadingSaved = false;
  String? _postsError;
  String? _savedError;
  int? _nextCursorId;
  int? _savedNextCursorId;
  bool _hasMorePosts = true;
  bool _hasMoreSaved = true;
  final ScrollController _scrollController = ScrollController();
  bool _isNavigatingToDetail = false;
  
  final _formKey = GlobalKey<FormState>();
  XFile? _selectedImage;
  final Map<String, TextEditingController> _controllers = {};
  late TabController _tabController;
  
  // Initialize all sections as expanded (kept for legacy keys)
  final Map<String, bool> _expandedSections = {
    'basic': true,
    'personal': true,
    'preferences': true,
    'company': true,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedTab = _tabController.index);
        if (_tabController.index == 1 && _myPosts.isEmpty && !_isLoadingPosts && _postsError == null) {
          _fetchMyPosts();
        } else if (_tabController.index == 2 && _savedPosts.isEmpty && !_isLoadingSaved && _savedError == null) {
          _fetchSavedPosts();
        }
      }
    });
    _loadUserData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      if (_selectedTab == 1 && _hasMorePosts && _postsError == null) {
        _fetchMoreMyPosts();
      } else if (_selectedTab == 2 && _hasMoreSaved && _savedError == null) {
        _fetchMoreSavedPosts();
      }
    }
  }

  Future<void> _loadUserData() async {
    try {
      setState(() => _isLoading = true);
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username');
      
      if (username == null || username.isEmpty) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorDialog('No user logged in');
        }
        return;
      }

      setState(() {
        _username = username;
        _email = prefs.getString('email') ?? '';
      });

      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/accessprofile/userprofile_info'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'username': _username}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() {
            _profileData = jsonResponse['data'] as Map<String, dynamic>?;
            _role = _profileData?['role']?.toString();
            
            final profilePath = _profileData?['profile_picture']?.toString();
            _profilePicture = profilePath != null && profilePath.isNotEmpty
                ? 'https://server.awarcrown.com/accessprofile/uploads/$profilePath'
                : null;
            
            _username = _profileData?['username']?.toString() ?? _username;
            _email = _profileData?['email']?.toString() ?? _email;
            
            _initializeControllers();
            _isLoading = false;
          });
        } else {
          _showErrorDialog(jsonResponse['message'] ?? 'Failed to load profile');
          setState(() => _isLoading = false);
        }
      } else {
        _showErrorDialog('Failed to fetch profile: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorDialog('Error loading profile: ${_getErrorMessage(e)}');
      }
    }
  }

  String _getErrorMessage(dynamic e) {
    if (e is SocketException) {
      return 'No internet connection. Please check your network.';
    } else if (e is TimeoutException) {
      return 'Request timed out. Please try again.';
    } else if (e is http.ClientException) {
      return 'Network error occurred. Please try again.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
Future<void> _fetchMyPosts({int? cursorId}) async {
  if (_username == null || _username!.isEmpty) return;
  if (_isLoadingPosts) return;
  
  setState(() {
    _isLoadingPosts = true;
    _postsError = null;
  });

  try {
    // REQUIRED PARAMS
    final params = {
      'username': _username!,
      'target_username': _username!, 
    };

    if (cursorId != null) {
      params['cursorId'] = cursorId.toString();
    }

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');

    final url = 'https://server.awarcrown.com/accessprofile/fetch_user_posts?action=my_posts&$queryString';

    debugPrint("âž¡ï¸ FETCH POSTS URL: $url");

    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception('Server error: ${response.statusCode}');
    }

    final data = json.decode(response.body);
    if (data is! Map<String, dynamic>) {
      throw FormatException('Invalid JSON structure');
    }

    if (mounted) {
      setState(() {
        final newPosts = data['posts'] ?? [];

        if (cursorId == null) {
          _myPosts = newPosts;
        } else {
          final postsToAdd = newPosts.where((newPost) =>
            !_myPosts.any((existing) => existing['post_id'] == newPost['post_id'])
          ).toList();
          _myPosts.addAll(postsToAdd);
        }

        _nextCursorId = data['nextCursorId'];
        _hasMorePosts = _nextCursorId != null;
        _isLoadingPosts = false;
      });
    }
  } catch (e) {
    debugPrint('âŒ Error fetching my posts: $e');
    if (mounted) {
      setState(() {
        _postsError = _getErrorMessage(e);
        _isLoadingPosts = false;
      });
    }
  }
}

  Future<void> _fetchMoreMyPosts() async {
    if (_nextCursorId != null) {
      await _fetchMyPosts(cursorId: _nextCursorId);
    }
  }

  Future<void> _fetchSavedPosts({int? cursorId}) async {
    if (_username == null || _username!.isEmpty) return;
    if (_isLoadingSaved) return;
    
    setState(() {
      _isLoadingSaved = true;
      _savedError = null;
    });

    try {
      // Try to fetch from API first
      final params = {'username': _username!};
      if (cursorId != null) params['cursorId'] = cursorId.toString();
      final queryString = params.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      final url = 'https://server.awarcrown.com/accessprofile/fetch_user_posts?action=saved_posts&$queryString';
      
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
          if (mounted) {
            setState(() {
              final newPosts = data['posts'] ?? [];
              if (cursorId == null) {
                _savedPosts = newPosts;
              } else {
                final postsToAdd = newPosts.where((newPost) =>
                    !_savedPosts.any((existing) => existing['post_id'] == newPost['post_id'])).toList();
                _savedPosts.addAll(postsToAdd);
              }
              _savedNextCursorId = data['nextCursorId'];
              _hasMoreSaved = _savedNextCursorId != null;
              _isLoadingSaved = false;
            });
          }
          return;
        }
      }
      
      // Fallback: Load from local cache if API fails
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('saved_posts');
      if (savedStr != null && cursorId == null) {
        final savedList = json.decode(savedStr) as List;
        if (savedList.isNotEmpty && mounted) {
          // Fetch post details for saved post IDs
          final savedIds = savedList.cast<int>();
          final posts = <dynamic>[];
          for (var postId in savedIds) {
            try {
              final postResponse = await http.get(
                Uri.parse( 'https://server.awarcrown.com/accessprofile/fetch_user_posts?action=saved_posts&$queryString'),

              ).timeout(const Duration(seconds: 5));
              if (postResponse.statusCode == 200) {
                final postData = json.decode(postResponse.body);
                if (postData['post'] != null) {
                  posts.add(postData['post']);
                 
                }
              }
            } catch (e) {
              debugPrint('Error fetching post $postId: $e');
            }
          }
          if (mounted) {
            setState(() {
              _savedPosts = posts;
              _hasMoreSaved = false;
              _isLoadingSaved = false;
            });
          }
          return;
        }
      }
      
      throw Exception('No saved posts found');
    } catch (e) {
      debugPrint('Error fetching saved posts: $e');
      if (mounted) {
        setState(() {
          _savedError = _getErrorMessage(e);
          _isLoadingSaved = false;
        });
      }
    }
  }

  Future<void> _fetchMoreSavedPosts() async {
    if (_savedNextCursorId != null) {
      await _fetchSavedPosts(cursorId: _savedNextCursorId);
    }
  }
void _initializeControllers() {
  _controllers.clear();
  String getVal(String key) => _profileData?[key]?.toString() ?? '';

  // Common fields
  _controllers['role'] = TextEditingController(text: _role ?? '');
  _controllers['full_name'] = TextEditingController(
    text: _role == "startup" ? getVal('founders_names') : getVal('full_name'),
  );
  _controllers['email'] = TextEditingController(text: getVal('email'));
  _controllers['phone'] = TextEditingController(text: getVal('phone'));
  _controllers['bio'] = TextEditingController(text: getVal('description'));

  // STUDENT ROLE
  if (_role == "student") {
    _controllers['interests'] = TextEditingController(text: getVal('interests'));
  }

  // STARTUP ROLE
  else if (_role == "startup") {
    _controllers['founders_names'] = TextEditingController(text: getVal('founders_names'));
    _controllers['startup_name'] = TextEditingController(text: getVal('startup_name'));
    _controllers['industry'] = TextEditingController(text: getVal('industry'));
    _controllers['team_size'] = TextEditingController(text: getVal('team_size'));

    // Social links
    _controllers['instagram'] = TextEditingController(text: getVal('instagram'));
    _controllers['facebook'] = TextEditingController(text: getVal('facebook'));

    // Business fields
    _controllers['founding_date'] = TextEditingController(text: getVal('founding_date'));
    _controllers['stage'] = TextEditingController(text: getVal('stage'));
    _controllers['business_reg_type'] = TextEditingController(text: getVal('business_reg_type'));
    _controllers['business_registration'] = TextEditingController(text: getVal('business_registration'));

    // Government info
    _controllers['founder_id'] = TextEditingController(text: getVal('founder_id'));
    _controllers['gov_id_type'] = TextEditingController(text: getVal('gov_id_type'));

    // Additional info
    _controllers['highlights'] = TextEditingController(text: getVal('highlights'));
    _controllers['funding_goals'] = TextEditingController(text: getVal('funding_goals'));
    _controllers['mentorship_needs'] = TextEditingController(text: getVal('mentorship_needs'));
    _controllers['business_vision'] = TextEditingController(text: getVal('business_vision'));

    // Contact Email
    _controllers['reference'] = TextEditingController(text: getVal('reference'));

    // Docs
    _controllers['additional_docs'] = TextEditingController(text: getVal('additional_docs'));
    _controllers['supporting_docs'] = TextEditingController(text: getVal('supporting_docs'));

    // Verification
    _controllers['email_verification'] = TextEditingController(text: getVal('email_verification'));
  }
}



  

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorDialog('Please address the validation errors.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final body = {'username': _username};
      _controllers.forEach((key, controller) {
        if (controller.text.isNotEmpty) {
          body[key] = controller.text.trim();
        }
      });

      final response = await http.post(
        Uri.parse('https://server.awarcrown.com/accessprofile/update_profile'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          _showSuccess('Profile updated successfully');
          setState(() => _isEditing = false);
          await _loadUserData();
        } else {
          _showErrorDialog(jsonResponse['message'] ?? 'Failed to update profile');
        }
      } else {
        _showErrorDialog('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) _showErrorDialog('Error updating profile: ${_getErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image != null) {
        final fileExtension = image.path.split('.').last.toLowerCase();
        if (!['jpg', 'jpeg', 'png', 'gif'].contains(fileExtension)) {
          _showErrorDialog('Only JPG, PNG, or GIF images are supported.');
          return;
        }
        final file = File(image.path);
        final fileSize = await file.length();
        if (fileSize > 5 * 1024 * 1024) {
          _showErrorDialog('Image size exceeds 5MB limit.');
          return;
        }
        setState(() => _selectedImage = image);
      }
    } catch (e) {
      _showErrorDialog('Error picking image: ${_getErrorMessage(e)}');
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (_selectedImage == null || _username == null) {
      _showErrorDialog('No image selected or user not logged in');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://server.awarcrown.com/accessprofile/upload_picture'),
      );
      request.fields['username'] = _username!;

      String? mimeType;
      final fileExtension = _selectedImage!.path.split('.').last.toLowerCase();
      switch (fileExtension) {
        case 'jpg':
        case 'jpeg':
          mimeType = 'image/jpeg';
          break;
        case 'png':
          mimeType = 'image/png';
          break;
        case 'gif':
          mimeType = 'image/gif';
          break;
        default:
          mimeType = 'application/octet-stream';
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'profile_picture',
          _selectedImage!.path,
          contentType: MediaType.parse(mimeType),
        ),
      );

      final response = await request.send().timeout(const Duration(seconds: 30));
      final responseBody = await response.stream.bytesToString();

      if (!mounted) return;

      final jsonResponse = json.decode(responseBody);
      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        setState(() {
          final profilePath = jsonResponse['profile_path']?.toString();
          _profilePicture = profilePath != null && profilePath.isNotEmpty
              ? 'https://server.awarcrown.com/accessprofile/uploads/$profilePath'
              : null;
          _selectedImage = null;
        });
        _showSuccess('Profile picture updated');
        await _loadUserData();
      } else {
        _showErrorDialog(jsonResponse['message'] ?? 'Failed to upload: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      if (mounted) _showErrorDialog('Error uploading profile picture: ${_getErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Expanded(child: Text('Error')),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showProfileImage() {
    if (_profilePicture == null) return;
    showDialog(
      context: context,
      // ignore: deprecated_member_use
      barrierColor: Colors.black.withOpacity(0.95),
      barrierDismissible: true,
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: Hero(
              tag: 'profile_image_$_profilePicture',
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: CachedNetworkImage(
                  imageUrl: _profilePicture!,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(),
                  ),
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

  Widget _buildProfileHeader() {
    return Container(
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
                  tag: 'profile_image_$_profilePicture',
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade200, width: 2),
                      boxShadow: [
                        BoxShadow(
                          // ignore: deprecated_member_use
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 43,
                      backgroundImage: _selectedImage != null
                          ? FileImage(File(_selectedImage!.path))
                          : _profilePicture != null
                              ? CachedNetworkImageProvider(_profilePicture!)
                              : null,
                      backgroundColor: Colors.grey.shade100,
                      child: _profilePicture == null && _selectedImage == null
                          ? Icon(Icons.person, size: 45, color: Colors.grey.shade400)
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
                    GestureDetector(
                      onTap: () {
                        if (_username != null && _username!.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PublicProfilePage(targetUsername: _username!),
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          Text(
                            _username ?? 'User',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A1A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.open_in_new, size: 16, color: Colors.grey.shade600),
                        ],
                      ),
                    ),
                    if (_email != null && _email!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _email!,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (_role == 'student')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Explorer',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1B5E20),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (_role == 'Company/HR')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Builder at Ideaship',

                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    if (_profileData?['bio'] != null && _profileData!['bio'].toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        _profileData!['bio'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ],
                    if (_profileData?['website'] != null && _profileData!['website'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link, size: 14, color: Colors.blue.shade600),
                          const SizedBox(width: 4),
                          Text(
                            _profileData!['website'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _StatButton(
                  label: 'Posts',
                  count: _myPosts.length,
                  onTap: () {
                    _tabController.animateTo(1);
                  },
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              Expanded(
                child: _StatButton(
                  label: 'Saved',
                  count: _savedPosts.length,
                  onTap: () {
                    _tabController.animateTo(2);
                  },
                ),
              ),
            ],
          ),
          if (_isEditing) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('Change Photo'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                if (_selectedImage != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _uploadProfilePicture,
                      icon: const Icon(Icons.save, size: 18),
                      label: const Text('Save Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _StatButton({required String label, required int count, required VoidCallback onTap}) {
    return GestureDetector(
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

  Widget _buildProfileInfoTab() {
    if (_profileData == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No profile data available'),
        ),
      );
    }

    return SingleChildScrollView(
  padding: const EdgeInsets.all(20),
  child: Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // BASIC INFORMATION SECTION
_buildInfoSection(
  'Basic Information',
  Icons.info_outline,
  [
    if (_role == 'student')
      _buildInfoField('Full Name', 'full_name', isRequired: true)
    else if (_role == 'startup')
      _buildInfoField('Founder Name', 'founders_names', isRequired: true),

    if (_role == 'startup')
      _buildInfoField('Startup Name', 'startup_name', isRequired: true),
  ],
),


        const SizedBox(height: 16),

        _buildInfoSection(
          'Personal Information',
          Icons.person_outline,
          [
            _buildInfoField('Email', 'email', alwaysReadOnly: true),
            _buildInfoField('Phone', 'phone'),
            _buildInfoField('Bio', 'bio', isMultiline: true),
          ],
        ),

        // Student-specific fields
        if (_role == 'student') ...[
          const SizedBox(height: 16),
          _buildInfoSection(
            'Education',
            Icons.school_outlined,
            [
              _buildInfoField('Interests', 'interests', isMultiline: true),
            ],
          ),
        ]

        // STARTUP SECTION
        else if (_role == 'startup') ...[
          const SizedBox(height: 16),

          _buildInfoSection(
            'Startup Information',
            Icons.business_outlined,
            [
              _buildInfoField('Founders Name', 'founders_names',alwaysReadOnly: true),
              _buildInfoField('Startup Name', 'startup_name',alwaysReadOnly: true),
              _buildInfoField('Phone', 'phone',alwaysReadOnly: true),
              _buildInfoField('Contact Email', 'reference', alwaysReadOnly: true),
              _buildInfoField('Industry', 'industry'),
              _buildInfoField('Team Size', 'team_size', isNumeric: true),
              _buildInfoField('Founding Date', 'founding_date', alwaysReadOnly: true),
              _buildInfoField('Stage', 'stage'),
            ],
          ),

          const SizedBox(height: 16),

          _buildInfoSection(
            'Social Profiles',
            Icons.link,
            [
              _buildInfoField('Instagram', 'instagram'),
              _buildInfoField('Facebook', 'facebook'),
            ],
          ),

          const SizedBox(height: 16),

          _buildInfoSection(
            'Business Details',
            Icons.domain,
            [
              _buildInfoField('Business Registration Type', 'business_reg_type'),
              _buildInfoField('Registration Number', 'business_registration',alwaysReadOnly: true),
              _buildInfoField('Government ID Type', 'gov_id_type',alwaysReadOnly: true),
              _buildInfoField('Founder Govt ID Number', 'founder_id',alwaysReadOnly: true),
            ],
          ),

          const SizedBox(height: 16),

          _buildInfoSection(
            'Vision & Goals',
            Icons.flag_outlined,
            [
              _buildInfoField('Highlights / Achievements', 'highlights', isMultiline: true),
              _buildInfoField('Funding Goals', 'funding_goals', isMultiline: true),
              _buildInfoField('Mentorship Needs', 'mentorship_needs', isMultiline: true),
              _buildInfoField('Business Vision', 'business_vision', isMultiline: true),
            ],
          ),

          const SizedBox(height: 16),

          _buildInfoSection(
            'Documents & Verification',
            Icons.verified_outlined,
            [
              _buildInfoField('Email Verification Status', 'email_verification',
                  alwaysReadOnly: true),
              _buildInfoField('Supporting Docs', 'supporting_docs', isMultiline: true),
              _buildInfoField('Additional Docs', 'additional_docs', isMultiline: true),
            ],
          ),
        ],

        if (_isEditing) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _updateProfile,
                  child: const Text('Save Changes'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      _selectedImage = null;
                    });
                    _initializeControllers();
                  },
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(String title, IconData icon, List<Widget> fields) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.black.withOpacity(0.03),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: const Color(0xFF007AFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF007AFF), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          ...fields,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildInfoField(String label, String fieldKey, {
    bool isRequired = false,
    bool isMultiline = false,
    bool isNumeric = false,
    bool alwaysReadOnly = false,
  }) {
    final effectiveReadOnly = alwaysReadOnly || !_isEditing;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextFormField(
        controller: _controllers[fieldKey],
        maxLines: isMultiline ? 3 : 1,
        readOnly: effectiveReadOnly,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumeric
            ? [FilteringTextInputFormatter.digitsOnly]
            : fieldKey == 'phone' || fieldKey == 'contact_phone'
                ? [FilteringTextInputFormatter.allow(RegExp(r'^\+?[\d\s-]*$'))]
                : null,
        decoration: InputDecoration(
          labelText: label + (isRequired && !effectiveReadOnly ? ' *' : ''),
          filled: true,
          fillColor: effectiveReadOnly ? Colors.grey.shade50 : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF007AFF), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: TextStyle(
          fontSize: 15,
          color: effectiveReadOnly ? Colors.grey.shade600 : Colors.black87,
        ),
        validator: effectiveReadOnly ? null : (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return '$label is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildPostsTab() {
    if (_postsError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                _postsError!,
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _fetchMyPosts(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoadingPosts && _myPosts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.post_add, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
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
                'Start sharing your ideas!',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchMyPosts(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _myPosts.length + (_hasMorePosts ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _myPosts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildPostCard(_myPosts[index], index);
        },
      ),
    );
  }

  Widget _buildSavedPostsTab() {
    if (_savedError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                _savedError!,
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _fetchSavedPosts(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoadingSaved && _savedPosts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_savedPosts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.bookmark_border, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No saved posts',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Posts you save will appear here',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _fetchSavedPosts(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _savedPosts.length + (_hasMoreSaved ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _savedPosts.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildPostCard(_savedPosts[index], index);
        },
      ),
    );
  }

  Widget _buildPostCard(dynamic post, int index) {
    final postId = post['post_id'];
    final imageUrl = post['media_url'] != null && post['media_url'].isNotEmpty
        ? 'https://server.awarcrown.com/feed/${post['media_url']}'
        : null;
    final screenWidth = MediaQuery.of(context).size.width - 40;
    const double aspectRatio = 1.0;

    return GestureDetector(
      onTap: () async {
        if (_isNavigatingToDetail) return;
        _isNavigatingToDetail = true;
        try {
          final response = await http
              .get(
                Uri.parse('https://server.awarcrown.com/feed/fetch_comments?post_id=$postId&username=${Uri.encodeComponent(_username ?? '')}'),
              )
              .timeout(const Duration(seconds: 10));

          if (response.statusCode == 200 && mounted) {
            final data = json.decode(response.body);
            final comments = data['comments'] ?? [];
            final prefs = await SharedPreferences.getInstance();
            final userId = prefs.getInt('user_id');

            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CommentsPage(
                  post: post,
                  comments: comments,
                  username: _username ?? '',
                  userId: userId,
                ),
              ),
            );
          }
        } catch (e) {
          debugPrint('Error fetching comments: $e');
        } finally {
          _isNavigatingToDetail = false;
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
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
                  GestureDetector(
                    onTap: () {
                      final username = post['username'];
                      if (username != null && username.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PublicProfilePage(targetUsername: username),
                          ),
                        );
                      }
                    },
                    child: CircleAvatar(
                      radius: 22,
                      backgroundImage: post['profile_picture'] != null
                          ? CachedNetworkImageProvider(
                              'https://server.awarcrown.com/accessprofile/uploads/${post['profile_picture']}')
                          : null,
                      backgroundColor: Colors.grey.shade100,
                      child: post['profile_picture'] == null
                          ? Icon(Icons.person, size: 22, color: Colors.grey.shade400)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            final username = post['username'];
                            if (username != null && username.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PublicProfilePage(targetUsername: username),
                                ),
                              );
                            }
                          },
                          child: Text(
                            post['username'] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatTime(post['created_at']),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (post['content'] != null && post['content'].isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  post['content'],
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.grey.shade800,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (imageUrl != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: AspectRatio(
                  aspectRatio: aspectRatio,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: (screenWidth * MediaQuery.of(context).devicePixelRatio).round(),
                      memCacheHeight: (screenWidth * aspectRatio * MediaQuery.of(context).devicePixelRatio).round(),
                      placeholder: (context, url) => Container(
                        color: Colors.grey.shade100,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.image_not_supported, color: Colors.grey.shade400, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: Row(
                children: [
                  Icon(Icons.favorite, size: 20, color: Colors.red.shade400),
                  const SizedBox(width: 6),
                  Text(
                    '${post['like_count'] ?? 0}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.mode_comment_outlined, size: 20, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    '${post['comment_count'] ?? 0}',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  const Spacer(),
                  if (_selectedTab == 2)
                    Icon(Icons.bookmark, size: 20, color: Colors.amber.shade700),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
            color: Color(0xFF1A1A1A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Profile',
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  _selectedImage = null;
                });
                _initializeControllers();
              },
              tooltip: 'Cancel',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF007AFF),
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: const Color(0xFF007AFF),
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'My Posts'),
            Tab(text: 'Saved'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildProfileHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileInfoTab(),
                _buildPostsTab(),
                _buildSavedPostsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
