import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';

class UserProfile extends StatefulWidget {
  const UserProfile({super.key});

  @override
  State<UserProfile> createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  String? _username;
  String? _email;
  String? _role;
  String? _profilePicture;
  Map<String, dynamic>? _profileData;
  bool _isDarkMode = false;
  bool _isLoading = true;
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  XFile? _selectedImage;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _expandedSections = {
    'basic': true,
    'personal': true,
    'education': true,
    'preferences': true,
    'company': true,
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isDarkMode = prefs.getBool('isDarkMode') ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
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
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() {
            _profileData = jsonResponse['data'] as Map<String, dynamic>?;
            _role = _profileData?['role']?.toString();
            // Construct full profile picture URL from profile_path
            final profilePath = _profileData?['profile_picture']?.toString();
            _profilePicture = profilePath != null && profilePath.isNotEmpty
                ? 'https://server.awarcrown.com/accessprofile/uploads/$profilePath'
                : null;
            _username = _profileData?['username']?.toString() ?? _username;
            _email = _profileData?['email']?.toString() ?? _email;
            _controllers.clear();
            // Common fields
            _controllers['role'] = TextEditingController(text: _role ?? '');
            _controllers['full_name'] = TextEditingController(text: _profileData?['full_name']?.toString() ?? '');
            _controllers['email'] = TextEditingController(text: _profileData?['email']?.toString() ?? '');
            _controllers['phone'] = TextEditingController(text: _profileData?['phone']?.toString() ?? '');
            _controllers['dob'] = TextEditingController(text: _profileData?['dob']?.toString() ?? '');
            _controllers['address'] = TextEditingController(text: _profileData?['address']?.toString() ?? '');
            _controllers['nationality'] = TextEditingController(text: _profileData?['nationality']?.toString() ?? '');
            if (_role == 'student') {
              _controllers['student_id'] = TextEditingController(text: _profileData?['student_id']?.toString() ?? '');
              _controllers['institution'] = TextEditingController(text: _profileData?['institution']?.toString() ?? '');
              _controllers['linkedin'] = TextEditingController(text: _profileData?['linkedin']?.toString() ?? '');
              _controllers['academic_level'] = TextEditingController(text: _profileData?['academic_level']?.toString() ?? '');
              _controllers['major'] = TextEditingController(text: _profileData?['major']?.toString() ?? '');
              _controllers['portfolio'] = TextEditingController(text: _profileData?['portfolio']?.toString() ?? '');
              _controllers['skills_dev'] = TextEditingController(text: _profileData?['skills_dev']?.toString() ?? '');
              _controllers['interests'] = TextEditingController(text: _profileData?['interests']?.toString() ?? '');
              _controllers['expected_passout_year'] = TextEditingController(text: _profileData?['expected_passout_year']?.toString() ?? '');
            } else if (_role == 'Company/HR') {
              _controllers['company_name'] = TextEditingController(text: _profileData?['company_name']?.toString() ?? '');
              _controllers['contact_person_name'] = TextEditingController(text: _profileData?['contact_person_name']?.toString() ?? '');
              _controllers['contact_designation'] = TextEditingController(text: _profileData?['contact_designation']?.toString() ?? '');
              _controllers['contact_email'] = TextEditingController(text: _profileData?['contact_email']?.toString() ?? '');
              _controllers['contact_phone'] = TextEditingController(text: _profileData?['contact_phone']?.toString() ?? '');
              _controllers['company_address'] = TextEditingController(text: _profileData?['company_address']?.toString() ?? '');
              _controllers['industry'] = TextEditingController(text: _profileData?['industry']?.toString() ?? '');
              _controllers['company_size'] = TextEditingController(text: _profileData?['company_size']?.toString() ?? '');
              _controllers['website'] = TextEditingController(text: _profileData?['website']?.toString() ?? '');
              _controllers['linkedin_profile'] = TextEditingController(text: _profileData?['linkedin_profile']?.toString() ?? '');
              _controllers['budget'] = TextEditingController(text: _profileData?['budget']?.toString() ?? '');
              _controllers['company_culture'] = TextEditingController(text: _profileData?['company_culture']?.toString() ?? '');
              _controllers['preferred_talent_sources'] = TextEditingController(text: _profileData?['preferred_talent_sources']?.toString() ?? '');
              _controllers['training_programs'] = TextEditingController(text: _profileData?['training_programs']?.toString() ?? '');
              _controllers['candidate_preferences'] = TextEditingController(text: _profileData?['candidate_preferences']?.toString() ?? '');
              _controllers['diversity_goals'] = TextEditingController(text: _profileData?['diversity_goals']?.toString() ?? '');
              _controllers['location_preferences'] = TextEditingController(text: _profileData?['location_preferences']?.toString() ?? '');
              _controllers['business_registration'] = TextEditingController(text: _profileData?['business_registration']?.toString() ?? '');
              _controllers['authorized_signatory'] = TextEditingController(text: _profileData?['authorized_signatory']?.toString() ?? '');
              _controllers['ein'] = TextEditingController(text: _profileData?['ein']?.toString() ?? '');
              _controllers['reference_contact'] = TextEditingController(text: _profileData?['reference_contact']?.toString() ?? '');
              _controllers['website_domain_verification'] = TextEditingController(text: _profileData?['website_domain_verification']?.toString() ?? '');
              _controllers['email_verification'] = TextEditingController(text: _profileData?['email_verification']?.toString() ?? '');
            }
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
        _showErrorDialog('Error loading profile: $e');
      }
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

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(jsonResponse['message'] ?? 'Profile updated successfully'),
              backgroundColor: _buildColorScheme().primary,
            ),
          );
          setState(() => _isEditing = false);
          await _loadUserData();
        } else {
          _showErrorDialog(jsonResponse['message'] ?? 'Failed to update profile');
        }
      } else {
        _showErrorDialog('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('Error updating profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
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
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      _showErrorDialog('Error picking image: $e');
    }
  }

  Future<void> _uploadProfilePicture() async {
    if (_selectedImage == null || _username == null) {
      _showErrorDialog('No image selected or user not logged in');
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('Uploading image from path: ${_selectedImage!.path}');
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
          _showErrorDialog('Unsupported file type: $fileExtension. Only JPG, PNG, or GIF allowed.');
          setState(() => _isLoading = false);
          return;
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'profile_picture',
          _selectedImage!.path,
          contentType: MediaType.parse(mimeType),
        ),
      );

      final response = await request.send().timeout(const Duration(seconds: 15));
      final responseBody = await response.stream.bytesToString();

      debugPrint('Response headers: ${response.headers}');
      debugPrint('Response body: $responseBody');

      if (response.headers['content-type']?.contains('application/json') != true) {
        debugPrint('Non-JSON response received: $responseBody');
        _showErrorDialog('Server returned an unexpected response (Status: ${response.statusCode}). Please check the server configuration.');
        setState(() => _isLoading = false);
        return;
      }

      final jsonResponse = json.decode(responseBody);

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        setState(() {
          // Construct full profile picture URL from profile_path
          final profilePath = jsonResponse['profile_path']?.toString();
          _profilePicture = profilePath != null && profilePath.isNotEmpty
              ? 'https://server.awarcrown.com/accessprofile/uploads/$profilePath'
              : null;
          _selectedImage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(jsonResponse['message'] ?? 'Profile picture updated successfully'),
            backgroundColor: _buildColorScheme().primary,
          ),
        );
      } else {
        _showErrorDialog(jsonResponse['message'] ?? 'Failed to upload profile picture: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error uploading profile picture: $e');
      _showErrorDialog('Error uploading profile picture: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Error', style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  ColorScheme _buildColorScheme() {
    final primaryColor = const Color(0xFF0077B5);
    return _isDarkMode
        ? ColorScheme.dark(
            primary: primaryColor,
            onPrimary: Colors.white,
            surface: const Color(0xFF1A1A1A),
            onSurface: Colors.white,
            surfaceContainer: const Color(0xFF2A2A2A),
            onSurfaceVariant: Colors.grey[400]!,
            outline: Colors.grey[700]!,
            error: Colors.redAccent,
            onError: Colors.white,
            secondary: Colors.grey[600]!,
            onSecondary: Colors.white,
          )
        : ColorScheme.light(
            primary: primaryColor,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black87,
            surfaceContainer: Colors.grey[50]!,
            onSurfaceVariant: Colors.black54,
            outline: Colors.grey[300]!,
            error: Colors.redAccent,
            onError: Colors.white,
            secondary: Colors.grey[600]!,
            onSecondary: Colors.white,
          );
  }

  Widget _buildProfileField(String label, dynamic value, String fieldKey,
      {bool isRequired = false, bool isMultiline = false, bool isNumeric = false, bool alwaysReadOnly = false, String? Function(String? value)? customValidator}) {
    final colorScheme = _buildColorScheme();
    final effectiveReadOnly = alwaysReadOnly || !_isEditing;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextFormField(
        controller: _controllers[fieldKey],
        maxLines: isMultiline ? 3 : 1,
        readOnly: effectiveReadOnly,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumeric
            ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))]
            : fieldKey == 'phone' || fieldKey == 'contact_phone'
                ? [FilteringTextInputFormatter.allow(RegExp(r'^\+?[\d\s-]*$'))]
                : null,
        decoration: InputDecoration(
          labelText: label + (isRequired && !effectiveReadOnly ? ' *' : ''),
          labelStyle: TextStyle(
            color: effectiveReadOnly ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: effectiveReadOnly ? colorScheme.surfaceContainer : colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outline, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outline, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.error, width: 1),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outline, width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          errorStyle: TextStyle(color: colorScheme.error, fontSize: 12),
        ),
        style: TextStyle(
          fontSize: 16,
          color: effectiveReadOnly ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
        ),
        validator: effectiveReadOnly ? null : (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return '$label is required';
          }
          if (isNumeric && value != null && double.tryParse(value) == null) {
            return '$label must be a valid number';
          }
          if (customValidator != null) {
            return customValidator(value);
          }
          return null;
        },
        autovalidateMode: effectiveReadOnly ? AutovalidateMode.disabled : AutovalidateMode.onUserInteraction,
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> fields, String sectionKey, {IconData? icon}) {
    final colorScheme = _buildColorScheme();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        initiallyExpanded: _expandedSections[sectionKey] ?? false,
        onExpansionChanged: (expanded) {
          setState(() {
            _expandedSections[sectionKey] = expanded;
          });
        },
        leading: icon != null ? Icon(icon, color: colorScheme.primary, size: 24) : null,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        children: fields,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16.0),
        childrenPadding: const EdgeInsets.all(16.0),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildPersonalDetailsTab() {
    final colorScheme = _buildColorScheme();
    return RefreshIndicator(
      onRefresh: _loadUserData,
      color: colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isDarkMode
                      ? [Colors.black87, Colors.grey[900]!]
                      : [Colors.blue[50]!, Colors.white],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16.0),
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: colorScheme.primary,
                    backgroundImage: _selectedImage != null
                        ? FileImage(File(_selectedImage!.path))
                        : _profilePicture != null
                            ? NetworkImage(_profilePicture!)
                            : null,
                    child: _profilePicture == null && _selectedImage == null
                        ? Text(
                            _username?.isNotEmpty == true ? _username!.substring(0, 1).toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 40, color: Colors.white),
                          )
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _username ?? 'User',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _email ?? 'Not specified',
                    style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _role == 'student'
                        ? '${_profileData?['major'] ?? 'Student'} at ${_profileData?['institution'] ?? 'Not specified'}'
                        : '${_profileData?['contact_designation'] ?? 'HR'} at ${_profileData?['company_name'] ?? 'Not specified'}',
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                  ),
                  if (_isEditing) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _pickImage();
                        },
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Select Profile Picture'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (_selectedImage != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _uploadProfilePicture();
                          },
                          icon: const Icon(Icons.save),
                          label: const Text('Save Profile Picture'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_profileData != null) ...[
                    _buildSection(
                      'Basic Information',
                      [
                        _buildProfileField(
                          'Role',
                          _role ?? 'Not specified',
                          'role',
                          isRequired: true,
                          alwaysReadOnly: true,
                          customValidator: (value) => value != 'student' && value != 'Company/HR' ? 'Role must be "student" or "Company/HR"' : null,
                        ),
                        _buildProfileField('Full Name', _profileData?['full_name'] ?? 'Not specified', 'full_name', isRequired: true),
                        if (_role == 'student')
                          _buildProfileField('Student ID', _profileData?['student_id'] ?? 'Not specified', 'student_id', isRequired: true),
                      ],
                      'basic',
                      icon: Icons.info_outline,
                    ),
                    _buildSection(
                      'Personal Information',
                      [
                        _buildProfileField(
                          'Email',
                          _profileData?['email'] ?? 'Not specified',
                          'email',
                          alwaysReadOnly: true,
                          customValidator: (value) => value != null && value.isNotEmpty && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value) ? 'Enter valid email' : null,
                        ),
                        _buildProfileField(
                          'Phone',
                          _profileData?['phone'] ?? 'Not specified',
                          'phone',
                          alwaysReadOnly: true,
                          customValidator: (value) => value != null && value.isNotEmpty && !RegExp(r'^\+\d{10,15}$').hasMatch(value) ? 'Enter valid phone number (e.g., +1234567890)' : null,
                        ),
                        _buildProfileField(
                          'Date of Birth',
                          _profileData?['dob'] ?? 'Not specified',
                          'dob',
                          customValidator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                              if (!regex.hasMatch(value)) return 'Enter valid date (YYYY-MM-DD)';
                              final parts = value.split('-');
                              final year = int.tryParse(parts[0]);
                              if (year == null || year < 1900 || year > DateTime.now().year) return 'Invalid year';
                            }
                            return null;
                          },
                        ),
                        _buildProfileField('Address', _profileData?['address'] ?? 'Not specified', 'address', isMultiline: true),
                        _buildProfileField('Nationality', _profileData?['nationality'] ?? 'Not specified', 'nationality'),
                      ],
                      'personal',
                      icon: Icons.person_outline,
                    ),
                    if (_role == 'student') ...[
                      _buildSection(
                        'Education',
                        [
                          _buildProfileField('Institution', _profileData?['institution'] ?? 'Not specified', 'institution', alwaysReadOnly: true),
                          _buildProfileField('Academic Level', _profileData?['academic_level'] ?? 'Not specified', 'academic_level', alwaysReadOnly: true),
                          _buildProfileField('Major', _profileData?['major'] ?? 'Not specified', 'major', alwaysReadOnly: true),
                          _buildProfileField(
                            'Expected Passout Year',
                            _profileData?['expected_passout_year'] ?? 'Not specified',
                            'expected_passout_year',
                            isNumeric: true,
                            alwaysReadOnly: true,
                            customValidator: (value) {
                              if (value != null && value.isNotEmpty) {
                                final year = int.tryParse(value);
                                if (year == null || year < DateTime.now().year || year > DateTime.now().year + 10) {
                                  return 'Enter a valid year (${DateTime.now().year}-${DateTime.now().year + 10})';
                                }
                              }
                              return null;
                            },
                          ),
                          _buildProfileField(
                            'LinkedIn',
                            _profileData?['linkedin'] ?? 'Not specified',
                            'linkedin',
                            customValidator: (value) => value != null && value.isNotEmpty && !RegExp(r'^https?://(www\.)?linkedin\.com/.+$').hasMatch(value)
                                ? 'Enter valid LinkedIn URL'
                                : null,
                          ),
                          _buildProfileField(
                            'Portfolio',
                            _profileData?['portfolio'] ?? 'Not specified',
                            'portfolio',
                            customValidator: (value) => value != null && value.isNotEmpty && !RegExp(r'^https?://.+$').hasMatch(value) ? 'Enter valid URL' : null,
                          ),
                        ],
                        'education',
                        icon: Icons.school_outlined,
                      ),
                      _buildSection(
                        'Preferences & Other',
                        [
                          _buildProfileField('Skills Development', _profileData?['skills_dev'] ?? 'Not specified', 'skills_dev', isMultiline: true),
                          _buildProfileField('Interests', _profileData?['interests'] ?? 'Not specified', 'interests', isMultiline: true),
                        ],
                        'preferences',
                        icon: Icons.favorite_outline,
                      ),
                    ] else if (_role == 'Company/HR') ...[
                      _buildSection(
                        'Company Details',
                        [
                          _buildProfileField('Company Name', _profileData?['company_name'] ?? 'Not specified', 'company_name', isRequired: true),
                          _buildProfileField('Contact Person Name', _profileData?['contact_person_name'] ?? 'Not specified', 'contact_person_name'),
                          _buildProfileField('Contact Designation', _profileData?['contact_designation'] ?? 'Not specified', 'contact_designation'),
                          _buildProfileField(
                            'Contact Email',
                            _profileData?['contact_email'] ?? 'Not specified',
                            'contact_email',
                            alwaysReadOnly: true,
                            customValidator: (value) => value != null && value.isNotEmpty && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value) ? 'Enter valid email' : null,
                          ),
                          _buildProfileField(
                            'Contact Phone',
                            _profileData?['contact_phone'] ?? 'Not specified',
                            'contact_phone',
                            alwaysReadOnly: true,
                            customValidator: (value) => value != null && value.isNotEmpty && !RegExp(r'^\+\d{10,15}$').hasMatch(value) ? 'Enter valid phone number (e.g., +1234567890)' : null,
                          ),
                          _buildProfileField('Company Address', _profileData?['company_address'] ?? 'Not specified', 'company_address', isMultiline: true),
                          _buildProfileField('Industry', _profileData?['industry'] ?? 'Not specified', 'industry'),
                          _buildProfileField(
                            'Company Size',
                            _profileData?['company_size'] ?? 'Not specified',
                            'company_size',
                            isNumeric: true,
                            customValidator: (value) => value != null && value.isNotEmpty && (int.tryParse(value) == null || int.parse(value) < 0)
                                ? 'Enter valid company size'
                                : null,
                          ),
                          _buildProfileField(
                            'Website',
                            _profileData?['website'] ?? 'Not specified',
                            'website',
                            customValidator: (value) => value != null && value.isNotEmpty && !RegExp(r'^https?://.+$').hasMatch(value) ? 'Enter valid URL' : null,
                          ),
                          _buildProfileField(
                            'LinkedIn Profile',
                            _profileData?['linkedin_profile'] ?? 'Not specified',
                            'linkedin_profile',
                            customValidator: (value) => value != null && value.isNotEmpty && !RegExp(r'^https?://(www\.)?linkedin\.com/.+$').hasMatch(value)
                                ? 'Enter valid LinkedIn URL'
                                : null,
                          ),
                          _buildProfileField(
                            'Budget',
                            _profileData?['budget'] ?? 'Not specified',
                            'budget',
                            isNumeric: true,
                            customValidator: (value) => value != null && value.isNotEmpty && (double.tryParse(value) == null || double.parse(value) < 0)
                                ? 'Enter valid budget'
                                : null,
                          ),
                          _buildProfileField('Company Culture', _profileData?['company_culture'] ?? 'Not specified', 'company_culture', isMultiline: true),
                          _buildProfileField('Preferred Talent Sources', _profileData?['preferred_talent_sources'] ?? 'Not specified', 'preferred_talent_sources', isMultiline: true),
                          _buildProfileField('Training Programs', _profileData?['training_programs'] ?? 'Not specified', 'training_programs', isMultiline: true),
                        ],
                        'company',
                        icon: Icons.business_outlined,
                      ),
                      _buildSection(
                        'Preferences & Compliance',
                        [
                          _buildProfileField('Candidate Preferences', _profileData?['candidate_preferences'] ?? 'Not specified', 'candidate_preferences', isMultiline: true),
                          _buildProfileField('Diversity Goals', _profileData?['diversity_goals'] ?? 'Not specified', 'diversity_goals', isMultiline: true),
                          _buildProfileField('Location Preferences', _profileData?['location_preferences'] ?? 'Not specified', 'location_preferences'),
                          _buildProfileField('Business Registration', _profileData?['business_registration'] ?? 'Not specified', 'business_registration'),
                          _buildProfileField('Authorized Signatory', _profileData?['authorized_signatory'] ?? 'Not specified', 'authorized_signatory'),
                          _buildProfileField('EIN', _profileData?['ein'] ?? 'Not specified', 'ein'),
                          _buildProfileField('Reference Contact', _profileData?['reference_contact'] ?? 'Not specified', 'reference_contact'),
                          _buildProfileField('Website Domain Verification', _profileData?['website_domain_verification'] ?? 'Not specified', 'website_domain_verification'),
                          _buildProfileField('Email Verification', _profileData?['email_verification'] ?? 'Not specified', 'email_verification'),
                        ],
                        'preferences',
                        icon: Icons.verified_user_outlined,
                      ),
                    ],
                  ],
                  if (_isEditing) ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                _updateProfile();
                              },
                              icon: const Icon(Icons.save),
                              label: const Text('Save Profile'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.primary,
                                foregroundColor: colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _isEditing = false;
                                  _selectedImage = null;
                                });
                                _controllers.forEach((key, controller) {
                                  controller.text = _profileData?[key]?.toString() ?? '';
                                });
                              },
                              icon: const Icon(Icons.cancel),
                              label: const Text('Cancel'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: colorScheme.primary,
                                side: BorderSide(color: colorScheme.primary, width: 1.5),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = _buildColorScheme();
    final themeData = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
    );

    return Theme(
      data: themeData,
      child: Scaffold(
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
            : CustomScrollView(
                slivers: [
                  SliverAppBar(
                    floating: false,
                    pinned: true,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                    ),
                    title: Text(
                      'Profile',
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    actions: [
                      if (!_isLoading && _profileData != null)
                        IconButton(
                          icon: Icon(_isEditing ? Icons.save : Icons.edit),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            if (_isEditing) {
                              _updateProfile();
                            } else {
                              setState(() => _isEditing = true);
                            }
                          },
                        ),
                    ],
                  ),
                  SliverFillRemaining(
                    child: _buildPersonalDetailsTab(),
                  ),
                ],
              ),
        floatingActionButton: !_isEditing && !_isLoading && _profileData != null
            ? FloatingActionButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  setState(() => _isEditing = true);
                },
                backgroundColor: colorScheme.primary,
                child: const Icon(Icons.edit),
              )
            : null,
      ),
    );
  }
}