import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:ideaship/auth/auth_log_reg.dart';
import 'package:ideaship/dashboard.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'studentrole.dart';
import 'companyrole.dart';
// import other role files as needed

Widget loadRolePage(String route) {
  switch (route) {
    case 'studentrole.dart':
      return const StudentRolePage();
    case 'companyrole.dart':
      return const CompanyRolePage();
    // Add cases for other roles
    default:
      return Container(
        color: Colors.grey[200],
        child: const Center(child: Text('Unknown Role Form')),
      );
  }
}

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> roles = [
    {
      'title': 'Student/Professional',
      'subtitle': 'Seeking opportunities',
      'icon': 'assets/student.svg',
      'route': 'studentrole.dart',
      'heroTag': 'student-icon'
    },
    {
      'title': 'Company/HR',
      'subtitle': 'Looking to hire talent',
      'icon': 'assets/company.svg',
      'route': 'companyrole.dart',
      'heroTag': 'company-icon'
    },
    {
      'title': 'Startup/Entrepreneur',
      'subtitle': 'Building solutions',
      'icon': 'assets/startup.svg',
      'route': 'startuprole.dart',
      'heroTag': 'startup-icon'
    },
    // {
    //   'title': 'Investor',
    //   'subtitle': 'Funding ventures',
    //   'icon': 'assets/investor.svg',
    //   'route': 'investorrole.dart',
    //   'heroTag': 'investor-icon'
    // },
    {
      'title': 'Mentor/Advisor',
      'subtitle': 'Guiding professionals',
      'icon': 'assets/mentor.svg',
      'route': 'mentorrole.dart',
      'heroTag': 'mentor-icon'
    },
    {
      'title': 'Reporter/Journalist',
      'subtitle': 'Creating & sharing news',
      'icon': 'assets/reporter.svg',
      'route': 'reporterrole.dart',
      'heroTag': 'reporter-icon'


    },
   {
     'title': 'Educator/Trainer',
     'subtitle': 'Skill development',
     'icon': 'assets/educator.svg',
     'route': 'educatorrole.dart',
     'heroTag': 'educator-icon'
   },
    {
      'title': 'Researcher/Innovator',
      'subtitle': 'Cutting-edge projects',
      'icon': 'assets/researcher.svg',
      'route': 'researcherrole.dart',
      'heroTag': 'researcher-icon'
    },
    {
      'title': 'Freelancer/Consultant',
      'subtitle': 'Expertise on-demand',
      'icon': 'assets/freelancer.svg',
      'route': 'freelancerrole.dart',
      'heroTag': 'freelancer-icon'
    },
    // {
    //   'title': 'Incubator/Accelerator',
    //   'subtitle': 'Startup support',
    //   'icon': 'assets/incubator.svg',
    //   'route': 'incubatorrole.dart',
    //   'heroTag': 'incubator-icon'
    // },
    {
      'title': 'Community/Non-Profit',
      'subtitle': 'Social innovation',
      'icon': 'assets/community.svg',
      'route': 'communityrole.dart',
      'heroTag': 'community-icon'
    },
    // {
    //   'title': 'Government/Policy Maker',
    //   'subtitle': 'Policy support',
    //   'icon': 'assets/government.svg',
    //   'route': 'governmentrole.dart',
    //   'heroTag': 'government-icon'
    // },
    {
      'title': 'Service Provider',
      'subtitle': 'Legal & Tech support',
      'icon': 'assets/service.svg',
      'route': 'servicerole.dart',
      'heroTag': 'service-icon'
    },
    // {
    //   'title': 'Recruiter/Placement',
    //   'subtitle': 'Job assistance',
    //   'icon': 'assets/recruiter.svg',
    //   'route': 'recruiterrole.dart',
    //   'heroTag': 'recruiter-icon'
    // },
    // {
    //   'title': 'Alumni/Professional',
    //   'subtitle': 'Networking & stories',
    //   'icon': 'assets/alumni.svg',
    //   'route': 'alumnirole.dart',
    //   'heroTag': 'alumni-icon'
    // }
  ];

  List<Map<String, String>> filteredRoles = [];
  Timer? _debounce;
  String? _username;
  // ignore: unused_field
  String? _email;
  String? _id;
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadBasicUserData();
    filteredRoles = roles;
    _searchController.addListener(_filterRoles);
  }

  Future<void> _loadBasicUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'User';
      _email = prefs.getString('email');
      _id = prefs.getString('id');
      _role = prefs.getString('role');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkFormStatus());
  }

  Future<void> _checkFormStatus() async {
    final prefs = await SharedPreferences.getInstance();
    bool profileCompleted = prefs.getBool('profileCompleted') ?? false;

    if (profileCompleted) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
      }
      return;
    }

    if (_id != null && _id != '0') {
      try {
        print('Checking form status for ID: $_id');

        http.Response response;

        // Try POST first
        try {
          response = await http
              .post(
                Uri.parse('https://server.awarcrown.com/roledata/formstatus'),
                body: {'id': _id},
                headers: {'Content-Type': 'application/x-www-form-urlencoded'},
              )
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          print("POST request failed, trying GET... Error: $e");

          // Fallback to GET
          response = await http
              .get(
                Uri.parse(
                    'https://server.awarcrown.com/roledata/formstatus?id=$_id'),
              )
              .timeout(const Duration(seconds: 10));
        }

        if (response.statusCode == 200) {
          try {
            final Map<String, dynamic> data = json.decode(response.body);

            if (data['success'] == true && data['completed'] == true) {
              await prefs.setBool('profileCompleted', true);

              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DashboardPage()),
                );
              }
              return;
            }
          } catch (jsonErr) {
            _showError("Invalid server response. Please try again later.");
            print("JSON Parse Error: $jsonErr");
          }
        } else if (response.statusCode == 401) {
          _showError("Session expired. Please log in again.");
          await prefs.clear();
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AuthLogReg()),
            );
          }
          return;
        } else {
          _showError(
              "Server error (${response.statusCode}). Please try again later.");
        }
      } on TimeoutException {
        _showError("Request timed out. Check your internet connection.");
      } catch (e) {
        _showError("Something went wrong. Please try again.");
        print('Error checking form status: $e');
      }

      // Fallback: redirect to role form if role exists
      if (_role != null) {
        String route = _getRouteForRole(_role!);
        if (route.isNotEmpty && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => loadRolePage(route)),
          );
        }
      }
      return;
    }
    // Stay on role selection by default
  }

  String _getRouteForRole(String role) {
    switch (role.toLowerCase()) {
      case 'student':
      case 'professional':
        return 'studentrole.dart';
      case 'company':
      case 'hr':
        return 'companyrole.dart';
      // Add cases for other roles
      default:
        return '';
    }
  }

  void _filterRoles() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final query = _searchController.text.toLowerCase();
      setState(() {
        filteredRoles = roles
            .where((role) =>
                role['title']!.toLowerCase().contains(query) ||
                role['subtitle']!.toLowerCase().contains(query))
            .toList();
      });
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Welcome, $_username!',
          style: const TextStyle(
            color: Color(0xFF2C3E50),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF2C3E50)),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear(); // Logout: clear all
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const AuthLogReg()),
                );
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            top: screenHeight * 0.02,
            left: screenWidth * 0.04,
            right: screenWidth * 0.04,
            bottom: screenHeight * 0.02,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select your role to get started',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: const Color(0xFF333333),
                ),
                semanticsLabel: 'Select your role to proceed',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search role...',
                  prefixIcon:
                      const Icon(Icons.search, color: Color(0xFF27AE60)),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount =
                        (constraints.maxWidth > 360) ? 2 : 1;
                    return GridView.builder(
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: screenWidth * 0.03,
                        mainAxisSpacing: screenHeight * 0.02,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: filteredRoles.length,
                      itemBuilder: (context, index) {
                        final role = filteredRoles[index];
                        return RoleCard(
                          title: role['title']!,
                          subtitle: role['subtitle']!,
                          iconPath: role['icon']!,
                          route: role['route']!,
                          heroTag: role['heroTag']!,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final String iconPath;
  final String route;
  final String heroTag;

  const RoleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.iconPath,
    required this.route,
    required this.heroTag,
  });

  @override
  State<RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<RoleCard> {
  bool isTapped = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTapDown: (_) => setState(() => isTapped = true),
      onTapUp: (_) => setState(() => isTapped = false),
      onTapCancel: () => setState(() => isTapped = false),
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) {
              return FadeTransition(
                opacity: animation,
                child: loadRolePage(widget.route),
              );
            },
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: isTapped
              ? []
              : [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
          border: isTapped
              ? Border.all(color: const Color(0xFF27AE60), width: 2)
              : null,
        ),
        child: Card(
          elevation: isTapped ? 0 : 6,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: widget.heroTag,
                  child: AnimatedScale(
                    scale: 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: SvgPicture.asset(
                      widget.iconPath,
                      height: screenWidth * 0.12,
                      color: const Color(0xFF27AE60),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: screenWidth * 0.045,
                    color: const Color(0xFF2C3E50),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: const Color(0xFF7F8C8D),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
