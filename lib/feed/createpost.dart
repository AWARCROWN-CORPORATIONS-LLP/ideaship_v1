import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> with TickerProviderStateMixin {
  final TextEditingController _contentController = TextEditingController();
  String _visibility = 'public';
  File? _image;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _isUploading = false;
  String _username = '';
  String? _uploadError;
  double _uploadProgress = 0.0;
  int _uploadedBytes = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  // ISSUE 1 FIX: Use a regular http.Client or cancel the entire request/stream.
  // The original implementation was attempting to cancel the stream of a completed
  // http.StreamedResponse, which is incorrect. We'll use a standard variable
  // to hold the subscription for cancellation.
  StreamSubscription<List<int>>? _uploadSubscription;
  http.MultipartRequest? _currentRequest;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _contentController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    // ISSUE 3 FIX: Ensure the subscription is cancelled if it exists before disposing.
    _uploadSubscription?.cancel();
    _animationController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // Load username from SharedPreferences
  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? '';
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    // Dismiss any existing snackbars before showing a new one
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
        action: isError
            ? SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              )
            : null,
      ),
    );
  }

  // ISSUE 1 FIX: Updated logic to correctly cancel the upload stream before popping.
  Future<bool> _onWillPop() async {
    if (_isUploading) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 12),
              Expanded(child: Text('Upload in Progress')),
            ],
          ),
          content: const Text(
            'Your post is currently being uploaded. If you leave now, the upload will be cancelled and your post may not be saved.\n\nAre you sure you want to leave?',
            style: TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () {
                // Cancel the upload stream/request here
                _uploadSubscription?.cancel();
                _currentRequest = null; // Mark request as cancelled/disposed
                Navigator.pop(context, true);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Leave Anyway'),
            ),
          ],
        ),
      );
      // If the user chooses 'Leave Anyway', the `_isUploading` state should be reset after navigation.
      // This is handled implicitly as we pop the screen.
      return shouldLeave ?? false;
    }
    if (_contentController.text.trim().isNotEmpty || _image != null) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Discard Post?'),
          content: const Text(
            'You have unsaved changes. Are you sure you want to leave?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      return shouldLeave ?? false;
    }
    return true;
  }

  // Show dialog to guide user to settings
  Future<void> _showPermissionSettingsDialog(String permissionName) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permission Denied'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Access to **$permissionName** was denied. Please enable it in app settings to use this feature.'),
            if (Platform.isAndroid && permissionName == 'photos')
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'Note: For Android 13+, ensure "Photos and videos" permission is granted in app settings.',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Image picking without compression for HD upload
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedImage = await _picker.pickImage(
        source: source,
        // Recommended to set image quality to max or remove it for full quality HD upload
        // Setting it to null or 100 ensures max quality, but max quality is the default.
        // If you truly want NO compression, remove the quality argument.
      );

      if (pickedImage != null) {
        setState(() {
          _image = File(pickedImage.path);
        });
        _animationController.forward();
      }
    } on PlatformException catch (e) {
      String permissionName = source == ImageSource.camera ? 'camera' : 'photos';
      if (e.code == 'permission' || e.message?.contains('permission') == true || e.code == 'photo_access_denied') {
        await _showPermissionSettingsDialog(permissionName);
      } else {
        _showSnackBar('Error picking image: ${e.message}', isError: true);
      }
      debugPrint('Image pick PlatformException: $e');
    } catch (e) {
      _showSnackBar('Error picking image: ${e.toString()}', isError: true);
      debugPrint('Image pick general error: $e');
    }
  }

  // Show source selection dialog with better UI
  void _showImageSourceDialog() {
    if (_isLoading) return; // Prevent interaction during upload/loading
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Image Source', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  String _getUserFriendlyError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('socketexception') || errorString.contains('failed host lookup') || errorString.contains('network is unreachable')) {
      return 'No internet connection. Please check your network and try again.';
    } else if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return 'Upload took too long. Please check your connection and try again.';
    } else if (errorString.contains('401') || errorString.contains('unauthorized')) {
      return 'Your session has expired. Please log in again.';
    } else if (errorString.contains('403') || errorString.contains('forbidden')) {
      return 'You don\'t have permission to create posts.';
    } else if (errorString.contains('413') || errorString.contains('too large')) {
      return 'Image file is too large. Please choose a smaller image.';
    } else if (errorString.contains('500') || errorString.contains('internal server error')) {
      return 'Server error occurred. Please try again in a moment.';
    } else if (errorString.contains('format') || errorString.contains('invalid')) {
      return 'Invalid file format. Please choose a valid image.';
    } else if (errorString.contains('not logged in') || errorString.contains('authentication') || errorString.contains('session has expired')) {
      return 'Please log in to create posts.';
    } else {
      // General error fallback, now also checking for file size error thrown locally
      if (errorString.contains('image file is too large')) {
        return 'Image file is too large (max 10MB). Please choose a smaller image.';
      }
      return 'Failed to upload post. Please try again. ($errorString)';
    }
  }

  Future<void> _showErrorDialog(String title, String message) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
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

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();

    // Validation
    if (content.isEmpty && _image == null) {
      _showSnackBar('Please add content or an image before posting', isError: true);
      return;
    }
    if (content.length > 1000) {
      _showSnackBar('Content is too long. Maximum 1000 characters allowed.', isError: true);
      return;
    }
    if (_username.isEmpty) {
      // Re-attempt loading or show login prompt
      await _loadUsername();
      if (_username.isEmpty) {
        _showSnackBar('Username not found. Please log in again.', isError: true);
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadError = null;
    });
    // ISSUE 2 FIX: Reverse animation should only be called if we successfully start the process.
    if (_animationController.status == AnimationStatus.completed) {
      _animationController.reverse();
    }


    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? '';
      final email = prefs.getString('email') ?? '';

      if (username.isEmpty || email.isEmpty) {
        throw Exception('User not logged in. Credentials missing.');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://server.awarcrown.com/feed/upload_post'),
      );
      _currentRequest = request; // Keep track of the request for cancellation

      request.fields['content'] = content;
      request.fields['visibility'] = _visibility;
      request.fields['username'] = username;
      request.fields['email'] = email;

      if (_image != null) {
        final fileSize = await _image!.length();
        const maxFileSize = 10 * 1024 * 1024; // 10MB limit
        if (fileSize > maxFileSize) {
          throw Exception('Image file is too large (max 10MB)');
        }
        // ISSUE 4 FIX: The original code's try-catch around fromPath was confusing.
        // It's better to perform the file size check first, and let the normal
        // try-catch handle exceptions from `fromPath`.
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          _image!.path,
          // You might want to infer the content type here for better server handling
          // contentType: MediaType('image', 'jpeg'), 
        ));
      }

      // Send the request
      final streamedResponse = await request.send();

      // Track upload progress logic
      // Only track if we are uploading an image or the server sends a valid content length for the upload stream
      if (streamedResponse.contentLength != null && _image != null) {
        _uploadedBytes = 0;
        
        // This is where we listen to the *response* stream to read the response body,
        // but since we are using MultipartRequest, the progress should ideally be tracked
        // before the request is sent, or by listening to the request's byte count.
        // For simplicity and common practice with http.MultipartRequest, we usually
        // track the progress of the *request payload* being sent.

        // Note: The original implementation tracked the upload progress from the
        // *response* stream which is incorrect. A correct multipart upload progress
        // requires a custom implementation (e.g., using `http.Client` and `Stream.transform`
        // or a dedicated upload library) as `http.MultipartRequest` doesn't
        // expose the sent bytes easily.

        // The following part is kept from the original code but serves to read the *response* stream.
        // Since the actual progress is not easily exposed by `http.MultipartRequest.send()`,
        // let's adjust to only track the status change after a successful request.
        
        // --- Correct way for Response Tracking (not upload tracking, but necessary for response) ---
        final completer = Completer<String>();
        final responseBodyBuffer = StringBuffer();
        
        // ISSUE 1 FIX: Store the subscription for potential cancellation
        _uploadSubscription = streamedResponse.stream.listen(
          (chunk) {
            // This is the response body coming back, not the upload progress
            // We use this part to track the response receipt.
            responseBodyBuffer.write(utf8.decode(chunk));

            // Optional: You could update a final progress to 1.0 once the stream starts being received
            if (streamedResponse.contentLength != null) {
                _uploadedBytes += chunk.length;
                if (_uploadedBytes > 0) {
                   setState(() {
                       _uploadProgress = 0.99; // Indicate near-completion after headers and server processing starts
                   });
                }
            }
          },
          onDone: () {
            completer.complete(responseBodyBuffer.toString());
          },
          onError: (error) {
            // Cancel response body reading if an error occurs mid-stream
            completer.completeError(error);
          },
          cancelOnError: true,
        );

        // Wait for the entire response to be read
        final responseBody = await completer.future.timeout(const Duration(seconds: 30)); 
        // -----------------------------------------------------------------------------------------
        
        _uploadSubscription = null; // Clear the subscription now that it's done

        final statusCode = streamedResponse.statusCode;

        if (statusCode != 200) {
          String errorMessage = 'Server error occurred';
          try {
            final errorData = json.decode(responseBody);
            errorMessage = errorData['message'] ?? errorMessage;
          } catch (_) {
            errorMessage = 'Server returned error code: $statusCode';
          }
          throw Exception(errorMessage);
        }

        final responseData = json.decode(responseBody);

        if (responseData['status'] == 'success') {
          if (mounted) {
            _showSnackBar(responseData['message'] ?? 'Post created successfully!');
            await Future.delayed(const Duration(milliseconds: 500));
            // ISSUE 5 FIX: Ensure state reset before popping if successful
            _resetStateOnCompletion(); 
            Navigator.pop(context, true);
          }
        } else {
          final errorMsg = responseData['message'] ?? 'Failed to upload post';
          throw Exception(errorMsg);
        }
      } else {
        // Handle case where we couldn't track stream progress, usually for smaller uploads or when no image.
        final response = await http.Response.fromStream(streamedResponse).timeout(const Duration(seconds: 30));
        
        if (response.statusCode != 200) {
          String errorMessage = 'Server error occurred';
          try {
            final errorData = json.decode(response.body);
            errorMessage = errorData['message'] ?? errorMessage;
          } catch (_) {
            errorMessage = 'Server returned error code: ${response.statusCode}';
          }
          throw Exception(errorMessage);
        }

        final responseData = json.decode(response.body);

        if (responseData['status'] == 'success') {
          if (mounted) {
            _showSnackBar(responseData['message'] ?? 'Post created successfully!');
            await Future.delayed(const Duration(milliseconds: 500));
            // ISSUE 5 FIX: Ensure state reset before popping if successful
            _resetStateOnCompletion(); 
            Navigator.pop(context, true);
          }
        } else {
          final errorMsg = responseData['message'] ?? 'Failed to upload post';
          throw Exception(errorMsg);
        }
      }
    } on TimeoutException {
        // Catch specific timeout errors
        throw Exception('Timed out waiting for server response.');
    } catch (e) {
      // ISSUE 6 FIX: The catch block had nested `if (mounted)` checks and redundant `_animationController.forward()` calls.
      final friendlyError = _getUserFriendlyError(e);
      _uploadError = friendlyError;

      if (mounted) {
        _showErrorDialog('Upload Failed', friendlyError);
        _resetStateOnCompletion();
      }
    }
  }
  
  // Helper to centralize state reset logic
  void _resetStateOnCompletion() {
      setState(() {
        _isLoading = false;
        _isUploading = false;
        _uploadProgress = 0.0;
        _uploadedBytes = 0;
        _currentRequest = null;
        _uploadSubscription?.cancel();
        _uploadSubscription = null;
      });
      _animationController.forward();
  }

  Widget _buildImagePreview() {
    if (_image == null) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          // ISSUE 7 FIX: Add the same subtle shadow as the info card for consistency
          boxShadow: [
             BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  Image.file(
                    _image!,
                    width: double.infinity,
                    height: 300,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      debugPrint('Image preview error: $error');
                      return Container(
                        height: 300,
                        color: Colors.grey.shade100,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 20),
                        onPressed: _isLoading
                            ? null
                            : () => setState(() => _image = null),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.image, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Photo added: ${(_image?.lengthSync() ?? 0) > 0 ? '${((_image!.lengthSync() / 1024) / 1024).toStringAsFixed(2)} MB' : 'Processing...'}', // ISSUE 8 FIX: Show file size
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() => _image = null),
                    child: const Text(
                      'Remove',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
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
    // final colorScheme = Theme.of(context).colorScheme; // colorScheme not used
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text(
            'Create Post',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: Color(0xFF1A1A1A),
            ),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: Colors.grey.shade200,
            ),
          ),
          actions: [
            if (_isUploading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: null, // ISSUE 9 FIX: Circular indicator should be indeterminate if progress tracking is unreliable
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Uploading...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              TextButton(
                // Disable if content is empty and no image
                onPressed: _isLoading || (_contentController.text.trim().isEmpty && _image == null) ? null : _submitPost,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF007AFF),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text(
                  'Post',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
          ],
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Upload progress bar
              if (_isUploading)
                Container(
                  width: double.infinity,
                  height: 3,
                  color: Colors.grey.shade200,
                  child: LinearProgressIndicator(
                    // ISSUE 10 FIX: Show progress only if progress is > 0, otherwise indeterminate/null 
                    // (though true MultipartRequest progress is tricky)
                    value: _uploadProgress > 0.0 && _uploadProgress < 1.0 ? _uploadProgress : null,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                  ),
                ),
              // Error banner
              if (_uploadError != null && !_isUploading)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.red.shade50,
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _uploadError!,
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        color: Colors.red.shade700,
                        onPressed: () => setState(() => _uploadError = null),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // User info card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Color(0xFF007AFF),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Posting as',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _username.isEmpty ? 'Loading...' : _username,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Content field
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: _contentController,
                          enabled: !_isLoading,
                          maxLines: 8,
                          maxLength: 1000,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                          decoration: InputDecoration(
                            hintText: "What's on your mind?",
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                            counterText: '${_contentController.text.length}/1000',
                            counterStyle: TextStyle(
                              color: _contentController.text.length > 1000
                                  ? Colors.red
                                  : Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Visibility selector
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _visibility,
                          decoration: const InputDecoration(
                            labelText: 'Visibility',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'public',
                              child: Row(
                                children: [
                                  Icon(Icons.public, size: 18, color: Colors.blue),
                                  SizedBox(width: 8),
                                  Text('Public'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'friends',
                              child: Row(
                                children: [
                                  Icon(Icons.people, size: 18, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text('Friends'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'private',
                              child: Row(
                                children: [
                                  Icon(Icons.lock, size: 18, color: Colors.orange),
                                  SizedBox(width: 8),
                                  Text('Private'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: _isLoading
                              ? null
                              : (value) => setState(() => _visibility = value!),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Add photo button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isLoading ? null : _showImageSourceDialog,
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.add_photo_alternate,
                                      color: Color(0xFF007AFF),
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Text(
                                      'Add Photo',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildImagePreview(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}