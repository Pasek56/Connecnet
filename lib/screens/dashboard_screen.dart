import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'profile_screen.dart';
import 'news_screen.dart';
import 'conversations_screen.dart';
import 'public_profile_screen.dart';

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

  // Like state
  Set<int> _likedEncargos = {};
  Map<int, int> _likeCounts = {};

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
    await _fetchLikes();
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
          .select('*, comentarios:comentarios(count)')
          .order('id_enc', ascending: false);

      List<Map<String, dynamic>> encargos = List<Map<String, dynamic>>.from(
        response,
      );

      // Extraer IDs únicos de remitentes
      final senderIds = encargos
          .map((e) => e['sender_profile_id'])
          .where((id) => id != null)
          .toSet()
          .toList();

      if (senderIds.isNotEmpty) {
        // Buscar perfiles
        final profilesResponse = await _supabase
            .schema('perfiles')
            .from('perfil_unificado')
            .select()
            .filter('id', 'in', senderIds);

        final profiles = List<Map<String, dynamic>>.from(profilesResponse);
        final profileMap = {for (var p in profiles) p['id']: p};

        // Asociar perfiles a los encargos
        for (var encargo in encargos) {
          final senderId = encargo['sender_profile_id'];
          if (senderId != null) {
            encargo['sender'] = profileMap[senderId];
          }
        }
      }

      setState(() {
        _encargos = encargos;
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

  // ─── Likes ──────────────────────────────────────────────────────────

  Future<void> _fetchLikes() async {
    final profileId = _userProfile?['id'] as int?;
    if (profileId == null) return;

    try {
      // Fetch which encargos this user has liked
      final myLikes = await _supabase
          .schema('publicaciones')
          .from('likes')
          .select('encargo_id')
          .eq('profile_id', profileId);

      final likedIds = <int>{};
      for (var row in List<Map<String, dynamic>>.from(myLikes)) {
        likedIds.add(row['encargo_id'] as int);
      }

      // Fetch like counts for all encargos currently displayed
      final encargoIds = _encargos
          .map((e) => e['id_enc'] as int?)
          .where((id) => id != null)
          .cast<int>()
          .toList();

      final counts = <int, int>{};
      if (encargoIds.isNotEmpty) {
        final countsResponse = await _supabase
            .schema('publicaciones')
            .from('likes')
            .select('encargo_id')
            .filter('encargo_id', 'in', encargoIds);

        for (var row in List<Map<String, dynamic>>.from(countsResponse)) {
          final eid = row['encargo_id'] as int;
          counts[eid] = (counts[eid] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _likedEncargos = likedIds;
          _likeCounts = counts;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar likes: $e');
    }
  }

  Future<void> _toggleLike(int encargoId) async {
    final profileId = _userProfile?['id'] as int?;
    if (profileId == null) return;

    final wasLiked = _likedEncargos.contains(encargoId);

    // Optimistic UI update
    setState(() {
      if (wasLiked) {
        _likedEncargos.remove(encargoId);
        _likeCounts[encargoId] = (_likeCounts[encargoId] ?? 1) - 1;
      } else {
        _likedEncargos.add(encargoId);
        _likeCounts[encargoId] = (_likeCounts[encargoId] ?? 0) + 1;
      }
    });

    try {
      if (wasLiked) {
        await _supabase
            .schema('publicaciones')
            .from('likes')
            .delete()
            .eq('encargo_id', encargoId)
            .eq('profile_id', profileId);
      } else {
        await _supabase.schema('publicaciones').from('likes').insert({
          'encargo_id': encargoId,
          'profile_id': profileId,
        });
      }
    } catch (e) {
      // Revert on failure
      if (mounted) {
        setState(() {
          if (wasLiked) {
            _likedEncargos.add(encargoId);
            _likeCounts[encargoId] = (_likeCounts[encargoId] ?? 0) + 1;
          } else {
            _likedEncargos.remove(encargoId);
            _likeCounts[encargoId] = (_likeCounts[encargoId] ?? 1) - 1;
          }
        });
      }
      debugPrint('Error al alternar like: $e');
    }
  }

  // ─── PFP Navigation ─────────────────────────────────────────────────

  void _navigateToProfile(Map<String, dynamic> sender) {
    final senderId = sender['id'] as int?;
    final currentId = _userProfile?['id'] as int?;

    if (senderId == null) return;

    if (senderId == currentId) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(onLogout: widget.onLogout ?? () {}),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PublicProfileScreen(profileId: senderId),
        ),
      );
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

  Future<void> _deletePost(int postId) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161C22),
        title: const Text('Eliminar publicación', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro de que deseas eliminar esta publicación?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _supabase.schema('publicaciones').from('encargo').delete().eq('id_enc', postId);
                await _fetchEncargos();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Publicación eliminada'),
                      backgroundColor: Color(0xFF1DA1F2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al eliminar: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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

  String _getSenderPfp(Map<String, dynamic>? sender) {
    final pfp = sender?['pfp'];
    if (pfp != null && pfp.toString().isNotEmpty) {
      return pfp.toString();
    }
    return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200';
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: _buildCustomAppBar(),
      drawer: !isWideScreen
          ? Drawer(
              child: Container(
                color: Colors.white,
                child: SafeArea(
                  child: _buildSidebarContents(),
                ),
              ),
            )
          : null,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sidebar on wide screens
          if (isWideScreen)
            Container(
              width: 260,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  right: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: _buildSidebarContents(),
            ),
          
          // Main Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchEncargos,
              color: const Color(0xFF003E90),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF003E90)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      itemCount: _encargos.length + 2,
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildCourseBannerCard();
                        if (index == 1) return _buildCreatePostWidget();
                        return _buildPostCard(context, _encargos[index - 2]);
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: !isWideScreen
          ? Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'btn_article',
                  onPressed: _openNewsScreen,
                  backgroundColor: const Color(0xFF003E90),
                  child: const Icon(Icons.article, color: Colors.white),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'btn_messages',
                  onPressed: _openConversationsScreen,
                  backgroundColor: const Color(0xFF003E90),
                  child: const Icon(Icons.message_rounded, color: Colors.white),
                ),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'btn_profile',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProfileScreen(onLogout: widget.onLogout ?? () {}),
                      ),
                    );
                  },
                  backgroundColor: const Color(0xFF003E90),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
              ],
            )
          : null,
    );
  }

  PreferredSizeWidget _buildCustomAppBar() {
    final isWideScreen = MediaQuery.of(context).size.width > 800;
    return PreferredSize(
      preferredSize: const Size.fromHeight(115),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // White top bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  if (!isWideScreen)
                    Builder(
                      builder: (context) => IconButton(
                        icon: const Icon(Icons.menu, color: Colors.black87),
                        onPressed: () => Scaffold.of(context).openDrawer(),
                      ),
                    ),
                  Image.asset(
                    'Images/Logo_Unet.png',
                    height: 38,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF003E90),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(Icons.school, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'U',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF003E90),
                    ),
                  ),
                  const Text(
                    'VIRTUAL',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  // Top Navigation links (visible on wider screens)
                  if (isWideScreen) ...[
                    _buildTopNavLink('Página Principal', true),
                    _buildTopNavLink('Noticias', false, onTap: _openNewsScreen),
                    _buildTopNavLink('Mensajes', false, onTap: _openConversationsScreen),
                    _buildTopNavLink('Mi Perfil', false, onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(onLogout: widget.onLogout ?? () {}),
                        ),
                      );
                    }),
                    const SizedBox(width: 20),
                  ],
                  // Right icons
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none, color: Colors.black87),
                        onPressed: () {},
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: const Text(
                            '4',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.black87),
                    onPressed: _openConversationsScreen,
                  ),
                ],
              ),
            ),
          ),
          // Blue sub-header bar
          Container(
            color: const Color(0xFF003E90),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            height: 48,
            child: Row(
              children: [
                _buildBlueBarTab('Publicaciones', true),
                _buildBlueBarTab('Noticias', false, onTap: _openNewsScreen),
                _buildBlueBarTab('Mensajería', false, onTap: _openConversationsScreen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNavLink(String text, bool isActive, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? const Color(0xFF003E90) : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildBlueBarTab(String text, bool isActive, {VoidCallback? onTap}) {
    return Container(
      decoration: BoxDecoration(
        border: isActive
            ? const Border(
                bottom: BorderSide(
                  color: Colors.white,
                  width: 3.0,
                ),
              )
            : null,
      ),
      margin: const EdgeInsets.only(right: 24),
      alignment: Alignment.center,
      child: InkWell(
        onTap: onTap ?? () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarContents() {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        // Sidebar header with close button (only if drawer on mobile)
        if (isMobile)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.black87),
              onPressed: () => Navigator.pop(context),
            ),
          ),

        // User info chip at the top of the sidebar
        if (_userProfile != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(_getSenderPfp(_userProfile)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getSenderName(_userProfile),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        (_userProfile!['profile_type'] ?? 'estudiante').toString().toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF003E90),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const Divider(height: 24, indent: 16, endIndent: 16),

        // Functional navigation items
        _buildSidebarItem(Icons.home_outlined, 'Inicio', isSelected: true, onTap: () {
          if (isMobile) Navigator.pop(context);
        }),
        _buildSidebarItem(Icons.newspaper_outlined, 'Noticias', onTap: () {
          if (isMobile) Navigator.pop(context);
          _openNewsScreen();
        }),
        _buildSidebarItem(Icons.chat_bubble_outline, 'Mensajería', onTap: () {
          if (isMobile) Navigator.pop(context);
          _openConversationsScreen();
        }),
        _buildSidebarItem(Icons.person_outline, 'Mi Perfil', onTap: () {
          if (isMobile) Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(onLogout: widget.onLogout ?? () {}),
            ),
          );
        }),

        const Divider(height: 32, indent: 16, endIndent: 16),

        _buildSidebarItem(Icons.logout, 'Cerrar Sesión', color: Colors.redAccent, onTap: () {
          if (isMobile) Navigator.pop(context);
          if (widget.onLogout != null) widget.onLogout!();
        }),
      ],
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, {bool isSelected = false, VoidCallback? onTap, Color? color}) {
    final itemColor = color ?? (isSelected ? const Color(0xFF003E90) : Colors.black54);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF003E90).withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        onTap: onTap ?? () {},
        dense: true,
        leading: Icon(icon, color: itemColor, size: 16),
        title: Text(
          title,
          style: TextStyle(
            color: color ?? (isSelected ? const Color(0xFF003E90) : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        minLeadingWidth: 0,
        visualDensity: const VisualDensity(vertical: -3),
      ),
    );
  }

  void _openNewsScreen() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            width: MediaQuery.of(context).size.width > 800 ? 700 : double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              child: NewsScreen(userProfile: _userProfile),
            ),
          ),
        );
      },
    );
  }

  void _openConversationsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationsScreen(userProfile: _userProfile),
      ),
    );
  }

  Widget _buildCourseBannerCard() {
    final userName = _getSenderName(_userProfile);
    final profileType = (_userProfile?['profile_type'] ?? 'estudiante').toString();
    final roleBadgeLabel = profileType == 'docente'
        ? 'Docente'
        : profileType == 'egresado'
            ? 'Egresado'
            : 'Estudiante';

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF00224D), Color(0xFF003E90), Color(0xFF1565C0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left content
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: Text(
                          roleBadgeLabel.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '¡Bienvenido a',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const Text(
                        'UnetConnect!',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Quick action chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildWelcomeChip(Icons.article_outlined, 'Noticias', _openNewsScreen),
                          _buildWelcomeChip(Icons.chat_bubble_outline, 'Mensajes', _openConversationsScreen),
                          _buildWelcomeChip(Icons.person_outline, 'Mi Perfil', () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProfileScreen(onLogout: widget.onLogout ?? () {}),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Right decorative side
              if (MediaQuery.of(context).size.width > 500)
                Expanded(
                  flex: 3,
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white.withOpacity(0.15),
                          backgroundImage: NetworkImage(_getSenderPfp(_userProfile)),
                        ),
                        const SizedBox(height: 12),
                        Image.asset(
                          'Images/Logo_Unet.png',
                          height: 28,
                          color: Colors.white.withOpacity(0.8),
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.school, color: Colors.white70, size: 28),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'VIRTUAL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeChip(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreatePostWidget() {
    final pfp = _getSenderPfp(_userProfile);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundImage: NetworkImage(pfp),
              radius: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _postController,
                    maxLines: null,
                    style: const TextStyle(color: Colors.black87, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: '¿Qué está pasando hoy en el curso?',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
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
                                  color: Colors.grey.shade100,
                                  alignment: Alignment.center,
                                  child: const Text('Imagen seleccionada', style: TextStyle(color: Colors.black54)),
                                ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            radius: 16,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 16),
                              onPressed: () {
                                setState(() {
                                  _selectedImagePath = null;
                                });
                              },
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.image_outlined, color: Color(0xFF003E90)),
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
                      ElevatedButton(
                        onPressed: _isPosting ? null : _addPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003E90),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, Map<String, dynamic> encargo) {
    final sender = encargo['sender'] as Map<String, dynamic>?;
    final senderName = _getSenderName(sender);
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
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showCommentDialog(context, encargo),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF003E90).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.language,
                      color: Color(0xFF003E90),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            GestureDetector(
                              onTap: sender != null
                                  ? () => _navigateToProfile(sender)
                                  : null,
                              child: Text(
                                senderName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                senderType.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Publicado en el curso',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_userProfile?['profile_type'] == 'docente')
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () => _deletePost(encargo['id_enc']),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
              const SizedBox(height: 12),
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
                text: desc,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color: Colors.black87,
                ),
                linkStyle: const TextStyle(
                  color: Color(0xFF003E90),
                  decoration: TextDecoration.underline,
                ),
              ),
              if (img.isNotEmpty) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _FullScreenImageViewer(imageUrl: img),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      img,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: 180,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final encargoId = encargo['id_enc'] as int;
                  final isLiked = _likedEncargos.contains(encargoId);
                  final likeCount = _likeCounts[encargoId] ?? 0;

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _buildActionIcon(
                            Icons.chat_bubble_outline,
                            '$commentsCount',
                            onTap: () => _showCommentDialog(context, encargo),
                          ),
                          const SizedBox(width: 16),
                          _buildActionIcon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            likeCount > 0 ? '$likeCount' : '0',
                            color: isLiked ? Colors.redAccent : null,
                            onTap: () => _toggleLike(encargoId),
                          ),
                        ],
                      ),
                      OutlinedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Actividad marcada como leída'),
                              backgroundColor: Color(0xFF003E90),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Marcar como hecha',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  );
                },
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
    final iconColor = color ?? Colors.grey.shade600;
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 18),
            if (count.isNotEmpty && count != '0') ...[
              const SizedBox(width: 6),
              Text(
                count,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
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
          .select('*')
          .eq('encargo_id', widget.encargo['id_enc'])
          .order('id_coment', ascending: true);

      List<Map<String, dynamic>> comments = List<Map<String, dynamic>>.from(
        response,
      );

      // Extraer IDs únicos
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al responder: $e')));
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
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 12,
        left: 16,
        right: 16,
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Respuestas y Comentarios',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoadingComments
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF003E90)),
                  )
                : _comments.isEmpty
                ? Center(
                    child: Text(
                      'Aún no hay respuestas. ¡Sé el primero en responder!',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    itemCount: _comments.length,
                    itemBuilder: (context, index) {
                      final coment = _comments[index];
                      final sender = coment['sender'] as Map<String, dynamic>?;
                      final senderName = _getSenderName(sender);
                      final content = coment['content'] ?? '';
                      final senderType = coment['sender_profile_type'] ?? 'estudiante';

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFF003E90).withOpacity(0.1),
                                child: Text(
                                  senderName.isNotEmpty
                                      ? senderName[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                    color: Color(0xFF003E90),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          senderName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '@$senderType',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
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
                                      text: content,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 13.5,
                                      ),
                                      linkStyle: const TextStyle(
                                        color: Color(0xFF003E90),
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(color: Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(color: Colors.black87, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Escribe tu respuesta...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isSending ? null : _sendComment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003E90),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    elevation: 0,
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
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
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
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
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
                  child: Icon(Icons.broken_image, color: Colors.grey, size: 64),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
