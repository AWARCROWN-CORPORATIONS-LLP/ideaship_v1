import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import '../dashboard.dart'; // Import Dashboard for navigation

class CompanyRolePage extends StatefulWidget {
  const CompanyRolePage({super.key});

  @override
  State<CompanyRolePage> createState() => _CompanyRolePageState();
}

class _CompanyRolePageState extends State<CompanyRolePage> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _contactPersonNameController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _industryController = TextEditingController();
  final _websiteController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _candidatePreferencesController = TextEditingController();
  final _diversityGoalsController = TextEditingController();
  final _budgetController = TextEditingController();
  final _companyCultureController = TextEditingController();
  final _preferredTalentSourcesController = TextEditingController();
  final _trainingProgramsController = TextEditingController();
  final _businessRegistrationController = TextEditingController();
  final _authorizedSignatoryController = TextEditingController();
  final _einController = TextEditingController();
  final _referenceContactController = TextEditingController();
  final _websiteDomainVerificationController = TextEditingController();
  String? _contactDesignation;
  String? _selectedCompanySize;
  String? _selectedLocationPreference;
  bool _bgCheckConsent = false;
  String _username = '';
  String _email = '';
  String _id = '';
  bool _isLoading = false;

  // Suggestions data
  final List<String> industries = ['Tech', 'Finance', 'Healthcare', 'Education', 'Manufacturing', 'Marketing', 'Other'];
  final List<String> companySizes = ['Small (1-50 employees)', 'Medium (51-500 employees)', 'Large (501-1000 employees)', 'Enterprise (1000+ employees)'];
  final List<String> designations = ['HR', 'CEO', 'Admin', 'Manager', 'Other'];
  final List<String> locationPrefs = ['On-site', 'Remote', 'Hybrid'];

  @override
  void initState() {
    super.initState();
    _loadSessionData();
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
      // Do not auto-fill contact email; let user input
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
        try {
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
        } catch (jsonError) {
          print('JSON parse error in profile status check: $jsonError');
        }
      } else {
        print('Unexpected status code in profile status check: ${response.statusCode}');
      }
    } on SocketException {
      print('Network error during profile status check: No internet connection');
    } on FormatException {
      print('Invalid response format during profile status check');
    } on TimeoutException {
      print('Timeout during profile status check');
    } catch (e) {
      print('Unexpected error checking profile status: $e');
    }
  }

  // Load saved form data from SharedPreferences
  Future<void> _loadFormData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _currentStep = prefs.getInt('currentStep') ?? 0;
        _companyNameController.text = prefs.getString('companyName') ?? '';
        _contactPersonNameController.text = prefs.getString('contactPersonName') ?? '';
        _contactDesignation = prefs.getString('contactDesignation');
        _contactEmailController.text = prefs.getString('contactEmail') ?? '';
        _contactPhoneController.text = prefs.getString('contactPhone') ?? '';
        _companyAddressController.text = prefs.getString('companyAddress') ?? '';
        _industryController.text = prefs.getString('industry') ?? '';
        _selectedCompanySize = prefs.getString('companySize');
        _websiteController.text = prefs.getString('website') ?? '';
        _linkedinController.text = prefs.getString('linkedin') ?? '';
        _candidatePreferencesController.text = prefs.getString('candidatePreferences') ?? '';
        _diversityGoalsController.text = prefs.getString('diversityGoals') ?? '';
        _selectedLocationPreference = prefs.getString('locationPreferences');
        _budgetController.text = prefs.getString('budget') ?? '';
        _companyCultureController.text = prefs.getString('companyCulture') ?? '';
        _preferredTalentSourcesController.text = prefs.getString('preferredTalentSources') ?? '';
        _trainingProgramsController.text = prefs.getString('trainingPrograms') ?? '';
        _businessRegistrationController.text = prefs.getString('businessRegistration') ?? '';
        _authorizedSignatoryController.text = prefs.getString('authorizedSignatory') ?? '';
        _einController.text = prefs.getString('ein') ?? '';
        _referenceContactController.text = prefs.getString('referenceContact') ?? '';
        _websiteDomainVerificationController.text = prefs.getString('websiteDomainVerification') ?? '';
        _bgCheckConsent = prefs.getBool('bgCheckConsent') ?? false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading saved data: $e')),
        );
      }
    }
  }

  // Save form data to SharedPreferences
  Future<void> _saveFormData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('currentStep', _currentStep);
      await prefs.setString('companyName', _companyNameController.text);
      await prefs.setString('contactPersonName', _contactPersonNameController.text);
      if (_contactDesignation != null) await prefs.setString('contactDesignation', _contactDesignation!);
      await prefs.setString('contactEmail', _contactEmailController.text);
      await prefs.setString('contactPhone', _contactPhoneController.text);
      await prefs.setString('companyAddress', _companyAddressController.text);
      await prefs.setString('industry', _industryController.text);
      await prefs.setString('companySize', _selectedCompanySize ?? '');
      await prefs.setString('website', _websiteController.text);
      await prefs.setString('linkedin', _linkedinController.text);
      await prefs.setString('candidatePreferences', _candidatePreferencesController.text);
      await prefs.setString('diversityGoals', _diversityGoalsController.text);
      await prefs.setString('locationPreferences', _selectedLocationPreference ?? '');
      await prefs.setString('budget', _budgetController.text);
      await prefs.setString('companyCulture', _companyCultureController.text);
      await prefs.setString('preferredTalentSources', _preferredTalentSourcesController.text);
      await prefs.setString('trainingPrograms', _trainingProgramsController.text);
      await prefs.setString('businessRegistration', _businessRegistrationController.text);
      await prefs.setString('authorizedSignatory', _authorizedSignatoryController.text);
      await prefs.setString('ein', _einController.text);
      await prefs.setString('referenceContact', _referenceContactController.text);
      await prefs.setString('websiteDomainVerification', _websiteDomainVerificationController.text);
      await prefs.setBool('bgCheckConsent', _bgCheckConsent);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress saved automatically!')),
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
      await prefs.remove('companyName');
      await prefs.remove('contactPersonName');
      await prefs.remove('contactDesignation');
      await prefs.remove('contactEmail');
      await prefs.remove('contactPhone');
      await prefs.remove('companyAddress');
      await prefs.remove('industry');
      await prefs.remove('companySize');
      await prefs.remove('website');
      await prefs.remove('linkedin');
      await prefs.remove('candidatePreferences');
      await prefs.remove('diversityGoals');
      await prefs.remove('locationPreferences');
      await prefs.remove('budget');
      await prefs.remove('companyCulture');
      await prefs.remove('preferredTalentSources');
      await prefs.remove('trainingPrograms');
      await prefs.remove('businessRegistration');
      await prefs.remove('authorizedSignatory');
      await prefs.remove('ein');
      await prefs.remove('referenceContact');
      await prefs.remove('websiteDomainVerification');
      await prefs.remove('bgCheckConsent');
    } catch (e) {
      print('Error clearing form data: $e');
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _contactPersonNameController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _companyAddressController.dispose();
    _industryController.dispose();
    _websiteController.dispose();
    _linkedinController.dispose();
    _candidatePreferencesController.dispose();
    _diversityGoalsController.dispose();
    _budgetController.dispose();
    _companyCultureController.dispose();
    _preferredTalentSourcesController.dispose();
    _trainingProgramsController.dispose();
    _businessRegistrationController.dispose();
    _authorizedSignatoryController.dispose();
    _einController.dispose();
    _referenceContactController.dispose();
    _websiteDomainVerificationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      _saveFormData(); // Save data before moving to next step
      if (_currentStep < 2) {
        setState(() => _currentStep++);
      } else {
        _showSubmitConfirmation();
      }
    } else {
      _showErrorDialog('Please address the validation errors before proceeding.');
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _saveFormData(); // Save data before going back
      setState(() => _currentStep--);
    }
  }

  void _showSubmitConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Submission'),
        content: const Text('Are you sure you want to submit your company profile? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitForm();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF34495E)),
            child: const Text('Submit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorDialog('Please address the validation errors before submitting.');
      return;
    }

    if (!_bgCheckConsent) {
      _showErrorDialog('You must consent to background verification to proceed.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _sendDataToBackend();

      if (response.statusCode >= 500) {
        _showErrorDialog('Server error occurred. Please try again later.');
        return;
      }

      if (response.statusCode >= 400) {
        String errorMsg = 'Validation error. Please review your inputs.';
        try {
          final Map<String, dynamic> jsonResponse = json.decode(response.body);
          errorMsg = jsonResponse['message'] ?? errorMsg;
          if (response.statusCode == 409) {
            // Handle duplicate: set completed and navigate
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('profileCompleted', true);
            await prefs.setString('role', 'company');
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
          }
        } catch (jsonError) {
          print('JSON parse error in submit: $jsonError');
        }
        _showErrorDialog(errorMsg);
        return;
      }

      try {
        final Map<String, dynamic> jsonResponse = json.decode(response.body);
        if (jsonResponse['success'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('role', 'company');
          await prefs.setBool('profileCompleted', true);
          await prefs.setString('companyName', _companyNameController.text);
          await _clearFormData(); // Clear saved form data after successful submission

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(jsonResponse['message'] ?? 'Your company profile has been successfully registered. Welcome to the network!')),
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
          _showErrorDialog(jsonResponse['message'] ?? 'Submission failed. Please try again.');
        }
      } catch (jsonError) {
        _showErrorDialog('Invalid response from server. Please try again.');
      }
    } on SocketException {
      _showErrorDialog('No internet connection. Please check your network and try again.');
    } on FormatException {
      _showErrorDialog('Invalid server response. Please try again later.');
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
        title: const Text('Error'),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<http.Response> _sendDataToBackend() async {
    final url = Uri.parse('https://server.awarcrown.com/roledata/companyrole');
    final body = {
      'id': _id,
      'username': _username,
      'email': _email,
      'company_name': _companyNameController.text.trim(),
      'contact_person_name': _contactPersonNameController.text.trim(),
      'contact_designation': _contactDesignation ?? '',
      'contact_email': _contactEmailController.text.trim(),
      'contact_phone': _contactPhoneController.text.trim(),
      'company_address': _companyAddressController.text.trim(),
      'industry': _industryController.text.trim(),
      'company_size': _selectedCompanySize ?? '',
      'website': _websiteController.text.trim(),
      'linkedin_profile': _linkedinController.text.trim(),
      'candidate_preferences': _candidatePreferencesController.text.trim(),
      'diversity_goals': _diversityGoalsController.text.trim(),
      'location_preferences': _selectedLocationPreference ?? '',
      'budget': _budgetController.text.trim(),
      'company_culture': _companyCultureController.text.trim(),
      'preferred_talent_sources': _preferredTalentSourcesController.text.trim(),
      'training_programs': _trainingProgramsController.text.trim(),
      'business_registration': _businessRegistrationController.text.trim(),
      'authorized_signatory': _authorizedSignatoryController.text.trim(),
      'ein': _einController.text.trim(),
      'reference_contact': _referenceContactController.text.trim(),
      'website_domain_verification': _websiteDomainVerificationController.text.trim(),
      'email_verification': 'verified',
      'bg_check_consent': _bgCheckConsent.toString(),
      'role_type': 'company',
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
    return Column(
      children: [
        Container(
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
                        color: index <= _currentStep ? const Color(0xFF34495E) : Colors.grey[300],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[400]!),
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
                      ['Basic Information', 'Preferences', 'Verification'][index],
                      style: TextStyle(
                        fontSize: 12,
                        color: index <= _currentStep ? const Color(0xFF34495E) : Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
        // Progress bar
        LinearProgressIndicator(
          value: (_currentStep + 1) / 3.0,
          backgroundColor: Colors.grey[300],
         valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34495E)),

          minHeight: 4,
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildBasicInfoStep();
      case 1:
        return _buildPreferencesStep();
      case 2:
        return _buildVerificationStep();
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
                  'Step 1: Company Overview',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Provide essential details about your organization to establish your presence on the platform.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _companyNameController,
                  decoration: InputDecoration(
                    labelText: 'Company Name *',
                    hintText: 'e.g., Acme Technologies Inc.',
                    prefixIcon: const Icon(Icons.business, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Legal name of the organization',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Company name is required';
                    if (value.trim().length < 2) return 'Company name must be at least 2 characters';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactPersonNameController,
                  decoration: InputDecoration(
                    labelText: 'Contact Person Name *',
                    hintText: 'e.g., Jane Smith',
                    prefixIcon: const Icon(Icons.person, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Full name of the HR representative',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Contact name is required';
                    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) return 'Only letters and spaces allowed';
                    if (value.trim().length < 2) return 'Name must be at least 2 characters';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _contactDesignation,
                  decoration: InputDecoration(
                    labelText: 'Designation *',
                    hintText: 'Select designation',
                    prefixIcon: const Icon(Icons.badge, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Role of the contact person',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  items: designations.map((String des) {
                    return DropdownMenuItem<String>(value: des, child: Text(des));
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _contactDesignation = newValue;
                    });
                  },
                  validator: (value) => value == null ? 'Designation is required' : null,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactEmailController,
                  decoration: InputDecoration(
                    labelText: 'Contact Email *',
                    hintText: 'e.g., hr@acme.com',
                    prefixIcon: const Icon(Icons.email, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Official company email address',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [], // Disable autofill
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Email is required';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) return 'Please enter a valid email address';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactPhoneController,
                  decoration: InputDecoration(
                    labelText: 'Contact Phone *',
                    hintText: 'e.g., +1-123-456-7890',
                    prefixIcon: const Icon(Icons.phone, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Include country code',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Phone is required';
                    if (!RegExp(r'^\+?[\d\s\-\(\)]{10,}$').hasMatch(value.trim())) return 'Enter a valid phone number (at least 10 digits)';
                    return null;
                  },
                  keyboardType: TextInputType.phone,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _companyAddressController,
                  decoration: InputDecoration(
                    labelText: 'Company Address *',
                    hintText: 'e.g., 123 Business Ave, City, State 12345',
                    prefixIcon: const Icon(Icons.location_on, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Headquarters or primary office location',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Address is required';
                    if (value.trim().length < 10) return 'Address must be at least 10 characters';
                    return null;
                  },
                  maxLines: 2,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return industries.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase())).toList();
                  },
                  onSelected: (String selection) {
                    _industryController.text = selection;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Industry *',
                        hintText: 'e.g., Tech',
                        prefixIcon: const Icon(Icons.category, color: Color(0xFF34495E)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        helperText: 'Sector your company operates in',
                        errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Industry is required';
                        return null;
                      },
                      onFieldSubmitted: (String value) => onFieldSubmitted(),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    );
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCompanySize,
                  decoration: InputDecoration(
                    labelText: 'Company Size *',
                    hintText: 'Select size',
                    prefixIcon: const Icon(Icons.people, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Approximate number of employees',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  items: companySizes.map((String size) {
                    return DropdownMenuItem<String>(value: size, child: Text(size));
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCompanySize = newValue;
                    });
                  },
                  validator: (value) => value == null ? 'Company size is required' : null,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _websiteController,
                  decoration: InputDecoration(
                    labelText: 'Website *',
                    hintText: 'e.g., https://www.acme.com',
                    prefixIcon: const Icon(Icons.language, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Official company website',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Website is required';
                    final trimmed = value.trim();
                    if (!RegExp(r'^(https?://)?[\w.-]+\.[a-z]{2,}$').hasMatch(trimmed)) return 'Please enter a valid URL';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _linkedinController,
                  decoration: InputDecoration(
                    labelText: 'LinkedIn/Business Profile',
                    hintText: 'e.g., https://linkedin.com/company/acme',
                    prefixIcon: const Icon(Icons.link, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Company LinkedIn page for verification',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    final trimmed = value.trim();
                    if (!trimmed.startsWith('https://www.linkedin.com/')) return 'Must start with https://www.linkedin.com/';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
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
                  'Step 2: Company Preferences',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Share your organizational priorities to better connect with suitable talent.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _candidatePreferencesController,
                  decoration: InputDecoration(
                    labelText: 'Candidate Preferences *',
                    hintText: 'e.g., 2+ years experience, Relevant certifications',
                    prefixIcon: const Icon(Icons.person_search, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Desired qualifications and experience',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Candidate preferences are required';
                    if (value.trim().length < 20) return 'Please provide at least 20 characters';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _diversityGoalsController,
                  decoration: InputDecoration(
                    labelText: 'Diversity Goals *',
                    hintText: 'e.g., 30% women in tech roles, Inclusive hiring practices',
                    prefixIcon: const Icon(Icons.diversity_3, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Commitment to diversity, equity, and inclusion',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Diversity goals are required';
                    if (value.trim().length < 10) return 'Please provide at least 10 characters';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedLocationPreference,
                  decoration: InputDecoration(
                    labelText: 'Location Preferences *',
                    hintText: 'Select preference',
                    prefixIcon: const Icon(Icons.map, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Preferred work arrangement for roles',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  items: locationPrefs.map((String loc) {
                    return DropdownMenuItem<String>(value: loc, child: Text(loc));
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedLocationPreference = newValue;
                    });
                  },
                  validator: (value) => value == null ? 'Location preference is required' : null,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _budgetController,
                  decoration: InputDecoration(
                    labelText: 'Budget (Salary Range) *',
                    hintText: 'e.g., 800k - 1200k annually',
                    prefixIcon: const Icon(Icons.attach_money, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Compensation structure for roles',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Budget is required';
                    if (!RegExp(r'^[\d,]+\s*-\s*[\d,]+(\s*(annually|monthly|hourly))?$').hasMatch(value.trim())) return 'Enter valid range (e.g., 800k - 1200k annually)';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _companyCultureController,
                  decoration: InputDecoration(
                    labelText: 'Company Culture *',
                    hintText: 'e.g., Collaborative, Innovative, Work-life balance focused',
                    prefixIcon: const Icon(Icons.workspace_premium, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Core values and work environment',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Company culture is required';
                    if (value.trim().length < 20) return 'Please provide at least 20 characters';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _preferredTalentSourcesController,
                  decoration: InputDecoration(
                    labelText: 'Preferred Talent Sources *',
                    hintText: 'e.g., Top universities, Job boards, Referrals',
                    prefixIcon: const Icon(Icons.school, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Channels for sourcing candidates',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Talent sources are required';
                    if (value.trim().length < 10) return 'Please provide at least 10 characters';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _trainingProgramsController,
                  decoration: InputDecoration(
                    labelText: 'Training Programs *',
                    hintText: 'e.g., Onboarding academy, Skill development workshops',
                    prefixIcon: const Icon(Icons.lightbulb_outline, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Internal training and onboarding offered',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Training programs are required';
                    if (value.trim().length < 20) return 'Please provide at least 20 characters';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationStep() {
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
                  'Step 3: Verification',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Complete verification to access full platform features and build trust with candidates.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _businessRegistrationController,
                  decoration: InputDecoration(
                    labelText: 'Business Registration *',
                    hintText: 'e.g., Certificate number or registration ID',
                    prefixIcon: const Icon(Icons.verified_user, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Proof of company registration',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Business registration is required';
                    if (value.trim().length < 5) return 'Must be at least 5 characters';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _authorizedSignatoryController,
                  decoration: InputDecoration(
                    labelText: 'Authorized Signatory *',
                    hintText: 'e.g., Jane Smith, HR Director',
                    prefixIcon: const Icon(Icons.edit, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Name and title confirming authority',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Authorized signatory is required';
                    if (value.trim().length < 5) return 'Must be at least 5 characters';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
TextFormField(
  controller: _einController,
  decoration: InputDecoration(
    labelText: 'Employer Identification Number (EIN) *',
    hintText: 'e.g., 12-3456789 or AB-1234XYZ',
    prefixIcon: const Icon(Icons.numbers, color: Color(0xFF34495E)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    helperText: 'For tax and legal verification',
    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
  ),
  validator: (value) {
    if (value == null || value.trim().isEmpty) {
      return 'EIN is required';
    }
    // ✅ Accepts letters, numbers, and dash/hyphen
    if (!RegExp(r'^[A-Za-z0-9-]+$').hasMatch(value.trim())) {
      return 'Only letters, numbers, and "-" are allowed';
    }
    return null;
  },


                  keyboardType: TextInputType.number,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _referenceContactController,
                  decoration: InputDecoration(
                    labelText: 'Reference Contact *',
                    hintText: 'e.g., seniorleadership@acme.com or +1-987-654-3210',
                    prefixIcon: const Icon(Icons.contact_phone, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Senior leadership or external partner for validation',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Reference contact is required';
                    final trimmed = value.trim();
                    if (trimmed.contains('@')) {
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(trimmed)) return 'Invalid email format';
                    } else if (!RegExp(r'^\+?[\d\s\-\(\)]{10,}$').hasMatch(trimmed)) return 'Invalid phone format (at least 10 digits)';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _websiteDomainVerificationController,
                  decoration: InputDecoration(
                    labelText: 'Website/Domain Verification *',
                    hintText: 'e.g., acme.com domain confirmation code',
                    prefixIcon: const Icon(Icons.domain, color: Color(0xFF34495E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Confirmation of official website or email domain',
                    errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Verification is required';
                    if (value.trim().length < 3) return 'Must be at least 3 characters';
                    return null;
                  },
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _bgCheckConsent,
                      activeColor: const Color(0xFF34495E),
                      onChanged: (value) => setState(() => _bgCheckConsent = value ?? false),
                    ),
                    const Expanded(
                      child: Text(
                        'I consent to background verification for the company to ensure compliance and trust. *',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!_bgCheckConsent)
                  const Text(
                    'Background check consent is required for submission.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
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
              onPressed: _isLoading ? null : _prevStep,
              child: const Text('Back', style: TextStyle(color: Color(0xFF34495E))),
            )
          else
            const SizedBox(width: 0),
          const Spacer(),
          Row(
            children: [
              if (_currentStep < 2)
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : () {
                    if (_formKey.currentState!.validate()) {
                      _saveFormData();
                    } else {
                      _showErrorDialog('Please address the validation errors in this step.');
                    }
                  },
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _nextStep,
                icon: _currentStep < 2 ? const Icon(Icons.arrow_forward, size: 18) : const Icon(Icons.check, size: 18),
                label: Text(_currentStep == 2 ? 'Submit' : 'Next'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF34495E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
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
                    colors: [Color(0xFF34495E), Color(0xFF5D6D7E)],
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
                      'Register your company to connect with top talent',
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
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF34495E)),

                ),
              ),
            ),
        ],
      ),
    );
  }
}