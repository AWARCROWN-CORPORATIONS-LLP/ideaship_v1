// dashboard.dart
import 'package:flutter/material.dart';
import 'package:ideaship/feed/createpost.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ideaship/auth/auth_log_reg.dart';
import 'feed/posts.dart'; // Import the PostsPage from feed/posts.dart
import 'feed/createpost.dart'; // Import CreatePostPage
// TODO: Import other pages as needed, e.g.,
// import 'feed/startups.dart';
// import 'feed/investors.dart';
// import 'feed/mentors.dart';
// import 'feed/companies.dart';
// import 'chat/message.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _selectedIndex = 0;

  late TabController _tabController;

  String? _username;
  String? _email;
  String? _role;
  String? _major;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this); // Updated to 5 tabs
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _username = prefs.getString('username') ?? '';
        _email = prefs.getString('email') ?? '';
        _role = prefs.getString('role') ?? '';
        _major = prefs.getString('major');
        _isLoading = false;
      });
    }
  }

  void _openJobDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _showMessageDialog() {
    // TODO: Navigate to chat/message.dart instead of dialog
    // Navigator.push(context, MaterialPageRoute(builder: (context) => MessagePage()));
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Messages Coming Soon!'),
          content: const Text(
            'We are building a larger community globally to connect. This is within weeks we will make this feature available.',
            style: TextStyle(fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Got it!'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthLogReg()),
      );
    }
  }

  AppBar _buildAppBar() {
    List<Widget> actions = [
      IconButton(
        onPressed: () {
          // TODO: Implement notifications
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notifications coming soon!')),
          );
        },
        icon: const Icon(Icons.notifications_outlined, color: Colors.black87),
      ),
      IconButton(
        onPressed: _showMessageDialog,
        icon: const Icon(Icons.chat_bubble_outline, color: Colors.black87),
      ),
      IconButton(
        icon: const Icon(Icons.logout),
        onPressed: _logout,
      ),
    ];

    if (_selectedIndex == 0) {
      return AppBar(
        elevation: 0.4,
        backgroundColor: Colors.white,
        title: const Text("Ideaship",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1268D1),
                fontSize: 25)),
        actions: actions,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF1268D1),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF1268D1),
          tabs: const [
            Tab(text: "Feed"),
            Tab(text: "Startups"),
          
          ],
        ),
      );
    } else {
      String title;
      switch (_selectedIndex) {
        case 1:
          title = 'Roles';
          break;
        case 3:
          title = 'Alerts';
          break;
        case 4:
          title = 'Settings';
          break;
        default:
          title = 'Ideaship';
      }
      return AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        elevation: 0.4,
        actions: actions,
      );
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: const [
                PostsPage(), // Dynamic feed from feed/posts.dart
                Center(child: Text("Startups Page")), // TODO: Replace with StartupsPage() from feed/startups.dart
                Center(child: Text("Investors Page")), // TODO: Replace with InvestorsPage() from feed/investors.dart
                Center(child: Text("Mentors Page")), // TODO: Replace with MentorsPage() from feed/mentors.dart
                Center(child: Text("Companies Page")), // TODO: Replace with CompaniesPage() from feed/companies.dart
              ],
            ),
            // Right-side handle
            Positioned(
              right: 6,
              top: MediaQuery.of(context).size.height * 0.25,
              child: GestureDetector(
                onTap: _openJobDrawer,
                child: Container(
                  width: 36,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                  ),
                  child: const Center(
                      child: RotatedBox(
                          quarterTurns: 1,
                          child: Icon(Icons.arrow_forward_ios, size: 18))),
                ),
              ),
            ),
          ],
        );
      case 1:
        return Center(
          child: _isLoading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Welcome, $_username!'),
                    Text('Email: $_email'),
                    Text('Role: $_role'),
                    if (_major != null) Text('Major: $_major'),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to role-specific dashboard or features
                      },
                      child: const Text('Go to Features'),
                    ),
                  ],
                ),
        );
      case 3:
        return const Center(child: Text('Alerts Page'));
      case 4:
        return const Center(child: Text('Settings Page'));
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: JobDrawer(),
      endDrawerEnableOpenDragGesture: true,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                // Open post creation page createpost.dart
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreatePostPage()),
                );
              },
              backgroundColor: const Color(0xFF1268D1),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                _navButton(Icons.home_rounded, "Home", 0),
                _navButton(Icons.work_outline, "Roles", 1),
              ]),
              Row(children: [
                _navButton(Icons.notifications_outlined, "Alerts", 3),
                _navButton(Icons.settings_outlined, "Settings", 4),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navButton(IconData icon, String label, int index) {
    bool active = _selectedIndex == index;
    return MaterialButton(
      minWidth: 56,
      onPressed: () {
        setState(() {
          _selectedIndex = index;
        });
        if (index == 0) {
          _tabController.animateTo(0);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? const Color(0xFF1268D1) : Colors.grey[700]),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: active ? const Color(0xFF1268D1) : Colors.grey[700])),
        ],
      ),
    );
  }
}

class JobDrawer extends StatelessWidget {
  JobDrawer({super.key});

  final List<Map<String, String>> jobs = List.generate(5, (i) {
    return {
      'title': 'Software Intern #$i',
      'location': i % 2 == 0 ? 'Remote' : 'Bengaluru',
      'type': i % 2 == 0 ? 'Internship' : 'Full-time',
    };
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(children: [
              const Text("Jobs",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close))
            ]),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: jobs.length,
              itemBuilder: (context, i) {
                final j = jobs[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    title: Text(j['title']!),
                    subtitle: Text("${j['location']} • ${j['type']}"),
                    trailing:
                        ElevatedButton(onPressed: () {}, child: const Text("Apply")),
                  ),
                );
              },
            ),
          )
        ]),
      ),
    );
  }
}