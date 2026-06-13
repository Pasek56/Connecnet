import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final List<Map<String, dynamic>> _posts = List.generate(
    5,
    (index) => {
      'likes': (index + 1) * 7,
      'isLiked': false,
    },
  );

  void _toggleLike(int index) {
    setState(() {
      if (_posts[index]['isLiked']) {
        _posts[index]['likes']--;
        _posts[index]['isLiked'] = false;
      } else {
        _posts[index]['likes']++;
        _posts[index]['isLiked'] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Publicaciones',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) {
          return _buildPostCard(context, index);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildPostCard(BuildContext context, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF161C22),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade800, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                  child: Text(
                    'U$index',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Usuario $index',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '@usuario$index • ${index + 1}h',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz, color: Colors.grey),
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Este es el contenido de la publicación número $index. Aquí puedes compartir tus ideas, noticias y conectar con otros desarrolladores en ConnectNet.',
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActionIcon(
                  Icons.chat_bubble_outline,
                  '${(index + 1) * 2}',
                ),
                _buildActionIcon(Icons.repeat, '$index'),
                _buildActionIcon(
                  _posts[index]['isLiked'] ? Icons.favorite : Icons.favorite_border,
                  '${_posts[index]['likes']}',
                  color: _posts[index]['isLiked'] ? const Color(0xFFF91880) : Colors.grey.shade400,
                  onTap: () => _toggleLike(index),
                ),
                _buildActionIcon(Icons.bookmark_border, ''),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon(IconData icon, String count, {Color? color, VoidCallback? onTap}) {
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
