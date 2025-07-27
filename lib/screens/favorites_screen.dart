import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/file_explorer_provider.dart';
import '../models/file_item.dart';

class FavoritesScreen extends ConsumerWidget {
  final VoidCallback? onNavigateToFileExplorer;
  
  const FavoritesScreen({super.key, this.onNavigateToFileExplorer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('お気に入り'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (favorites.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_all),
              onPressed: () => _showClearAllDialog(context, ref),
            ),
        ],
      ),
      body: favorites.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'お気に入りのファイルはありません',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'ファイルのハートアイコンをタップして\nお気に入りに追加してください',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              itemCount: favorites.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final path = favorites[index];
                return _buildFavoriteItem(context, ref, path);
              },
            ),
    );
  }

  Widget _buildFavoriteItem(BuildContext context, WidgetRef ref, String path) {
    final file = File(path);
    final directory = Directory(path);
    
    // Check if file or directory exists
    final exists = file.existsSync() || directory.existsSync();
    
    if (!exists) {
      return ListTile(
        leading: const Icon(Icons.error_outline, color: Colors.red),
        title: Text(
          path.split(Platform.pathSeparator).last,
          style: const TextStyle(
            decoration: TextDecoration.lineThrough,
            color: Colors.grey,
          ),
        ),
        subtitle: const Text(
          'ファイルが見つかりません',
          style: TextStyle(color: Colors.red),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            ref.read(favoritesProvider.notifier).removeFavorite(path);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('お気に入りから削除しました')),
            );
          },
        ),
      );
    }

    final entity = file.existsSync() ? file : directory;
    final stat = entity.statSync();
    final fileName = path.split(Platform.pathSeparator).last;
    final isDirectory = directory.existsSync();

    return ListTile(
      leading: Icon(
        isDirectory ? Icons.folder : _getFileIcon(fileName),
        color: isDirectory ? Colors.blue : _getFileColor(fileName),
        size: 40,
      ),
      title: Text(
        fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${_formatFileSize(stat.size)} • ${_formatDate(stat.modified)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.favorite, color: Colors.red),
            onPressed: () {
              ref.read(favoritesProvider.notifier).removeFavorite(path);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('お気に入りから削除しました')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () => _openInFileExplorer(context, ref, path, isDirectory),
          ),
        ],
      ),
      onTap: () => _openInFileExplorer(context, ref, path, isDirectory),
    );
  }

  void _openInFileExplorer(BuildContext context, WidgetRef ref, String path, bool isDirectory) {
    final targetPath = isDirectory ? path : Directory(path).parent.path;
    ref.read(fileExplorerProvider.notifier).navigateToPath(targetPath);
    
    // Switch to file explorer tab using callback
    if (onNavigateToFileExplorer != null) {
      onNavigateToFileExplorer!();
    }
  }

  void _showClearAllDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('すべてのお気に入りを削除'),
        content: const Text('すべてのお気に入りを削除しますか？\nこの操作は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              // Clear all favorites
              final favorites = ref.read(favoritesProvider);
              for (final path in favorites) {
                ref.read(favoritesProvider.notifier).removeFavorite(path);
              }
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('すべてのお気に入りを削除しました')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    const audioExtensions = ['mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg'];
    const videoExtensions = ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv'];
    const documentExtensions = ['pdf', 'doc', 'docx', 'txt', 'rtf'];
    const archiveExtensions = ['zip', 'rar', '7z', 'tar', 'gz'];
    
    if (imageExtensions.contains(extension)) return Icons.image;
    if (audioExtensions.contains(extension)) return Icons.audio_file;
    if (videoExtensions.contains(extension)) return Icons.video_file;
    if (documentExtensions.contains(extension)) return Icons.description;
    if (archiveExtensions.contains(extension)) return Icons.archive;
    
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    const audioExtensions = ['mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg'];
    const videoExtensions = ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv'];
    const documentExtensions = ['pdf', 'doc', 'docx', 'txt', 'rtf'];
    const archiveExtensions = ['zip', 'rar', '7z', 'tar', 'gz'];
    
    if (imageExtensions.contains(extension)) return Colors.green;
    if (audioExtensions.contains(extension)) return Colors.purple;
    if (videoExtensions.contains(extension)) return Colors.red;
    if (documentExtensions.contains(extension)) return Colors.orange;
    if (archiveExtensions.contains(extension)) return Colors.brown;
    
    return Colors.grey;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}