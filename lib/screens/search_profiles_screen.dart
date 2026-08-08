import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'public_profile_screen.dart';

class SearchProfilesScreen extends StatefulWidget {
  const SearchProfilesScreen({super.key});

  @override
  State<SearchProfilesScreen> createState() => _SearchProfilesScreenState();
}

class _SearchProfilesScreenState extends State<SearchProfilesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().isNotEmpty) {
        _performSearch(query.trim());
      } else {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    });
    // Force rebuild to update clear icon visibility
    setState(() {});
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase
          .schema('perfiles')
          .from('perfil_unificado')
          .select()
          .or('nombres.ilike.%$query%,apellidos.ilike.%$query%,nombres_prof.ilike.%$query%,apellidos_prof.ilike.%$query%,nombres_pro.ilike.%$query%,apellidos_pro.ilike.%$query%')
          .limit(20);

      if (mounted) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error searching profiles: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al buscar perfiles: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _getDisplayName(Map<String, dynamic> profile) {
    final type = profile['profile_type'] ?? 'estudiante';
    if (type == 'docente') {
      final name = '${profile['nombres_prof'] ?? ''} ${profile['apellidos_prof'] ?? ''}'.trim();
      return name.isNotEmpty ? name : 'Docente';
    } else if (type == 'egresado') {
      final name = '${profile['nombres_pro'] ?? ''} ${profile['apellidos_pro'] ?? ''}'.trim();
      return name.isNotEmpty ? name : 'Egresado';
    } else {
      final name = '${profile['nombres'] ?? ''} ${profile['apellidos'] ?? ''}'.trim();
      return name.isNotEmpty ? name : 'Estudiante';
    }
  }

  String _getProfilePicture(Map<String, dynamic> profile) {
    final pfp = profile['pfp'];
    if (pfp != null && pfp.toString().isNotEmpty) {
      return pfp.toString();
    }
    return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=200';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Buscar perfiles...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 18),
          onChanged: _onSearchChanged,
        ),
        backgroundColor: const Color(0xFF161C22),
        elevation: 1,
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1DA1F2)))
          : _searchResults.isEmpty && _searchController.text.isNotEmpty
              ? const Center(
                  child: Text(
                    'No se encontraron perfiles',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final profile = _searchResults[index];
                    final name = _getDisplayName(profile);
                    final pfp = _getProfilePicture(profile);
                    final type = profile['profile_type'] ?? 'estudiante';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(pfp),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        type.toString().toUpperCase(),
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PublicProfileScreen(profileId: profile['id']),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}
