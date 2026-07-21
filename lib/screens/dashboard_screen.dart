import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_screen.dart';
import 'news_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onLogout;

  const DashboardScreen({super.key, this.onLogout});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _postController = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isPosting = false;
  String? _selectedImagePath;
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _encargos = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    await _fetchUserProfile();
    await _fetchEncargos();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final profile = await _supabase
            .schema('perfiles')
            .from('perfil_unificado')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        if (profile != null) {
          _userProfile = profile;
        }
      }
    } catch (e) {
      debugPrint('Error al cargar perfil del usuario: $e');
    }
  }

  Future<void> _fetchEncargos() async {
    try {
      final response = await _supabase
          .schema('publicaciones')
          .from('encargo')
          .select('*, sender:sender_profile_id(*), comentarios:comentarios(count)')
          .order('id_enc', ascending: false);

      setState(() {
        _encargos = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error al cargar encargos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar publicaciones: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _addPost() async {
    final content = _postController.text.trim();
    if (content.isEmpty) return;

    if (_userProfile == null) {
      await _fetchUserProfile();
    }

    setState(() {
      _isPosting = true;
    });

    try {
      final profileId = _userProfile?['id'];
      final profileType = _userProfile?['profile_type'] ?? 'estudiante';

      await _supabase.schema('publicaciones').from('encargo').insert({
        'desc_enc': content,
        'img_enc': _selectedImagePath ?? '',
        'sender_profile_id': profileId,
        'sender_profile_type': profileType,
      });

      _postController.clear();
      setState(() {
        _selectedImagePath = null;
      });

      await _fetchEncargos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Publicación realizada con éxito!'),
            backgroundColor: Color(0xFF1DA1F2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al publicar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPosting = false;
        });
      }
    }
  }

  String _getSenderName(Map<String, dynamic>? sender) {
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

  String _getSenderPfp(Map<String, dynamic>? sender) {
    final pfp = sender?['pfp'];
    if (pfp != null && pfp.toString().isNotEmpty) {
      return pfp.toString();
    }
    return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200';
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'ConnectNet',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: Color(0xFF1DA1F2),
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Publicaciones'),
              Tab(text: 'Noticias'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Publicaciones (Encargos)
            RefreshIndicator(
              onRefresh: _fetchEncargos,
              color: const Color(0xFF1DA1F2),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF1DA1F2)),
                    )
                  : ListView.builder(
                      itemCount: _encargos.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildCreatePostWidget();
                        return _buildPostCard(context, _encargos[index - 1]);
                      },
                    ),
            ),
            // Tab 2: Noticias
            const NewsScreen(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileScreen(
                  onLogout: widget.onLogout ?? () {},
                ),
              ),
            );
          },
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: const Icon(Icons.person, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildCreatePostWidget() {
    final pfp = _getSenderPfp(_userProfile);
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF161C22),
        border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(pfp),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _postController,
                  maxLines: null,
                  decoration: const InputDecoration(
                    hintText: '¿Qué está pasando?',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                ),
                if (_selectedImagePath != null) ...[
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _selectedImagePath!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            height: 100,
                            color: Colors.grey.shade900,
                            alignment: Alignment.center,
                            child: const Text('Imagen adjunta'),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _selectedImagePath = null;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.image, color: Colors.blue),
                          onPressed: () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 70,
                              maxWidth: 800,
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedImagePath = picked.path;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: _isPosting ? null : _addPost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: _isPosting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Publicar',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, Map<String, dynamic> encargo) {
    final sender = encargo['sender'] as Map<String, dynamic>?;
    final senderName = _getSenderName(sender);
    final senderPfp = _getSenderPfp(sender);
    final senderType = encargo['sender_profile_type'] ?? 'estudiante';
    final desc = encargo['desc_enc'] ?? '';
    final img = encargo['img_enc'] ?? '';

    int commentsCount = 0;
    if (encargo['comentarios'] != null && encargo['comentarios'] is List) {
      final list = encargo['comentarios'] as List;
      if (list.isNotEmpty && list.first['count'] != null) {
        commentsCount = list.first['count'] as int;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF161C22),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade800, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showCommentDialog(context, encargo),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(senderPfp),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          senderName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '@$senderType',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                desc,
                style: const TextStyle(fontSize: 15, height: 1.4),
              ),
              if (img.isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    img,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 200,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildActionIcon(
                    Icons.chat_bubble_outline,
                    '$commentsCount',
                    onTap: () => _showCommentDialog(context, encargo),
                  ),
                  _buildActionIcon(Icons.repeat, '0'),
                  _buildActionIcon(Icons.favorite_border, '0'),
                  _buildActionIcon(Icons.bookmark_border, ''),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCommentDialog(BuildContext context, Map<String, dynamic> encargo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _EncargoCommentModal(
          encargo: encargo,
          userProfile: _userProfile,
          onCommentAdded: () {
            _fetchEncargos();
          },
        );
      },
    );
  }

  Widget _buildActionIcon(
    IconData icon,
    String count, {
    Color? color,
    VoidCallback? onTap,
  }) {
    final iconColor = color ?? Colors.grey.shade400;
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            if (count.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                count,
                style: TextStyle(color: iconColor, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EncargoCommentModal extends StatefulWidget {
  final Map<String, dynamic> encargo;
  final Map<String, dynamic>? userProfile;
  final VoidCallback onCommentAdded;

  const _EncargoCommentModal({
    required this.encargo,
    required this.userProfile,
    required this.onCommentAdded,
  });

  @override
  State<_EncargoCommentModal> createState() => _EncargoCommentModalState();
}

class _EncargoCommentModalState extends State<_EncargoCommentModal> {
  final TextEditingController _commentController = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _isLoadingComments = true;
  bool _isSending = false;
  List<Map<String, dynamic>> _comments = [];

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    try {
      final response = await _supabase
          .schema('publicaciones')
          .from('comentarios')
          .select('*, sender:sender_profile_id(*)')
          .eq('encargo_id', widget.encargo['id_enc'])
          .order('id_coment', ascending: true);

      setState(() {
        _comments = List<Map<String, dynamic>>.from(response);
        _isLoadingComments = false;
      });
    } catch (e) {
      debugPrint('Error al obtener comentarios: $e');
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
        });
      }
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final profileId = widget.userProfile?['id'];
      final profileType = widget.userProfile?['profile_type'] ?? 'estudiante';

      await _supabase.schema('publicaciones').from('comentarios').insert({
        'encargo_id': widget.encargo['id_enc'],
        'content': text,
        'sender_profile_id': profileId,
        'sender_profile_type': profileType,
      });

      _commentController.clear();
      await _fetchComments();
      widget.onCommentAdded();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al responder: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _getSenderName(Map<String, dynamic>? sender) {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF161C22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Comentarios',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoadingComments
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1DA1F2)),
                  )
                : _comments.isEmpty
                    ? Center(
                        child: Text(
                          'Aún no hay comentarios. ¡Sé el primero en responder!',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final coment = _comments[index];
                          final sender =
                              coment['sender'] as Map<String, dynamic>?;
                          final senderName = _getSenderName(sender);
                          final content = coment['content'] ?? '';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFF1DA1F2)
                                      .withValues(alpha: 0.2),
                                  child: Text(
                                    senderName.isNotEmpty
                                        ? senderName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: Color(0xFF1DA1F2),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        senderName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        content,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          const Divider(color: Colors.grey),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Escribe tu respuesta...',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    border: InputBorder.none,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _isSending ? null : _sendComment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Responder',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
