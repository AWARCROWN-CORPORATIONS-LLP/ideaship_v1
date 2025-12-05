import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ideaship/thr_project/thread_details.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../thr_project/threads.dart';
import '../feed/posts.dart';

enum NotificationFilter { all, unread }

class NotificationsPage extends StatefulWidget {
  final Function(int) onUnreadChanged;
  const NotificationsPage({super.key, required this.onUnreadChanged});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _allNotifications = [];
  List<Map<String, dynamic>> _filteredNotifications = [];
  NotificationFilter _filter = NotificationFilter.all;
  String _searchQuery = '';

  late AnimationController? _fadeController;
  Animation<double>? _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController!, curve: Curves.easeInOut);
    _loadNotifications();
  }

  @override
  void dispose() {
    _fadeController?.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getStringList('notifications') ?? [];
    final List<Map<String, dynamic>> loaded = notificationsJson
        .map((jsonStr) => Map<String, dynamic>.from(json.decode(jsonStr)))
        .toList()
      ..sort((a, b) => (b['timestamp'] as String).compareTo(a['timestamp'] as String));

    if (mounted) {
      setState(() {
        _allNotifications = loaded;
        _applyFilterAndSearch();
      });
      final unread = loaded.where((n) => !(n['read'] ?? false)).length;
      widget.onUnreadChanged(unread);
      _fadeController?.forward(from: 0.0);
    }
  }

  void _applyFilterAndSearch() {
    List<Map<String, dynamic>> filtered = List.from(_allNotifications);

    if (_filter == NotificationFilter.unread) {
      filtered = filtered.where((n) => !(n['read'] ?? false)).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((n) {
        final title = (n['title'] as String? ?? '').toLowerCase();
        final body = (n['body'] as String? ?? '').toLowerCase();
        return title.contains(query) || body.contains(query);
      }).toList();
    }

    setState(() {
      _filteredNotifications = filtered;
    });
  }

  Map<String, List<Map<String, dynamic>>> _groupNotifications() {
    final groups = <String, List<Map<String, dynamic>>>{
      'Today': [],
      'Yesterday': [],
      'Older': [],
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var notif in _filteredNotifications) {
      final date = DateTime.parse(notif['timestamp']).toLocal();
      final notifDate = DateTime(date.year, date.month, date.day);

      if (notifDate == today) {
        groups['Today']!.add(notif);
      } else if (notifDate == yesterday) {
        groups['Yesterday']!.add(notif);
      } else {
        groups['Older']!.add(notif);
      }
    }

    groups.removeWhere((key, value) => value.isEmpty);
    return groups;
  }

  Future<void> _markAsReadById(String id) async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getStringList('notifications') ?? [];
    bool updated = false;

    for (int i = 0; i < notificationsJson.length; i++) {
      final data = json.decode(notificationsJson[i]) as Map<String, dynamic>;
      if (data['id'] == id && !(data['read'] ?? false)) {
        data['read'] = true;
        notificationsJson[i] = json.encode(data);
        updated = true;
        break;
      }
    }

    if (updated) {
      await prefs.setStringList('notifications', notificationsJson);
      await _loadNotifications();
    }
  }

  Future<void> _deleteById(String id) async {
    HapticFeedback.mediumImpact();
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getStringList('notifications') ?? [];
    final initialLength = notificationsJson.length;
    notificationsJson.removeWhere((jsonStr) {
      final data = json.decode(jsonStr);
      return data['id'] == id;
    });

    if (notificationsJson.length < initialLength) {
      await prefs.setStringList('notifications', notificationsJson);
      await _loadNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _clearAllNotifications() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text('This will permanently delete all notifications. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Clear All', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('notifications');
      await _loadNotifications();
      widget.onUnreadChanged(0);
    }
  }

  Future<void> _markAllAsRead() async {
    HapticFeedback.selectionClick();
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getStringList('notifications') ?? [];
    bool changed = false;

    for (int i = 0; i < notificationsJson.length; i++) {
      final data = json.decode(notificationsJson[i]) as Map<String, dynamic>;
      if (!(data['read'] ?? false)) {
        data['read'] = true;
        notificationsJson[i] = json.encode(data);
        changed = true;
      }
    }

    if (changed) {
      await prefs.setStringList('notifications', notificationsJson);
      await _loadNotifications();
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'new_comment':
      case 'new_post_comment':
        return Icons.mode_comment_outlined;
      case 'inspired':
        return Icons.favorite_border;
      case 'collab_request':
        return Icons.group_add;
      case 'mention':
        return Icons.alternate_email;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getIconColor(String type, ColorScheme colorScheme) {
    switch (type) {
      case 'inspired':
        return Colors.pink;
      case 'collab_request':
        return Colors.deepPurple;
      case 'mention':
        return Colors.blue;
      default:
        return colorScheme.primary;
    }
  }

  String _formatTime(String timestamp) {
    final dateTime = DateTime.parse(timestamp).toLocal();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  void _showActionMenu(BuildContext context, Map<String, dynamic> notif) {
    final id = notif['id'] as String;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: const Text('Delete Notification'),
              onTap: () {
                Navigator.pop(context);
                _deleteById(id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onNotificationTap(Map<String, dynamic> notif, BuildContext context) async {
    await _markAsReadById(notif['id']);

    final threadId = int.tryParse(notif['data']?['thread_id'] ?? '');
    final postId = int.tryParse(notif['data']?['post_id'] ?? '');

    if (threadId != null) {
      try {
        final response = await http
            .get(Uri.parse('https://server.awarcrown.com/threads/$threadId'))
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200 && mounted) {
          final thread = Thread.fromJson(json.decode(response.body));
          final prefs = await SharedPreferences.getInstance();
          final username = prefs.getString('username') ?? '';
          final userId = prefs.getInt('user_id') ?? 0;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ThreadDetailScreen(
                thread: thread,
                username: username,
                userId: userId,
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load thread')));
        }
      }
    } else if (postId != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final username = prefs.getString('username') ?? '';
        final postResponse = await http.get(
          Uri.parse(
              'https://server.awarcrown.com/feed/fetch_single_post?post_id=$postId&username=${Uri.encodeComponent(username)}'),
        );

        if (postResponse.statusCode == 200) {
          final data = json.decode(postResponse.body);
          final post = data['post'] ?? {};
          if (post.isNotEmpty) {
            final commentsResponse = await http.get(
              Uri.parse(
                  'https://server.awarcrown.com/feed/fetch_comments?post_id=$postId&username=${Uri.encodeComponent(username)}'),
            );
            List<dynamic> comments = [];
            if (commentsResponse.statusCode == 200) {
              final cData = json.decode(commentsResponse.body);
              comments = cData['comments'] ?? [];
            }

            final userId = prefs.getInt('user_id') ?? 0;
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CommentsPage(
                    post: post,
                    comments: comments,
                    username: username,
                    userId: userId,
                  ),
                ),
              );
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load post')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final grouped = _groupNotifications();
    final unreadCount = _allNotifications.where((n) => !(n['read'] ?? false)).length;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Notifications'),
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          if (unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Chip(
                backgroundColor: colorScheme.primary,
                label: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
          PopupMenuButton<NotificationFilter>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filter = value);
              _applyFilterAndSearch();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: NotificationFilter.all, child: Row(children: [Icon(Icons.list), SizedBox(width: 12), Text('All')])),
              const PopupMenuItem(value: NotificationFilter.unread, child: Row(children: [Icon(Icons.mark_email_unread), SizedBox(width: 12), Text('Unread')])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (value) {
                _searchQuery = value;
                _applyFilterAndSearch();
              },
              decoration: InputDecoration(
                hintText: 'Search notifications...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: colorScheme.surfaceContainer.withOpacity(0.4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          if (_allNotifications.isNotEmpty && unreadCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _markAllAsRead,
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Mark all as read'),
                ),
              ),
            ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadNotifications,
              color: colorScheme.primary,
              child: _filteredNotifications.isEmpty
                  ? _buildEmptyState()
                  : FadeTransition(
                      opacity: _fadeAnimation!,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: grouped.length,
                        itemBuilder: (context, index) {
                          final sectionTitle = grouped.keys.elementAt(index);
                          final items = grouped[sectionTitle]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                                child: Text(
                                  sectionTitle,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              ...items.map((notif) => _buildNotificationCard(notif)),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final isRead = notif['read'] ?? false;
    final type = notif['data']?['type'] ?? '';
    final icon = _getIconForType(type);

    return Dismissible(
      key: Key(notif['id']),
      direction: DismissDirection.horizontal,
      background: Container(
        color: Colors.green,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 30),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(Icons.done_all, color: Colors.white), Text('Read', style: TextStyle(color: Colors.white))],
        ),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 30),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Icon(Icons.delete, color: Colors.white), Text('Delete', style: TextStyle(color: Colors.white))],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          _deleteById(notif['id']);
          return true;
        } else {
          await _markAsReadById(notif['id']);
          return false;
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        elevation: isRead ? 1 : 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: _getIconColor(type, Theme.of(context).colorScheme).withOpacity(0.15),
            child: Icon(icon, color: _getIconColor(type, Theme.of(context).colorScheme), size: 26),
          ),
          title: Text(
            notif['title'] ?? 'New notification',
            style: TextStyle(
              fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
              fontSize: 15.5,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              notif['body'] ?? '',
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatTime(notif['timestamp']),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
              ),
              if (!isRead)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Icon(Icons.circle, size: 10, color: Theme.of(context).colorScheme.primary),
                ),
            ],
          ),
          onTap: () => _onNotificationTap(notif, context),
          onLongPress: () => _showActionMenu(context, notif),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.notifications_off_outlined,
                size: 100,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
              ),
              const SizedBox(height: 24),
              Text(
                _filter == NotificationFilter.unread ? 'No unread notifications' : 'No notifications yet',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Stay tuned — when something happens, you’ll see it here!',
                style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}