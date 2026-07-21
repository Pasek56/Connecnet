import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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

  double _profileRating = 0.0;
  String _profileName = '';
  String _profileImageUrl =
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200';
  String? _profileImagePath;
  String _profileHandle = '';
  String _profileBio = '';

  // Mocked list of tweets/posts with state (empty profile)
  final List<Map<String, dynamic>> _tweets = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchProfile();
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
            _updateLocalProfileState(data);
          });
        } else {
          // Si no existe, crear uno por defecto
          final nameParts = (user.email ?? 'Usuario')
              .split('@')
              .first
              .split('.');
          final name = nameParts.first;
          final lastName = nameParts.length > 1 ? nameParts[1] : '';

          final defaultProfile = {
            'user_id': user.id,
            'profile_type': 'estudiante',
            'nombres': name,
            'apellidos': lastName,
            'correo': user.email ?? '',
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
            'mater1': '',
            'mater2': '',
            'mater3': '',
            'empleo1': '',
            'empleo2': '',
            'empleo3': '',
            'titulo': '',
          };
          await _supabase
              .schema('perfiles')
              .from('perfil_unificado')
              .insert(defaultProfile);
          setState(() {
            _profileData = defaultProfile;
            _updateLocalProfileState(defaultProfile);
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

  void _updateLocalProfileState(Map<String, dynamic> data) {
    final profileType = data['profile_type'] ?? 'estudiante';

    switch (profileType) {
      case 'docente':
        _profileName =
            '${data['nombres_prof'] ?? ''} ${data['apellidos_prof'] ?? ''}'
                .trim();
        _profileHandle = (data['correo_prof'] ?? '').toString().split('@').first;
        _profileBio = [
          data['mater1'],
          data['mater2'],
          data['mater3'],
        ].where((m) => m != null && m.toString().isNotEmpty).join(', ');
        if (_profileBio.isNotEmpty) {
          _profileBio = 'Materias: $_profileBio';
        }
        break;
      case 'egresado':
        _profileName =
            '${data['nombres_pro'] ?? ''} ${data['apellidos_pro'] ?? ''}'
                .trim();
        _profileHandle = (data['correo_pro'] ?? '').toString().split('@').first;
        _profileBio = data['titulo'] ?? '';
        break;
      default: // estudiante
        _profileName =
            '${data['nombres'] ?? ''} ${data['apellidos'] ?? ''}'.trim();
        _profileHandle = (data['correo'] ?? '').toString().split('@').first;
        final semestre = data['semestre'] ?? '';
        final experiencia = data['experiencia'] ?? '';
        _profileBio = 'Semestre: $semestre';
        if (experiencia.toString().isNotEmpty) {
          _profileBio += ' · $experiencia';
        }
        break;
    }

    if (_profileName.isEmpty) _profileName = 'Usuario';
    if (_profileHandle.isEmpty) _profileHandle = 'usuario';

    _profileImageUrl = data['pfp'] ??
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200';

    // Load existing rating
    final rating1 = data['rating1e'];
    if (rating1 != null && rating1 is num && rating1 > 0) {
      _profileRating = rating1.toDouble();
    }
  }

  String _getDisplayName() {
    return _profileName.isNotEmpty ? _profileName : 'Usuario';
  }

  String _getHandle() {
    return _profileHandle.isNotEmpty ? _profileHandle : 'usuario';
  }

  String _getBio() {
    return _profileBio.isNotEmpty ? _profileBio : 'Sin biografía aún.';
  }

  String _getProfilePicUrl() {
    return _profileImagePath ?? _profileImageUrl;
  }

  String _getProfileTypeLabel() {
    final type = _profileData?['profile_type'] ?? 'estudiante';
    switch (type) {
      case 'docente':
        return 'Docente';
      case 'egresado':
        return 'Egresado';
      default:
        return 'Estudiante';
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
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1DA1F2)),
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
              floating: false,
              pinned: true,
              backgroundColor: Colors.black,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Image and Edit Profile Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.black, width: 4),
                          ),
                          child: CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage(pfpUrl),
                          ),
                        ),
                        OutlinedButton(
                          onPressed: _showEditProfileDialog,
                          style: OutlinedButton.styleFrom(
                            side:
                                const BorderSide(color: Color(0xFF536471)),
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
                    const SizedBox(height: 12),

                    // User Info
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
                      '@$handle',
                      style: const TextStyle(
                          fontSize: 15, color: Color(0xFF71767B)),
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

                    // Metadata details (Profile type badge, location, joined date)
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildMetaItem(
                            Icons.badge_outlined, profileTypeLabel),
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

                    // Rating
                    const Text(
                      'Calificar Perfil',
                      style: TextStyle(
                        color: Color(0xFF71767B),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildRatingStars(),
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

  void _showEditProfileDialog() {
    final nombresController = TextEditingController(
      text: _profileData?['nombres'] ?? '',
    );
    final apellidosController = TextEditingController(
      text: _profileData?['apellidos'] ?? '',
    );
    String selectedType = _profileData?['profile_type'] ?? 'estudiante';
    final semestreController = TextEditingController(
      text: (_profileData?['semestre'] ?? 1).toString(),
    );
    final tituloController = TextEditingController(
      text: _profileData?['titulo'] ?? '',
    );

    String? selectedImagePath = _profileImagePath;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161C22),
              title: const Text(
                'Editar Perfil',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombresController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Nombres',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF1DA1F2)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: apellidosController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Apellidos',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF1DA1F2)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue:
                          ['estudiante', 'profesional'].contains(selectedType)
                          ? selectedType
                          : 'estudiante',
                      dropdownColor: const Color(0xFF161C22),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Perfil',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF1DA1F2)),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'estudiante',
                          child: Text('Estudiante'),
                        ),
                        DropdownMenuItem(
                          value: 'profesional',
                          child: Text('Profesional'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() {
                            selectedType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    if (selectedType == 'estudiante')
                      TextField(
                        controller: semestreController,
                        style: const TextStyle(color: Colors.white),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Semestre (ej. 1, 5, 8)',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF1DA1F2)),
                          ),
                        ),
                      )
                    else if (selectedType == 'profesional')
                      TextField(
                        controller: tituloController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Título o Profesión',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Color(0xFF1DA1F2)),
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ClipOval(
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: Image.network(
                              selectedImagePath ?? _profileImageUrl,
                              fit: BoxFit.cover,
                              width: 48,
                              height: 48,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 70,
                              maxWidth: 800,
                              maxHeight: 800,
                            );
                            if (pickedFile != null) {
                              setStateDialog(() {
                                selectedImagePath = pickedFile.path;
                              });
                            }
                          },
                          icon: const Icon(Icons.image, color: Colors.white),
                          label: const Text(
                            'Subir Foto',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2F3336),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Update DB logic
                    final user = _supabase.auth.currentUser;
                    if (user != null) {
                      try {
                        final updates = {
                          'nombres': nombresController.text,
                          'apellidos': apellidosController.text,
                          'profile_type': selectedType,
                          if (selectedType == 'estudiante')
                            'semestre':
                                int.tryParse(semestreController.text) ?? 1,
                          if (selectedType == 'profesional')
                            'titulo': tituloController.text,
                        };

                        await _supabase
                            .schema('perfiles')
                            .from('perfil_unificado')
                            .update(updates)
                            .eq('user_id', user.id);

                        // Refetch profile to update state properly
                        await _fetchProfile();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      }
                    }
                    if (selectedImagePath != null) {
                      setState(() {
                        _profileImagePath = selectedImagePath;
                      });
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DA1F2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Guardar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
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

  bool _profileRated = false;

  Widget _buildRatingStars() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            index < _profileRating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 28,
          ),
          onPressed: () {
            if (_profileRated) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Ya has calificado este perfil'),
                  backgroundColor: Color(0xFF1DA1F2),
                ),
              );
              return;
            }
            setState(() {
              _profileRating = index + 1.0;
              _profileRated = true;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Calificaste este perfil con ${_profileRating.toInt()} estrellas',
                ),
                backgroundColor: const Color(0xFF1DA1F2),
              ),
            );
          },
        );
      }),
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
        return InkWell(
          onTap: () => _showCommentDialog(context, tweet),
          child: Padding(
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
                              border: Border.all(
                                color: const Color(0xFF2F3336),
                              ),
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
                                  content: Text(
                                    'Enlace copiado al portapapeles',
                                  ),
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
          ),
        );
      },
    );
  }

  void _showCommentDialog(BuildContext context, Map<String, dynamic> tweet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161C22),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 16,
            right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.withValues(alpha: 0.2),
                    child: const Text(
                      'M',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Respondiendo a @${tweet['handle']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const TextField(
                autofocus: true,
                maxLines: 4,
                minLines: 1,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Escribe tu respuesta...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Comentario publicado')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Responder',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
