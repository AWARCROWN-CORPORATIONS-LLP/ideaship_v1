import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ideaship/feed/createpost.dart';
import 'package:ideaship/feed/posts.dart';
import 'package:ideaship/feed/startups.dart';
import 'package:ideaship/settings/usersettings.dart';
import 'package:ideaship/user/userprofile.dart';
import 'package:ideaship/thr_project/threads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ideaship/notify/notifications.dart';
import 'package:http/http.dart' as http;
import 'package:ideaship/feed/publicprofile.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, LaunchMode;
import 'package:ideaship/Market/marketplace.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
 

  int _selectedIndex = 0;
  late TabController _tabController;
  String? _username;
  String? _email;
  String? _role;
  bool _isLoading = true;
  bool _isDarkMode = false;
  bool _isButtonLocked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadUserData();
    _loadThemePreference();
    _checkForUpdate();
     _checkForGooglePlayUpdate();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_selectedIndex == 0) {
      setState(() {});
    }
  }

  Future<void> _checkForUpdate() async {
    try {
      final res = await http
          .get(Uri.parse("https://server.awarcrown.com/update/update_check"))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        if (data['update_available'] == 1) {
          _showUpdateDialog(
            data['message'] ?? "A new version is available!",
            data['update_url'] ??
                "https://play.google.com/store/apps/details?id=com.awarcrown.ideaship",
          );
        }
      }
    } catch (e) {
      debugPrint("Update check error: $e");
    }
  }

  void _showUpdateDialog(String message, String updateUrl) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 25),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.12),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    size: 42,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Update Required",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      backgroundColor: Colors.blue,
                    ),
                    onPressed: () {
                      launchUrl(
                        Uri.parse(updateUrl),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    child: const Text(
                      "Update Now",
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Future<void> _forceImmediateUpdate() async {
  try {
    await InAppUpdate.performImmediateUpdate();
  } catch (e) {
    debugPrint('Immediate update failed: $e');
  }
}

  Future<void> _checkForGooglePlayUpdate() async {
   try {
    final info = await InAppUpdate.checkForUpdate();

    if (!mounted) return;

    if (info.updateAvailability == UpdateAvailability.updateAvailable &&
        info.immediateUpdateAllowed) {
      await _forceImmediateUpdate();
    }
  } catch (e) {
    debugPrint('Google Play update check failed: $e');
  }
}
Future<void> _startFlexibleUpdate() async {
  try {
    await InAppUpdate.startFlexibleUpdate();
    await InAppUpdate.completeFlexibleUpdate();
  } catch (e) {
    debugPrint('Flexible update failed: $e');
  }
}void _showForceUpdateDialog() {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => WillPopScope(
      onWillPop: () async => false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Update Required'),
        content: const Text(
          'A new version is available. Please update to continue using Ideaship.',
        ),
        actions: [
          ElevatedButton(
            onPressed: _forceImmediateUpdate,
            child: const Text('Update Now'),
          ),
        ],
      ),
    ),
  );
}




  Future<void> _coolDownAction(
    Future<void> Function() action, {
    int delayMs = 600,
  }) async {
    if (_isButtonLocked) {
      _showCooldownHint();
      return;
    }

    _isButtonLocked = true;

    try {
      await action();
    } finally {
      Future.delayed(Duration(milliseconds: delayMs), () {
        _isButtonLocked = false;
      });
    }
  }

void _showCooldownHint() {
  if (!mounted) return;

  HapticFeedback.lightImpact(); 

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(milliseconds: 900),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.black.withOpacity(0.88),
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 50,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.hourglass_top_rounded, size: 16, color: Colors.white70),
          SizedBox(width: 8),
          Text(
            "Cooling down…",
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
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

  Future<void> _toggleTheme() async {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', _isDarkMode);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _username = prefs.getString('username') ?? '';
          _email = prefs.getString('email') ?? '';
          _role = prefs.getString('role') ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorBanner('Failed to load user data: ${e.toString()}');
      }
    }
  }

  void _showErrorBanner(String message) {
    if (!mounted) return;

    final colorScheme = _buildColorScheme();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.white.withOpacity(0.96),
        elevation: 6,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 80,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 3),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 18, color: Colors.black54),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSearchPress() {
    showSearch(context: context, delegate: PostSearchDelegate());
  }

  ColorScheme _buildColorScheme() {
    const primaryColor = Color(0xFF1268D1);
    return _isDarkMode
        ? ColorScheme.dark(
            primary: primaryColor,
            onPrimary: Colors.white,
            surface: const Color(0xFF121212),
            onSurface: Colors.white,
            surfaceContainerHighest: const Color(0xFF1E1E1E),
            onSurfaceVariant: Colors.grey[400]!,
            outline: Colors.grey[700]!,
            error: Colors.red,
            onError: Colors.white,
            secondary: Colors.grey[600]!,
            onSecondary: Colors.white,
          )
        : ColorScheme.light(
            primary: primaryColor,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black87,
            surfaceContainerHighest: Colors.grey[100]!,
            onSurfaceVariant: Colors.black54,
            outline: Colors.grey[400]!,
            error: Colors.red,
            onError: Colors.white,
            secondary: Colors.grey[600]!,
            onSecondary: Colors.white,
          );
  }

  AppBar _buildAppBar(ColorScheme colorScheme) {
    List<Widget> actions = [
      IconButton(
        onPressed: _handleSearchPress,
        icon: Icon(Icons.search, color: colorScheme.onSurface),
      ),
      IconButton(
        onPressed: () {
          _coolDownAction(() async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NotificationsPage(onUnreadChanged: (_) {}),
              ),
            );
          });
        },

        icon: Icon(
          Icons.notifications_outlined,
          color: _isButtonLocked ? Colors.grey : colorScheme.onSurface,
        ),
      ),
      IconButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserProfile()),
          );
        },
        icon: Icon(Icons.account_circle, color: colorScheme.onSurface),
      ),
    ];

    if (_selectedIndex == 0) {
      return AppBar(
        automaticallyImplyLeading: false,
        elevation: 0.4,
        backgroundColor: colorScheme.surface,
        title: Text(
          "Ideaship",
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            fontStyle: FontStyle.italic,
            color: colorScheme.primary,
            fontSize: 30,
            shadows: [
              Shadow(
                offset: const Offset(1, 1),
                blurRadius: 5,
                color: colorScheme.primary.withOpacity(0.5),
              ),
            ],
          ),
        ),
        actions: actions,
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
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
          title = 'Marketplace';
          break;
        case 2:
          title = 'Round Table';
          break;
        case 3:
          title = 'Settings';
          break;
        default:
          title = 'Ideaship';
      }
      return AppBar(
        automaticallyImplyLeading: false,
        title: Text(title, style: TextStyle(color: colorScheme.onSurface)),
        backgroundColor: colorScheme.surface,
        elevation: 0.4,
        actions: actions,
      );
    }
  }

  Widget _buildBody(ColorScheme colorScheme) {
    switch (_selectedIndex) {
      case 0:
        return TabBarView(
          controller: _tabController,
          children: const [PostsPage(), StartupsPage()],
        );
      case 1:
        return const MarketplacePage();

      case 2:
        return ThreadsScreen();
      case 3:
        return const SettingsPage();

      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = _buildColorScheme();
    final themeData = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
    );

    return Theme(
      data: themeData,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: _buildAppBar(colorScheme),

        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final slide = Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(animation);

            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: KeyedSubtree(
            key: ValueKey<int>(_selectedIndex),
            child: _buildBody(colorScheme),
          ),
        ),

        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

        floatingActionButton: Opacity(
          opacity: _selectedIndex == 0 ? 1.0 : 0.4,
          child: FloatingActionButton(
            onPressed: _selectedIndex == 0
                ? () {
                    _coolDownAction(() async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreatePostPage(),
                        ),
                      );
                    });
                  }
                : () {
                    _showCooldownHint();
                  },

            backgroundColor: themeData.colorScheme.primary,
            child: const Icon(Icons.add, size: 28, color: Colors.white),
          ),
        ),

        bottomNavigationBar: BottomAppBar(
          color: themeData.colorScheme.surface,
          elevation: 8,
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          child: SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _navButton(Icons.home_rounded, "Home", 0, colorScheme),
                _navButton(Icons.storefront_outlined, "Market", 1, colorScheme),

                const SizedBox(width: 60),

                _navButton(Icons.article, "Round", 2, colorScheme),
                _navButton(Icons.settings_outlined, "Settings", 3, colorScheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navButton(
    IconData icon,
    String label,
    int index,
    ColorScheme colorScheme,
  ) {
    bool active = _selectedIndex == index;
    return MaterialButton(
      minWidth: 70,
      onPressed: () {
        _coolDownAction(() async {
          if (index == 3) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            );
          } else {
            setState(() => _selectedIndex = index);
          }
        });
      },

      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 26,
            color: active ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: active
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class PostSearchDelegate extends SearchDelegate with ChangeNotifier {
  Timer? _debounce;
  List<dynamic> _results = [];
  bool _loading = false;

  List<String> _recentSearches = [];

  PostSearchDelegate() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    _recentSearches = prefs.getStringList("search_history") ?? [];
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList("search_history", _recentSearches);
  }

  void _addToHistory(String username) {
    if (!_recentSearches.contains(username)) {
      _recentSearches.insert(0, username);
      if (_recentSearches.length > 10) {
        _recentSearches.removeLast();
      }
    }

    _saveHistory();
    notifyListeners();
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("search_history");
    _recentSearches.clear();
    notifyListeners();
  }

  void _onQueryChanged(String query, BuildContext context) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchResults(query, context);
    });
  }

  Future<void> _fetchResults(String query, BuildContext context) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      _results = [];
      _loading = false;
      notifyListeners();
      return;
    }

    _loading = true;
    notifyListeners();

    try {
      final url = Uri.parse(
        "https://server.awarcrown.com/accessprofile/search?username=$trimmed",
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _results = data["results"] ?? [];
      } else {
        _results = [];
      }
    } catch (e) {
      _results = [];
    }

    _loading = false;
    notifyListeners();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    _onQueryChanged(query, context);

    if (query.trim().isEmpty) {
      return _recentSearchList(context);
    }

    if (_loading) {
      return _shimmerLoader();
    }

    return _buildResultsList(context);
  }

  @override
  Widget buildResults(BuildContext context) {
    if (_loading) return _shimmerLoader();
    return _buildResultsList(context);
  }

  Widget _shimmerLoader() {
    return ListView.builder(
      itemCount: 6,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
      },
    );
  }

  Widget _recentSearchList(BuildContext context) {
    if (_recentSearches.isEmpty) {
      return _emptyState("Search students or companies");
    }

    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "Recent Searches",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(onPressed: _clearHistory, child: const Text("Clear")),
          ],
        ),
        ..._recentSearches.map(
          (username) => ListTile(
            leading: const Icon(Icons.history),
            title: Text(username),
            onTap: () async {
              query = username;
              await _fetchResults(username, context);
              // ignore: use_build_context_synchronously
              showResults(context);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultsList(BuildContext context) {
    if (_results.isEmpty) {
      return _emptyState("No users found");
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final user = _results[index];

        return TweenAnimationBuilder(
          duration: const Duration(milliseconds: 250),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: _resultTile(context, user),
        );
      },
    );
  }

  Widget _resultTile(BuildContext context, dynamic user) {
    final username = user["username"];
    final profilePic = user["profile_picture"];

    return GestureDetector(
      onTap: () {
        _addToHistory(username);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PublicProfilePage(targetUsername: username),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              // ignore: deprecated_member_use
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(radius: 26, backgroundImage: NetworkImage(profilePic)),
            const SizedBox(width: 16),

            Expanded(
              child: RichText(
                text: TextSpan(
                  children: _highlightMatch(username),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  List<TextSpan> _highlightMatch(String username) {
    if (query.isEmpty) {
      return [TextSpan(text: "@$username")];
    }

    final lower = username.toLowerCase();
    final input = query.toLowerCase();
    final start = lower.indexOf(input);

    if (start == -1) {
      return [TextSpan(text: "@$username")];
    }

    return [
      TextSpan(text: "@${username.substring(0, start)}"),
      TextSpan(
        text: username.substring(start, start + input.length),
        style: const TextStyle(color: Colors.blue),
      ),
      TextSpan(text: username.substring(start + input.length)),
    ];
  }

  Widget _emptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded),
      onPressed: () => close(context, null),
    );
  }
}
