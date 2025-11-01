import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_test/flutter_test.dart';

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
  String _username = ''; // Store username for display
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadUsername(); // Load username on init
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Show dialog to guide user to settings
  Future<void> _showPermissionSettingsDialog(String permissionName) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permission Denied'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Access to $permissionName was denied. Please enable it in app settings to use this feature.'),
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
      );

      if (pickedImage != null) {
        setState(() {
          _image = File(pickedImage.path);
        });
        _animationController.forward();
      }
    } on PlatformException catch (e) {
      String permissionName = source == ImageSource.camera ? 'camera' : 'photos';
      if (e.code == 'permission' || e.message?.contains('permission') == true) {
        await _showPermissionSettingsDialog(permissionName);
      } else {
        _showSnackBar('Error picking image: ${e.message}');
      }
      debugPrint('Image pick error: $e');
    } catch (e) {
      _showSnackBar('Error picking image: $e');
      debugPrint('Image pick error: $e');
    }
  }

  // Show source selection dialog with better UI
  void _showImageSourceDialog() {
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

  // Enhanced post submission with better validation and progress
  Future<void> _submitPost() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      _showSnackBar('Content cannot be empty');
      return;
    }
    if (content.length > 1000) { // Add character limit
      _showSnackBar('Content too long. Maximum 1000 characters.');
      return;
    }
    if (_username.isEmpty) {
      _showSnackBar('Username not found. Please log in again.');
      return;
    }

    setState(() => _isLoading = true);
    _animationController.reverse();

    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString('username') ?? '';
      final email = prefs.getString('email') ?? '';
      if (username.isEmpty || email.isEmpty) {
        throw Exception('User not logged in');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://server.awarcrown.com/feed/upload_post'),
      );

      request.fields['content'] = content;
      request.fields['visibility'] = _visibility;
      request.fields['username'] = username;
      request.fields['email'] = email;

      if (_image != null) {
        request.files.add(await http.MultipartFile.fromPath('image', _image!.path));
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode != 200) {
        throw Exception('Server error: ${streamedResponse.statusCode} - $responseBody');
      }

      final responseData = json.decode(responseBody);

      if (responseData['status'] == 'success') {
        _showSnackBar(responseData['message'] ?? 'Post created successfully!');
        if (mounted) Navigator.pop(context, true); // Pass success back if needed
      } else {
        final errorMsg = responseData['message'] ?? 'Failed to upload post';
        _showSnackBar(errorMsg);
      }
    } catch (e) {
      _showSnackBar('Error uploading post: $e');
      debugPrint('Upload error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _animationController.forward();
      }
    }
  }

  // Preview widget with animation, full width and higher preview
  Widget _buildImagePreview() {
    if (_image == null) return const SizedBox.shrink();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _image!,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('Image preview error: $error');
                return Container(
                  height: 300,
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, size: 100, color: Colors.grey),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _isLoading ? null : () => setState(() => _image = null),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Post'),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Display username
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_circle, color: Colors.white70),
                    const SizedBox(width: 8),
                    Text(
                      'Posting as: $_username',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _contentController,
                maxLines: 6,
                maxLength: 1000, // Enforce character limit
                decoration: InputDecoration(
                  labelText: "What's on your mind?",
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                  counterText: null, // Hide default counter
                  suffixIcon: Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Text('${_contentController.text.length}/1000'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _visibility,
                decoration: const InputDecoration(
                  labelText: 'Visibility',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'public', child: Text('Public')),
                  DropdownMenuItem(value: 'friends', child: Text('Friends')),
                  DropdownMenuItem(value: 'private', child: Text('Private')),
                ],
                onChanged: _isLoading ? null : (value) => setState(() => _visibility = value!),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _showImageSourceDialog,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('Add Photo'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              _buildImagePreview(),
            ],
          ),
        ),
      ),
    );
  }
}