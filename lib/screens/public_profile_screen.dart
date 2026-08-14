import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pantalla de perfil público (solo lectura) de otro usuario.
/// Recibe el [profileId] del perfil a mostrar.
class PublicProfileScreen extends StatefulWidget {
  final int profileId;

  const PublicProfileScreen({super.key, required this.profileId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    try {
      final data = await _supabase
          .schema('perfiles')
          .from('perfil_unificado')
          .select()
          .eq('id', widget.profileId)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() => _profileData = data);
        await _fetchPosts(data['id'] as int);
      }
    } catch (e) {
      debugPrint('Error cargando perfil público: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPosts(int profileId) async {
    try {
      final response = await _supabase
          .schema('publicaciones')
          .from('encargo')
          .select('*, comentarios:comentarios(count)')
          .eq('sender_profile_id', profileId)
          .order('id_enc', ascending: false);

      final List<Map<String, dynamic>> posts = [];
      for (var encargo in response) {
        int commentsCount = 0;
        if (encargo['comentarios'] is List) {
          final list = encargo['comentarios'] as List;
          if (list.isNotEmpty && list.first['count'] != null) {
            commentsCount = list.first['count'] as int;
          }
        }
        posts.add({
          'content': encargo['desc_enc'] ?? '',
          'imageUrl': encargo['img_enc'] ?? '',
          'hasImage': (encargo['img_enc'] != null &&
              encargo['img_enc'].toString().isNotEmpty &&
              !encargo['img_enc'].toString().startsWith('blob:')),
          'comments': commentsCount,
        });
      }

      if (mounted) setState(() => _posts = posts);
    } catch (e) {
      debugPrint('Error cargando posts del perfil público: $e');
    }
  }

  // ─── Helpers ─────────────────────────────────────────────────────────

  String _getName() {
    if (_profileData == null) return 'Usuario';
    final type = _profileData!['profile_type'] ?? 'estudiante';
    if (type == 'docente') {
      return '${_profileData!['nombres_prof'] ?? ''} ${_profileData!['apellidos_prof'] ?? ''}'
          .trim();
    } else if (type == 'egresado') {
      return '${_profileData!['nombres_pro'] ?? ''} ${_profileData!['apellidos_pro'] ?? ''}'
          .trim();
    } else {
      return '${_profileData!['nombres'] ?? ''} ${_profileData!['apellidos'] ?? ''}'
          .trim();
    }
  }

  String _getHandle() {
    final name = _getName();
    if (name.isEmpty) return '@usuario';
    final parts = name.split(' ');
    return '@${parts.first}${parts.length > 1 ? '_${parts[1]}' : ''}'
        .replaceAll(' ', '');
  }

  String _getPfp() {
    final pfp = _profileData?['pfp'];
    if (pfp != null && pfp.toString().isNotEmpty) return pfp.toString();
    return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200';
  }

  String _getBio() {
    final type = _profileData?['profile_type'] ?? 'estudiante';
    if (type == 'estudiante') {
      final s = _profileData?['semestre'] ?? 1;
      return 'Estudiante de $s Semestre.';
    } else if (type == 'docente') {
      final m1 = _profileData?['mater1'] ?? '';
      return m1.isNotEmpty ? 'Docente · $m1' : 'Docente';
    } else if (type == 'egresado') {
      final titulo = _profileData?['titulo'] ?? '';
      return titulo.isNotEmpty ? titulo : 'Egresado';
    }
    return 'Usuario de ConnectNet';
  }

  String _getTypeLabel() {
    switch (_profileData?['profile_type'] ?? 'estudiante') {
      case 'docente':
        return 'Docente';
      case 'egresado':
        return 'Egresado';
      default:
        return 'Estudiante';
    }
  }

  // ─── UI ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1DA1F2)),
        ),
      );
    }

    final displayName = _getName();
    final handle = _getHandle();
    final bio = _getBio();
    final pfpUrl = _getPfp();
    final typeLabel = _getTypeLabel();

    return Scaffold(
      backgroundColor: Colors.black,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: false,
              pinned: true,
              backgroundColor: Colors.black,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: innerBoxIsScrolled
                  ? Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: () => _openImageViewer(context, pfpUrl),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 4),
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundImage: NetworkImage(pfpUrl),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Name
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      handle,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF71767B),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Bio
                    Text(
                      bio,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Metadata
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildMetaItem(Icons.badge_outlined, typeLabel),
                        _buildMetaItem(
                            Icons.location_on_outlined, 'Venezuela'),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 3 Ratings Section
                    _buildThreeRatingsWidget(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF1DA1F2),
                  indicatorWeight: 3,
                  labelColor: Colors.white,
                  unselectedLabelColor: const Color(0xFF71767B),
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  tabs: const [
                    Tab(text: 'Posts'),
                    Tab(text: 'Fotos'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPostsList(),
            _buildPhotoGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF71767B)),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 14, color: Color(0xFF71767B)),
        ),
      ],
    );
  }

  Widget _buildPostsList() {
    if (_posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.blur_on, size: 64, color: Color(0xFF2F3336)),
            const SizedBox(height: 16),
            Text(
              'Aún no hay publicaciones.',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _posts.length,
      separatorBuilder: (_, _) =>
          const Divider(color: Color(0xFF2F3336), height: 1),
      itemBuilder: (context, index) {
        final post = _posts[index];
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post['content'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
              if (post['hasImage'] == true) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () =>
                      _openImageViewer(context, post['imageUrl'] as String),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      post['imageUrl'] as String,
                      fit: BoxFit.cover,
                      height: 200,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    '${post['comments']}',
                    style: TextStyle(
                        color: Colors.grey.shade500, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPhotoGrid() {
    final photos =
        _posts.where((p) => p['hasImage'] == true).toList();

    if (photos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.photo_library_outlined,
                size: 64, color: Color(0xFF2F3336)),
            const SizedBox(height: 16),
            Text(
              'No se han subido fotos aún.',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final url = photos[index]['imageUrl'] as String;
        return GestureDetector(
          onTap: () => _openImageViewer(context, url),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: const Color(0xFF2F3336),
              child: const Icon(Icons.broken_image,
                  color: Colors.grey, size: 32),
            ),
          ),
        );
      },
    );
  }

  void _openImageViewer(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenImageViewer(imageUrl: imageUrl),
      ),
    );
  }

  Widget _buildThreeRatingsWidget() {
    if (_profileData == null) return const SizedBox.shrink();

    final r1e = (_profileData!['rating1e'] is num) ? (_profileData!['rating1e'] as num).toInt() : 0;
    final r1n = (_profileData!['rating1n'] ?? '').toString();

    final avg = r1e.toDouble();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16181C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2F3336)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 22),
                  const SizedBox(width: 6),
                  const Text(
                    'Evaluación del Docente',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (avg > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.5)),
                      ),
                      child: Text(
                        '${avg.toStringAsFixed(1)} ★',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              InkWell(
                onTap: _showRatingEditDialog,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DA1F2).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF1DA1F2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.rate_review_outlined, color: Color(0xFF1DA1F2), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Calificar',
                        style: TextStyle(
                          color: Color(0xFF1DA1F2),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0E1114),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF1DA1F2).withOpacity(0.2),
                  child: const Icon(Icons.comment, size: 14, color: Color(0xFF1DA1F2)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r1n.isNotEmpty ? r1n : 'Opinión General',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (r1e == 0)
                        const Text(
                          'Sin calificar aún',
                          style: TextStyle(
                            color: Color(0xFF71767B),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(5, (starIdx) {
                    return Icon(
                      starIdx < r1e ? Icons.star : Icons.star_border,
                      color: r1e > 0 ? Colors.amber : Colors.grey.shade700,
                      size: 18,
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingEditDialog() {
    if (_profileData == null) return;

    int tempR1e = (_profileData!['rating1e'] is num) ? (_profileData!['rating1e'] as num).toInt() : 0;
    String tempR1n = (_profileData!['rating1n'] ?? '').toString();

    final n1Controller = TextEditingController(text: tempR1n);

    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Widget buildStarSelector(int currentVal, Function(int) onSelect) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (idx) {
                  final starVal = idx + 1;
                  return IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      starVal <= currentVal ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 26,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        onSelect(starVal);
                      });
                    },
                  );
                }),
              );
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF16181C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF2F3336)),
              ),
              title: const Row(
                children: [
                  Icon(Icons.star_rate_rounded, color: Colors.amber),
                  SizedBox(width: 8),
                  Text(
                    'Calificar',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Asigna puntuación (1 a 5 estrellas) y observación para la evaluación:',
                      style: TextStyle(color: Color(0xFF71767B), fontSize: 13),
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Evaluación General:',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    buildStarSelector(tempR1e, (val) => tempR1e = val),
                    const SizedBox(height: 4),
                    TextField(
                      controller: n1Controller,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 3,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Introduce tu opinión...',
                        hintStyle: const TextStyle(color: Color(0xFF71767B)),
                        filled: true,
                        fillColor: const Color(0xFF0E1114),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF2F3336)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DA1F2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);
                          try {
                            final updates = {
                              'rating1e': tempR1e,
                              'rating1n': n1Controller.text.trim(),
                              'rating2e': 0,
                              'rating2n': '',
                              'rating3e': 0,
                              'rating3n': '',
                            };

                            await _supabase
                                .schema('perfiles')
                                .from('perfil_unificado')
                                .update(updates)
                                .eq('id', widget.profileId);

                            if (mounted) {
                              setState(() {
                                _profileData!['rating1e'] = tempR1e;
                                _profileData!['rating1n'] = n1Controller.text.trim();
                                _profileData!['rating2e'] = 0;
                                _profileData!['rating2n'] = '';
                                _profileData!['rating3e'] = 0;
                                _profileData!['rating3n'] = '';
                              });
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Calificación guardada exitosamente'),
                                  backgroundColor: Color(0xFF1DA1F2),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error al guardar calificación: $e'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          } finally {
                            if (context.mounted) {
                              setDialogState(() => isSaving = false);
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Guardar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─── Full Screen Image Viewer ─────────────────────────────────────────────────

class _FullScreenImageViewer extends StatefulWidget {
  final String imageUrl;
  const _FullScreenImageViewer({required this.imageUrl});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  final TransformationController _transformController =
      TransformationController();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_map, color: Colors.white, size: 24),
            onPressed: _resetZoom,
            tooltip: 'Restablecer zoom',
          ),
        ],
      ),
      body: GestureDetector(
        onDoubleTap: _resetZoom,
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Center(
            child: InteractiveViewer(
              transformationController: _transformController,
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.network(
                widget.imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      color: const Color(0xFF1DA1F2),
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Icon(
                    Icons.broken_image,
                    color: Colors.grey,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sliver Tab Bar Delegate ──────────────────────────────────────────────────

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.black, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) => false;
}
