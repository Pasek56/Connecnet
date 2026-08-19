import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Model ─────────────────────────────────────────────────────────────────

class AppNotification {
  final String id;
  final String userId;
  final String? actorUserId;
  final String type; // 'message' | 'like_post' | 'like_news' | 'comment_post' | 'comment_news'
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final DateTime? readAt; // null = unread, set = read
  final Map<String, dynamic>? actorProfile; // from perfiles.perfil_unificado

  AppNotification({
    required this.id,
    required this.userId,
    this.actorUserId,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.readAt,
    this.actorProfile,
  });

  /// A notification is read when readAt is not null.
  bool get isRead => readAt != null;

  /// Resolves the actor's display name from their perfil_unificado data.
  String get actorName {
    if (actorProfile == null) return 'ConnectNet';
    final profileType = actorProfile!['profile_type'] ?? 'estudiante';
    String name;
    if (profileType == 'docente') {
      name =
          '${actorProfile!['nombres_prof'] ?? ''} ${actorProfile!['apellidos_prof'] ?? ''}'
              .trim();
    } else if (profileType == 'egresado') {
      name =
          '${actorProfile!['nombres_pro'] ?? ''} ${actorProfile!['apellidos_pro'] ?? ''}'
              .trim();
    } else {
      name =
          '${actorProfile!['nombres'] ?? ''} ${actorProfile!['apellidos'] ?? ''}'
              .trim();
    }
    return name.isNotEmpty ? name : 'Usuario';
  }

  /// Returns first non-empty character for the avatar fallback.
  String get actorInitial {
    final name = actorName;
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Returns the actor's profile picture URL if available.
  String? get actorAvatar {
    final pfp = actorProfile?['pfp'];
    if (pfp != null && pfp.toString().isNotEmpty) return pfp.toString();
    return null;
  }

  /// Human-readable title derived from notification type.
  String get title {
    if (type == 'message' && payload['is_global_news'] == true) {
      return '¡Nueva noticia publicada!';
    }
    
    switch (type) {
      case 'message':
        return 'Nuevo mensaje';
      case 'like_post':
        return 'Me gusta en tu publicación';
      case 'like_news':
        return 'Me gusta en tu noticia';
      case 'comment_post':
        return 'Nuevo comentario';
      case 'comment_news':
        return 'Nuevo comentario en noticia';
      default:
        return 'Notificación';
    }
  }

  /// Human-readable description derived from type + payload + actor name.
  String get description {
    final actor = actorName;
    if (type == 'message' && payload['is_global_news'] == true) {
      return '$actor publicó una nueva noticia en ConnectNet.';
    }

    switch (type) {
      case 'message':
        final preview = payload['message_preview'] as String? ??
            payload['content'] as String? ??
            '';
        return preview.isNotEmpty
            ? '$actor: "$preview"'
            : '$actor te envió un mensaje.';
      case 'like_post':
        return '$actor le dio me gusta a tu publicación.';
      case 'like_news':
        return '$actor le dio me gusta a tu noticia.';
      case 'comment_post':
        final comment = payload['comment_text'] as String? ??
            payload['content'] as String? ??
            '';
        return comment.isNotEmpty
            ? '$actor comentó: "$comment"'
            : '$actor comentó en tu publicación.';
      case 'comment_news':
        final comment = payload['comment_text'] as String? ??
            payload['content'] as String? ??
            '';
        return comment.isNotEmpty
            ? '$actor comentó: "$comment"'
            : '$actor comentó en tu noticia.';
      default:
        return 'Tienes una nueva notificación.';
    }
  }

  factory AppNotification.fromMap(
    Map<String, dynamic> map, {
    Map<String, dynamic>? actorProfile,
  }) {
    final rawCreatedAt = map['created_at'];
    final rawReadAt = map['read_at'];

    DateTime parsedCreatedAt;
    if (rawCreatedAt is DateTime) {
      parsedCreatedAt = rawCreatedAt;
    } else if (rawCreatedAt != null) {
      parsedCreatedAt = DateTime.parse(rawCreatedAt.toString());
    } else {
      parsedCreatedAt = DateTime.now();
    }

    DateTime? parsedReadAt;
    if (rawReadAt is DateTime) {
      parsedReadAt = rawReadAt;
    } else if (rawReadAt != null) {
      parsedReadAt = DateTime.parse(rawReadAt.toString());
    }

    return AppNotification(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      actorUserId: map['actor_user_id']?.toString(),
      type: map['type']?.toString() ?? 'unknown',
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? {}),
      createdAt: parsedCreatedAt,
      readAt: parsedReadAt,
      actorProfile: actorProfile,
    );
  }

