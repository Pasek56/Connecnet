import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'news_detail_screen.dart';

class NewsScreen extends StatefulWidget {
  final Map<String, dynamic>? userProfile;

  const NewsScreen({super.key, this.userProfile});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final TextEditingController _newsTitleController = TextEditingController();
  final TextEditingController _newsContentController = TextEditingController();
  final TextEditingController _newsImageUrlController = TextEditingController();
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isPosting = false;
  List<Map<String, dynamic>> _newsList = [];

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  @override
  void dispose() {
    _newsTitleController.dispose();
    _newsContentController.dispose();
    _newsImageUrlController.dispose();
    super.dispose();
  }

  Future<void> _fetchNews() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase
          .schema('publicaciones')
          .from('noticia')
          .select('*, comentarios:comentarios(count)')
          .order('id_pub', ascending: false);

      setState(() {
        _newsList = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error al cargar noticias: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar noticias: $e'),
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

  Future<void> _addNews() async {
    final title = _newsTitleController.text.trim();
    final content = _newsContentController.text.trim();
    final imgUrl = _newsImageUrlController.text.trim();

    if (content.isEmpty && title.isEmpty) return;

    final fullDesc = title.isNotEmpty && content.isNotEmpty
        ? '$title\n\n$content'
        : (title.isNotEmpty ? title : content);

    setState(() {
      _isPosting = true;
    });

    try {
      await _supabase.schema('publicaciones').from('noticia').insert({
        'desc_pub': fullDesc,
        'img_pub': imgUrl, // img_pub is NOT NULL
      });

      _newsTitleController.clear();
      _newsContentController.clear();
      _newsImageUrlController.clear();

      await _fetchNews();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Noticia publicada exitosamente'),
            backgroundColor: Color(0xFF1DA1F2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al publicar noticia: $e'),
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

  Map<String, String> _parseNewsDesc(String rawDesc) {
    if (rawDesc.contains('\n\n')) {
      final parts = rawDesc.split('\n\n');
      return {
        'title': parts.first.trim(),
        'content': parts.sublist(1).join('\n\n').trim(),
      };
    }
    return {'title': rawDesc, 'content': rawDesc};
  }

  Widget _buildCreateNewsWidget() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF161C22),
        border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Publicar una Noticia',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _newsTitleController,
            decoration: const InputDecoration(
              hintText: 'Título de la noticia...',
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey),
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextField(
            controller: _newsContentController,
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              hintText: 'Desarrollo de la noticia...',
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey),
            ),
          ),
          TextField(
            controller: _newsImageUrlController,
            decoration: InputDecoration(
              hintText: 'URL de la imagen o selecciona una...',
              border: InputBorder.none,
              hintStyle: const TextStyle(color: Colors.grey),
              icon: const Icon(Icons.image, color: Colors.blue, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.photo_library, color: Colors.blue),
                onPressed: () async {
                  final picker = ImagePicker();
                  final pickedFile = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 70,
                    maxWidth: 800,
                  );
                  if (pickedFile != null) {
                    setState(() {
                      _newsImageUrlController.text = pickedFile.path;
                    });
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _isPosting ? null : _addNews,
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
                      'Publicar Noticia',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchNews,
      color: const Color(0xFF1DA1F2),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1DA1F2)),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _newsList.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  final profileType = widget.userProfile?['profile_type'];
                  return (profileType == 'docente' || profileType == 'egresado')
                      ? _buildCreateNewsWidget()
                      : const SizedBox.shrink();
                }
                final rawNews = _newsList[index - 1];
                final parsed = _parseNewsDesc(rawNews['desc_pub'] ?? '');
                final imgUrl = rawNews['img_pub'] ?? '';

                int commentsCount = 0;
                if (rawNews['comentarios'] != null &&
                    rawNews['comentarios'] is List) {
                  final list = rawNews['comentarios'] as List;
                  if (list.isNotEmpty && list.first['count'] != null) {
                    commentsCount = list.first['count'] as int;
                  }
                }

                final newsData = {
                  'id_pub': rawNews['id_pub'],
                  'title': parsed['title'],
                  'content': parsed['content'],
                  'imageUrl': imgUrl.isNotEmpty ? imgUrl : null,
                  'date': 'Publicación #${rawNews['id_pub']}',
                  'source': 'ConnectNet News',
                  'commentsCount': commentsCount,
                };

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: const Color(0xFF161C22),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade800, width: 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              NewsDetailScreen(news: newsData),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (newsData['imageUrl'] != null &&
                            (newsData['imageUrl'] as String).isNotEmpty)
                          Image.network(
                            newsData['imageUrl'] as String,
                            height: 180,
                            width: double.infinity,
                            fit: BoxFit.cover,
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
                                    size: 16,
                                    color: Color(0xFF1DA1F2),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    newsData['source'] as String,
                                    style: const TextStyle(
                                      color: Color(0xFF1DA1F2),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    newsData['date'] as String,
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                newsData['title'] as String,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                newsData['content'] as String,
                                style: TextStyle(
                                  color: Colors.grey.shade300,
                                  fontSize: 14,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.chat_bubble_outline,
                                    size: 16,
                                    color: Colors.grey.shade500,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$commentsCount',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 13,
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
              },
            ),
    );
  }
}
