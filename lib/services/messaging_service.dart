import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessagingService {
  final _supabase = Supabase.instance.client;

  // ─── Helpers for profile display ───────────────────────────────────

  String getSenderName(Map<String, dynamic>? sender) {
    if (sender == null) return 'Usuario';
    final type = sender['profile_type'] ?? 'estudiante';
    if (type == 'docente') {
      final name =
          '${sender['nombres_prof'] ?? ''} ${sender['apellidos_prof'] ?? ''}'
              .trim();
      return name.isNotEmpty ? name : 'Docente';
    } else if (type == 'egresado') {
      final name =
          '${sender['nombres_pro'] ?? ''} ${sender['apellidos_pro'] ?? ''}'
              .trim();
      return name.isNotEmpty ? name : 'Egresado';
    } else {
      final name =
          '${sender['nombres'] ?? ''} ${sender['apellidos'] ?? ''}'.trim();
      return name.isNotEmpty ? name : 'Estudiante';
    }
  }

  String getSenderPfp(Map<String, dynamic>? sender) {
    final pfp = sender?['pfp'];
    if (pfp != null && pfp.toString().isNotEmpty) {
      return pfp.toString();
    }
    return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200';
  }

  String getProfileTypeLabel(Map<String, dynamic>? profile) {
    final type = profile?['profile_type'] ?? 'estudiante';
    switch (type) {
      case 'docente':
        return 'Docente';
      case 'egresado':
        return 'Egresado';
      default:
        return 'Estudiante';
    }
  }

  // ─── Current user profile ──────────────────────────────────────────

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      return await _supabase
          .schema('perfiles')
          .from('perfil_unificado')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
    } catch (e) {
      debugPrint('Error getting current profile: $e');
      return null;
    }
  }

  // ─── Conversations ─────────────────────────────────────────────────

  /// Get or create a conversation between two users.
  /// Always stores the smaller id as user_a_id for consistency.
  Future<Map<String, dynamic>?> getOrCreateConversation(
    int userAId,
    int userBId,
  ) async {
    try {
      final smallId = userAId < userBId ? userAId : userBId;
      final bigId = userAId < userBId ? userBId : userAId;

      // Try to find existing conversation
      final existing = await _supabase
          .schema('messages')
          .from('conversations')
          .select()
          .eq('user_a_id', smallId)
          .eq('user_b_id', bigId)
          .maybeSingle();

      if (existing != null) return existing;

      // Create new conversation
      final inserted = await _supabase
          .schema('messages')
          .from('conversations')
          .insert({
            'user_a_id': smallId,
            'user_b_id': bigId,
          })
          .select()
          .single();

      return inserted;
    } catch (e) {
      debugPrint('Error get/create conversation: $e');
      return null;
    }
  }

  /// Fetch all conversations for a given profile, including the other
  /// participant's profile data and the last message.
  Future<List<Map<String, dynamic>>> getConversations(int profileId) async {
    try {
      // Fetch conversations where the user is either user_a or user_b
      final responseA = await _supabase
          .schema('messages')
          .from('conversations')
          .select()
          .eq('user_a_id', profileId)
          .order('created_at', ascending: false);

      final responseB = await _supabase
          .schema('messages')
          .from('conversations')
          .select()
          .eq('user_b_id', profileId)
          .order('created_at', ascending: false);

      final allConversations = <Map<String, dynamic>>[
        ...List<Map<String, dynamic>>.from(responseA),
        ...List<Map<String, dynamic>>.from(responseB),
      ];

      if (allConversations.isEmpty) return [];

      // Collect all other-user profile IDs
      final otherProfileIds = <int>{};
      for (var conv in allConversations) {
        final aId = conv['user_a_id'] as int;
        final bId = conv['user_b_id'] as int;
        otherProfileIds.add(aId == profileId ? bId : aId);
      }

      // Fetch profiles
      Map<int, Map<String, dynamic>> profileMap = {};
      if (otherProfileIds.isNotEmpty) {
        final profilesResponse = await _supabase
            .schema('perfiles')
            .from('perfil_unificado')
            .select()
            .filter('id', 'in', otherProfileIds.toList());
        final profiles =
            List<Map<String, dynamic>>.from(profilesResponse);
        profileMap = {for (var p in profiles) p['id'] as int: p};
      }

      // Fetch last message and read status for each conversation
      final conversationIds =
          allConversations.map((c) => c['id'] as String).toList();

      // Fetch conversation reads for this user
      Map<String, DateTime> readMap = {};
      try {
        final readsResponse = await _supabase
            .schema('messages')
            .from('conversation_reads')
            .select()
            .eq('profile_id', profileId)
            .filter('conversation_id', 'in', conversationIds);
        for (var r in List<Map<String, dynamic>>.from(readsResponse)) {
          readMap[r['conversation_id'] as String] =
              DateTime.parse(r['last_read_at'] as String);
        }
      } catch (_) {
        // conversation_reads may not have entries yet
      }

      // Enrich each conversation
      List<Map<String, dynamic>> enriched = [];
      for (var conv in allConversations) {
        final convId = conv['id'] as String;
        final aId = conv['user_a_id'] as int;
        final bId = conv['user_b_id'] as int;
        final otherId = aId == profileId ? bId : aId;
        final otherProfile = profileMap[otherId];

        // Fetch last message
        Map<String, dynamic>? lastMessage;
        try {
          lastMessage = await _supabase
              .schema('messages')
              .from('message')
              .select()
              .eq('conversation_id', convId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();
        } catch (_) {}

        // Count unread messages
        int unreadCount = 0;
        if (lastMessage != null) {
          final lastRead = readMap[convId];
          if (lastRead != null) {
            try {
              final unreadResponse = await _supabase
                  .schema('messages')
                  .from('message')
                  .select()
                  .eq('conversation_id', convId)
                  .eq('receiver_id', profileId)
                  .gt('created_at', lastRead.toIso8601String());
              unreadCount =
                  List<Map<String, dynamic>>.from(unreadResponse).length;
            } catch (_) {}
          } else {
            // Never read → count all messages from the other user
            try {
              final unreadResponse = await _supabase
                  .schema('messages')
                  .from('message')
                  .select()
                  .eq('conversation_id', convId)
                  .eq('receiver_id', profileId);
              unreadCount =
                  List<Map<String, dynamic>>.from(unreadResponse).length;
            } catch (_) {}
          }
        }

        enriched.add({
          ...conv,
          'other_profile': otherProfile,
          'last_message': lastMessage,
          'unread_count': unreadCount,
          'sort_key': lastMessage != null
              ? lastMessage['created_at']
              : conv['created_at'],
        });
      }

      // Sort by most recent activity
      enriched.sort((a, b) {
        final aTime = a['sort_key'] as String? ?? '';
        final bTime = b['sort_key'] as String? ?? '';
        return bTime.compareTo(aTime);
      });

      return enriched;
    } catch (e) {
      debugPrint('Error fetching conversations: $e');
      return [];
    }
  }

  // ─── Messages ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    try {
      final response = await _supabase
          .schema('messages')
          .from('message')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> sendMessage({
    required String conversationId,
    required int senderId,
    required int receiverId,
    required String content,
  }) async {
    try {
      final inserted = await _supabase
          .schema('messages')
          .from('message')
          .insert({
            'conversation_id': conversationId,
            'sender_id': senderId,
            'receiver_id': receiverId,
            'content': content,
          })
          .select()
          .single();
      return inserted;
    } catch (e) {
      debugPrint('Error sending message: $e');
      return null;
    }
  }

  // ─── Read tracking ─────────────────────────────────────────────────

  Future<void> markAsRead(String conversationId, int profileId) async {
    try {
      await _supabase.schema('messages').from('conversation_reads').upsert(
        {
          'conversation_id': conversationId,
          'profile_id': profileId,
          'last_read_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  // ─── Realtime ──────────────────────────────────────────────────────

  /// Subscribe to new messages in a conversation.
  /// Returns a RealtimeChannel that can be unsubscribed.
  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(Map<String, dynamic> newMessage) onNewMessage,
  ) {
    final channel = _supabase
        .channel('messages:$conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'messages',
          table: 'message',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: conversationId,
          ),
          callback: (payload) {
            onNewMessage(payload.newRecord);
          },
        )
        .subscribe();
    return channel;
  }

  /// Subscribe to any new message where this user is a receiver (for
  /// conversation list updates).
  RealtimeChannel subscribeToAllMessages(
    int profileId,
    void Function() onUpdate,
  ) {
    final channel = _supabase
        .channel('all_messages:$profileId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'messages',
          table: 'message',
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord['receiver_id'] == profileId ||
                newRecord['sender_id'] == profileId) {
              onUpdate();
            }
          },
        )
        .subscribe();
    return channel;
  }

  void unsubscribe(RealtimeChannel channel) {
    _supabase.removeChannel(channel);
  }

  // ─── User Search ───────────────────────────────────────────────────

  /// Safely run a single query; returns [] on error so one bad column
  /// doesn't kill the entire search.
  Future<List<dynamic>> _safeQuery(Future<List<dynamic>> query) async {
    try {
      return await query;
    } catch (e) {
      debugPrint('Search sub-query failed (non-fatal): $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(
    String query,
    int currentProfileId,
  ) async {
    try {
      if (query.trim().isEmpty) return [];

      final searchTerm = '%${query.trim()}%';

      final response = await _supabase
          .schema('perfiles')
          .from('perfil_unificado')
          .select()
          .neq('id', currentProfileId)
          .or('nombres.ilike.$searchTerm,apellidos.ilike.$searchTerm,nombres_prof.ilike.$searchTerm,apellidos_prof.ilike.$searchTerm,nombres_pro.ilike.$searchTerm,apellidos_pro.ilike.$searchTerm')
          .limit(20);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [
        {
          'id': -1,
          'nombres': 'Error:',
          'apellidos': e.toString(),
          'profile_type': 'estudiante',
          'pfp': null,
        }
      ];
    }
  }
}
