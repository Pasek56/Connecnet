import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/messaging_service.dart';
import 'public_profile_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final Map<String, dynamic> currentProfile;
  final Map<String, dynamic> otherProfile;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.currentProfile,
    required this.otherProfile,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final MessagingService _messagingService = MessagingService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  RealtimeChannel? _realtimeChannel;

  int get _myProfileId => widget.currentProfile['id'] as int;
  int get _otherProfileId => widget.otherProfile['id'] as int;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _setupRealtime();
    _markAsRead();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      _messagingService.unsubscribe(_realtimeChannel!);
    }
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setupRealtime() {
    _realtimeChannel = _messagingService.subscribeToMessages(
      widget.conversationId,
      (newMessage) {
        if (mounted) {
          setState(() {
            // Avoid duplicates
            if (!_messages.any((m) => m['id'] == newMessage['id'])) {
              _messages.add(newMessage);
            }
          });
          _scrollToBottom();
          _markAsRead();
        }
      },
    );
  }

  Future<void> _markAsRead() async {
    await _messagingService.markAsRead(
      widget.conversationId,
      _myProfileId,
    );
  }

  Future<void> _loadMessages() async {
    final messages =
        await _messagingService.getMessages(widget.conversationId);
    if (mounted) {
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
      // Wait for the frame to render then scroll
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom(animated: false);
      });
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    final result = await _messagingService.sendMessage(
      conversationId: widget.conversationId,
      senderId: _myProfileId,
      receiverId: _otherProfileId,
      content: text,
    );

    if (result != null && mounted) {
      _messageController.clear();
      setState(() {
        // Only add if not already added by realtime
        if (!_messages.any((m) => m['id'] == result['id'])) {
          _messages.add(result);
        }
      });
      _scrollToBottom();
    }

    if (mounted) setState(() => _isSending = false);
  }

  String _formatMessageTime(String? isoTime) {
    if (isoTime == null) return '';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return '';
    }
  }

  String _formatDateHeader(String? isoTime) {
    if (isoTime == null) return '';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDay = DateTime(dt.year, dt.month, dt.day);

      if (messageDay == today) return 'Hoy';
      if (messageDay == today.subtract(const Duration(days: 1))) return 'Ayer';

      const months = [
        'ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  bool _shouldShowDateHeader(int index) {
    if (index == 0) return true;
    final current = _messages[index]['created_at'] as String?;
    final previous = _messages[index - 1]['created_at'] as String?;
    if (current == null || previous == null) return false;

    try {
      final currentDt = DateTime.parse(current).toLocal();
      final previousDt = DateTime.parse(previous).toLocal();
      return currentDt.day != previousDt.day ||
          currentDt.month != previousDt.month ||
          currentDt.year != previousDt.year;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final otherName = _messagingService.getSenderName(widget.otherProfile);
    final otherPfp = _messagingService.getSenderPfp(widget.otherProfile);
    final otherType =
        _messagingService.getProfileTypeLabel(widget.otherProfile);

    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161C22),
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(otherPfp),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PublicProfileScreen(
                      profileId: widget.otherProfile['id'] as int,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    otherName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    otherType,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1DA1F2),
                    ),
                  )
                : _messages.isEmpty
                    ? _buildEmptyChat(otherName)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isMine =
                              message['sender_id'] == _myProfileId;
                          final showDate = _shouldShowDateHeader(index);

                          return Column(
                            children: [
                              if (showDate)
                                _buildDateHeader(
                                  _formatDateHeader(
                                    message['created_at'] as String?,
                                  ),
                                ),
                              _buildMessageBubble(
                                message,
                                isMine,
                                index,
                              ),
                            ],
                          );
                        },
                      ),
          ),
          // Input area
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyChat(String otherName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF1DA1F2).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.waving_hand_rounded,
                size: 32,
                color: Color(0xFF1DA1F2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '¡Saluda a $otherName!',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Este es el inicio de tu conversación.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF2F3336),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> message,
    bool isMine,
    int index,
  ) {
    final time = _formatMessageTime(message['created_at'] as String?);
    final content = message['content'] as String? ?? '';

    // Check if next message is from the same sender (for tail grouping)
    final isLastInGroup = index == _messages.length - 1 ||
        _messages[index + 1]['sender_id'] != message['sender_id'];

    return Padding(
      padding: EdgeInsets.only(
        bottom: isLastInGroup ? 8 : 3,
        left: isMine ? 48 : 0,
        right: isMine ? 0 : 48,
      ),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isMine
                    ? const Color(0xFF1DA1F2)
                    : const Color(0xFF2F3336),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(
                    isMine || !isLastInGroup ? 18 : 4,
                  ),
                  bottomRight: Radius.circular(
                    !isMine || !isLastInGroup ? 18 : 4,
                  ),
                ),
              ),
              child: Text(
                content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
            ),
            if (isLastInGroup)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? 10
            : MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF161C22),
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade800.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2F3336),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Material(
              color: const Color(0xFF1DA1F2),
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _isSending ? null : _sendMessage,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
