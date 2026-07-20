import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  final _supabase = Supabase.instance.client;

  // Mocked list of tweets/posts with state (empty profile)
  final List<Map<String, dynamic>> _tweets = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchProfile();
  }

  // --- Helper methods to resolve correct column names per profile_type ---

  String _getDisplayName() {
    if (_profileData == null) return 'Usuario';
    final type = _profileData!['profile_type'] ?? 'estudiante';
    switch (type) {
      case 'docente':
        final nombres = _profileData!['nombres_prof'] ?? '';
        final apellidos = _profileData!['apellidos_prof'] ?? '';
        return '$nombres $apellidos'.trim();
      case 'egresado':
        final nombres = _profileData!['nombres_pro'] ?? '';
        final apellidos = _profileData!['apellidos_pro'] ?? '';
        return '$nombres $apellidos'.trim();
      default: // estudiante
        final nombres = _profileData!['nombres'] ?? '';
        final apellidos = _profileData!['apellidos'] ?? '';
        return '$nombres $apellidos'.trim();
    }
  }

  String _getEmail() {
    if (_profileData == null) return '';
    final type = _profileData!['profile_type'] ?? 'estudiante';
    switch (type) {
      case 'docente':
        return _profileData!['correo_prof'] ?? '';
      case 'egresado':
        return _profileData!['correo_pro'] ?? '';
      default:
        return _profileData!['correo'] ?? '';
    }
  }

  String _getHandle() {
    final email = _getEmail();
    if (email.contains('@')) {
      return '@${email.split('@').first}';
    }
    final name = _getDisplayName().replaceAll(' ', '_');
    return '@$name';
  }

  String _getProfilePicUrl() {
    return _profileData?['pfp'] ??
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200';
  }

  String _getBio() {
    if (_profileData == null) return '';
    final type = _profileData!['profile_type'] ?? 'estudiante';
    switch (type) {
      case 'estudiante':
        final semestre = _profileData!['semestre'] ?? '';
        final exp = _profileData!['experiencia'] ?? '';
        final preparador = _profileData!['preparador'] == 'S' ? ' | Preparador' : '';
        return 'Estudiante de semestre $semestre$preparador${exp.toString().isNotEmpty ? '\n$exp' : ''}'.trim();
      case 'docente':
        final materias = [
          _profileData!['mater1'],
          _profileData!['mater2'],
          _profileData!['mater3'],
        ].where((m) => m != null && m.toString().isNotEmpty).toList();
        return 'Docente${materias.isNotEmpty ? '\nMaterias: ${materias.join(', ')}' : ''}'.trim();
      case 'egresado':
        final titulo = _profileData!['titulo'] ?? '';
        final empleos = [
          _profileData!['empleo1'],
          _profileData!['empleo2'],
          _profileData!['empleo3'],
        ].where((e) => e != null && e.toString().isNotEmpty).toList();
        return 'Egresado${titulo.toString().isNotEmpty ? ' | $titulo' : ''}${empleos.isNotEmpty ? '\nExperiencia: ${empleos.join(', ')}' : ''}'.trim();
      default:
        return '';
    }
  }

  String _getProfileTypeLabel() {
    switch (_profileData?['profile_type']) {
      case 'docente':
        return 'Docente';
      case 'egresado':
        return 'Egresado';
      default:
        return 'Estudiante';
    }
  }

  // --- Build default profile data with correct columns per type ---

  Map<String, dynamic> _buildDefaultProfile(String userId, String email) {
    final nameParts = email.split('@').first.split('.');
    final name = nameParts.first;
    final lastName = nameParts.length > 1 ? nameParts[1] : '';

    // Default to estudiante for fallback profile creation
    return {
      'user_id': userId,
      'profile_type': 'estudiante',
      'nombres': name,
      'apellidos': lastName,
      'correo': email,
      'pfp':
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200',
      'semestre': 1,
      'experiencia': '',
      'preparador': 'N',
      'rating1e': 0,
      'rating1n': '',
      'rating2e': 0,
      'rating2n': '',
      'rating3e': 0,
      'rating3n': '',
    };
  }

  Future<void> _fetchProfile() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase
            .schema('perfiles')
            .from('perfil_unificado')
            .select()
            .eq('user_id', user.id)
            .maybeSingle();

        if (data != null) {
          setState(() {
            _profileData = data;
          });
        } else {
          // Si no existe, crear uno por defecto
          final defaultProfile =
              _buildDefaultProfile(user.id, user.email ?? 'usuario@unet.edu.ve');
          await _supabase
              .schema('perfiles')
              .from('perfil_unificado')
              .insert(defaultProfile);
          setState(() {
            _profileData = defaultProfile;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar perfil: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleLike(int index) {
    setState(() {
      final tweet = _tweets[index];
      if (tweet['isLiked']) {
        tweet['likes']--;
        tweet['isLiked'] = false;
      } else {
        tweet['likes']++;
        tweet['isLiked'] = true;
      }
    });
  }

  void _toggleRetweet(int index) {
    setState(() {
      final tweet = _tweets[index];
      if (tweet['isRetweeted']) {
        tweet['retweets']--;
        tweet['isRetweeted'] = false;
      } else {
        tweet['retweets']++;
        tweet['isRetweeted'] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading indicator while profile is being fetched
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF1DA1F2),
          ),
        ),
      );
    }

    final displayName = _getDisplayName();
    final handle = _getHandle();
    final bio = _getBio();
    final pfpUrl = _getProfilePicUrl();
    final profileTypeLabel = _getProfileTypeLabel();

    return Scaffold(
      backgroundColor:
          Colors.black, // True black background for modern Twitter/X dark mode
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 180.0,
              floating: false,
              pinned: true,
              backgroundColor: Colors.black,
              elevation: 0,
              leading: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: widget.onLogout,
                ),
              ),
              actions: [
                CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.5),
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    tooltip: 'Cerrar Sesión',
                    onPressed: widget.onLogout,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Cover Image with nice gradient
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1A2B49), Color(0xFF1DA1F2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Opacity(
                        opacity: 0.4,
                        child: Image.network(
                          'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?auto=format&fit=crop&q=80&w=800',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // Dark overlay to ensure header text readability
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Image and Edit Profile Button
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const SizedBox(height: 40),
                        Positioned(
                          top: -50,
                          left: 0,
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Simulación de Editar Perfil',
                                    ),
                                    backgroundColor: Color(0xFF1DA1F2),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF536471),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text(
                                'Editar perfil',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // User Info — dynamic from _profileData
                    Text(
                      displayName.isNotEmpty ? displayName : 'Usuario',
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
                          fontSize: 15, color: Color(0xFF71767B)),
                    ),
                    const SizedBox(height: 12),

                    // Bio — dynamic from profile data
                    if (bio.isNotEmpty)
                      Text(
                        bio,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Metadata details (Profile type badge, location, joined date)
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildMetaItem(Icons.badge_outlined, profileTypeLabel),
                        _buildMetaItem(
                            Icons.location_on_outlined, 'Venezuela'),
                        _buildMetaItem(
                          Icons.calendar_today_outlined,
                          'Se unió en junio de 2026',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Followers & Following Counters
                    Row(
                      children: [
                        _buildCountItem('0', 'Siguiendo'),
                        const SizedBox(width: 20),
                        _buildCountItem('0', 'Seguidores'),
                      ],
                    ),
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
                    Tab(text: 'Respuestas'),
                    Tab(text: 'Fotos'),
                    Tab(text: 'Me gusta'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildTweetList(),
            _buildEmptyState('Aún no hay respuestas publicadas.'),
            _buildEmptyState(
              'No se han subido archivos multimedia recientemente.',
            ),
            _buildTweetList(onlyLiked: true),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(IconData icon, String text, {bool isLink = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF71767B)),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: isLink ? const Color(0xFF1DA1F2) : const Color(0xFF71767B),
            fontWeight: isLink ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildCountItem(String count, String label) {
    return Row(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF71767B), fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildTweetList({bool onlyLiked = false}) {
    final filteredTweets = onlyLiked
        ? _tweets.where((t) => t['isLiked'] == true).toList()
        : _tweets;

    if (filteredTweets.isEmpty) {
      return _buildEmptyState(
        onlyLiked
            ? 'No tienes posts marcados como "Me gusta" todavía.'
            : 'No has publicado ningún post aún.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: filteredTweets.length,
      separatorBuilder: (context, index) =>
          const Divider(color: Color(0xFF2F3336), height: 1),
      itemBuilder: (context, index) {
        final tweet = filteredTweets[index];
        final globalIndex = _tweets.indexOf(tweet);
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(tweet['avatarUrl']),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header (Display Name, Handle, Time)
                    Row(
                      children: [
                        Text(
                          tweet['displayName'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '@${tweet['handle']} · ${tweet['time']}',
                            style: const TextStyle(
                              color: Color(0xFF71767B),
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(
                          Icons.more_horiz,
                          color: Color(0xFF71767B),
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Tweet Text
                    Text(
                      tweet['content'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),

                    // Optional image attachment
                    if (tweet['hasImage']) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF2F3336)),
                          ),
                          child: Image.network(
                            tweet['imageUrl'],
                            fit: BoxFit.cover,
                            height: 200,
                            width: double.infinity,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Action buttons bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildActionButton(
                          Icons.chat_bubble_outline_rounded,
                          tweet['comments'].toString(),
                          const Color(0xFF71767B),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Comentarios simulados'),
                              ),
                            );
                          },
                        ),
                        _buildActionButton(
                          Icons.repeat_rounded,
                          tweet['retweets'].toString(),
                          tweet['isRetweeted']
                              ? const Color(0xFF00BA7C)
                              : const Color(0xFF71767B),
                          onTap: () => _toggleRetweet(globalIndex),
                        ),
                        _buildActionButton(
                          tweet['isLiked']
                              ? Icons.favorite
                              : Icons.favorite_border,
                          tweet['likes'].toString(),
                          tweet['isLiked']
                              ? const Color(0xFFF91880)
                              : const Color(0xFF71767B),
                          onTap: () => _toggleLike(globalIndex),
                        ),
                        _buildActionButton(
                          Icons.share_outlined,
                          '',
                          const Color(0xFF71767B),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Enlace copiado al portapapeles'),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(
    IconData icon,
    String text,
    Color color, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          if (text.isNotEmpty && text != '0')
            Text(text, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.blur_on, size: 64, color: Color(0xFF2F3336)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF71767B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: Colors.black, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
