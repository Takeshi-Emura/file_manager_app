import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../providers/archive_viewer_provider.dart';
import '../providers/viewer_settings_provider.dart';

class ArchiveImageViewerScreen extends ConsumerStatefulWidget {
  final String archivePath;

  const ArchiveImageViewerScreen({
    super.key,
    required this.archivePath,
  });

  @override
  ConsumerState<ArchiveImageViewerScreen> createState() => _ArchiveImageViewerScreenState();
}

class _ArchiveImageViewerScreenState extends ConsumerState<ArchiveImageViewerScreen> {
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(archiveViewerProvider.notifier).loadArchive(widget.archivePath);
    });
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(archiveViewerProvider);
    final fileName = widget.archivePath.split(Platform.pathSeparator).last;

    // Initialize page controller when image list is loaded
    if (state.imageFiles.isNotEmpty && _pageController == null) {
      _pageController = PageController(initialPage: state.currentIndex);
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fileName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
            if (state.imageFiles.isNotEmpty)
              Text(
                '${state.currentIndex + 1} / ${state.imageFiles.length}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettingsDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showArchiveInfo(context),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: _buildBody(state),
    );
  }

  Widget _buildBody(ArchiveViewerState state) {
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'アーカイブを読み込み中...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: const TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(archiveViewerProvider.notifier).loadArchive(widget.archivePath);
              },
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    if (state.imageFiles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              color: Colors.white,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'アーカイブ内に画像が見つかりませんでした',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      );
    }

    return _buildImageGallery(state);
  }

  Widget _buildImageGallery(ArchiveViewerState state) {
    final settings = ref.watch(viewerSettingsProvider);
    _pageController ??= PageController(initialPage: state.currentIndex);

    return GestureDetector(
      onTapUp: (details) {
        final screenWidth = MediaQuery.of(context).size.width;
        final tapPosition = details.localPosition.dx;
        final isLeftSide = tapPosition < screenWidth / 2;
        
        // reverseSwipeDirection設定に基づいてタップの動作を決定
        final shouldGoNext = settings.reverseSwipeDirection ? isLeftSide : !isLeftSide;
        
        if (shouldGoNext) {
          // 次に進む
          if (state.hasNext) {
            ref.read(archiveViewerProvider.notifier).goToNext();
            _pageController?.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        } else {
          // 前に戻る
          if (state.hasPrevious) {
            ref.read(archiveViewerProvider.notifier).goToPrevious();
            _pageController?.previousPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        }
      },
      child: PhotoViewGallery.builder(
        pageController: _pageController,
        itemCount: state.imageFiles.length,
        reverse: settings.reverseSwipeDirection,
        builder: (context, index) {
          final imageFile = state.imageFiles[index];
          
          return PhotoViewGalleryPageOptions(
            imageProvider: MemoryImage(imageFile.data),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4,
            initialScale: PhotoViewComputedScale.contained,
            heroAttributes: PhotoViewHeroAttributes(tag: '${widget.archivePath}_$index'),
            errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
          );
        },
        onPageChanged: (index) {
          ref.read(archiveViewerProvider.notifier).goToIndex(index);
        },
        backgroundDecoration: const BoxDecoration(
          color: Colors.black,
        ),
        loadingBuilder: (context, event) => const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.white,
            size: 64,
          ),
          SizedBox(height: 16),
          Text(
            '画像を読み込めませんでした',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _showArchiveInfo(BuildContext context) {
    final state = ref.read(archiveViewerProvider);
    final fileName = widget.archivePath.split(Platform.pathSeparator).last;
    final file = File(widget.archivePath);
    final stat = file.statSync();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アーカイブ情報'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('ファイル名', fileName),
            _buildInfoRow('パス', widget.archivePath),
            _buildInfoRow('サイズ', _formatFileSize(stat.size)),
            _buildInfoRow('更新日時', _formatDate(stat.modified)),
            if (state.imageFiles.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildInfoRow('画像数', '${state.imageFiles.length}'),
              if (state.currentImage != null) ...[
                _buildInfoRow('現在の画像', state.currentImage!.name),
                _buildInfoRow('画像サイズ', _formatFileSize(state.currentImage!.size)),
              ],
            ],
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
            width: 80,
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
           '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ビューワー設定'),
        content: Consumer(
          builder: (context, ref, child) {
            final settings = ref.watch(viewerSettingsProvider);
            
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('操作方向を反転'),
                  subtitle: Text(
                    settings.reverseSwipeDirection 
                        ? '左スワイプ・左タップで次'
                        : '右スワイプ・右タップで次'
                  ),
                  value: settings.reverseSwipeDirection,
                  onChanged: (value) {
                    ref.read(viewerSettingsProvider.notifier).setReverseSwipeDirection(value);
                  },
                ),
              ],
            );
          },
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
}