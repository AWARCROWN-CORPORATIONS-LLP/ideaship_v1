import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:io';
import '../dashboard.dart'; // Import Dashboard for navigation

class StudentRolePage extends StatefulWidget {
  const StudentRolePage({super.key});

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
  final _addressController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _institutionController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _academicLevelController = TextEditingController();
  final _majorController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _skillsDevController = TextEditingController();
  final _interestsController = TextEditingController();
  final _expectedPassoutYearController = TextEditingController();
  String _username = '';
  String _email = '';
  String _id = '';
  bool _isLoading = false;

  // Suggestions data
  final List<String> nationalities = ['United States', 'India', 'United Kingdom', 'Canada', 'Australia', 'Germany', 'France', 'China', 'Japan', 'Brazil'];
  final List<String> academicLevels = ['High School', 'Bachelor\'s', 'Master\'s', 'PhD', 'Other'];
  final List<String> majors = ['Computer Science', 'Engineering', 'Business', 'Medicine', 'Arts', 'Law', 'Other'];
  final List<String> skillsDevs = ['Leadership', 'Coding', 'Public Speaking', 'Project Management', 'Data Analysis', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadSessionData();
    _dobController.text = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 7300)));
    _loadFormData(); // Load saved form data
    _checkProfileStatus(); // Check if profile already completed
  }

  Future<void> _loadSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _username = prefs.getString('username') ?? 'Unknown';
        _email = prefs.getString('email') ?? 'Unknown';
        _id = prefs.getString('id') ?? '0';
      });
      _usernameController.text = _username;
      _emailController.text = _email;
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to load session data: $e');
      }
    }
  }

  // Check if profile is already completed to prevent duplicate submission
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
      // Ignore network errors during check; proceed with form
      print('Network error during profile status check');
    } on FormatException {
      print('Invalid response during profile status check');
    } on TimeoutException {
      print('Timeout during profile status check');
    } catch (e) {
      print('Error checking profile status: $e');
    }
  }

  // Load saved form data from SharedPreferences
  Future<void> _loadFormData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentStep = prefs.getInt('currentStep') ?? 0;
        _fullNameController.text = prefs.getString('fullName') ?? '';
        _dobController.text = prefs.getString('dob') ?? DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 7300)));
        _phoneController.text = prefs.getString('phone') ?? '';
        _addressController.text = prefs.getString('address') ?? '';
        _nationalityController.text = prefs.getString('nationality') ?? '';
        _institutionController.text = prefs.getString('institution') ?? '';
        _studentIdController.text = prefs.getString('studentId') ?? '';
        _linkedinController.text = prefs.getString('linkedin') ?? '';
        _academicLevelController.text = prefs.getString('academicLevel') ?? '';
        _majorController.text = prefs.getString('major') ?? '';
        _portfolioController.text = prefs.getString('portfolio') ?? '';
        _skillsDevController.text = prefs.getString('skillsDev') ?? '';
        _interestsController.text = prefs.getString('interests') ?? '';
        _expectedPassoutYearController.text = prefs.getString('expectedPassoutYear') ?? '';
      });
    } catch (e) {
      print('Error loading form data: $e');
    }
  }

  // Save form data to SharedPreferences
  Future<void> _saveFormData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('currentStep', _currentStep);
      await prefs.setString('fullName', _fullNameController.text);
      await prefs.setString('dob', _dobController.text);
      await prefs.setString('phone', _phoneController.text);
      await prefs.setString('address', _addressController.text);
      await prefs.setString('nationality', _nationalityController.text);
      await prefs.setString('institution', _institutionController.text);
      await prefs.setString('studentId', _studentIdController.text);
      await prefs.setString('linkedin', _linkedinController.text);
      await prefs.setString('academicLevel', _academicLevelController.text);
      await prefs.setString('major', _majorController.text);
      await prefs.setString('portfolio', _portfolioController.text);
      await prefs.setString('skillsDev', _skillsDevController.text);
      await prefs.setString('interests', _interestsController.text);
      await prefs.setString('expectedPassoutYear', _expectedPassoutYearController.text);

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

  // Clear saved form data after successful submission
  Future<void> _clearFormData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('currentStep');
      await prefs.remove('fullName');
      await prefs.remove('dob');
      await prefs.remove('phone');
      await prefs.remove('address');
      await prefs.remove('nationality');
      await prefs.remove('institution');
      await prefs.remove('studentId');
      await prefs.remove('linkedin');
      await prefs.remove('academicLevel');
      await prefs.remove('major');
      await prefs.remove('portfolio');
      await prefs.remove('skillsDev');
      await prefs.remove('interests');
      await prefs.remove('expectedPassoutYear');
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
    _addressController.dispose();
    _nationalityController.dispose();
    _institutionController.dispose();
    _studentIdController.dispose();
    _linkedinController.dispose();
    _academicLevelController.dispose();
    _majorController.dispose();
    _portfolioController.dispose();
    _skillsDevController.dispose();
    _interestsController.dispose();
    _expectedPassoutYearController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      _saveFormData(); // Save data before moving to next step
      if (_currentStep < 2) {
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
      _saveFormData(); // Save data before going back
      setState(() => _currentStep--);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 7300)),
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

      String errorMsg = 'Failed to save profile. Status code: ${response.statusCode}';
      bool isSuccess = false;
      String successMessage = 'Welcome to the world\'s largest career network! Profile saved successfully!';

      try {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (response.statusCode >= 200 && response.statusCode < 300 && jsonResponse['success'] == true) {
          isSuccess = true;
          successMessage = jsonResponse['message'] ?? successMessage;
        } else if (response.statusCode == 409) {
          errorMsg = jsonResponse['message'] ?? 'Profile already exists for this user';
          // Handle duplicate: set completed and navigate
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
        // JSON parse failed; use status-based error
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
        await _clearFormData(); // Clear saved form data after successful submission

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
      'address': _addressController.text,
      'nationality': _nationalityController.text,
      'institution': _institutionController.text,
      'student_id': _studentIdController.text,
      'linkedin': _linkedinController.text,
      'academic_level': _academicLevelController.text,
      'major': _majorController.text,
      'portfolio': _portfolioController.text,
      'skills_dev': _skillsDevController.text,
      'interests': _interestsController.text,
      'expected_passout_year': _expectedPassoutYearController.text,
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
        children: List.generate(3, (index) {
          return Expanded(
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
                  ['Basics', 'Experience', 'Preferences'][index],
                  style: TextStyle(
                    fontSize: 12,
                    color: index <= _currentStep ? const Color(0xFF27AE60) : Colors.grey,
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
      case 2:
        return _buildPreferencesStep();
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: EdgeInsets.all(screenWidth * 0.04),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Step 1: Tell us about yourself',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
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
                    prefixIcon: const Icon(Icons.person, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    prefixIcon: const Icon(Icons.email, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Your registered email (auto-filled)',
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
                  controller: _fullNameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'e.g., John Doe',
                    prefixIcon: const Icon(Icons.account_circle, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Enter your complete legal name as on documents',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (value.length < 2) return 'Name too short';
                    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) return 'Only letters and spaces allowed';
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
                    prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF27AE60)),
                    suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Select your date of birth from calendar',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    final dob = DateTime.parse(value);
                    final age = DateTime.now().difference(dob).inDays ~/ 365;
                    if (age < 16 || age > 100) return 'Age must be between 16 and 100';
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
                    prefixIcon: const Icon(Icons.phone, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Include country code for international reach',
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
                    hintText: 'e.g., 123 Main St, City, State 12345',
                    prefixIcon: const Icon(Icons.location_on, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Your current residential address',
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
                    return nationalities.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase())).toList();
                  },
                  onSelected: (String selection) {
                    _nationalityController.text = selection;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    _nationalityController.text = controller.text;
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Nationality',
                        hintText: 'e.g., United States',
                        prefixIcon: const Icon(Icons.flag, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        helperText: 'Select or type your nationality',
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
                  controller: _institutionController,
                  decoration: InputDecoration(
                    labelText: 'Educational Institution',
                    hintText: 'e.g., Harvard University',
                    prefixIcon: const Icon(Icons.school, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Name of your current school/university',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (value.length < 3) return 'Too short';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _studentIdController,
                  decoration: InputDecoration(
                    labelText: 'Student ID / Roll Number',
                    hintText: 'e.g., 2023001',
                    prefixIcon: const Icon(Icons.card_membership, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Your unique student identification number',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(value)) return 'Alphanumeric only';
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

  Widget _buildExperienceStep() {
    final screenWidth = MediaQuery.of(context).size.width;
    return Column(
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
                  'Step 2: Share your experience',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Highlight what makes you unique – opportunities await! Fields marked optional can be skipped if not applicable.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _linkedinController,
                  decoration: InputDecoration(
                    labelText: 'LinkedIn Profile (optional)',
                    hintText: 'e.g., https://linkedin.com/in/johndoe',
                    prefixIcon: const Icon(Icons.link, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Link to your professional profile',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    if (!value.startsWith('https://www.linkedin.com/')) return 'Must start with https://www.linkedin.com/';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _academicLevelController.text.isEmpty ? null : _academicLevelController.text,
                  decoration: InputDecoration(
                    labelText: 'Current Academic Level',
                    hintText: 'e.g., Bachelor\'s',
                    prefixIcon: const Icon(Icons.book, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Required - Your highest education level',
                  ),
                  items: academicLevels.map((String level) {
                    return DropdownMenuItem<String>(value: level, child: Text(level));
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _academicLevelController.text = newValue ?? '';
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    return majors.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase())).toList();
                  },
                  onSelected: (String selection) {
                    _majorController.text = selection;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    _majorController.text = controller.text;
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Major/Field of Study',
                        hintText: 'e.g., Computer Science',
                        prefixIcon: const Icon(Icons.subject, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        helperText: 'Required - Your area of study or expertise',
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
                  controller: _expectedPassoutYearController,
                  decoration: InputDecoration(
                    labelText: 'Expected Passout Year',
                    hintText: 'e.g., 2026',
                    prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Year you expect to graduate',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    final year = int.tryParse(value);
                    if (year == null) return 'Enter a valid year';
                    final currentYear = DateTime.now().year;
                    if (year < currentYear || year > currentYear + 10) return 'Year must be between $currentYear and ${currentYear + 10}';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _portfolioController,
                  decoration: InputDecoration(
                    labelText: 'Portfolio/Links (optional)',
                    hintText: 'e.g., github.com/johndoe/portfolio',
                    prefixIcon: const Icon(Icons.link, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Links to your work samples or GitHub',
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    if (!RegExp(r'^(https?://)?[\w.-]+\.[a-z]{2,}$').hasMatch(value)) return 'Enter valid URL';
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

  Widget _buildPreferencesStep() {
    final screenWidth = MediaQuery.of(context).size.width;
    return Column(
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
                  'Step 3: Your aspirations',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'What excites you? Let\'s match you with dream opportunities.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    return skillsDevs.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase())).toList();
                  },
                  onSelected: (String selection) {
                    _skillsDevController.text = selection;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    _skillsDevController.text = controller.text;
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Skills to Develop',
                        hintText: 'e.g., Leadership',
                        prefixIcon: const Icon(Icons.trending_up, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        helperText: 'Areas you want to improve in',
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
                  controller: _interestsController,
                  decoration: InputDecoration(
                    labelText: 'Interests',
                    hintText: 'e.g., AI, Sustainability',
                    prefixIcon: const Icon(Icons.favorite, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Hobbies or topics that motivate you',
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (value.length < 10) return 'At least 10 characters';
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
              child: const Text('Back', style: TextStyle(color: Color(0xFF27AE60))),
            )
          else
            const SizedBox(width: 0),
          const Spacer(),
          Row(
            children: [
              if (_currentStep < 2) // Only show Save & Next for steps before the last
                ElevatedButton(
                  onPressed: _isLoading ? null : () {
                    if (_formKey.currentState!.validate()) {
                      _saveFormData(); // Save without moving to next step
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