import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:ideaship/feed/publicprofile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'threads.dart';

class ThreadDetailScreen extends StatefulWidget {
  final Thread thread;
  final String username;
  final int userId;

  const ThreadDetailScreen({
    super.key,
    required this.thread,
    required this.username,
    required this.userId,
  });

  @override
  State<ThreadDetailScreen> createState() => _ThreadDetailScreenState();
}

class _ThreadDetailScreenState extends State<ThreadDetailScreen>
    with TickerProviderStateMixin {
  List<Comment> comments = [];
  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;
  final TextEditingController _commentController = TextEditingController();
  late AnimationController _detailAnimationController;
  late Animation<double> _detailFadeAnimation;
  final ScrollController _commentsScrollController = ScrollController();
  Timer? _commentsRetryTimer;
  Timer? _commentPollingTimer; 
  int _commentsRetryCount = 0;
  static const int _commentsMaxRetries = 3;
  http.Client? _commentsHttpClient;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOnline = false;
  final Set<int> _loadedCommentIds = <int>{};
  int _lastCommentCount = 0; 

  File? _selectedImage;
  bool _isUploadingImage = false;
  final ImagePicker _imagePicker = ImagePicker();

  // UI State
  final Color _pageColor = const Color(0xFFF8F9FA);
  final Color _cardColor = Colors.white;
  final Color _primaryTextColor = const Color(0xFF1a2533);
  final Color _secondaryTextColor = const Color(0xFF6B7280);
  int? _replyToCommentId;
  final FocusNode _commentFocusNode = FocusNode();

  // Draft comment state
  Timer? _draftSaveTimer;
  static const Duration _draftSaveDelay = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    _commentsHttpClient = http.Client();
    _detailAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _detailFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _detailAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _detailAnimationController.forward();
    _initConnectivity();
    _loadComments();
    _syncInspireStatus();
    _startCommentPolling(); // Start async polling
    _loadDraftComment(); // Load saved draft
    _commentController.addListener(_onCommentChanged); // Auto-save drafts
  }

  // Load draft comment from local storage
  Future<void> _loadDraftComment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftKey = 'comment_draft_${widget.thread.id}';
      final draft = prefs.getString(draftKey);
      if (draft != null && draft.isNotEmpty && mounted) {
        _commentController.text = draft;
      }
    } catch (e) {
      debugPrint('Error loading draft: $e');
    }
  }

  // Save draft comment to local storage
  Future<void> _saveDraftComment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftKey = 'comment_draft_${widget.thread.id}';
      final text = _commentController.text.trim();
      if (text.isNotEmpty) {
        await prefs.setString(draftKey, text);
      } else {
        await prefs.remove(draftKey);
      }
    } catch (e) {
      debugPrint('Error saving draft: $e');
    }
  }

  // Auto-save draft when comment text changes
  void _onCommentChanged() {
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(_draftSaveDelay, _saveDraftComment);
  }

  // Clear draft after successful submission
  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftKey = 'comment_draft_${widget.thread.id}';
      await prefs.remove(draftKey);
    } catch (e) {
      debugPrint('Error clearing draft: $e');
    }
  }

  // Calculate reading time estimate
  String _getReadingTime(String text) {
    final wordCount = text.split(RegExp(r'\s+')).length;
    final readingTime = (wordCount / 200)
        .ceil(); // Average 200 words per minute
    if (readingTime < 1) return '< 1 min read';
    return '$readingTime min read';
  }

  // Share thread
  Future<void> _shareThread() async {
    try {
      final threadUrl =
          'https://server.awarcrown.com/threads/${widget.thread.id}';
      final shareText =
          'Check out this discussion: "${widget.thread.title}"\n\n$threadUrl';
      await Share.share(shareText, subject: widget.thread.title);
    } catch (e) {
      _showError('Failed to share thread');
    }
  }

  // Scroll to comments section smoothly
  void _scrollToComments() {
    if (_commentsScrollController.hasClients) {
      _commentsScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToProfile(String username) {
    if (username.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PublicProfilePage(targetUsername: username),
      ),
    );
  }

  void _addCommentIds(Comment comment) {
    _loadedCommentIds.add(comment.id);
    for (var reply in comment.replies) {
      _addCommentIds(reply);
    }
  }

  void _updateLoadedIdsForList(List<Comment> comList) {
    for (var c in comList) {
      _addCommentIds(c);
    }
  }

  Future<void> _initConnectivity() async {
    final connectivity = Connectivity();
    final results = await connectivity.checkConnectivity();
    _isOnline = results.any((result) => result != ConnectivityResult.none);
    if (mounted) setState(() {});
    _connectivitySubscription = connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final wasOnline = _isOnline;
      _isOnline = results.any((result) => result != ConnectivityResult.none);
      if (mounted) setState(() {});
      if (mounted && _isOnline && !wasOnline) {
        _loadComments();
        _startCommentPolling();
      } else if (!_isOnline) {
        _stopCommentPolling();
      }
    });
  }

  Future<bool> _isDeviceOnline() async {
    try {
      final connectivity = Connectivity();
      final results = await connectivity.checkConnectivity();
      return results.any((result) => result != ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  // Async comment polling (websocket-like behavior)
  void _startCommentPolling() {
    _stopCommentPolling(); // Stop any existing polling
    if (!_isOnline) return;

    _commentPollingTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      if (!mounted || !_isOnline) {
        timer.cancel();
        return;
      }
      await _pollForNewComments(); // Async update without full refresh
    });
  }

  void _stopCommentPolling() {
    _commentPollingTimer?.cancel();
    _commentPollingTimer = null;
  }

  // Poll for new comments without full refresh
  Future<void> _pollForNewComments() async {
    if (widget.username.isEmpty || !_isOnline) return;

    try {
      final code = await _getThreadCode(widget.thread.id);
      final uri = Uri.parse(
        'https://server.awarcrown.com/threads/comments'
        '?id=${widget.thread.id}'
        '&username=${Uri.encodeComponent(widget.username)}'
        '&limit=1000'
        '&offset=0'
        '${code != null ? '&code=${Uri.encodeComponent(code)}' : ''}',
      );

      final response = await (_commentsHttpClient ?? http.Client())
          .get(uri)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final commentList = data['comments'] as List<dynamic>? ?? [];

        // Only update if comment count changed (async update)
        if (commentList.length != _lastCommentCount) {
          List<Comment> newComments = [];
          for (final dynamic c in commentList) {
            if (c is Map<String, dynamic>) {
              try {
                newComments.add(Comment.fromJson(c, isFromCache: false));
              } catch (e) {
                debugPrint('Error parsing comment: $e');
              }
            }
          }

          if (mounted) {
            setState(() {
              comments = newComments;
              _lastCommentCount = newComments.length;
              _updateLoadedIdsForList(comments);
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Polling error: $e');
    }
  }

  Future<void> _syncInspireStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'inspired_${widget.thread.id}';
    if (prefs.containsKey(key)) {
      widget.thread.isInspiredByMe = prefs.getBool(key) ?? false;
      if (mounted) setState(() {});
      return;
    }
    final bool online = await _isDeviceOnline();
    if (!online) return;
    try {
      final code = await _getThreadCode(widget.thread.id);
      final uri = Uri.parse(
        'https://server.awarcrown.com/threads/inspire?id=${widget.thread.id}',
      );
      final body = json.encode({
        'type': 'check',
        'username': widget.username,
        if (code != null) 'code': code,
      });
      final response = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final bool inspired = data['user_has_inspired'] ?? false;
        await prefs.setBool(key, inspired);
        widget.thread.isInspiredByMe = inspired;
        widget.thread.inspiredCount =
            data['inspired_count'] ?? widget.thread.inspiredCount;
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Failed to sync inspire status: $e');
    }
  }

  Future<String?> _getThreadCode(int threadId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('code_$threadId');
  }

  Future<void> _setThreadCode(int threadId, String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('code_$threadId', code);
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _commentsRetryTimer?.cancel();
    _commentPollingTimer?.cancel();
    _connectivitySubscription?.cancel();
    _commentsScrollController.dispose();
    _detailAnimationController.dispose();
    _commentController.removeListener(_onCommentChanged);
    _commentController.dispose();
    _commentsHttpClient?.close();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    if (widget.username.isEmpty) {
      if (mounted) {
        setState(() {
          isLoading = false;
          hasError = true;
          errorMessage = 'Please log in to view comments';
        });
        _showError('Please log in to view comments');
      }
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
        hasError = false;
      });
    }

    List<Comment> newComments = [];
    final bool online = await _isDeviceOnline();
    bool fetchSuccess = false;
    bool usingCache = false;

    if (online) {
      try {
        final code = await _getThreadCode(widget.thread.id);
        final uri = Uri.parse(
          'https://server.awarcrown.com/threads/comments'
          '?id=${widget.thread.id}'
          '&username=${Uri.encodeComponent(widget.username)}'
          '&limit=1000'
          '&offset=0'
          '${code != null ? '&code=${Uri.encodeComponent(code)}' : ''}',
        );

        final response = await (_commentsHttpClient ?? http.Client())
            .get(uri)
            .timeout(const Duration(seconds: 15));

        debugPrint('Comments response: ${response.body}');
        if (response.statusCode == 200 || response.statusCode == 201) {
          final data = json.decode(response.body);
          final commentList = data['comments'] as List<dynamic>? ?? [];

          for (final dynamic c in commentList) {
            if (c is Map<String, dynamic>) {
              try {
                newComments.add(Comment.fromJson(c, isFromCache: false));
              } catch (e) {
                debugPrint('Error parsing comment: $e');
              }
            }
          }
          fetchSuccess = true;
          _lastCommentCount = newComments.length;
        } else if (response.statusCode == 403) {
          _showError('Access denied. Invalid code for private thread.');
        } else if (response.statusCode == 404) {
          newComments = [];
          _lastCommentCount = 0;
        } else {
          throw Exception(
            'Failed to load comments: ${response.statusCode} - ${response.body}',
          );
        }
      } catch (e) {
        debugPrint('Load comments error: $e');
      }
    }

    if (!online || !fetchSuccess) {
      usingCache = true;
      newComments = List<Comment>.from(comments);
      if (newComments.isEmpty) {
        if (mounted) {
          setState(() {
            isLoading = false;
            hasError = true;
            errorMessage = 'No cached comments. Please connect to internet.';
          });
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        comments = newComments;
        _loadedCommentIds.clear();
        _updateLoadedIdsForList(comments);
        isLoading = false;
        hasError = false;
        _commentsRetryCount = 0;
      });
    }

    if (usingCache && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Showing cached comments. Syncing when online.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _scheduleCommentsRetry() {
    if (_commentsRetryCount >= _commentsMaxRetries) return;
    _commentsRetryTimer?.cancel();
    _commentsRetryCount++;
    final delay = Duration(seconds: 2) * (1 << (_commentsRetryCount - 1));
    _commentsRetryTimer = Timer(delay, () async {
      final bool online = await _isDeviceOnline();
      if (mounted && !isLoading && online) {
        _loadComments();
      }
    });
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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Pick image for comment
  Future<void> _pickImage() async {
    try {
      final XFile? pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedImage != null) {
        final file = File(pickedImage.path);
        final fileSize = await file.length();
        const maxFileSize = 10 * 1024 * 1024; // 10MB

        if (fileSize > maxFileSize) {
          _showError('Image size exceeds 10MB limit');
          return;
        }

        setState(() {
          _selectedImage = file;
        });
      }
    } on PlatformException catch (e) {
      if (e.code == 'photo_access_denied' || e.code == 'camera_access_denied') {
        _showError(
          'Permission denied. Please enable photo access in settings.',
        );
      } else {
        _showError('Error picking image: ${e.message}');
      }
    } catch (e) {
      _showError('Error picking image: ${_getErrorMessage(e)}');
    }
  }

  // Remove selected image
  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _addComment(String body, {int? parentId, File? image}) async {
    final bool online = await _isDeviceOnline();
    if (!online) {
      _showError('Please connect to internet to add comment.');
      return;
    }
    if (widget.username.isEmpty) {
      if (mounted) _showError('Please log in to comment');
      return;
    }
    if (body.trim().isEmpty && image == null) {
      if (mounted) _showError('Comment cannot be empty');
      return;
    }

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final code = await _getThreadCode(widget.thread.id);
      final uri = Uri.parse(
        'https://server.awarcrown.com/threads/comments?id=${widget.thread.id}',
      );

      var request = http.MultipartRequest('POST', uri);
      request.fields['body'] = body.trim();
      request.fields['parent_id'] = (parentId ?? 0).toString();
      request.fields['username'] = widget.username;
      if (code != null) {
        request.fields['code'] = code;
      }

      if (image != null) {
        final fileSize = await image.length();
        const maxFileSize = 10 * 1024 * 1024; // 10MB
        if (fileSize > maxFileSize) {
          throw Exception('Image file is too large (max 10MB)');
        }
        request.files.add(
          await http.MultipartFile.fromPath('image', image.path),
        );
      }

      final streamedResponse = await request.send();
      // ignore: unused_local_variable
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 201) {
        _commentController.clear();
        _commentFocusNode.unfocus();
        await _clearDraft(); // Clear draft after successful submission
        setState(() {
          _replyToCommentId = null;
          _selectedImage = null;
          _isUploadingImage = false;
        });

        // Async update comments without full refresh
        await _pollForNewComments();
        _showSuccess('Comment added successfully!');
      } else {
        throw Exception(
          'Failed to add comment: ${streamedResponse.statusCode}',
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
      });
      if (mounted) _showError('Failed to add comment: ${_getErrorMessage(e)}');
    }
  }

  void _submitComment() {
    if (_commentController.text.trim().isNotEmpty || _selectedImage != null) {
      _addComment(
        _commentController.text,
        parentId: _replyToCommentId,
        image: _selectedImage,
      );
    }
  }

  void _onReplyTapped(Comment comment) {
    setState(() {
      _replyToCommentId = comment.id;
      _commentController.text = '@${comment.commenter} ';
      _commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentController.text.length),
      );
      _commentFocusNode.requestFocus();
    });
  }

  Future<void> _toggleInspire(int threadId) async {
    final bool online = await _isDeviceOnline();
    if (!online) {
      _showError('Please connect to internet to update inspiration.');
      return;
    }
    if (widget.username.isEmpty) return;
    final oldCount = widget.thread.inspiredCount;
    final oldInspired = widget.thread.isInspiredByMe;
    final newInspired = !oldInspired;
    widget.thread.isInspiredByMe = newInspired;
    widget.thread.inspiredCount += newInspired ? 1 : -1;
    if (mounted) setState(() {});
    try {
      final code = await _getThreadCode(threadId);
      final bodyData = json.encode({
        'type': newInspired ? 'inspired' : 'uninspired',
        'username': widget.username,
        if (code != null) 'code': code,
      });
      final uri = Uri.parse(
        'https://server.awarcrown.com/threads/inspire?id=$threadId',
      );
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: bodyData,
          )
          .timeout(const Duration(seconds: 10));
      final prefs = await SharedPreferences.getInstance();
      final key = 'inspired_$threadId';
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (data.containsKey('inspired_count')) {
            widget.thread.inspiredCount = data['inspired_count'];
          }
          if (data.containsKey('user_has_inspired')) {
            widget.thread.isInspiredByMe = data['user_has_inspired'] as bool;
          }
          await prefs.setBool(key, widget.thread.isInspiredByMe);
          _showSuccess(
            data['message'] ??
                (newInspired ? 'Inspired by this discussion!' : 'Uninspired.'),
          );
        } else {
          widget.thread.isInspiredByMe = oldInspired;
          widget.thread.inspiredCount = oldCount;
          await prefs.setBool(key, oldInspired);
          if (mounted) setState(() {});
          _showSuccess(data['message'] ?? 'No change');
        }
      } else {
        throw Exception('Failed to toggle inspire: ${response.statusCode}');
      }
    } catch (e) {
      widget.thread.isInspiredByMe = oldInspired;
      widget.thread.inspiredCount = oldCount;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('inspired_$threadId', oldInspired);
      if (mounted) setState(() {});
      if (mounted) {
        _showError('Failed to toggle inspire: ${_getErrorMessage(e)}');
      }
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildLinearCommentLayout() {
    final bool usingCache = comments.any((c) => c.isFromCache);
    return Column(
      children: [
        if (usingCache)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            color: Colors.orange.withOpacity(0.1),
            child: const Text(
              'Showing cached comments. Syncing when online.',
              style: TextStyle(color: Colors.orange, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ListView.builder(
          itemCount: comments.length,
          controller: _commentsScrollController,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemBuilder: (context, index) {
            final comment = comments[index];
            return _CommentCard(comment: comment, onReply: _onReplyTapped);
          },
        ),
      ],
    );
  }
Widget _buildCommentsSection() {
  if (isLoading) {
    return Column(
      children: List.generate(
        3,
        (index) => Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
            child: const SizedBox(height: 80),
          ),
        ),
      ),
    );
  }

  if (hasError) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 50, color: Colors.red[300]),
            const SizedBox(height: 8),
            Text(errorMessage ?? 'Failed to load comments'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadComments,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  if (comments.isEmpty) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48.0),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.comment_outlined, size: 60, color: Color(0xFF6B7280)),
            const SizedBox(height: 16),
            Text(
              'Be the first to comment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pull up a chair and share your thoughts!',
              style: TextStyle(fontSize: 14, color: _secondaryTextColor),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 FIXED COMMENT LIST (NO LISTVIEW!)
  return Column(
    children: comments.map((c) {
      return _CommentCard(
        comment: c,
        onReply: _onReplyTapped,
      );
    }).toList(),
  );
}

  Widget _buildCommentInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: _cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedImage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      _selectedImage!,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: _removeImage,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blue[100],
                child: Text(
                  widget.username.isNotEmpty
                      ? widget.username[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: _replyToCommentId == null
                        ? 'Pull up a chair...'
                        : 'Replying...',
                    hintStyle: TextStyle(color: _secondaryTextColor),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: Color(0xFF4A90E2),
                        width: 2,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _submitComment(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.image_outlined,
                  color: _selectedImage != null
                      ? Colors.blue
                      : Colors.grey[600],
                ),
                onPressed: _isUploadingImage ? null : _pickImage,
              ),
              IconButton(
                icon: _isUploadingImage
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, color: Color(0xFF4A90E2)),
                onPressed: _isUploadingImage ? null : _submitComment,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _HeaderActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _navigateToProfile(widget.thread.creator),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white.withOpacity(0.3),
            child: Text(
              widget.thread.creator.isNotEmpty
                  ? widget.thread.creator[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => _navigateToProfile(widget.thread.creator),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.thread.creator,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${widget.thread.creatorRole.isNotEmpty ? '${widget.thread.creatorRole} • ' : ''}${widget.thread.createdAt.toString().split(' ')[0]}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: Text(
            widget.thread.category.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTags() {
    if (widget.thread.tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: widget.thread.tags
            .map(
              (t) => Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#$t',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _onRefresh() async {
    if (!_isOnline) {
      if (mounted) {
        _showError('Connect to internet to refresh.');
      }
      return;
    }
    await _loadComments();
  }

  @override
  Widget build(BuildContext context) {
    const Color gradientStart = Color(0xFF6A11CB);
    const Color gradientMid = Color(0xFF2575FC);
    const Color gradientEnd = Color(0xFF00C9FF);

    final bool isInspired = widget.thread.isInspiredByMe;
    final Color inspireColor = isInspired
        ? const Color(0xFFF59E0B)
        : const Color(0xFF90F0C0);
    final bool usingCache = widget.thread.isFromCache;
    return Scaffold(
      backgroundColor: _pageColor,
      body: Column(
        children: [
          if (usingCache)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.orange.withOpacity(0.1),
              child: const Text(
                'Data from cache. Pull to refresh for latest.',
                style: TextStyle(color: Colors.orange, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 400,
                  floating: false,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: gradientStart,
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    background: Hero(
                      tag: 'thread_${widget.thread.id}',
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [gradientStart, gradientMid, gradientEnd],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            MediaQuery.of(context).padding.top + 56,
                            16,
                            16,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeaderInfo(context),
                              const SizedBox(height: 20),
                              Text(
                                widget.thread.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.thread.body,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 15,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 14,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getReadingTime(widget.thread.body),
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              _buildTags(),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _HeaderActionButton(
                                      icon: isInspired
                                          ? Icons.lightbulb
                                          : Icons.lightbulb_outline,
                                      label: '${widget.thread.inspiredCount}',
                                      color: inspireColor,
                                      onTap: () =>
                                          _toggleInspire(widget.thread.id),
                                    ),
                                    _HeaderActionButton(
                                      icon: Icons.comment_outlined,
                                      label: '${widget.thread.commentCount}',
                                      color: const Color(0xFF90F0C0),
                                      onTap: _scrollToComments,
                                    ),
                                    _HeaderActionButton(
                                      icon: Icons.share_outlined,
                                      label: 'Share',
                                      color: Colors.white,
                                      onTap: _shareThread,
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
                ),
                SliverToBoxAdapter(
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: FadeTransition(
                      opacity: _detailFadeAnimation,
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(20, 20, 12, 12),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Discussion',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1a2533),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildCommentsSection(),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (!isLoading && !hasError && widget.username.isNotEmpty)
            _buildCommentInputBar(),
        ],
      ),
    );
  }
}

// URL detection regex
final _urlRegex = RegExp(r'https?://[^\s]+|www\.[^\s]+', caseSensitive: false);

// Extract URLs from text
List<String> _extractUrls(String text) {
  final matches = _urlRegex.allMatches(text);
  return matches.map((match) => match.group(0)!).toList();
}

// Build text spans with highlighted URLs (for SelectableText)
List<TextSpan> _buildTextSpansWithUrls(String text, BuildContext context) {
  final urls = _extractUrls(text);
  if (urls.isEmpty) {
    return [TextSpan(text: text)];
  }

  final List<TextSpan> spans = [];
  int lastIndex = 0;

  for (final url in urls) {
    final urlIndex = text.indexOf(url, lastIndex);
    if (urlIndex == -1) continue;

    // Add text before URL
    if (urlIndex > lastIndex) {
      spans.add(
        TextSpan(
          text: text.substring(lastIndex, urlIndex),
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF333D4B),
            height: 1.5,
          ),
        ),
      );
    }

    // Add URL
    final displayUrl = url.startsWith('www.') ? 'https://$url' : url;
    spans.add(
      TextSpan(
        text: url,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF4A90E2),
          height: 1.5,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w500,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () async {
            final uri = Uri.parse(displayUrl);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
      ),
    );

    lastIndex = urlIndex + url.length;
  }

  // Add remaining text
  if (lastIndex < text.length) {
    spans.add(
      TextSpan(
        text: text.substring(lastIndex),
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFF333D4B),
          height: 1.5,
        ),
      ),
    );
  }

  return spans;
}

// Build text with highlighted URLs (for regular Text widget)
Widget _buildTextWithUrls(String text, BuildContext context) {
  return RichText(
    text: TextSpan(children: _buildTextSpansWithUrls(text, context)),
  );
}

class _CommentCard extends StatefulWidget {
  final Comment comment;
  final bool isReply;
  final Function(Comment) onReply;

  const _CommentCard({
    required this.comment,
    this.isReply = false,
    required this.onReply,
  });

  @override
  State<_CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<_CommentCard> {
  late bool _isExpanded;
  bool _isTextExpanded = false;
  static const int _maxTextLength =
      200; // Characters before showing "Read more"

  @override
  void initState() {
    super.initState();
    _isExpanded = false;
    _isTextExpanded = widget.comment.body.length <= _maxTextLength;
  }

  String get _timeAgo {
    final diff = DateTime.now().difference(widget.comment.createdAt);
    if (diff.inDays >= 365) {
      final years = (diff.inDays / 365).floor();
      return '${years}y';
    } else if (diff.inDays >= 30) {
      final months = (diff.inDays / 30).floor();
      return '${months}mo';
    } else if (diff.inDays >= 1) {
      return '${diff.inDays}d';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes}m';
    } else {
      return 'Just now';
    }
  }

  // Show long press menu
  void _showLongPressMenu(BuildContext context, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Rect.fromLTWH(0, 0, overlay.size.width, overlay.size.height),
      ),
      items: [
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.copy, size: 20),
              SizedBox(width: 8),
              Text('Copy text'),
            ],
          ),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: widget.comment.body));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Comment copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            }
          },
        ),
        PopupMenuItem(
          child: const Row(
            children: [
              Icon(Icons.share, size: 20),
              SizedBox(width: 8),
              Text('Share comment'),
            ],
          ),
          onTap: () async {
            try {
              await Share.share(
                '${widget.comment.commenter}: ${widget.comment.body}',
              );
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to share'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            }
          },
        ),
      ],
    );
  }

  // Show image in full screen
  void _showImageFullScreen(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl:
                    'https://server.awarcrown.com/threads/uploads/$imageUrl',
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(
                    Icons.error_outline,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLongText = widget.comment.body.length > _maxTextLength;
    final displayText = _isTextExpanded || !isLongText
        ? widget.comment.body
        : '${widget.comment.body.substring(0, _maxTextLength)}...';

    return Padding(
      padding: EdgeInsets.only(
        left: widget.isReply ? 32.0 : 16.0,
        right: 16.0,
        top: 12.0,
        bottom: 4.0,
      ),
      child: GestureDetector(
        onLongPressStart: (details) {
          _showLongPressMenu(context, details.globalPosition);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (widget.comment.commenter.isEmpty) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PublicProfilePage(
                          targetUsername: widget.comment.commenter,
                        ),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue[100],
                    child: Text(
                      widget.comment.commenter.isNotEmpty
                          ? widget.comment.commenter[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (widget.comment.commenter.isEmpty) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PublicProfilePage(
                                targetUsername: widget.comment.commenter,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          widget.comment.commenter,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: Color(0xFF1a2533),
                          ),
                        ),
                      ),
                      Text(
                        _timeAgo,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.only(left: 42.0, top: 8, bottom: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.comment.body.isNotEmpty)
                    SelectableText.rich(
                      TextSpan(
                        children: _buildTextSpansWithUrls(displayText, context),
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF333D4B),
                        height: 1.5,
                      ),
                    ),

                  if (isLongText)
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isTextExpanded = !_isTextExpanded;
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _isTextExpanded ? 'Show less' : 'Read more',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4A90E2),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  if (widget.comment.imageUrl != null &&
                      widget.comment.imageUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: GestureDetector(
                        onTap: () => _showImageFullScreen(
                          context,
                          widget.comment.imageUrl!,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl:
                                    'https://server.awarcrown.com/threads/uploads/${widget.comment.imageUrl}',
                                width: double.infinity,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  height: 200,
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 200,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.error_outline),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(
                                    Icons.zoom_in,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(left: 30.0),
              child: TextButton(
                onPressed: () => widget.onReply(widget.comment),
                child: const Text(
                  'Reply',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4A90E2),
                  ),
                ),
              ),
            ),

            if (widget.comment.replies.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 30.0, top: 4.0),
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  icon: Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                  ),
                  label: Text(
                    _isExpanded
                        ? 'Hide replies'
                        : 'View ${widget.comment.replies.length} '
                              '${widget.comment.replies.length > 1 ? 'replies' : 'reply'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A90E2),
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

            if (widget.comment.replies.isNotEmpty && _isExpanded)
              Padding(
                padding: const EdgeInsets.only(left: 12.0, top: 8.0),
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Color(0xFFE5E9F0), width: 2.0),
                    ),
                  ),
                  child: Column(
                    children: widget.comment.replies
                        .map(
                          (reply) => _CommentCard(
                            comment: reply,
                            isReply: true,
                            onReply: widget.onReply,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),

            if (widget.comment.isFromCache)
              const Padding(
                padding: EdgeInsets.only(left: 42.0, top: 4),
                child: Text(
                  'Cached',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
          ], 
        ),
      ),
    );
  }
}
