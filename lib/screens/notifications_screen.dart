import 'package:flutter/material.dart';

class AppNotification {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final String type; // 'like', 'comment', 'mention', 'connection', 'system'
  final String senderName;
  final String? senderAvatarUrl;
  final bool isRead;
  final bool? isConnectionAccepted; // null = pending, true = accepted, false = declined

  AppNotification({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.type,
    required this.senderName,
    this.senderAvatarUrl,
    this.isRead = false,
    this.isConnectionAccepted,
  });

  AppNotification copyWith({
    bool? isRead,
    bool? isConnectionAccepted,
  }) {
    return AppNotification(
      id: id,
      title: title,
      description: description,
      timestamp: timestamp,
      type: type,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      isRead: isRead ?? this.isRead,
      isConnectionAccepted: isConnectionAccepted ?? this.isConnectionAccepted,
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<AppNotification> _notifications = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    
    // Seed initial mock data
    _notifications.addAll([
      AppNotification(
        id: '1',
        title: 'Nueva solicitud de conexión',
        description: 'Ana Martínez quiere conectar contigo en ConnectNet.',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        type: 'connection',
        senderName: 'Ana Martínez',
        isRead: false,
        isConnectionAccepted: null,
      ),
      AppNotification(
        id: '2',
        title: 'Te han mencionado',
        description: 'Carlos Soto te mencionó en una publicación: "¿Podrías revisar el último reporte de diseño para el lunes?"',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        type: 'mention',
        senderName: 'Carlos Soto',
        isRead: false,
      ),
      AppNotification(
        id: '3',
        title: 'Nuevo comentario',
        description: 'María Gómez comentó en tu publicación: "¡Excelente iniciativa! Cuenta con mi apoyo."',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        type: 'comment',
        senderName: 'María Gómez',
        isRead: true,
      ),
      AppNotification(
        id: '4',
        title: 'Me gusta',
        description: 'A Juan Pérez le gustó tu publicación sobre el proyecto de robótica.',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        type: 'like',
        senderName: 'Juan Pérez',
        isRead: true,
      ),
      AppNotification(
        id: '5',
        title: 'Actualización del sistema',
        description: '¡Tu perfil ahora es 100% visible para reclutadores de ConnectNet!',
        timestamp: DateTime.now().subtract(const Duration(days: 3)),
        type: 'system',
        senderName: 'Soporte ConnectNet',
        isRead: true,
      ),
    ]);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addMockNotification() {
    final names = ['Luis Rodríguez', 'Sofía Castro', 'Diego Torres', 'Valentina Ruiz'];
    final types = ['like', 'comment', 'mention', 'connection'];
    final descriptions = {
      'like': 'le gustó tu publicación reciente.',
      'comment': 'comentó: "Me parece una excelente idea, ¿cómo podemos participar?"',
      'mention': 'te etiquetó en un encargo del laboratorio.',
      'connection': 'te ha enviado una solicitud de conexión profesional.',
    };

    final randomType = (types..shuffle()).first;
    final randomName = (names..shuffle()).first;
    final desc = '${descriptions[randomType]}';

    setState(() {
      _notifications.insert(
        0,
        AppNotification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: randomType == 'like'
              ? 'Me gusta'
              : randomType == 'comment'
                  ? 'Nuevo comentario'
                  : randomType == 'mention'
                      ? 'Nueva mención'
                      : 'Nueva conexión',
          description: '$randomName $desc',
          timestamp: DateTime.now(),
          type: randomType,
          senderName: randomName,
          isRead: false,
          isConnectionAccepted: randomType == 'connection' ? null : null,
        ),
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Nueva notificación simulada recibida!'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _markAllAsRead() {
    setState(() {
      for (int i = 0; i < _notifications.length; i++) {
        _notifications[i] = _notifications[i].copyWith(isRead: true);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Todas las notificaciones marcadas como leídas.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearNotification(String id) {
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
  }

  void _toggleReadStatus(int index, List<AppNotification> filteredList) {
    final actualIndex = _notifications.indexWhere((n) => n.id == filteredList[index].id);
    if (actualIndex != -1) {
      setState(() {
        _notifications[actualIndex] = _notifications[actualIndex].copyWith(
          isRead: !_notifications[actualIndex].isRead,
        );
      });
    }
  }

  void _handleConnection(String id, bool accept) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      setState(() {
        _notifications[index] = _notifications[index].copyWith(
          isConnectionAccepted: accept,
          isRead: true,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept
              ? 'Conexión aceptada con éxito'
              : 'Solicitud de conexión rechazada'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<AppNotification> _getFilteredNotifications(String tab) {
    switch (tab) {
      case 'menciones':
        return _notifications.where((n) => n.type == 'mention').toList();
      case 'conexiones':
        return _notifications.where((n) => n.type == 'connection').toList();
      case 'reacciones':
        return _notifications.where((n) => n.type == 'like' || n.type == 'comment').toList();
      case 'todas':
      default:
        return _notifications;
    }
  }

  String _formatTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) {
      return 'Ahora';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} h';
    } else {
      return '${difference.inDays} d';
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.comment_rounded;
      case 'mention':
        return Icons.alternate_email_rounded;
      case 'connection':
        return Icons.person_add_rounded;
      case 'system':
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'like':
        return Colors.redAccent;
      case 'comment':
        return const Color(0xFF1DA1F2);
      case 'mention':
        return Colors.amber.shade700;
      case 'connection':
        return Colors.teal;
      case 'system':
      default:
        return Colors.blueGrey;
    }
  }

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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check_rounded, color: Colors.black87),
            tooltip: 'Marcar todas como leídas',
            onPressed: unreadCount > 0 ? _markAllAsRead : null,
          ),
          IconButton(
            icon: const Icon(Icons.offline_pin_rounded, color: Colors.black87),
            tooltip: 'Simular Notificación',
            onPressed: _addMockNotification,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF003E90),
          labelColor: const Color(0xFF003E90),
          unselectedLabelColor: Colors.grey.shade600,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Todas'),
            Tab(text: 'Menciones'),
            Tab(text: 'Conexiones'),
            Tab(text: 'Reacciones'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNotificationList('todas'),
          _buildNotificationList('menciones'),
          _buildNotificationList('conexiones'),
          _buildNotificationList('reacciones'),
        ],
      ),
    );
  }

  Widget _buildNotificationList(String filterType) {
    final filtered = _getFilteredNotifications(filterType);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_outlined,
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No tienes notificaciones',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final notification = filtered[index];
        final typeColor = _getColorForType(notification.type);

        return Dismissible(
          key: Key(notification.id),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) => _clearNotification(notification.id),
          background: Container(
            color: Colors.redAccent.shade100,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
          ),
          child: InkWell(
            onTap: () => _toggleReadStatus(index, filtered),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: notification.isRead ? Colors.white : const Color(0xFF003E90).withValues(alpha: 0.05),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade200,
                    width: 0.8,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Smaller Type Avatar (size 20 radius, similar to message screen)
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: typeColor.withValues(alpha: 0.1),
                        child: Text(
                          notification.senderName.substring(0, 1).toUpperCase(),
                          style: TextStyle(color: typeColor, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.grey.shade200, width: 1),
                          ),
                          child: Icon(
                            _getIconForType(notification.type),
                            size: 10,
                            color: typeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Content details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              notification.title,
                              style: TextStyle(
                                fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
                                fontSize: 13.5,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              _formatTime(notification.timestamp),
                              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          notification.description,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: notification.isRead ? Colors.grey.shade600 : Colors.black87,
                          ),
                        ),
                        if (notification.type == 'connection') ...[
                          const SizedBox(height: 8),
                          if (notification.isConnectionAccepted == null)
                            Row(
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF003E90),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  onPressed: () => _handleConnection(notification.id, true),
                                  child: const Text('Aceptar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.grey.shade700,
                                    side: BorderSide(color: Colors.grey.shade300),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  onPressed: () => _handleConnection(notification.id, false),
                                  child: const Text('Rechazar', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: notification.isConnectionAccepted == true
                                    ? Colors.teal.withValues(alpha: 0.1)
                                    : Colors.redAccent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                notification.isConnectionAccepted == true
                                    ? '✓ Conexión aceptada'
                                    : '✗ Solicitud rechazada',
                                style: TextStyle(
                                  color: notification.isConnectionAccepted == true
                                      ? Colors.teal
                                      : Colors.redAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
