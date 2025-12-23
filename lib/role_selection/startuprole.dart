// ignore_for_file: unused_field
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../dashboard.dart';

class StartupRolePage extends StatefulWidget {
  final String? initialUsername;
  final String? initialEmail;
  final String? initialId;

  const StartupRolePage({
    super.key,
    this.initialUsername,
    this.initialEmail,
    this.initialId,
  });

  @override
  State<StartupRolePage> createState() => _StartupRolePageState();
}

class _StartupRolePageState extends State<StartupRolePage> with TickerProviderStateMixin {
  int _currentStep = 0;
  late PageController _pageController;
  late List<GlobalKey<FormState>> _formKeys;

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  List<TextEditingController> _founderControllers = [];
  final _startupNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _industryController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _foundingDateController = TextEditingController();
  final _stageController = TextEditingController();
  final _highlightsController = TextEditingController();

  String? _logoPath;
  String _username = '';
  String _email = '';
  String _id = '';
  bool _isLoading = false;

  final List<String> industries = [
    'Fintech',
    'Healthtech',
    'Edtech',
    'Agritech',
    'Cleantech',
    'E-commerce',
    'SaaS',
    'Biotech',
    'Other'
  ];
  final List<String> stages = [
    'Idea',
    'Pre-seed',
    'Seed',
    'Series A',
    'Series B',
    'Growth',
    'Mature'
  ];

  @override
  void initState() {
    super.initState();

    // Prefill from widget props if available
    if (widget.initialUsername != null ||
        widget.initialEmail != null ||
        widget.initialId != null) {
      _username = widget.initialUsername ?? _username;
      _email = widget.initialEmail ?? _email;
      _id = widget.initialId ?? _id;
      _usernameController.text = _username;
      _emailController.text = _email;
    }

    _pageController = PageController(initialPage: _currentStep);
    _formKeys = List.generate(2, (_) => GlobalKey<FormState>()); // Now only 2 steps

    _loadSessionData();
    _loadFormData();

    _foundingDateController.text = DateFormat('yyyy-MM-dd').format(
      DateTime.now().subtract(const Duration(days: 365 * 2)),
    );

    _checkProfileStatus();
  }

