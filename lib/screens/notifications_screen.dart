import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _service = NotificationService();
  final _supabase = Supabase.instance.client;

  String? _userId;
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _userId = _supabase.auth.currentUser?.id;
    _loadNotifications();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_realtimeChannel != null) {
      _service.unsubscribe(_realtimeChannel!);
    }
    super.dispose();
  }

  // ─── Data Loading ────────────────────────────────────────────────────────

  Future<void> _loadNotifications() async {
    if (_userId == null) {
      setState(() {
        _isLoading = false;
        _error = 'No hay sesión activa.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final notifications = await _service.getNotifications(_userId!);
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error al cargar las notificaciones.';
        });
      }
    }
  }

  void _subscribeToRealtime() {
    if (_userId == null) return;
    _realtimeChannel = _service.subscribeToNotifications(
      _userId!,
      (_) => _loadNotifications(),
    );
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> _markAllAsRead() async {
    if (_userId == null) return;
    setState(() {
      for (int i = 0; i < _notifications.length; i++) {
        if (!_notifications[i].isRead) {
          _notifications[i] = _notifications[i].copyWith(forceRead: true);
        }
      }
    });
    await _service.markAllAsRead(_userId!);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todas las notificaciones marcadas como leídas.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _clearNotification(String id) async {
    setState(() => _notifications.removeWhere((n) => n.id == id));
    await _service.deleteNotification(id);
  }

  Future<void> _toggleReadStatus(
      int index, List<AppNotification> filteredList) async {
    final notif = filteredList[index];
    final actualIndex = _notifications.indexWhere((n) => n.id == notif.id);
    if (actualIndex == -1) return;

    final newReadState = !notif.isRead;
    setState(() {
      _notifications[actualIndex] = notif.copyWith(forceRead: newReadState);
    });
    if (newReadState) {
      await _service.markAsRead(notif.id);
    } else {
      await _service.markAsUnread(notif.id);
    }
  }

  // ─── Filtering ───────────────────────────────────────────────────────────

  List<AppNotification> _getFilteredNotifications(String tab) {
    switch (tab) {
      case 'publicaciones':
        return _notifications
            .where((n) => n.type == 'like_post' || n.type == 'comment_post')
            .toList();
      case 'noticias':
        return _notifications
            .where((n) =>
                n.type == 'like_news' ||
                n.type == 'comment_news' ||
                (n.type == 'message' && n.payload['is_global_news'] == true))
            .toList();
      case 'mensajes':
        return _notifications
            .where((n) =>
                n.type == 'message' && n.payload['is_global_news'] != true)
            .toList();
      case 'todas':
      default:
        return _notifications;
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _formatTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inSeconds < 60) return 'Ahora';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min';
    if (difference.inHours < 24) return '${difference.inHours} h';
    if (difference.inDays < 7) return '${difference.inDays} d';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  IconData _getIconForNotification(AppNotification n) {
    if (n.type == 'message' && n.payload['is_global_news'] == true) {
      return Icons.article_rounded;
    }
    switch (n.type) {
      case 'like_post':
        return Icons.favorite_rounded;
      case 'like_news':
        return Icons.thumb_up_rounded;
      case 'comment_post':
        return Icons.comment_rounded;
      case 'comment_news':
        return Icons.chat_bubble_rounded;
      case 'message':
        return Icons.message_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColorForNotification(AppNotification n) {
    if (n.type == 'message' && n.payload['is_global_news'] == true) {
      return const Color(0xFF1DA1F2);
    }
    switch (n.type) {
      case 'like_post':
        return Colors.redAccent;
      case 'like_news':
        return const Color(0xFFFF9800);
      case 'comment_post':
        return const Color(0xFF1DA1F2);
      case 'comment_news':
        return const Color(0xFF9C27B0);
      case 'message':
        return const Color(0xFF003E90);
      default:
        return Colors.blueGrey;
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Row(
          children: [
            const Text(
              'Notificaciones',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
            tooltip: 'Recargar',
            onPressed: _isLoading ? null : _loadNotifications,
          ),
          if (unreadCount > 0)
            IconButton(
              icon: const Icon(Icons.playlist_add_check_rounded,
                  color: Colors.black87),
              tooltip: 'Marcar todas como leídas',
              onPressed: _markAllAsRead,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF003E90),
          labelColor: const Color(0xFF003E90),
          unselectedLabelColor: Colors.grey.shade600,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          isScrollable: false,
          tabs: const [
            Tab(text: 'Todas'),
            Tab(text: 'Publicaciones'),
            Tab(text: 'Noticias'),
            Tab(text: 'Mensajes'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF003E90)))
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNotificationList('todas'),
                    _buildNotificationList('publicaciones'),
                    _buildNotificationList('noticias'),
                    _buildNotificationList('mensajes'),
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Error desconocido',
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003E90),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(String tab) {
    final labels = {
      'todas': 'No tienes notificaciones',
      'publicaciones': 'Sin notificaciones de publicaciones',
      'noticias': 'Sin notificaciones de noticias',
      'mensajes': 'Sin notificaciones de mensajes',
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              labels[tab] ?? 'No hay notificaciones',
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationList(String filterType) {
    final filtered = _getFilteredNotifications(filterType);

    if (filtered.isEmpty) return _buildEmpty(filterType);

    return RefreshIndicator(
      color: const Color(0xFF003E90),
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 20),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final notification = filtered[index];
          return _buildNotificationTile(notification, index, filtered);
        },
      ),
    );
  }

  Widget _buildNotificationTile(
    AppNotification notification,
    int index,
    List<AppNotification> filteredList,
  ) {
    final typeColor = _getColorForNotification(notification);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _clearNotification(notification.id),
      background: Container(
        color: Colors.redAccent.shade100,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      child: InkWell(
        onTap: () => _toggleReadStatus(index, filteredList),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: notification.isRead
                ? Colors.white
                : const Color(0xFF003E90).withValues(alpha: 0.04),
            border: Border(
              bottom: BorderSide(color: Colors.grey.shade100, width: 1),
            ),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar with type-badge overlay ──────────────────────
              Stack(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: typeColor.withValues(alpha: 0.12),
                    backgroundImage: notification.actorAvatar != null
                        ? NetworkImage(notification.actorAvatar!)
                        : null,
                    child: notification.actorAvatar == null
                        ? Text(
                            notification.actorInitial,
                            style: TextStyle(
                                color: typeColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: typeColor,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Icon(
                        _getIconForNotification(notification),
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // ── Text content ─────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.bold,
                              fontSize: 13.5,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatTime(notification.createdAt),
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: notification.isRead
                            ? Colors.grey.shade500
                            : Colors.black87,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // ── Unread dot ───────────────────────────────────────────
              if (!notification.isRead)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: typeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
