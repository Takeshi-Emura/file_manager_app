import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/file_item.dart';
import '../providers/file_explorer_provider.dart';

class FileListItem extends ConsumerWidget {
  final FileItem fileItem;
  final VoidCallback? onTap;

  const FileListItem({
    super.key,
    required this.fileItem,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFavorite = ref.watch(favoritesProvider).contains(fileItem.path);

    return ListTile(
      leading: _buildFileIcon(),
      title: Text(
        fileItem.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${_formatFileSize(fileItem.size)} • ${_formatDate(fileItem.lastModified)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : null,
            ),
            onPressed: () {
              if (isFavorite) {
                ref.read(favoritesProvider.notifier).removeFavorite(fileItem.path);
              } else {
                ref.read(favoritesProvider.notifier).addFavorite(fileItem.path);
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(value, ref, context),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'rename',
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('名前を変更'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Icons.delete, color: Colors.red),
                  title: Text('削除', style: TextStyle(color: Colors.red)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'info',
                child: ListTile(
                  leading: Icon(Icons.info),
                  title: Text('詳細情報'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildFileIcon() {
    IconData iconData;
    Color? iconColor;

    switch (fileItem.type) {
      case FileType.directory:
        iconData = Icons.folder;
        iconColor = Colors.blue;
        break;
      case FileType.image:
        iconData = Icons.image;
        iconColor = Colors.green;
        break;
      case FileType.audio:
        iconData = Icons.audio_file;
        iconColor = Colors.purple;
        break;
      case FileType.video:
        iconData = Icons.video_file;
        iconColor = Colors.red;
        break;
      case FileType.document:
        iconData = Icons.description;
        iconColor = Colors.orange;
        break;
      case FileType.archive:
        iconData = Icons.archive;
        iconColor = Colors.brown;
        break;
      case FileType.unknown:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
        break;
    }

    return Icon(iconData, color: iconColor, size: 40);
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

  void _handleMenuAction(String action, WidgetRef ref, BuildContext context) {
    switch (action) {
      case 'rename':
        _showRenameDialog(context, ref);
        break;
      case 'delete':
        _showDeleteConfirmation(context, ref);
        break;
      case 'info':
        _showFileInfo(context);
        break;
    }
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref) {
    final currentName = fileItem.name;
    String? extension;
    String nameWithoutExtension = currentName;

    // ファイルの場合は拡張子を分離
    if (fileItem.type != FileType.directory && currentName.contains('.')) {
      final lastDotIndex = currentName.lastIndexOf('.');
      extension = currentName.substring(lastDotIndex);
      nameWithoutExtension = currentName.substring(0, lastDotIndex);
    }

    final controller = TextEditingController(text: nameWithoutExtension);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('名前を変更'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'ファイル名',
                suffixText: extension ?? '',
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
              onSubmitted: (_) => _performRename(context, ref, controller.text, extension),
            ),
            if (extension != null) ...[
              const SizedBox(height: 8),
              Text(
                '拡張子: $extension',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => _performRename(context, ref, controller.text, extension),
            child: const Text('変更'),
          ),
        ],
      ),
    );
  }

  void _performRename(BuildContext context, WidgetRef ref, String newName, String? extension) async {
    if (newName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ファイル名を入力してください')),
      );
      return;
    }

    final fullNewName = extension != null ? '$newName$extension' : newName;
    
    if (fullNewName == fileItem.name) {
      Navigator.of(context).pop();
      return;
    }

    try {
      final file = File(fileItem.path);
      final directory = file.parent;
      final newPath = '${directory.path}${Platform.pathSeparator}$fullNewName';
      
      // 新しい名前のファイルが既に存在するかチェック
      if (await File(newPath).exists() || await Directory(newPath).exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('同じ名前のファイルが既に存在します')),
          );
        }
        return;
      }

      // ファイル名変更
      if (fileItem.type == FileType.directory) {
        await Directory(fileItem.path).rename(newPath);
      } else {
        await file.rename(newPath);
      }

      // ファイルリストを更新
      ref.read(fileExplorerProvider.notifier).refresh();
      
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「$fullNewName」に名前を変更しました')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('名前の変更に失敗しました: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('「${fileItem.name}」を削除しますか？\n\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => _performDelete(context, ref),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _performDelete(BuildContext context, WidgetRef ref) async {
    try {
      if (fileItem.type == FileType.directory) {
        await Directory(fileItem.path).delete(recursive: true);
      } else {
        await File(fileItem.path).delete();
      }

      // お気に入りからも削除
      ref.read(favoritesProvider.notifier).removeFavorite(fileItem.path);
      
      // ファイルリストを更新
      ref.read(fileExplorerProvider.notifier).refresh();
      
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('「${fileItem.name}」を削除しました')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }

  void _showFileInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ファイル情報'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('名前', fileItem.name),
            _buildInfoRow('パス', fileItem.path),
            _buildInfoRow('種類', _getTypeString()),
            _buildInfoRow('サイズ', _formatFileSize(fileItem.size)),
            _buildInfoRow('更新日時', _formatDateTime(fileItem.lastModified)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _getTypeString() {
    switch (fileItem.type) {
      case FileType.directory:
        return 'フォルダ';
      case FileType.image:
        return '画像ファイル';
      case FileType.audio:
        return '音声ファイル';
      case FileType.video:
        return '動画ファイル';
      case FileType.document:
        return 'ドキュメント';
      case FileType.archive:
        return 'アーカイブ';
      case FileType.unknown:
        return 'ファイル';
    }
  }

  String _formatDateTime(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}