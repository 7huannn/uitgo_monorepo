import 'package:flutter/material.dart';
import 'package:rider_app/features/notifications/models/notification_model.dart';
import 'package:rider_app/features/notifications/services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _service = NotificationService();
  late Future<NotificationPageResult> _future;
  bool _unreadOnly = true;

  @override
  void initState() {
    super.initState();
    _future = _loadNotifications();
  }

  Future<NotificationPageResult> _loadNotifications() {
    return _service.listNotifications(unreadOnly: _unreadOnly);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _loadNotifications();
    });
    await _future;
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (notification.isRead) return;
    try {
      await _service.markAsRead(notification.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể cập nhật thông báo: $e')),
        );
      }
    } finally {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _unreadOnly = !_unreadOnly;
                _future = _loadNotifications();
              });
            },
            child: Text(_unreadOnly ? 'Xem tất cả' : 'Chỉ chưa đọc'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<NotificationPageResult>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _buildError(snapshot.error.toString());
            }
            final data = snapshot.data;
            if (data == null || data.items.isEmpty) {
              return _buildEmptyState();
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: data.items.length,
              physics: const AlwaysScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notification = data.items[index];
                return Dismissible(
                  key: ValueKey(notification.id),
                  direction: notification.isRead
                      ? DismissDirection.none
                      : DismissDirection.endToStart,
                  onDismissed: (_) => _markAsRead(notification),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.green[400],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.check, color: Colors.white),
                  ),
                  child: _NotificationTile(
                    notification: notification,
                    onTap: () => _markAsRead(notification),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.notifications_off_outlined,
                  size: 56, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _unreadOnly
                    ? 'Bạn đã đọc tất cả thông báo.'
                    : 'Chưa có thông báo nào.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildError(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                'Không thể tải thông báo',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _refresh,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = notification.isRead ? Colors.grey[600] : Colors.black;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Colors.white
              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.isRead
                ? Colors.grey[200]!
                : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  notification.type == 'promotion'
                      ? Icons.local_offer_outlined
                      : Icons.notifications_active_outlined,
                  color: notification.isRead
                      ? Colors.grey[500]
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notification.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
                if (!notification.isRead)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notification.body,
              style: TextStyle(color: color),
            ),
            const SizedBox(height: 8),
            Text(
              _timeAgo(notification.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  static String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes} phút trước';
    if (diff.inDays < 1) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }
}
