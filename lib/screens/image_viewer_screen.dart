import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import '../providers/image_viewer_provider.dart';
import '../providers/viewer_settings_provider.dart';

class ImageViewerScreen extends ConsumerStatefulWidget {
  final String imagePath;

  const ImageViewerScreen({
    super.key,
    required this.imagePath,
  });

  @override
  ConsumerState<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends ConsumerState<ImageViewerScreen> {
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(imageViewerProvider.notifier).loadImagesFromFolder(widget.imagePath);
    });
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageViewerProvider);
    final currentImagePath = state.currentImage ?? widget.imagePath;
    final fileName = currentImagePath.split(Platform.pathSeparator).last;

    // Initialize page controller when image list is loaded
    if (state.imageList.isNotEmpty && _pageController == null) {
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
            if (state.imageList.length > 1)
              Text(
                '${state.currentIndex + 1} / ${state.imageList.length}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (state.imageList.length > 1)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _showSettingsDialog(context),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showImageInfo(context, currentImagePath),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: state.imageList.isEmpty
          ? _buildSingleImageView(widget.imagePath)
          : _buildImageGallery(state),
    );
  }

  Widget _buildSingleImageView(String imagePath) {
    return PhotoView(
      imageProvider: FileImage(File(imagePath)),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4,
      initialScale: PhotoViewComputedScale.contained,
      backgroundDecoration: const BoxDecoration(
        color: Colors.black,
      ),
      loadingBuilder: (context, event) => const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      ),
      errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
    );
  }

  Widget _buildImageGallery(ImageViewerState state) {
    if (state.imageList.isEmpty) {
      return _buildSingleImageView(widget.imagePath);
    }

    final settings = ref.watch(viewerSettingsProvider);
    _pageController ??= PageController(initialPage: state.currentIndex);

    return PhotoViewGallery.builder(
      pageController: _pageController,
      itemCount: state.imageList.length,
      reverse: settings.reverseSwipeDirection,
      builder: (context, index) {
        return PhotoViewGalleryPageOptions(
          imageProvider: FileImage(File(state.imageList[index])),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 4,
          initialScale: PhotoViewComputedScale.contained,
          heroAttributes: PhotoViewHeroAttributes(tag: state.imageList[index]),
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        );
      },
      onPageChanged: (index) {
        ref.read(imageViewerProvider.notifier).goToIndex(index);
      },
      backgroundDecoration: const BoxDecoration(
        color: Colors.black,
      ),
      loadingBuilder: (context, event) => const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
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

  void _showImageInfo(BuildContext context, String imagePath) {
    final state = ref.read(imageViewerProvider);
    final file = File(imagePath);
    final stat = file.statSync();
    final fileName = imagePath.split(Platform.pathSeparator).last;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('画像情報'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('ファイル名', fileName),
            _buildInfoRow('パス', imagePath),
            _buildInfoRow('サイズ', _formatFileSize(stat.size)),
            _buildInfoRow('更新日時', _formatDate(stat.modified)),
            if (state.imageList.length > 1) ...[
              const SizedBox(height: 8),
              _buildInfoRow('画像', '${state.currentIndex + 1} / ${state.imageList.length}'),
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
                  title: const Text('スワイプ方向を反転'),
                  subtitle: Text(
                    settings.reverseSwipeDirection 
                        ? '左スワイプで次の画像へ'
                        : '右スワイプで次の画像へ'
                  ),
                  value: settings.reverseSwipeDirection,
                  onChanged: (value) {
                    ref.read(viewerSettingsProvider.notifier).setReverseSwipeDirection(value);
                  },
                ),
                const SizedBox(height: 16),
                const Text(
                  'スワイプ方向説明:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  settings.reverseSwipeDirection
                      ? '• 左にスワイプ → 次の画像\n• 右にスワイプ → 前の画像'
                      : '• 右にスワイプ → 次の画像\n• 左にスワイプ → 前の画像',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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