  Future<void> _loadSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _username = widget.initialUsername ?? prefs.getString('username') ?? 'Unknown';
        _email = widget.initialEmail ?? prefs.getString('email') ?? 'Unknown';
        _id = widget.initialId ?? prefs.getString('id') ?? '0';
      });
      _usernameController.text = _username;
      _emailController.text = _email;
    } catch (e) {
      if (mounted) _showErrorDialog('Failed to load session data: $e');
    }
  }

  Future<void> _checkProfileStatus() async {
    if (_id == '0' || _id.isEmpty) return;

    try {
      final url = Uri.parse('https://server.awarcrown.com/roledata/formstatus');
      final response = await http.post(
        url,
        body: {'id': _id},
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final bool completed = jsonResponse['completed'] == true ||
            (jsonResponse['success'] == true && (jsonResponse['data']?.contains(_id) ?? false));

        if (completed && mounted) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('profileCompleted', true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile already completed! Redirecting to dashboard.')),
          );
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const DashboardPage(),
              transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      }
    } catch (e) {
      print('Error checking profile status: $e');
    }
  }

  Future<void> _loadFormData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentStep = prefs.getInt('currentStep') ?? 0;
        _startupNameController.text = prefs.getString('startupName') ?? '';
        _phoneController.text = prefs.getString('phone') ?? '';
        _addressController.text = prefs.getString('address') ?? '';
        _descriptionController.text = prefs.getString('description') ?? '';
        _industryController.text = prefs.getString('industry') ?? '';
        _linkedinController.text = prefs.getString('linkedin') ?? '';
        _instagramController.text = prefs.getString('instagram') ?? '';
        _facebookController.text = prefs.getString('facebook') ?? '';
        _foundingDateController.text = prefs.getString('foundingDate') ??
            DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 365 * 2)));
        _stageController.text = prefs.getString('stage') ?? '';
        _highlightsController.text = prefs.getString('highlights') ?? '';
        _logoPath = prefs.getString('logoPath');

        final foundersList = prefs.getStringList('founders') ?? [];
        _founderControllers = foundersList.map((name) => TextEditingController(text: name)).toList();
      });

      if (_founderControllers.isEmpty) {
        _addFounder();
      }

      _pageController.jumpToPage(_currentStep.clamp(0, 1)); // Max step is now 1
    } catch (e) {
      print('Error loading form data: $e');
    }
  }

  Future<void> _saveFormData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('currentStep', _currentStep);
      await prefs.setString('startupName', _startupNameController.text);
      await prefs.setString('phone', _phoneController.text);
      await prefs.setString('address', _addressController.text);
      await prefs.setString('description', _descriptionController.text);
      await prefs.setString('industry', _industryController.text);
      await prefs.setString('linkedin', _linkedinController.text);
      await prefs.setString('instagram', _instagramController.text);
      await prefs.setString('facebook', _facebookController.text);
      await prefs.setString('foundingDate', _foundingDateController.text);
      await prefs.setString('stage', _stageController.text);
      await prefs.setString('highlights', _highlightsController.text);
      if (_logoPath != null) await prefs.setString('logoPath', _logoPath!);
      await prefs.setStringList('founders', _founderControllers.map((c) => c.text).toList());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save progress: $e')),
        );
      }
    }
  }

  Future<void> _clearFormData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('currentStep');
      await prefs.remove('startupName');
      await prefs.remove('phone');
      await prefs.remove('address');
      await prefs.remove('description');
      await prefs.remove('industry');
      await prefs.remove('linkedin');
      await prefs.remove('instagram');
      await prefs.remove('facebook');
      await prefs.remove('foundingDate');
      await prefs.remove('stage');
      await prefs.remove('highlights');
      await prefs.remove('logoPath');
      await prefs.remove('founders');
    } catch (e) {
      print('Error clearing form data: $e');
    }
  }

  void _addFounder() {
    HapticFeedback.lightImpact();
    setState(() {
      _founderControllers.add(TextEditingController());
    });
  }

  void _removeFounder(int index) {
    HapticFeedback.mediumImpact();
    _founderControllers[index].dispose();
    setState(() {
      _founderControllers.removeAt(index);
    });
    if (_founderControllers.isEmpty) _addFounder();
    _saveFormData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _startupNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _industryController.dispose();
    _linkedinController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _foundingDateController.dispose();
    _stageController.dispose();
    _highlightsController.dispose();

    for (var ctrl in _founderControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    await showDialog<XFile?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Logo Source'),
        content: const Text('Choose how to pick your company logo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, null), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final image = await picker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                setState(() => _logoPath = image.path);
                _saveFormData();
              }
            },
            child: const Text('Gallery'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final image = await picker.pickImage(source: ImageSource.camera);
              if (image != null) {
                setState(() => _logoPath = image.path);
                _saveFormData();
              }
            },
            child: const Text('Camera'),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    final founderNames = _founderControllers.map((c) => c.text.trim()).where((n) => n.isNotEmpty).toList();
    if (founderNames.isEmpty) {
      _showErrorDialog('At least one founder name is required.');
      return;
    }

    if (_formKeys[_currentStep].currentState!.validate()) {
      _saveFormData();
      if (_currentStep < 1) { // Now max is 1
        HapticFeedback.lightImpact();
        _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      } else {
        _submitForm();
      }
    } else {
      _showErrorDialog('Please fix the errors in this step.');
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      HapticFeedback.lightImpact();
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentStep = index);
    _saveFormData();
  }

  Future<void> _selectFoundingDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _foundingDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKeys[_currentStep].currentState!.validate()) {
      _showErrorDialog('Please fix the errors in this step.');
      return;
    }

    final founderNames = _founderControllers.map((c) => c.text.trim()).where((n) => n.isNotEmpty).toList();
    if (founderNames.isEmpty) {
      _showErrorDialog('At least one founder name is required.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _sendDataToBackend();
      String errorMsg = 'Failed to save profile. Status code: ${response.statusCode}';
      bool isSuccess = false;
      String successMessage = 'Welcome to the world\'s largest career network! Profile saved successfully!';

      final responseBody = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseBody);

      if (response.statusCode >= 200 && response.statusCode < 300 && jsonResponse['success'] == true) {
        isSuccess = true;
        successMessage = jsonResponse['message'] ?? successMessage;
      } else if (response.statusCode == 409) {
        errorMsg = jsonResponse['message'] ?? 'Profile already exists for this user';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('profileCompleted', true);
        await prefs.setString('role', 'startup');
        await _clearFormData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$errorMsg Redirecting to dashboard.')),
          );
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const DashboardPage(),
              transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
        return;
      } else {
        errorMsg = jsonResponse['message'] ?? errorMsg;
      }

      if (isSuccess) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('role', 'startup');
        await prefs.setBool('profileCompleted', true);
        await prefs.setString('startupName', _startupNameController.text);
        await prefs.setString('phone', _phoneController.text);
        await _clearFormData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(successMessage)),
          );
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const DashboardPage(),
              transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      } else {
        _showErrorDialog(errorMsg);
      }
    } on SocketException {
      _showErrorDialog('Network error. Please check your internet connection.');
    } catch (e) {
      _showErrorDialog('An unexpected error occurred: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<http.StreamedResponse> _sendDataToBackend() async {
    final url = Uri.parse('https://server.awarcrown.com/roledata/startuprole');
    var request = http.MultipartRequest('POST', url);

    request.fields['id'] = _id;
    request.fields['username'] = _username;
    request.fields['email'] = _email;
    request.fields['founders_names'] = _founderControllers.map((c) => c.text.trim()).where((n) => n.isNotEmpty).join(', ');
    request.fields['startup_name'] = _startupNameController.text;
    request.fields['phone'] = _phoneController.text;
    request.fields['address'] = _addressController.text;
    request.fields['description'] = _descriptionController.text;
    request.fields['industry'] = _industryController.text;
    request.fields['linkedin'] = _linkedinController.text;
    request.fields['instagram'] = _instagramController.text;
    request.fields['facebook'] = _facebookController.text;
    request.fields['founding_date'] = _foundingDateController.text;
    request.fields['stage'] = _stageController.text;
    request.fields['highlights'] = _highlightsController.text;
    request.fields['email_verification'] = 'verified';
    request.fields['role_type'] = 'startup';

    if (_logoPath != null && File(_logoPath!).existsSync()) {
      request.files.add(await http.MultipartFile.fromPath(
        'logo',
        _logoPath!,
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    return await request.send().timeout(const Duration(seconds: 30));
  }

  void _showErrorDialog(String message) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Oops!'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // UI BUILDERS
  // ─────────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    final w = MediaQuery.of(context).size.width;
    return Container(
      margin: EdgeInsets.symmetric(vertical: w * 0.02, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(2, (index) { // Now only 2 steps
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (index > _currentStep) _nextStep();
                if (index < _currentStep) _prevStep();
              },
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: index <= _currentStep ? const Color(0xFF27AE60) : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: index <= _currentStep ? 16 : 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ['Basics', 'Professional'][index],
                    style: TextStyle(
                      fontSize: 12,
                      color: index <= _currentStep ? const Color(0xFF27AE60) : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    return PageView(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildBasicsStep(),
        _buildProfessionalStep(),
      ],
    );
  }

  ScrollPhysics _getScrollPhysics() {
    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics();
      default:
        return const ClampingScrollPhysics();
    }
  }

  Widget _buildBasicsStep() {
    final w = MediaQuery.of(context).size.width;
    final scrollPhysics = _getScrollPhysics();

    return Form(
      key: _formKeys[0],
      child: SingleChildScrollView(
        physics: scrollPhysics,
        padding: EdgeInsets.all(w * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Step 1: Startup Basics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Core details about your startup.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                prefixIcon: const Icon(Icons.person, color: Color(0xFF27AE60)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              readOnly: true,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email, color: Color(0xFF27AE60)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              readOnly: true,
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _startupNameController,
              decoration: InputDecoration(
                labelText: 'Startup Name',
                prefixIcon: const Icon(Icons.business, color: Color(0xFF27AE60)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 2) return 'Name too short';
                return null;
              },
            ),
            const SizedBox(height: 16),

            GestureDetector(
              onTap: _pickLogo,
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[50],
                ),
                child: _logoPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(_logoPath!), fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('Tap to upload logo (optional)', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Founders',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 180,
              child: ListView.builder(
                shrinkWrap: true,
                physics: scrollPhysics,
                itemCount: _founderControllers.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _founderControllers[index],
                              decoration: InputDecoration(
                                labelText: 'Founder Name ${index + 1}',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Name required' : null,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeFounder(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            ElevatedButton.icon(
              onPressed: _addFounder,
              icon: const Icon(Icons.add),
              label: const Text('Add Founder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27AE60),
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: 'e.g., +1-123-456-7890',
                prefixIcon: const Icon(Icons.phone, color: Color(0xFF27AE60)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (!RegExp(r'^\+?[\d\s\-\(\)]{10,}$').hasMatch(v)) return 'Enter valid phone (10+ digits)';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                labelText: 'Address',
                hintText: 'e.g., 123 Startup St, City, State 12345',
                prefixIcon: const Icon(Icons.location_on, color: Color(0xFF27AE60)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 2,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 10) return 'Address too short';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Briefly describe your startup',
                prefixIcon: const Icon(Icons.description, color: Color(0xFF27AE60)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 3,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 20) return 'Description too short';
                return null;
              },
            ),
            const SizedBox(height: 16),

            Autocomplete<String>(
              optionsBuilder: (text) {
                return industries.where((opt) => opt.toLowerCase().contains(text.text.toLowerCase())).toList();
              },
              onSelected: (selection) => _industryController.text = selection,
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                _industryController.text = controller.text;
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: InputDecoration(
                    labelText: 'Industry',
                    prefixIcon: const Icon(Icons.category, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  onFieldSubmitted: (_) => onSubmitted(),
                );
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _linkedinController,
              decoration: InputDecoration(
                labelText: 'LinkedIn Profile (optional)',
                hintText: 'e.g., linkedin.com/company/yourstartup',
                prefixIcon: const Icon(Icons.link, color: Color(0xFF27AE60)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (!RegExp(r'^https?://(www\.)?linkedin\.com/.*$').hasMatch(v)) return 'Enter valid LinkedIn URL';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _instagramController,
              decoration: InputDecoration(
                labelText: 'Instagram Profile (optional)',
                hintText: 'e.g., instagram.com/yourstartup',
                prefixIcon: const Icon(Icons.link, color: Color(0xFF27AE60)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (!RegExp(r'^https?://(www\.)?instagram\.com/.*$').hasMatch(v)) return 'Enter valid Instagram URL';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _facebookController,
              decoration: InputDecoration(
                labelText: 'Facebook Profile (optional)',
                hintText: 'e.g., facebook.com/yourstartup',
                prefixIcon: const Icon(Icons.link, color: Color(0xFF27AE60)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                if (!RegExp(r'^https?://(www\.)?facebook\.com/.*$').hasMatch(v)) return 'Enter valid Facebook URL';
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _foundingDateController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Founding Date',
                prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF27AE60)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final date = DateTime.tryParse(v);
                if (date == null || date.isAfter(DateTime.now())) return 'Invalid date';
                return null;
              },
              onTap: () => _selectFoundingDate(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalStep() {
    final w = MediaQuery.of(context).size.width;
    final scrollPhysics = _getScrollPhysics();

    return Form(
      key: _formKeys[1],
      child: SingleChildScrollView(
        physics: scrollPhysics,
        padding: EdgeInsets.all(w * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Step 2: Professional Snapshot',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Quick overview of your team and progress.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            DropdownButtonFormField<String>(
              value: _stageController.text.isEmpty ? null : _stageController.text,
              decoration: InputDecoration(
                labelText: 'Stage',
                prefixIcon: const Icon(Icons.trending_up, color: Color(0xFF27AE60)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: stages.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _stageController.text = v);
              },
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _highlightsController,
              decoration: InputDecoration(
                labelText: 'Key Highlights',
                hintText: 'Team skills (e.g., Python, Marketing) and achievements (e.g., MVP launched, 10k users)',
                prefixIcon: const Icon(Icons.lightbulb, color: Color(0xFF27AE60)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              maxLines: 4,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 20) return 'At least 20 characters';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final w = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.all(w * 0.04),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _prevStep,
              child: const Text('Back', style: TextStyle(color: Color(0xFF27AE60), fontSize: 16)),
            )
          else
            const SizedBox.shrink(),

          ElevatedButton(
            onPressed: _isLoading ? null : _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF27AE60),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(_currentStep == 1 ? 'Join Now' : 'Save & Next'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(w * 0.04, MediaQuery.of(context).padding.top + 20, w * 0.04, 20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF27AE60), Color(0xFF2ECC71)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome, $_username!',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Join the world\'s largest career network',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    _buildStepIndicator(),
                    Expanded(child: _buildStepContent()),
                  ],
                ),
              ),
              _buildNavigationButtons(),
            ],
          ),

          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}