  /// Creates a copy with updated read status.
  AppNotification copyWith({bool? forceRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      actorUserId: actorUserId,
      type: type,
      payload: payload,
      createdAt: createdAt,
      readAt: forceRead == null
          ? readAt
          : (forceRead ? DateTime.now() : null),
      actorProfile: actorProfile,
    );
  }
}

// ─── Service ───────────────────────────────────────────────────────────────

class NotificationService {
  final _supabase = Supabase.instance.client;

  /// Fetches all notifications for [userId] (auth UUID), ordered newest first.
  /// Uses the Data Loader pattern to batch-resolve actor profiles from
  /// perfiles.perfil_unificado without cross-schema JOINs.
  Future<List<AppNotification>> getNotifications(String userId) async {
    try {
      // 1. Load raw notification rows
      final response = await _supabase
          .schema('notificaciones')
          .from('notificaciones')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final rows = List<Map<String, dynamic>>.from(response);
      if (rows.isEmpty) return [];

      // 2. Collect unique actor_user_ids (auth UUIDs)
      final actorUuids = rows
          .map((r) => r['actor_user_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();

      // 3. Data Loader: batch-fetch actor profiles keyed by auth user_id
      // Using inFilter (Supabase Flutter v2 syntax) instead of .filter('in')
      Map<String, Map<String, dynamic>> profileByUuid = {};
      if (actorUuids.isNotEmpty) {
        final profilesResponse = await _supabase
            .schema('perfiles')
            .from('perfil_unificado')
            .select()
            .inFilter('user_id', actorUuids);

        final profiles = List<Map<String, dynamic>>.from(profilesResponse);
        profileByUuid = {
          for (final p in profiles)
            if (p['user_id'] != null) p['user_id'].toString(): p,
        };
      }

      // 4. Map rows to AppNotification with resolved actor profiles
      return rows.map((row) {
        final actorUuid = row['actor_user_id']?.toString();
        return AppNotification.fromMap(
          row,
          actorProfile: actorUuid != null ? profileByUuid[actorUuid] : null,
        );
      }).toList();
    } catch (e, stackTrace) {
      debugPrint('NotificationService.getNotifications error: $e');
      debugPrint('Stacktrace: $stackTrace');
      return [];
    }
  }

  /// Marks a single notification as read by setting read_at = now().
  Future<void> markAsRead(String id) async {
    try {
      await _supabase
          .schema('notificaciones')
          .from('notificaciones')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', id);
    } catch (e) {
      debugPrint('NotificationService.markAsRead error: $e');
    }
  }

  /// Marks all notifications of [userId] as read.
  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .schema('notificaciones')
          .from('notificaciones')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('user_id', userId)
          .isFilter('read_at', null);
    } catch (e) {
      debugPrint('NotificationService.markAllAsRead error: $e');
    }
  }

  /// Marks a notification as unread by setting read_at = null.
  Future<void> markAsUnread(String id) async {
    try {
      await _supabase
          .schema('notificaciones')
          .from('notificaciones')
          .update({'read_at': null})
          .eq('id', id);
    } catch (e) {
      debugPrint('NotificationService.markAsUnread error: $e');
    }
  }

  /// Deletes (dismisses) a notification by id.
  Future<void> deleteNotification(String id) async {
    try {
      await _supabase
          .schema('notificaciones')
          .from('notificaciones')
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('NotificationService.deleteNotification error: $e');
    }
  }

  /// Subscribes to INSERT events on notificaciones.notificaciones for [userId].
  /// Calls [onNew] with the raw row whenever a new notification arrives.
  RealtimeChannel subscribeToNotifications(
    String userId,
    void Function(Map<String, dynamic> newRow) onNew,
  ) {
    return _supabase
        .channel('notificaciones:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'notificaciones',
          table: 'notificaciones',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => onNew(payload.newRecord),
        )
        .subscribe();
  }

  void unsubscribe(RealtimeChannel channel) {
    _supabase.removeChannel(channel);
  }
}
