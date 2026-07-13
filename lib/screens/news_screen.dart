import 'package:flutter/material.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  final TextEditingController _newsTitleController = TextEditingController();
  final TextEditingController _newsContentController = TextEditingController();
  final TextEditingController _newsImageUrlController = TextEditingController();

  final List<Map<String, dynamic>> newsList = [
    {
      'title': 'Flutter 4.0 Lanzamiento Oficial',
      'content': 'La nueva versión de Flutter trae mejoras increíbles en rendimiento y nuevas herramientas de desarrollo para crear aplicaciones aún más rápidas y multiplataforma.',
      'imageUrl': 'https://images.unsplash.com/photo-1617042375876-a13e36732a04?auto=format&fit=crop&q=80&w=800',
      'date': 'Hace 2 horas',
      'source': 'Tech News',
    },
    {
      'title': 'Nueva actualización en ConnectNet',
      'content': 'Hemos añadido nuevas funciones a nuestra plataforma para mejorar la interacción entre los desarrolladores y la comunidad. ¡Descubre las nuevas características de los perfiles!',
      'imageUrl': 'https://images.unsplash.com/photo-1517694712202-14dd9538aa97?auto=format&fit=crop&q=80&w=800',
      'date': 'Hace 5 horas',
      'source': 'ConnectNet Team',
    },
    {
      'title': 'Consejos para mejorar tu código en Dart',
      'content': 'Descubre los mejores patrones de diseño y arquitecturas para mantener tu código limpio, seguro y escalable en proyectos cada vez más grandes.',
      'imageUrl': 'https://images.unsplash.com/photo-1555066931-4365d14bab8c?auto=format&fit=crop&q=80&w=800',
      'date': 'Ayer',
      'source': 'Dev Community',
    },
  ];

  @override
  void dispose() {
    _newsTitleController.dispose();
    _newsContentController.dispose();
    _newsImageUrlController.dispose();
    super.dispose();
  }

  void _addNews() {
    if (_newsTitleController.text.isNotEmpty && _newsContentController.text.isNotEmpty) {
      setState(() {
        newsList.insert(0, {
          'title': _newsTitleController.text,
          'content': _newsContentController.text,
          'imageUrl': _newsImageUrlController.text.isNotEmpty ? _newsImageUrlController.text : null,
          'date': 'Ahora mismo',
          'source': 'Usuario',
        });
        _newsTitleController.clear();
        _newsContentController.clear();
        _newsImageUrlController.clear();
      });
    }
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
          const Text('Publicar una Noticia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
            decoration: const InputDecoration(
              hintText: 'URL de la imagen (opcional)...',
              border: InputBorder.none,
              hintStyle: TextStyle(color: Colors.grey),
              icon: Icon(Icons.image, color: Colors.blue, size: 20),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _addNews,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Publicar Noticia', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: newsList.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildCreateNewsWidget();
        }
        final news = newsList[index - 1];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: const Color(0xFF161C22),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade800, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Abriendo noticia: ${news['title']}')),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (news['imageUrl'] != null)
                  Image.network(
                    news['imageUrl'],
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.article_outlined, size: 16, color: Color(0xFF1DA1F2)),
                          const SizedBox(width: 8),
                          Text(
                            news['source'],
                            style: const TextStyle(
                              color: Color(0xFF1DA1F2),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            news['date'],
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        news['title'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        news['content'],
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 14,
                          height: 1.4,
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
    );
  }
}
