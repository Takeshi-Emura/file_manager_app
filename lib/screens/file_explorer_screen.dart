import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/file_explorer_provider.dart';
import '../widgets/file_list_item.dart';
import '../widgets/file_grid_item.dart';
import '../providers/view_mode_provider.dart';
import '../models/file_item.dart';
import 'image_viewer_screen.dart';
import 'audio_player_screen.dart';
import 'video_player_screen.dart';
import 'archive_image_viewer_screen.dart';

class FileExplorerScreen extends ConsumerWidget {
  const FileExplorerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fileExplorerProvider);
    
    return PopScope(
      canPop: !state.canGoBack,
      onPopInvoked: (didPop) async {
        if (!didPop && state.canGoBack) {
          await ref.read(fileExplorerProvider.notifier).goBack();
        }
      },
      child: GestureDetector(
        onPanEnd: (details) {
          if (details.velocity.pixelsPerSecond.dx > 200 && state.canGoBack) {
            ref.read(fileExplorerProvider.notifier).goBack();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('ファイルマネージャー'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            leading: state.canGoBack
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      ref.read(fileExplorerProvider.notifier).goBack();
                    },
                  )
                : null,
            actions: [
              Consumer(
                builder: (context, ref, child) {
                  final isGridView = ref.watch(viewModeProvider);
                  return IconButton(
                    icon: Icon(isGridView ? Icons.view_list : Icons.grid_view),
                    onPressed: () {
                      ref.read(viewModeProvider.notifier).toggleViewMode();
                    },
                    tooltip: isGridView ? 'リスト表示' : 'グリッド表示',
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.create_new_folder),
                onPressed: () => _showCreateFolderDialog(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  ref.read(fileExplorerProvider.notifier).refresh();
                },
              ),
            ],
          ),
          body: Column(
            children: [
              _buildPathBar(context, ref, state),
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final isGridView = ref.watch(viewModeProvider);
                    return isGridView
                        ? _buildFileGrid(context, ref, state)
                        : _buildFileList(context, ref, state);
                  },
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () {
              ref.read(fileExplorerProvider.notifier).navigateUp();
            },
            tooltip: '上の階層へ',
            child: const Icon(Icons.arrow_upward),
          ),
        ),
      ),
    );
  }

  Widget _buildPathBar(BuildContext context, WidgetRef ref, FileExplorerState state) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Row(
        children: [
          if (state.canGoBack)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20),
              onPressed: () {
                ref.read(fileExplorerProvider.notifier).goBack();
              },
              tooltip: '前の階層に戻る',
            ),
          const Icon(Icons.folder),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              state.currentPath.isEmpty ? 'ルート' : state.currentPath,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(BuildContext context, WidgetRef ref, FileExplorerState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(fileExplorerProvider.notifier).refresh();
              },
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    if (state.files.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('このフォルダは空です'),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: state.files.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final fileItem = state.files[index];
        return FileListItem(
          fileItem: fileItem,
          onTap: () => _handleFileTap(context, ref, fileItem),
        );
      },
    );
  }

  Widget _buildFileGrid(BuildContext context, WidgetRef ref, FileExplorerState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(fileExplorerProvider.notifier).refresh();
              },
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    if (state.files.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('このフォルダは空です'),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
        childAspectRatio: 1.0,
      ),
      itemCount: state.files.length,
      itemBuilder: (context, index) {
        final fileItem = state.files[index];
        return FileGridItem(
          fileItem: fileItem,
          onTap: () => _handleFileTap(context, ref, fileItem),
        );
      },
    );
  }

  void _handleFileTap(BuildContext context, WidgetRef ref, FileItem fileItem) {
    if (fileItem.type == FileType.directory) {
      ref.read(fileExplorerProvider.notifier).navigateToPath(fileItem.path);
    } else if (fileItem.type == FileType.image) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(imagePath: fileItem.path),
        ),
      );
    } else if (fileItem.type == FileType.audio) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AudioPlayerScreen(audioPath: fileItem.path),
        ),
      );
    } else if (fileItem.type == FileType.video) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => VideoPlayerScreen(videoPath: fileItem.path),
        ),
      );
    } else if (fileItem.type == FileType.archive) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ArchiveImageViewerScreen(archivePath: fileItem.path),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${fileItem.name} を開くことができません'),
        ),
      );
    }
  }

  void _showCreateFolderDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('新しいフォルダを作成'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'フォルダ名',
              hintText: '新しいフォルダ',
            ),
            autofocus: true,
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                _createFolder(context, ref, value.trim());
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                final folderName = controller.text.trim();
                if (folderName.isNotEmpty) {
                  _createFolder(context, ref, folderName);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('作成'),
            ),
          ],
        );
      },
    );
  }

  void _createFolder(BuildContext context, WidgetRef ref, String folderName) {
    final currentState = ref.read(fileExplorerProvider);
    
    ref.read(fileExplorerProvider.notifier).createFolder(folderName).then((success) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('フォルダ「$folderName」を作成しました'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final newState = ref.read(fileExplorerProvider);
        final errorMessage = newState.error ?? 'フォルダの作成に失敗しました';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }
}