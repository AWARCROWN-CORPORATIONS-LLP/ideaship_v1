import 'package:flutter/material.dart';
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

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _allNotifications = [];
  NotificationFilter _filter = NotificationFilter.all;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    if (_filter == NotificationFilter.all) {
      return _allNotifications;
    }
    return _allNotifications.where((n) => !(n['read'] ?? false)).toList();
  }

  Future<void> _loadNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getStringList('notifications') ?? [];
    final List<Map<String, dynamic>> loaded = notificationsJson
        .map((jsonStr) => Map<String, dynamic>.from(json.decode(jsonStr)))
        .toList();
    if (mounted) {
      setState(() => _allNotifications = loaded);
      // Update unread count via callback with absolute value
      final unread = _allNotifications.where((n) => !(n['read'] ?? false)).length;
      widget.onUnreadChanged(unread);
    }
  }

  Future<void> _markAsReadById(String id) async {
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getStringList('notifications') ?? [];
    bool updated = false;
    for (int i = 0; i < notificationsJson.length; i++) {
      final data = json.decode(notificationsJson[i]);
      if (data['id'] == id && !(data['read'] ?? false)) {
        data['read'] = true;
        notificationsJson[i] = json.encode(data);
        updated = true;
        break;
      }
    }
    if (updated) {
      await prefs.setStringList('notifications', notificationsJson);
      await _loadNotifications();  // Refresh and update count
    }
  }

  Future<void> _clearAllNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notifications');
    if (mounted) {
      setState(() => _allNotifications = []);
      widget.onUnreadChanged(0);
    }
  }

  Future<void> _deleteById(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsJson = prefs.getStringList('notifications') ?? [];
    notificationsJson.removeWhere((jsonStr) {
      final data = json.decode(jsonStr);
      return data['id'] == id;
    });
    await prefs.setStringList('notifications', notificationsJson);
    await _loadNotifications();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted')),
      );
    }
  }

  Future<void> _showDeleteDialog(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text('Are you sure you want to delete this notification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _deleteById(id);
    }
  }

  void _showActionMenu(BuildContext context, Map<String, dynamic> notif) {
    final id = notif['id'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: const Text('Delete Notification'),
              subtitle: const Text('This action cannot be undone.'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, id);
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
      // Fetch and nav to thread
      try {
        final response = await http.get(
          Uri.parse('https://server.awarcrown.com/threads/$threadId'),
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final thread = Thread.fromJson(data);
          final prefs = await SharedPreferences.getInstance();
          final username = prefs.getString('username') ?? '';
          final userId = prefs.getInt('user_id') ?? 0;
          if (mounted) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => ThreadDetailScreen(
                thread: thread,
                username: username,
                userId: userId,
              ),
            ));
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load thread: $e')));
        }
      }
    } else if (postId != null) {
      // Fetch and nav to post
      try {
        final prefs = await SharedPreferences.getInstance();
        final username = prefs.getString('username') ?? '';
        final response = await http.get(
          Uri.parse('https://server.awarcrown.com/feed/fetch_single_post?post_id=$postId&username=${Uri.encodeComponent(username)}'),
        ).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final post = data['post'] ?? {};
          if (post.isNotEmpty) {
            final commentsResponse = await http.get(
              Uri.parse('https://server.awarcrown.com/feed/fetch_comments?post_id=$postId&username=${Uri.encodeComponent(username)}'),
            ).timeout(const Duration(seconds: 10));
            List<dynamic> comments = [];
            if (commentsResponse.statusCode == 200) {
              final commentsData = json.decode(commentsResponse.body);
              comments = commentsData['comments'] ?? [];
            }
            final userId = prefs.getInt('user_id') ?? 0;
            if (mounted) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => CommentsPage(
                  post: post,
                  comments: comments,
                  username: username,
                  userId: userId,
                ),
              ));
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load post: $e')));
        }
      }
    }
    // Else, just mark read
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'new_comment':
      case 'new_post_comment':
        return Icons.comment;
      case 'inspired':
        return Icons.thumb_up;
      case 'collab_request':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  String _formatTime(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _getEmptyMessage() {
    if (_allNotifications.isEmpty) {
      return 'No notifications yet';
    } else if (_filter == NotificationFilter.unread) {
      return 'No unread notifications';
    }
    return 'No notifications yet';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final filtered = _filteredNotifications;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Notifications ${filtered.length}',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        actions: [
          PopupMenuButton<NotificationFilter>(
            initialValue: _filter,
            onSelected: (NotificationFilter value) {
              setState(() {
                _filter = value;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<NotificationFilter>>[
              const PopupMenuItem<NotificationFilter>(
                value: NotificationFilter.all,
                child: Row(
                  children: [
                    Icon(Icons.list),
                    SizedBox(width: 8),
                    Text('All'),
                  ],
                ),
              ),
              const PopupMenuItem<NotificationFilter>(
                value: NotificationFilter.unread,
                child: Row(
                  children: [
                    Icon(Icons.mark_email_unread),
                    SizedBox(width: 8),
                    Text('Unread'),
                  ],
                ),
              ),
            ],
          ),
          if (_allNotifications.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.mark_chat_read),
              color: colorScheme.onSurface,
              onPressed: _allNotifications.any((n) => !(n['read'] ?? false))
                  ? () async {
                      // Mark all read
                      final prefs = await SharedPreferences.getInstance();
                      final notificationsJson = prefs.getStringList('notifications') ?? [];
                      bool changed = false;
                      for (int i = 0; i < notificationsJson.length; i++) {
                        final data = json.decode(notificationsJson[i]);
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
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              color: colorScheme.onSurface,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Clear All Notifications'),
                      content: const Text('This will permanently delete all notifications. Are you sure?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('Cancel', style: TextStyle(color: colorScheme.onSurfaceVariant)),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _clearAllNotifications();
                          },
                          child: Text('Clear All', style: TextStyle(color: colorScheme.error)),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications,
        color: colorScheme.primary,
        child: filtered.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none,
                      size: 80,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _getEmptyMessage(),
                      style: TextStyle(
                        fontSize: 18,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getEmptyMessage() == 'No notifications yet' 
                          ? 'Stay tuned for updates!' 
                          : 'Mark some as read to see them here.',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final notif = filtered[index];
                  final isRead = notif['read'] ?? false;
                  final type = notif['data']?['type'] ?? '';
                  final icon = _getIconForType(type);
                  final timeAgo = _formatTime(notif['timestamp']);

                  return AnimatedOpacity(
                    opacity: isRead ? 0.7 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: isRead ? 0 : 2,
                      color: isRead 
                          ? colorScheme.surfaceVariant.withOpacity(0.5)
                          : colorScheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isRead 
                              ? Colors.transparent 
                              : colorScheme.primary.withOpacity(0.1),
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _onNotificationTap(notif, context),
                        onLongPress: () => _showActionMenu(context, notif),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isRead 
                                      ? colorScheme.onSurfaceVariant.withOpacity(0.2)
                                      : colorScheme.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  icon,
                                  color: isRead 
                                      ? colorScheme.onSurfaceVariant 
                                      : colorScheme.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      notif['title'] ?? '',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: isRead 
                                            ? FontWeight.normal 
                                            : FontWeight.w600,
                                        color: isRead 
                                            ? colorScheme.onSurfaceVariant 
                                            : colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      notif['body'] ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    timeAgo,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.circle,
                                        size: 8,
                                        color: Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}