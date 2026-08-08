import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'public_profile_screen.dart';
import 'profile_screen.dart';

class NewsDetailScreen extends StatefulWidget {
  final Map<String, dynamic> news;

  const NewsDetailScreen({super.key, required this.news});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _isLoadingComments = true;
  bool _isSending = false;
  Map<String, dynamic>? _userProfile;
  List<Map<String, dynamic>> _comments = [];

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
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
      debugPrint('Error al obtener perfil en noticia: $e');
    }
  }

  Future<void> _fetchComments() async {
    final noticiaId = widget.news['id_pub'];
    if (noticiaId == null) {
      setState(() {
        _isLoadingComments = false;
      });
      return;
    }

    try {
      final response = await _supabase
          .schema('publicaciones')
          .from('comentarios')
          .select('*')
          .eq('noticia_id', noticiaId)
          .order('id_coment', ascending: true);

      List<Map<String, dynamic>> comments = List<Map<String, dynamic>>.from(
        response,
      );

      final senderIds = comments
          .map((c) => c['sender_profile_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      if (senderIds.isNotEmpty) {
        final profilesResponse = await _supabase
            .schema('perfiles')
            .from('perfil_unificado')
            .select()
            .filter('id', 'in', senderIds);

        final profiles = List<Map<String, dynamic>>.from(profilesResponse);
        final profileMap = {for (var p in profiles) p['id']: p};

        for (var c in comments) {
          final senderId = c['sender_profile_id'];
          if (senderId != null) {
            c['sender'] = profileMap[senderId];
          }
        }
      }

      setState(() {
        _comments = comments;
      });
    } catch (e) {
      debugPrint('Error al obtener comentarios de noticia: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
        });
      }
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    final noticiaId = widget.news['id_pub'];
    if (text.isEmpty || noticiaId == null) return;

    if (_userProfile == null) {
      await _fetchUserProfile();
    }

    setState(() {
      _isSending = true;
    });

    try {
      final profileId = _userProfile?['id'];
      final profileType = _userProfile?['profile_type'] ?? 'estudiante';

      await _supabase.schema('publicaciones').from('comentarios').insert({
        'noticia_id': noticiaId,
        'content': text,
        'sender_profile_id': profileId,
        'sender_profile_type': profileType,
      });

      _commentController.clear();
      await _fetchComments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar comentario: $e'),
            backgroundColor: Colors.redAccent,
          ),
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
      final name = '${sender['nombres'] ?? ''} ${sender['apellidos'] ?? ''}'
          .trim();
      return name.isNotEmpty ? name : 'Estudiante';
    }
  }

  @override
  Widget build(BuildContext context) {
    final imgUrl = widget.news['imageUrl'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        title: Text(widget.news['source'] ?? 'Noticia'),
        backgroundColor: const Color(0xFF161C22),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imgUrl != null && imgUrl.isNotEmpty)
                    Image.network(
                      imgUrl,
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.article_outlined,
                              size: 20,
                              color: Color(0xFF1DA1F2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.news['source'] ?? 'Fuente',
                              style: const TextStyle(
                                color: Color(0xFF1DA1F2),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              widget.news['date'] ?? '',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.news['title'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Linkify(
                          onOpen: (link) async {
                            final uri = Uri.tryParse(link.url);
                            if (uri != null && await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                          text: widget.news['content'] ?? '',
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            fontSize: 16,
                            height: 1.5,
                          ),
                          linkStyle: const TextStyle(
                            color: Color(0xFF1DA1F2),
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Divider(color: Colors.grey),
                        const SizedBox(height: 8),
                        const Text(
                          'Comentarios de la noticia',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _isLoadingComments
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF1DA1F2),
                                ),
                              )
                            : _comments.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16.0,
                                ),
                                child: Text(
                                  'No hay comentarios aún. ¡Escribe el primero!',
                                  style: TextStyle(color: Colors.grey.shade500),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _comments.length,
                                itemBuilder: (context, index) {
                                  final coment = _comments[index];
                                  final sender =
                                      coment['sender'] as Map<String, dynamic>?;
                                  final senderName = _getSenderName(sender);
                                  final content = coment['content'] ?? '';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8.0,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: sender != null
                                              ? () {
                                                  final senderId =
                                                      sender['id'] as int?;
                                                  final currentId =
                                                      _userProfile?['id']
                                                          as int?;
                                                  if (senderId != null) {
                                                    if (senderId == currentId) {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              ProfileScreen(
                                                                onLogout: () {},
                                                              ),
                                                        ),
                                                      );
                                                    } else {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              PublicProfileScreen(
                                                                profileId:
                                                                    senderId,
                                                              ),
                                                        ),
                                                      );
                                                    }
                                                  }
                                                }
                                              : null,
                                          icon: CircleAvatar(
                                            radius: 16,
                                            backgroundColor: const Color(
                                              0xFF1DA1F2,
                                            ).withValues(alpha: 0.2),
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
                                              Linkify(
                                                onOpen: (link) async {
                                                  final uri = Uri.tryParse(
                                                    link.url,
                                                  );
                                                  if (uri != null &&
                                                      await canLaunchUrl(uri)) {
                                                    await launchUrl(
                                                      uri,
                                                      mode: LaunchMode
                                                          .externalApplication,
                                                    );
                                                  }
                                                },
                                                text: content,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 14,
                                                ),
                                                linkStyle: const TextStyle(
                                                  color: Color(0xFF1DA1F2),
                                                  decoration:
                                                      TextDecoration.underline,
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Comment input bar at bottom
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF161C22),
              border: Border(top: BorderSide(color: Colors.grey.shade800)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Comentar esta noticia...',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isSending ? null : _sendComment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DA1F2),
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
                          'Comentar',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
