import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

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
  final _employeeIdController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _companyController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _academicLevelController = TextEditingController();
  final _majorController = TextEditingController();
  final _gpaController = TextEditingController();
  final _courseworkController = TextEditingController();
  final _extracurricularController = TextEditingController();
  final _workExpController = TextEditingController();
  final _skillsController = TextEditingController();
  final _projectsController = TextEditingController();
  final _certificationsController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _careerGoalsController = TextEditingController();
  final _industryPrefController = TextEditingController();
  final _jobTypeController = TextEditingController();
  final _locationPrefController = TextEditingController();
  final _workEnvController = TextEditingController();
  final _availabilityController = TextEditingController();
  final _skillsDevController = TextEditingController();
  final _interestsController = TextEditingController();
  final _govIdController = TextEditingController();
  final _govIdTypeController = TextEditingController();
  final _referenceController = TextEditingController();
  final _expectedPassoutYearController = TextEditingController();
  final _educationStatusController = TextEditingController();
  final _jobStatusController = TextEditingController();
  bool _bgCheckConsent = false;
  bool _isStudent = true; // Default to student, can be toggled
  String? _educationStatus; // 'studying' or 'graduated'
  String? _jobStatus; // 'current' or 'past'
  String? _govIdType; // 'Aadhar', 'PAN', 'Passport', 'Other'

  String _username = '';
  String _email = '';
  String _id = '';
  bool _isLoading = false;

  // Suggestions data
  final List<String> nationalities = ['United States', 'India', 'United Kingdom', 'Canada', 'Australia', 'Germany', 'France', 'China', 'Japan', 'Brazil'];
  final List<String> academicLevels = ['High School', 'Bachelor\'s', 'Master\'s', 'PhD', 'Other'];
  final List<String> majors = ['Computer Science', 'Engineering', 'Business', 'Medicine', 'Arts', 'Law', 'Other'];
  final List<String> industries = ['Tech', 'Finance', 'Healthcare', 'Education', 'Marketing', 'Other'];
  final List<String> jobTypes = ['Full-time', 'Part-time', 'Internship', 'Freelance', 'Remote'];
  final List<String> locations = ['New York', 'London', 'Mumbai', 'Toronto', 'Sydney', 'Berlin', 'Paris', 'Beijing', 'Tokyo', 'Sao Paulo'];
  final List<String> workEnvs = ['Office', 'Remote', 'Hybrid'];
  final List<String> availabilities = ['Immediate', '1-3 months', '3-6 months', '6+ months'];
  final List<String> skillsDevs = ['Leadership', 'Coding', 'Public Speaking', 'Project Management', 'Data Analysis', 'Other'];
  final List<String> educationStatuses = ['Still Studying', 'Graduated'];
  final List<String> jobStatuses = ['Current Job', 'Past Job'];
  final List<String> govIdTypes = ['Aadhar', 'PAN', 'Passport', 'Other'];

  @override
  void initState() {
    super.initState();
    _loadSessionData();
    _dobController.text = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 7300))); // Default to 20 years ago
  }

  Future<void> _loadSessionData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'Unknown';
      _email = prefs.getString('email') ?? 'Unknown';
      _id = prefs.getString('id') ?? '0';
    });
    _usernameController.text = _username;
    _emailController.text = _email;
  }

  @override
  void dispose() {
    // Dispose controllers
    _usernameController.dispose();
    _emailController.dispose();
    _fullNameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _nationalityController.dispose();
    _institutionController.dispose();
    _studentIdController.dispose();
    _employeeIdController.dispose();
    _jobTitleController.dispose();
    _companyController.dispose();
    _linkedinController.dispose();
    _academicLevelController.dispose();
    _majorController.dispose();
    _gpaController.dispose();
    _courseworkController.dispose();
    _extracurricularController.dispose();
    _workExpController.dispose();
    _skillsController.dispose();
    _projectsController.dispose();
    _certificationsController.dispose();
    _portfolioController.dispose();
    _careerGoalsController.dispose();
    _industryPrefController.dispose();
    _jobTypeController.dispose();
    _locationPrefController.dispose();
    _workEnvController.dispose();
    _availabilityController.dispose();
    _skillsDevController.dispose();
    _interestsController.dispose();
    _govIdController.dispose();
    _govIdTypeController.dispose();
    _referenceController.dispose();
    _expectedPassoutYearController.dispose();
    _educationStatusController.dispose();
    _jobStatusController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      if (_currentStep < 3) {
        setState(() => _currentStep++);
      } else {
        _submitForm();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
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

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final response = await _sendDataToBackend();
        if (response.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Welcome to the world\'s largest career network! Profile saved successfully!')),
            );
            Navigator.pop(context);
          }
        } else {
          _showErrorDialog('Failed to save profile. Status code: ${response.statusCode}');
        }
      } catch (e) {
        _showErrorDialog('Network error: $e. Please check your connection.');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      _showErrorDialog('Please fix the errors in this step.');
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
      'student_id': _isStudent ? _studentIdController.text : '',
      'employee_id': !_isStudent ? _employeeIdController.text : '',
      'job_title': _jobTitleController.text,
      'company': _companyController.text,
      'linkedin': _linkedinController.text,
      'academic_level': _academicLevelController.text,
      'major': _majorController.text,
      'gpa': _gpaController.text,
      'coursework': _courseworkController.text,
      'extracurricular': _extracurricularController.text,
      'work_exp': _workExpController.text,
      'skills': _skillsController.text,
      'projects': _projectsController.text,
      'certifications': _certificationsController.text,
      'portfolio': _portfolioController.text,
      'career_goals': _careerGoalsController.text,
      'industry_pref': _industryPrefController.text,
      'job_type': _jobTypeController.text,
      'location_pref': _locationPrefController.text,
      'work_env': _workEnvController.text,
      'availability': _availabilityController.text,
      'skills_dev': _skillsDevController.text,
      'interests': _interestsController.text,
      'education_status': _educationStatus ?? '',
      'expected_passout_year': _expectedPassoutYearController.text,
      'job_status': _jobStatus ?? '',
      'gov_id': _govIdController.text,
      'gov_id_type': _govIdType ?? '',
      'email_verification': 'verified', // Default verified
      'reference': _referenceController.text,
      'bg_check_consent': _bgCheckConsent.toString(),
      'role_type': _isStudent ? 'student' : 'professional',
    };
    return http.post(url, body: body);
  }

  Widget _buildStepIndicator() {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      margin: EdgeInsets.symmetric(vertical: screenWidth * 0.02),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(4, (index) {
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
                  ['Basics', 'Experience', 'Preferences', 'Verify'][index],
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
      case 3:
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
                  'Step 1: Tell us about yourself',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start your journey to the world\'s largest career network! Choose if you are a Student or Professional to tailor the form.',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Radio<bool>(
                      value: true,
                      groupValue: _isStudent,
                      onChanged: (value) => setState(() => _isStudent = value!),
                      activeColor: const Color(0xFF27AE60),
                    ),
                    const Text('Student'),
                    Radio<bool>(
                      value: false,
                      groupValue: _isStudent,
                      onChanged: (value) => setState(() => _isStudent = value!),
                      activeColor: const Color(0xFF27AE60),
                    ),
                    const Text('Professional'),
                  ],
                ),
                const SizedBox(height: 16),
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
                    labelText: 'Educational Institution / Current Employer',
                    hintText: 'e.g., Harvard University or Google Inc.',
                    prefixIcon: const Icon(Icons.school, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Name of your current school/university or employer',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (value.length < 3) return 'Too short';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (_isStudent)
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
                  )
                else
                  TextFormField(
                    controller: _employeeIdController,
                    decoration: InputDecoration(
                      labelText: 'Employee ID',
                      hintText: 'e.g., EMP-45678',
                      prefixIcon: const Icon(Icons.badge, color: Color(0xFF27AE60)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      helperText: 'Your unique employee identification number',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Required';
                      if (!RegExp(r'^[A-Za-z0-9\-]+$').hasMatch(value)) return 'Alphanumeric and hyphen only';
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
                if (!_isStudent)
                  ...[
                    DropdownButtonFormField<String>(
                      value: _jobStatus,
                      decoration: InputDecoration(
                        labelText: 'Job Status',
                        hintText: 'Select your current job status',
                        prefixIcon: const Icon(Icons.work_outline, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        helperText: 'Are you currently employed here?',
                      ),
                      items: jobStatuses.map((String status) {
                        return DropdownMenuItem<String>(value: status, child: Text(status));
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _jobStatus = newValue;
                        });
                      },
                      validator: (value) => value == null ? 'Required for professionals' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _jobTitleController,
                      decoration: InputDecoration(
                        labelText: 'Current/Past Job Title',
                        hintText: 'e.g., Software Engineer',
                        prefixIcon: const Icon(Icons.work, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        helperText: '$_jobStatus? Enter job title (required for professionals)',
                      ),
                      validator: (value) {
                        if (!_isStudent && (value == null || value.isEmpty)) return 'Required for professionals';
                        if (value != null && value.length < 2) return 'Too short';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _companyController,
                      decoration: InputDecoration(
                        labelText: 'Current/Past Company',
                        hintText: 'e.g., Google',
                        prefixIcon: const Icon(Icons.business, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        helperText: 'Company name where you work(ed) (required for professionals)',
                      ),
                      validator: (value) {
                        if (!_isStudent && (value == null || value.isEmpty)) return 'Required for professionals';
                        if (value != null && value.length < 2) return 'Too short';
                        return null;
                      },
                    ),
                  ],
                if (_isStudent)
                  ...[
                    DropdownButtonFormField<String>(
                      value: _educationStatus,
                      decoration: InputDecoration(
                        labelText: 'Education Status',
                        hintText: 'Select your current education status',
                        prefixIcon: const Icon(Icons.school, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        helperText: 'Are you still studying?',
                      ),
                      items: educationStatuses.map((String status) {
                        return DropdownMenuItem<String>(value: status, child: Text(status));
                      }).toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _educationStatus = newValue;
                        });
                      },
                      validator: (value) => value == null ? 'Required for students' : null,
                    ),
                    const SizedBox(height: 16),
                    if (_educationStatus == 'Still Studying')
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
                          if (value == null || value.isEmpty) return 'Required if still studying';
                          final year = int.tryParse(value);
                          if (year == null) return 'Enter a valid year';
                          final currentYear = DateTime.now().year;
                          if (year < currentYear || year > currentYear + 10) return 'Year must be between $currentYear and ${currentYear + 10}';
                          return null;
                        },
                      ),
                  ],
                const SizedBox(height: 16),
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
                    labelText: 'Current Academic Level (optional for professionals)',
                    hintText: 'e.g., Bachelor\'s',
                    prefixIcon: const Icon(Icons.book, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: '${_isStudent ? "Required" : "Optional"} - Your highest education level',
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
                    if (_isStudent && (value == null || value.isEmpty)) return 'Required';
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
                        labelText: 'Major/Field of Study (optional for professionals)',
                        hintText: 'e.g., Computer Science',
                        prefixIcon: const Icon(Icons.subject, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        helperText: '${_isStudent ? "Required" : "Optional"} - Your area of study or expertise',
                      ),
                      validator: (value) {
                        if (_isStudent && (value == null || value.isEmpty)) return 'Required';
                        return null;
                      },
                      onFieldSubmitted: (String value) => onFieldSubmitted(),
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _gpaController,
                  decoration: InputDecoration(
                    labelText: 'GPA/Grades (optional)',
                    hintText: 'e.g., 3.8/4.0',
                    prefixIcon: const Icon(Icons.grade, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Your academic performance (format: X/Y)',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    if (!RegExp(r'^[\d.]+/[1-4]$').hasMatch(value)) return 'Format: X/Y where Y is 1-4';
                    final parts = value.split('/');
                    final gpa = double.tryParse(parts[0]);
                    final scale = int.tryParse(parts[1]);
                    if (gpa == null || gpa < 0 || gpa > scale!) return 'GPA must be 0 to $scale';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _courseworkController,
                  decoration: InputDecoration(
                    labelText: 'Relevant Coursework (optional for professionals)',
                    hintText: 'e.g., Data Structures, Machine Learning',
                    prefixIcon: const Icon(Icons.menu_book, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: '${_isStudent ? "Required" : "Optional"} - Key courses you\'ve taken',
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (_isStudent && (value == null || value.isEmpty)) return 'Required';
                    if (value != null && value.length < 10) return 'At least 10 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _extracurricularController,
                  decoration: InputDecoration(
                    labelText: 'Extracurricular Activities / Professional Achievements (optional)',
                    hintText: 'e.g., Debate Club, Hackathon Winner',
                    prefixIcon: const Icon(Icons.group, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Clubs, events, or achievements that showcase your skills',
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
                  controller: _workExpController,
                  decoration: InputDecoration(
                    labelText: 'Work Experience / Internships (optional for students)',
                    hintText: 'e.g., Summer intern at XYZ Corp, 3 months',
                    prefixIcon: const Icon(Icons.work, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: '${_isStudent ? "Optional - include internships" : "Required"} - Describe roles and duration',
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (!_isStudent && (value == null || value.isEmpty)) return 'Required';
                    if (value != null && value.length < 20) return 'At least 20 characters describing experience';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _skillsController,
                  decoration: InputDecoration(
                    labelText: 'Skills',
                    hintText: 'e.g., Python, Leadership, Teamwork',
                    prefixIcon: const Icon(Icons.lightbulb, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'List 3-5 key skills separated by commas',
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    final skills = value.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                    if (skills.length < 3) return 'At least 3 skills';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _projectsController,
                  decoration: InputDecoration(
                    labelText: 'Projects',
                    hintText: 'e.g., Built a web app using React',
                    prefixIcon: const Icon(Icons.folder, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Describe 1-3 notable projects with outcomes',
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
                  controller: _certificationsController,
                  decoration: InputDecoration(
                    labelText: 'Certifications (optional)',
                    hintText: 'e.g., AWS Certified Developer',
                    prefixIcon: const Icon(Icons.verified, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'List relevant certifications with issuing body',
                  ),
                  maxLines: 2,
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
                TextFormField(
                  controller: _careerGoalsController,
                  decoration: InputDecoration(
                    labelText: 'Career Goals',
                    hintText: 'e.g., Become a full-stack developer',
                    prefixIcon: const Icon(Icons.star, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Short-term and long-term career objectives',
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (value.length < 20) return 'At least 20 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    return industries.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase())).toList();
                  },
                  onSelected: (String selection) {
                    _industryPrefController.text = selection;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    _industryPrefController.text = controller.text;
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Industry Preferences',
                        hintText: 'e.g., Tech',
                        prefixIcon: const Icon(Icons.business_center, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        helperText: 'Preferred sectors to work in',
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
                DropdownButtonFormField<String>(
                  value: _jobTypeController.text.isEmpty ? null : _jobTypeController.text,
                  decoration: InputDecoration(
                    labelText: 'Job/Opportunity Type',
                    hintText: 'e.g., Full-time',
                    prefixIcon: const Icon(Icons.work_outline, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Type of role you are seeking',
                  ),
                  items: jobTypes.map((String type) {
                    return DropdownMenuItem<String>(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _jobTypeController.text = newValue ?? '';
                    });
                  },
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    return locations.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase())).toList();
                  },
                  onSelected: (String selection) {
                    _locationPrefController.text = selection;
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    _locationPrefController.text = controller.text;
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Location Preferences',
                        hintText: 'e.g., New York',
                        prefixIcon: const Icon(Icons.map, color: Color(0xFF27AE60)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        helperText: 'Preferred work locations (cities/countries)',
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
                DropdownButtonFormField<String>(
                  value: _workEnvController.text.isEmpty ? null : _workEnvController.text,
                  decoration: InputDecoration(
                    labelText: 'Work Environment',
                    hintText: 'e.g., Remote',
                    prefixIcon: const Icon(Icons.home_work, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Preferred work setup',
                  ),
                  items: workEnvs.map((String env) {
                    return DropdownMenuItem<String>(value: env, child: Text(env));
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _workEnvController.text = newValue ?? '';
                    });
                  },
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _availabilityController.text.isEmpty ? null : _availabilityController.text,
                  decoration: InputDecoration(
                    labelText: 'Availability',
                    hintText: 'e.g., Immediate',
                    prefixIcon: const Icon(Icons.schedule, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'When can you start?',
                  ),
                  items: availabilities.map((String avail) {
                    return DropdownMenuItem<String>(value: avail, child: Text(avail));
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _availabilityController.text = newValue ?? '';
                    });
                  },
                  validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
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
                  'Step 4: Verify and join',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'One last step to unlock your profile and connect with millions!',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                DropdownButtonFormField<String>(
                  value: _govIdType,
                  decoration: const InputDecoration(
                    labelText: 'Government ID Type',
                    hintText: 'Select ID type',
                    prefixIcon: Icon(Icons.credit_card, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                    helperText: 'Choose the type of ID you are providing',
                  ),
                  items: govIdTypes.map((String type) {
                    return DropdownMenuItem<String>(value: type, child: Text(type));
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _govIdType = newValue;
                      _govIdController.clear(); // Clear when type changes
                    });
                  },
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _govIdController,
                  decoration: InputDecoration(
                    labelText: 'Government-Issued ID Number',
                    hintText: _govIdType == 'Aadhar' ? 'e.g., 1234 5678 9012 (12 digits)' : _govIdType == 'PAN' ? 'e.g., ABCDE1234F (10 alphanumeric)' : _govIdType == 'Passport' ? 'e.g., Z1234567 (6-12 chars)' : 'Enter full ID',
                    prefixIcon: const Icon(Icons.credit_card, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Provide full ID number for verification',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (_govIdType == 'Aadhar' && !RegExp(r'^\d{12}$').hasMatch(value.replaceAll(' ', ''))) return 'Aadhar must be 12 digits';
                    if (_govIdType == 'PAN' && !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$').hasMatch(value.toUpperCase())) return 'PAN must be 10 alphanumeric (5 letters, 4 digits, 1 letter)';
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
                    labelText: 'Reference Contact (optional)',
                    hintText: 'e.g., mentor@example.com',
                    prefixIcon: const Icon(Icons.person_add, color: Color(0xFF27AE60)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'Email or phone of a reference person',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    if (value.contains('@')) {
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Invalid email';
                    } else if (!RegExp(r'^\+?[\d\s\-\(\)]{10,}$').hasMatch(value)) return 'Invalid phone';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Checkbox(
                      value: _bgCheckConsent,
                      activeColor: const Color(0xFF27AE60),
                      onChanged: (value) => setState(() => _bgCheckConsent = value!),
                    ),
                    const Expanded(
                      child: Text(
                        'I consent to a background check to ensure a safe community.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
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
                : Text(_currentStep == 3 ? 'Join Now' : 'Next Step'),
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
              // App Bar with engaging title
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