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
  final _industryController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _instagramController = TextEditingController();
  final _facebookController = TextEditingController();
  final _foundingDateController = TextEditingController();
  final _stageController = TextEditingController();
  final _teamSizeController = TextEditingController();
  final _highlightsController = TextEditingController();
  final _additionalDocsController = TextEditingController();
  final _fundingGoalsController = TextEditingController();
  final _mentorshipNeedsController = TextEditingController();
  final _businessVisionController = TextEditingController();
  final _businessRegistrationController = TextEditingController();
  final _founderIdController = TextEditingController();
  final _referenceController = TextEditingController();
  final _supportingDocsController = TextEditingController();
  final List<Map<String, dynamic>> _teamMembers = [];
  String? _logoPath;
  String? _govIdType;
  String? _businessRegType; // New field for business registration type
  String _username = '';
  String _email = '';
  String _id = '';
  bool _isLoading = false;

  final List<String> industries = ['Fintech', 'Healthtech', 'Edtech', 'Agritech', 'Cleantech', 'E-commerce', 'SaaS', 'Biotech', 'Other'];
  final List<String> stages = ['Idea', 'Pre-seed', 'Seed', 'Series A', 'Series B', 'Growth', 'Mature'];
  final List<String> supports = ['Incubators', 'Accelerators', 'Venture Capital', 'Angel Investors', 'Government Grants', 'Crowdfunding'];
  final List<String> govIdTypes = ['Aadhar', 'PAN', 'Passport', 'Other'];
  final List<String> businessRegTypes = ['LLP', 'Private Limited', 'Public Limited', 'Not Registered', 'Other'];

  @override
  void initState() {
    super.initState();
    // Prefill using values passed from role selection before SharedPreferences load.
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
    _formKeys = List.generate(3, (index) => GlobalKey<FormState>());
    _loadSessionData();
    _foundingDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 365 * 2)));
    _loadFormData();
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
      if (mounted) {
        _showErrorDialog('Failed to load session data: $e');
      }
    }
  }

  Future<void> _checkProfileStatus() async {
    if (_id == '0' || _id.isEmpty) return;

    try {
      final url = Uri.parse('https://server.awarcrown.com/roledata/formstatus');
      final response = await http
          .post(
            url,
            body: {'id': _id},
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final responseBody = response.body;
        final Map<String, dynamic> jsonResponse = json.decode(responseBody);
        final bool completed = jsonResponse['completed'] == true || (jsonResponse['success'] == true && (jsonResponse['data']?.contains(_id) ?? false));
        if (completed) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('profileCompleted', true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile already completed! Redirecting to dashboard.')),
            );
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const DashboardPage(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 500),
              ),
            );
          }
        }
      }
    } on SocketException {
      print('Network error during profile status check');
    } on FormatException {
      print('Invalid response during profile status check');
    } on TimeoutException {
      print('Timeout during profile status check');
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
        _industryController.text = prefs.getString('industry') ?? '';
        _linkedinController.text = prefs.getString('linkedin') ?? '';
        _instagramController.text = prefs.getString('instagram') ?? '';
        _facebookController.text = prefs.getString('facebook') ?? '';
        _foundingDateController.text = prefs.getString('foundingDate') ?? DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 365 * 2)));
        _stageController.text = prefs.getString('stage') ?? '';
        _teamSizeController.text = prefs.getString('teamSize') ?? '';
        _highlightsController.text = prefs.getString('highlights') ?? '';
        _additionalDocsController.text = prefs.getString('additionalDocs') ?? '';
        _fundingGoalsController.text = prefs.getString('fundingGoals') ?? '';
        _mentorshipNeedsController.text = prefs.getString('mentorshipNeeds') ?? '';
        _businessVisionController.text = prefs.getString('businessVision') ?? '';
        _businessRegistrationController.text = prefs.getString('businessRegistration') ?? '';
        _businessRegType = prefs.getString('businessRegType');
        _founderIdController.text = prefs.getString('founderId') ?? '';
        _govIdType = prefs.getString('govIdType');
        _referenceController.text = prefs.getString('reference') ?? '';
        _supportingDocsController.text = prefs.getString('supportingDocs') ?? '';
        _logoPath = prefs.getString('logoPath');

        final foundersList = prefs.getStringList('founders') ?? [];
        _founderControllers = foundersList.map((name) => TextEditingController(text: name)).toList();
      });

      if (_founderControllers.isEmpty) {
        _addFounder();
      }
      _pageController.jumpToPage(_currentStep);
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
      await prefs.setString('industry', _industryController.text);
      await prefs.setString('linkedin', _linkedinController.text);
      await prefs.setString('instagram', _instagramController.text);
      await prefs.setString('facebook', _facebookController.text);
      await prefs.setString('foundingDate', _foundingDateController.text);
      await prefs.setString('stage', _stageController.text);
      await prefs.setString('teamSize', _teamSizeController.text);
      await prefs.setString('highlights', _highlightsController.text);
      await prefs.setString('additionalDocs', _additionalDocsController.text);
      await prefs.setString('fundingGoals', _fundingGoalsController.text);
      await prefs.setString('mentorshipNeeds', _mentorshipNeedsController.text);
      await prefs.setString('businessVision', _businessVisionController.text);
      await prefs.setString('businessRegistration', _businessRegistrationController.text);
      if (_businessRegType != null) await prefs.setString('businessRegType', _businessRegType!);
      await prefs.setString('founderId', _founderIdController.text);
      if (_govIdType != null) await prefs.setString('govIdType', _govIdType!);
      await prefs.setString('reference', _referenceController.text);
      await prefs.setString('supportingDocs', _supportingDocsController.text);
      if (_logoPath != null) await prefs.setString('logoPath', _logoPath!);

      await prefs.setStringList('founders', _founderControllers.map((c) => c.text).toList());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress saved!')),
        );
      }
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
      await prefs.remove('industry');
      await prefs.remove('linkedin');
      await prefs.remove('instagram');
      await prefs.remove('facebook');
      await prefs.remove('foundingDate');
      await prefs.remove('stage');
      await prefs.remove('teamSize');
      await prefs.remove('highlights');
      await prefs.remove('additionalDocs');
      await prefs.remove('fundingGoals');
      await prefs.remove('mentorshipNeeds');
      await prefs.remove('businessVision');
      await prefs.remove('businessRegistration');
      await prefs.remove('businessRegType');
      await prefs.remove('founderId');
      await prefs.remove('govIdType');
      await prefs.remove('reference');
      await prefs.remove('supportingDocs');
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
    if (_founderControllers.isEmpty) {
      _addFounder();
    }
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
    _industryController.dispose();
    _linkedinController.dispose();
    _instagramController.dispose();
    _facebookController.dispose();
    _foundingDateController.dispose();
    _stageController.dispose();
    _teamSizeController.dispose();
    _highlightsController.dispose();
    _additionalDocsController.dispose();
    _fundingGoalsController.dispose();
    _mentorshipNeedsController.dispose();
    _businessVisionController.dispose();
    _businessRegistrationController.dispose();
    _founderIdController.dispose();
    _referenceController.dispose();
    _supportingDocsController.dispose();

    for (var ctrl in _founderControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final ImagePicker picker = ImagePicker();
    await showDialog<XFile?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Logo Source'),
        content: const Text('Choose how to pick your company logo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final XFile? image = await picker.pickImage(source: ImageSource.gallery);
              if (image != null) {
                setState(() {
                  _logoPath = image.path;
                });
                _saveFormData();
              }
            },
            child: const Text('Gallery'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final XFile? image = await picker.pickImage(source: ImageSource.camera);
              if (image != null) {
                setState(() {
                  _logoPath = image.path;
                });
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
      if (_currentStep < 2) {
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
    setState(() {
      _currentStep = index;
    });
    _saveFormData();
  }

  Future<void> _selectFoundingDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
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

      try {
        final responseBody = await response.stream.bytesToString();
        final Map<String, dynamic> jsonResponse = json.decode(responseBody);
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
                pageBuilder: (context, animation, secondaryAnimation) => const DashboardPage(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 500),
              ),
            );
          }
          return;
        } else {
          errorMsg = jsonResponse['message'] ?? errorMsg;
        }
      } catch (e) {
        if (response.statusCode >= 400 && response.statusCode < 500) {
          errorMsg = 'Validation error. Please check your inputs.';
        } else if (response.statusCode >= 500) {
          errorMsg = 'Server error. Please try again later.';
        }
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
              pageBuilder: (context, animation, secondaryAnimation) => const DashboardPage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      } else {
        _showErrorDialog(errorMsg);
      }
    } on SocketException {
      _showErrorDialog('Network error. Please check your internet connection and try again.');
    } on FormatException {
      _showErrorDialog('Invalid response from server. Please try again.');
    } on TimeoutException {
      _showErrorDialog('Request timed out. Please check your connection and try again.');
    } catch (e) {
      _showErrorDialog('An unexpected error occurred: $e. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Oops!'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
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
    request.fields['industry'] = _industryController.text;
    request.fields['linkedin'] = _linkedinController.text;
    request.fields['instagram'] = _instagramController.text;
    request.fields['facebook'] = _facebookController.text;
    request.fields['founding_date'] = _foundingDateController.text;
    request.fields['stage'] = _stageController.text;
    request.fields['team_size'] = _teamSizeController.text;
    request.fields['highlights'] = _highlightsController.text;
    request.fields['additional_docs'] = _additionalDocsController.text;
    request.fields['funding_goals'] = _fundingGoalsController.text;
    request.fields['mentorship_needs'] = _mentorshipNeedsController.text;
    request.fields['business_vision'] = _businessVisionController.text;
    request.fields['business_reg_type'] = _businessRegType ?? '';
    request.fields['business_registration'] = _businessRegistrationController.text;
    request.fields['founder_id'] = _founderIdController.text;
    request.fields['gov_id_type'] = _govIdType ?? '';
    request.fields['reference'] = _referenceController.text;
    request.fields['supporting_docs'] = _supportingDocsController.text;
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

  Widget _buildStepIndicator() {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      margin: EdgeInsets.symmetric(vertical: screenWidth * 0.02),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(3, (index) {
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (index > _currentStep) {
                  _nextStep();
                } else if (index < _currentStep) {
                  _prevStep();
                }
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
                    ['Basics', 'Professional', 'Aspirations & Verify'][index],
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
        _buildAspirationsVerifyStep(),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final scrollPhysics = _getScrollPhysics();
    return Form(
      key: _formKeys[0],
      child: SingleChildScrollView(
        physics: scrollPhysics,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.04),
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
                    const SizedBox(height: 20),
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
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _startupNameController,
                      decoration: InputDecoration(
                        labelText: 'Startup Name',
                        prefixIcon: const Icon(Icons.business, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (value.length < 2) return 'Name too short';
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
                                child: Image.file(
                                  File(_logoPath!),
                                  fit: BoxFit.cover,
                                ),
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
                    const SizedBox(height: 16),
                    const Text(
                      'Founders',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 200,
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
                                      validator: (value) {
                                        if (value == null || value.isEmpty) return 'Name required';
                                        return null;
                                      },
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number',
                        hintText: 'e.g., +1-123-456-7890',
                        prefixIcon: const Icon(Icons.phone, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (!RegExp(r'^\+?[\d\s\-\(\)]{10,}$').hasMatch(value)) return 'Enter valid phone (10+ digits)';
                        return null;
                      },
                      keyboardType: TextInputType.phone,
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
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (value.length < 10) return 'Address too short';
                        return null;
                      },
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        return industries.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase())).toList();
                      },
                      onSelected: (String selection) {
                        _industryController.text = selection;
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        _industryController.text = controller.text;
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Industry',
                            prefixIcon: const Icon(Icons.category, color: Color(0xFF27AE60)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Required';
                            return null;
                          },
                          onFieldSubmitted: (String value) => onFieldSubmitted(),
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
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        if (!RegExp(r'^https?://(www\.)?linkedin\.com/.*$').hasMatch(value)) return 'Enter valid LinkedIn URL';
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
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        if (!RegExp(r'^https?://(www\.)?instagram\.com/.*$').hasMatch(value)) return 'Enter valid Instagram URL';
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
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        if (!RegExp(r'^https?://(www\.)?facebook\.com/.*$').hasMatch(value)) return 'Enter valid Facebook URL';
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
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final date = DateTime.tryParse(value);
                        if (date == null || date.isAfter(DateTime.now())) return 'Invalid date';
                        return null;
                      },
                      onTap: () => _selectFoundingDate(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfessionalStep() {
    final screenWidth = MediaQuery.of(context).size.width;
    final scrollPhysics = _getScrollPhysics();
    return Form(
      key: _formKeys[1],
      child: SingleChildScrollView(
        physics: scrollPhysics,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.04),
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
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: _stageController.text.isEmpty ? null : _stageController.text,
                      decoration: InputDecoration(
                        labelText: 'Stage',
                        prefixIcon: const Icon(Icons.trending_up, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: stages.map((String stage) {
                        return DropdownMenuItem<String>(value: stage, child: Text(stage));
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _stageController.text = newValue ?? '';
                        });
                      },
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _teamSizeController,
                      decoration: InputDecoration(
                        labelText: 'Team Size',
                        prefixIcon: const Icon(Icons.group, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        final size = int.tryParse(value);
                        if (size == null || size < 1 || size > 1000) return 'Enter valid number (1-1000)';
                        return null;
                      },
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
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (value.length < 20) return 'At least 20 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _additionalDocsController,
                      decoration: InputDecoration(
                        labelText: 'Additional Docs (optional)',
                        hintText: 'Links to funding history, portfolio, IP, etc.',
                        prefixIcon: const Icon(Icons.link, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAspirationsVerifyStep() {
    final screenWidth = MediaQuery.of(context).size.width;
    final scrollPhysics = _getScrollPhysics();
    return Form(
      key: _formKeys[2],
      child: SingleChildScrollView(
        physics: scrollPhysics,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(screenWidth * 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Step 3: Aspirations & Verify',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your goals and verification details.',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _fundingGoalsController,
                      decoration: InputDecoration(
                        labelText: 'Funding Goals',
                        hintText: 'e.g., 1M equity funding for scaling',
                        prefixIcon: const Icon(Icons.trending_up, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (value.length < 20) return 'At least 20 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mentorshipNeedsController,
                      decoration: InputDecoration(
                        labelText: 'Mentorship Needs',
                        hintText: 'e.g., Scaling operations, marketing',
                        prefixIcon: const Icon(Icons.school, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (value.length < 10) return 'At least 10 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _businessVisionController,
                      decoration: InputDecoration(
                        labelText: 'Business Vision',
                        hintText: 'Target market (e.g., SMEs in emerging markets) and growth plans (e.g., Expand to Asia in 12 months)',
                        prefixIcon: const Icon(Icons.timeline, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (value.length < 20) return 'At least 20 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _businessRegType,
                      decoration: InputDecoration(
                        labelText: 'Business Registration Type',
                        prefixIcon: const Icon(Icons.verified, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: businessRegTypes.map((String type) {
                        return DropdownMenuItem<String>(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _businessRegType = newValue;
                          _businessRegistrationController.clear();
                        });
                      },
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _businessRegistrationController,
                      decoration: InputDecoration(
                        labelText: 'Business Registration Number',
                        hintText: _businessRegType == 'LLP' ? 'e.g., AAB-1234' : _businessRegType == 'Private Limited' || _businessRegType == 'Public Limited' ? 'e.g., U72900MH2023PTC123456' : _businessRegType == 'Other' ? 'e.g., Custom ID' : 'Not required if unregistered',
                        prefixIcon: const Icon(Icons.verified, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (_businessRegType == 'Not Registered') return null;
                        if (value == null || value.isEmpty) return 'Required';
                        if (_businessRegType == 'LLP' && !RegExp(r'^[A-Z]{3}-\d{4}$').hasMatch(value)) return 'Enter valid LLP ID (e.g., AAB-1234)';
                        if ((_businessRegType == 'Private Limited' || _businessRegType == 'Public Limited') && !RegExp(r'^U\d{5}[A-Z]{2}\d{4}PTC\d{6}$').hasMatch(value)) {
                          return 'Enter valid CIN (e.g., U72900MH2023PTC123456)';
                        }
                        if (_businessRegType == 'Other' && value.length < 5) return 'Enter valid ID (at least 5 characters)';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _govIdType,
                      decoration:  InputDecoration(
                        labelText: 'Founder ID Type',
                        prefixIcon: const Icon(Icons.credit_card, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: govIdTypes.map((String type) {
                        return DropdownMenuItem<String>(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _govIdType = newValue;
                          _founderIdController.clear();
                        });
                      },
                      validator: (value) => value == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _founderIdController,
                      decoration: InputDecoration(
                        labelText: 'Founder ID Number',
                        hintText: _govIdType == 'Aadhar' ? 'e.g., 1234 5678 9012' : _govIdType == 'PAN' ? 'e.g., ABCDE1234F' : _govIdType == 'Passport' ? 'e.g., Z1234567' : 'Enter full ID',
                        prefixIcon: const Icon(Icons.credit_card, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (_govIdType == 'Aadhar' && !RegExp(r'^\d{12}$').hasMatch(value.replaceAll(' ', ''))) return 'Aadhar must be 12 digits';
                        if (_govIdType == 'PAN' && !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(value.toUpperCase())) return 'PAN must be 10 alphanumeric';
                        if (_govIdType == 'Passport' && (value.length < 6 || value.length > 12)) return 'Passport ID must be 6-12 characters';
                        if (_govIdType == 'Other' && value.length < 4) return 'At least 4 characters';
                        return null;
                      },
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _referenceController,
                      decoration: InputDecoration(
                        labelText: 'Reference Contact',
                        hintText: 'e.g., mentor@example.com',
                        prefixIcon: const Icon(Icons.person_add, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (value.contains('@')) {
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Invalid email';
                        // ignore: curly_braces_in_flow_control_structures
                        } else if (!RegExp(r'^\+?[\d\s\-\(\)]{10,}$').hasMatch(value)) return 'Invalid phone';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _supportingDocsController,
                      decoration: InputDecoration(
                        labelText: 'Supporting Docs (optional)',
                        hintText: 'Links to pitch deck, financials, website verification, etc.',
                        prefixIcon: const Icon(Icons.picture_as_pdf, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final screenWidth = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.04),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            TextButton(
              onPressed: _prevStep,
              child: const Text('Back', style: TextStyle(color: Color(0xFF27AE60))),
            )
          else
            const SizedBox(width: 0),
          const Spacer(),
          Row(
            children: [
              if (_currentStep < 2)
                ElevatedButton(
                  onPressed: _isLoading ? null : () {
                    if (_formKeys[_currentStep].currentState!.validate()) {
                      _saveFormData();
                    } else {
                      _showErrorDialog('Please fix the errors in this step.');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                        )
                      : const Text('Save'),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : Text(_currentStep == 2 ? 'Join Now' : 'Save & Next'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(screenWidth * 0.04, MediaQuery.of(context).padding.top + 20, screenWidth * 0.04, 20),
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
                    const SizedBox(height: 20),
                    Expanded(child: _buildStepContent()),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              _buildNavigationButtons(),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}