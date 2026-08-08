import 'dart:async';
import 'package:flutter/material.dart';
import '../services/messaging_service.dart';
import 'chat_screen.dart';

class NewConversationScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;

  const NewConversationScreen({super.key, this.userProfile});

  @override
  State<NewConversationScreen> createState() => _NewConversationScreenState();
}

class _NewConversationScreenState extends State<NewConversationScreen> {
  final MessagingService _messagingService = MessagingService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isSearching = false;
  bool _isCreating = false;
  Timer? _debounce;

  int? get _profileId => widget.userProfile?['id'] as int?;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    final profileId = _profileId;
    if (profileId == null) return;

    setState(() => _isSearching = true);

    final results = await _messagingService.searchUsers(query, profileId);

    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _startConversation(Map<String, dynamic> otherProfile) async {
    final profileId = _profileId;
    if (profileId == null) return;

    setState(() => _isCreating = true);

    final otherId = otherProfile['id'] as int;
    final conversation = await _messagingService.getOrCreateConversation(
      profileId,
      otherId,
    );

    if (conversation != null && mounted) {
      // Navigate to chat, replacing this screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            conversationId: conversation['id'] as String,
            currentProfile: widget.userProfile!,
            otherProfile: otherProfile,
          ),
        ),
      );
    } else if (mounted) {
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al crear la conversación'),
          backgroundColor: Colors.redAccent,
        ),
      );
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
          onPressed: () => Navigator.pop(context, false),
        ),
        title: const Text(
          'Nuevo mensaje',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade800.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2F3336),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Buscar personas...',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF71767B),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Color(0xFF71767B),
                            size: 20,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _results = []);
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {}); // Update suffix icon
                  _onSearchChanged(val);
                },
              ),
            ),
          ),

          // Loading overlay
          if (_isCreating)
            Container(
              padding: const EdgeInsets.all(20),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1DA1F2),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Creando conversación...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),

          // Results
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1DA1F2),
                    ),
                  )
                : _searchController.text.isEmpty
                    ? _buildInitialState()
                    : _results.isEmpty
                        ? _buildNoResults()
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              return _buildUserTile(_results[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_search_rounded,
            size: 48,
            color: Colors.grey.shade700,
          ),
          const SizedBox(height: 16),
          Text(
            'Busca por nombre o apellido',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: Colors.grey.shade700,
          ),
          const SizedBox(height: 16),
          Text(
            'No se encontraron usuarios',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> profile) {
    final name = _messagingService.getSenderName(profile);
    final pfp = _messagingService.getSenderPfp(profile);
    final typeLabel = _messagingService.getProfileTypeLabel(profile);

    return InkWell(
      onTap: _isCreating ? null : () => _startConversation(profile),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.shade800.withValues(alpha: 0.3),
            ),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: NetworkImage(pfp),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1DA1F2)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          typeLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1DA1F2),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Color(0xFF71767B),
            ),
          ],
        ),
      ),
    );
  }
}
