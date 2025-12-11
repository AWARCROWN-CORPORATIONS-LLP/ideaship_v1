import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../dashboard.dart';

class StudentRolePage extends StatefulWidget {
  final String? initialUsername;
  final String? initialEmail;
  final String? initialId;

  const StudentRolePage({
    super.key,
    this.initialUsername,
    this.initialEmail,
    this.initialId,
  });

  @override
  State<StudentRolePage> createState() => _StudentRolePageState();
}

class _StudentRolePageState extends State<StudentRolePage> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();
  final _interestsController = TextEditingController();
  String _username = '';
  String _email = '';
  String _id = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialUsername != null ||
        widget.initialEmail != null ||
        widget.initialId != null) {
      _username = widget.initialUsername ?? _username;
      _email = widget.initialEmail ?? _email;
      _id = widget.initialId ?? _id;
      _usernameController.text = _username;
      _emailController.text = _email;
    }
    _checkProfileStatus();
    _loadSessionData();
    _dobController.text = DateFormat('yyyy-MM-dd').format(
        DateTime.now().subtract(const Duration(days: 7300)));
    _loadFormData();
  }

  Future<void> _loadSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _username =
            widget.initialUsername ?? prefs.getString('username') ?? 'Unknown';
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
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        final bool completed = jsonResponse['completed'] == true ||
            (jsonResponse['success'] == true &&
                (jsonResponse['data']?.contains(_id) ?? false));
        if (completed) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('profileCompleted', true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Profile already completed! Redirecting to dashboard.',
                ),
              ),
            );
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const DashboardPage(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
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
        _fullNameController.text = prefs.getString('fullName') ?? '';
        _dobController.text = prefs.getString('dob') ??
            DateFormat('yyyy-MM-dd').format(
                DateTime.now().subtract(const Duration(days: 7300)));
        _phoneController.text = prefs.getString('phone') ?? '';
        _interestsController.text = prefs.getString('interests') ?? '';
      });
    } catch (e) {
      print('Error loading form data: $e');
    }
  }

  Future<void> _saveFormData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('currentStep', _currentStep);
      await prefs.setString('fullName', _fullNameController.text);
      await prefs.setString('dob', _dobController.text);
      await prefs.setString('phone', _phoneController.text);
      await prefs.setString('interests', _interestsController.text);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Progress saved!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save progress: $e')));
      }
    }
  }

  Future<void> _clearFormData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('currentStep');
      await prefs.remove('fullName');
      await prefs.remove('dob');
      await prefs.remove('phone');
      await prefs.remove('interests');
    } catch (e) {
      print('Error clearing form data: $e');
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _fullNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      _saveFormData();
      if (_currentStep < 1) {
        setState(() => _currentStep++);
      } else {
        _submitForm();
      }
    } else {
      _showErrorDialog('Please fix the errors in this step.');
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _saveFormData();
      setState(() => _currentStep--);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          DateTime.now().subtract(const Duration(days: 7300)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorDialog('Please fix the errors in this step.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _sendDataToBackend();

      String errorMsg =
          'Failed to save profile. Status code: ${response.statusCode}';
      bool isSuccess = false;
      String successMessage =
          'Welcome to the world\'s largest career network! Profile saved successfully!';

      try {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            jsonResponse['success'] == true) {
          isSuccess = true;
          successMessage = jsonResponse['message'] ?? successMessage;
        } else if (response.statusCode == 409) {
          errorMsg = jsonResponse['message'] ??
              'Profile already exists for this user';
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('profileCompleted', true);
          await prefs.setString('role', 'student');
          await _clearFormData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$errorMsg Redirecting to dashboard.')),
            );
            Navigator.pushReplacement(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const DashboardPage(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
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
        await prefs.setString('role', 'student');
        await prefs.setBool('profileCompleted', true);
        await prefs.setString('fullName', _fullNameController.text);
        await prefs.setString('phone', _phoneController.text);
        await _clearFormData();

        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(successMessage)));
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const DashboardPage(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
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
      _showErrorDialog(
          'Network error. Please check your internet connection and try again.');
    } on FormatException {
      _showErrorDialog('Invalid response from server. Please try again.');
    } on TimeoutException {
      _showErrorDialog(
          'Request timed out. Please check your connection and try again.');
    } catch (e) {
      _showErrorDialog(
          'An unexpected error occurred: $e. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
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

  Future<http.Response> _sendDataToBackend() async {
    final url = Uri.parse('https://server.awarcrown.com/roledata/studentrole');
    final body = {
      'id': _id,
      'username': _username,
      'email': _email,
      'full_name': _fullNameController.text,
      'dob': _dobController.text,
      'phone': _phoneController.text,
      'interests': _interestsController.text,
      'email_verification': 'verified',
      'role_type': 'student',
    };
    return http
        .post(
          url,
          body: body,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        )
        .timeout(const Duration(seconds: 30));
  }

  Widget _buildStepIndicator() {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      margin: EdgeInsets.symmetric(vertical: screenWidth * 0.02),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(2, (index) {
          return Expanded(
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: index <= _currentStep
                        ? const Color(0xFF27AE60)
                        : Colors.grey[300],
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
                  ['Basics', 'Personalise'][index],
                  style: TextStyle(
                    fontSize: 12,
                    color: index <= _currentStep
                        ? const Color(0xFF27AE60)
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildExperienceStep();
      default:
        return const SizedBox();
    }
  }

  Widget _buildBasicInfoStep() {
    final screenWidth = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Step 1: Tell us about yourself',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start your journey to the world\'s largest career network!',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    hintText: 'e.g., john_doe123',
                    prefixIcon: const Icon(Icons.person,
                        color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: 'Your login username (auto-filled)',
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'e.g., john@example.com',
                    prefixIcon:
                        const Icon(Icons.email, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: 'Your registered email (auto-filled)',
                  ),
                  readOnly: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'e.g., John Doe',
                    prefixIcon: const Icon(Icons.account_circle,
                        color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText:
                        'Enter your complete legal name as on documents',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (value.length < 2) return 'Name too short';
                    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
                      return 'Only letters and spaces allowed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    hintText: 'e.g., 1995-05-20',
                    prefixIcon: const Icon(Icons.calendar_today,
                        color: Color(0xFF27AE60)),
                    suffixIcon:
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: 'Select your date of birth from calendar',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    final dob = DateTime.parse(value);
                    final age =
                        DateTime.now().difference(dob).inDays ~/ 365;
                    if (age < 16 || age > 100) {
                      return 'Age must be between 16 and 100';
                    }
                    return null;
                  },
                  onTap: () => _selectDate(context),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'e.g., +1-123-456-7890',
                    prefixIcon:
                        const Icon(Icons.phone, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: 'Include country code for international reach',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (!RegExp(r'^\+?[\d\s\-\(\)]{10,}$').hasMatch(value)) {
                      return 'Enter valid phone (10+ digits)';
                    }
                    return null;
                  },
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExperienceStep() {
    final screenWidth = MediaQuery.of(context).size.width;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Step 2: Share your interests',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Highlight your interests to recommend best opportunities for you.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _interestsController,
                  decoration: InputDecoration(
                    labelText: 'Interests',
                    hintText: 'e.g., AI, Sustainability',
                    prefixIcon: const Icon(Icons.favorite,
                        color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: 'Hobbies or topics that motivate you',
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (value.length < 5) return 'At least 5 characters';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ],
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
              child: const Text(
                'Back',
                style: TextStyle(color: Color(0xFF27AE60)),
              ),
            )
          else
            const SizedBox(width: 0),
          const Spacer(),
          Row(
            children: [
              if (_currentStep < 1)
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            _saveFormData();
                          } else {
                            _showErrorDialog(
                                'Please fix the errors in this step.');
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save'),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(_currentStep == 1 ? 'Join Now' : 'Save & Next'),
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
                padding: EdgeInsets.fromLTRB(
                  screenWidth * 0.04,
                  MediaQuery.of(context).padding.top + 20,
                  screenWidth * 0.04,
                  20,
                ),
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
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
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
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(screenWidth * 0.02),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildStepIndicator(),
                        const SizedBox(height: 20),
                        _buildStepContent(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
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