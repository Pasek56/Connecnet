import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/messaging_service.dart';
import 'chat_screen.dart';
import 'new_conversation_screen.dart';

class ConversationsScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;

  const ConversationsScreen({super.key, this.userProfile});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen>
    with SingleTickerProviderStateMixin {
  final MessagingService _messagingService = MessagingService();
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  RealtimeChannel? _realtimeChannel;
  late AnimationController _fabAnimController;

  int? get _profileId => widget.userProfile?['id'] as int?;

  @override
  void initState() {
    super.initState();
    _fabAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadConversations();
    _setupRealtime();
    _fabAnimController.forward();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      _messagingService.unsubscribe(_realtimeChannel!);
    }
    _fabAnimController.dispose();
    super.dispose();
  }

  void _setupRealtime() {
    final profileId = _profileId;
    if (profileId == null) return;
    _realtimeChannel = _messagingService.subscribeToAllMessages(
      profileId,
      () {
        if (mounted) _loadConversations();
      },
    );
  }

  Future<void> _loadConversations() async {
    final profileId = _profileId;
    if (profileId == null) return;

    final conversations =
        await _messagingService.getConversations(profileId);
    if (mounted) {
      setState(() {
        _conversations = conversations;
        _isLoading = false;
      });
    }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'ahora';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Mensajes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1DA1F2)),
            )
          : _conversations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadConversations,
                  color: const Color(0xFF1DA1F2),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      return _buildConversationTile(
                        _conversations[index],
                        index,
                      );
                    },
                  ),
                ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(
          parent: _fabAnimController,
          curve: Curves.easeOutBack,
        ),
        child: FloatingActionButton(
          heroTag: 'btn_new_conversation',
          onPressed: () async {
            final result = await showDialog<bool>(
              context: context,
              builder: (context) {
                return Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(16),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.85,
                    width: MediaQuery.of(context).size.width > 800
                        ? 700
                        : double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.all(Radius.circular(16)),
                      child: NewConversationScreen(
                        userProfile: widget.userProfile,
                      ),
                    ),
                  ),
                );
              },
            );
            if (result == true) {
              _loadConversations();
            }
          },
          backgroundColor: const Color(0xFF1DA1F2),
          child: const Icon(Icons.edit, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF1DA1F2).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mail_outline_rounded,
                size: 40,
                color: Color(0xFF1DA1F2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sin mensajes aún',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Inicia una conversación con alguien de la comunidad ConnectNet.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(16),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.85,
                        width: MediaQuery.of(context).size.width > 800
                            ? 700
                            : double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(Radius.circular(16)),
                          child: NewConversationScreen(
                            userProfile: widget.userProfile,
                          ),
                        ),
                      ),
                    );
                  },
                );
                if (result == true) {
                  _loadConversations();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DA1F2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'Nuevo mensaje',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationTile(
    Map<String, dynamic> conversation,
    int index,
  ) {
    final otherProfile =
        conversation['other_profile'] as Map<String, dynamic>?;
    final lastMessage =
        conversation['last_message'] as Map<String, dynamic>?;
    final unreadCount = conversation['unread_count'] as int? ?? 0;

    final name = _messagingService.getSenderName(otherProfile);
    final pfp = _messagingService.getSenderPfp(otherProfile);
    final lastText = lastMessage?['content'] as String? ?? '';
    final lastTime = _formatTime(
      lastMessage?['created_at'] as String? ??
          conversation['created_at'] as String?,
    );

    // Was the last message sent by me?
    final isMine = lastMessage != null &&
        lastMessage['sender_id'] == _profileId;

    return AnimatedContainer(
      duration: Duration(milliseconds: 200 + index * 50),
      curve: Curves.easeOut,
      child: InkWell(
        onTap: () async {
          await showDialog(
            context: context,
            builder: (context) {
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.all(16),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.85,
                  width: MediaQuery.of(context).size.width > 800
                      ? 700
                      : double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    child: ChatScreen(
                      conversationId: conversation['id'] as String,
                      currentProfile: widget.userProfile!,
                      otherProfile: otherProfile ?? {},
                    ),
                  ),
                ),
              );
            },
          );
          _loadConversations();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Colors.grey.shade800.withValues(alpha: 0.5),
              ),
            ),
          ),
          child: Row(
            children: [
              // Avatar with online-style ring for unread
              Container(
                decoration: unreadCount > 0
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF1DA1F2),
                          width: 2,
                        ),
                      )
                    : null,
                padding: unreadCount > 0
                    ? const EdgeInsets.all(2)
                    : EdgeInsets.zero,
                child: CircleAvatar(
                  radius: 28,
                  backgroundImage: NetworkImage(pfp),
                ),
              ),
              const SizedBox(width: 14),
              // Name + last message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          lastTime,
                          style: TextStyle(
                            fontSize: 13,
                            color: unreadCount > 0
                                ? const Color(0xFF1DA1F2)
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isMine)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.done_all,
                              size: 16,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            lastText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: unreadCount > 0
                                  ? Colors.white70
                                  : Colors.grey.shade500,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1DA1F2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              unreadCount > 99
                                  ? '99+'
                                  : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
