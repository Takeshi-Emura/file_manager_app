import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:archive/archive.dart';
import 'dart:io';
import 'dart:typed_data';

final archiveViewerProvider = StateNotifierProvider<ArchiveViewerNotifier, ArchiveViewerState>((ref) {
  return ArchiveViewerNotifier();
});

class ArchiveViewerState {
  final List<ArchiveImageFile> imageFiles;
  final int currentIndex;
  final bool isLoading;
  final String? error;

  ArchiveViewerState({
    this.imageFiles = const [],
    this.currentIndex = 0,
    this.isLoading = false,
    this.error,
  });

  ArchiveViewerState copyWith({
    List<ArchiveImageFile>? imageFiles,
    int? currentIndex,
    bool? isLoading,
    String? error,
  }) {
    return ArchiveViewerState(
      imageFiles: imageFiles ?? this.imageFiles,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  ArchiveImageFile? get currentImage => imageFiles.isNotEmpty ? imageFiles[currentIndex] : null;
  bool get hasNext => currentIndex < imageFiles.length - 1;
  bool get hasPrevious => currentIndex > 0;
}

class ArchiveImageFile {
  final String name;
  final Uint8List data;
  final int size;

  ArchiveImageFile({
    required this.name,
    required this.data,
    required this.size,
  });
}

class ArchiveViewerNotifier extends StateNotifier<ArchiveViewerState> {
  ArchiveViewerNotifier() : super(ArchiveViewerState());

  Future<void> loadArchive(String archivePath) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      
      final file = File(archivePath);
      if (!await file.exists()) {
        throw Exception('アーカイブファイルが見つかりません');
      }

      final bytes = await file.readAsBytes();
      Archive? archive;

      // ファイル拡張子に基づいてアーカイブを解凍
      final extension = archivePath.split('.').last.toLowerCase();
      
      try {
        switch (extension) {
          case 'zip':
          case 'cbz':
            archive = ZipDecoder().decodeBytes(bytes);
            break;
          case 'tar':
            archive = TarDecoder().decodeBytes(bytes);
            break;
          case 'gz':
            if (archivePath.toLowerCase().endsWith('.tar.gz')) {
              final gzipBytes = GZipDecoder().decodeBytes(bytes);
              archive = TarDecoder().decodeBytes(gzipBytes);
            } else {
              final gzipBytes = GZipDecoder().decodeBytes(bytes);
              // 単一ファイルのgzipの場合は、そのデータから画像を検出
              await _loadSingleFile(gzipBytes, archivePath);
              return;
            }
            break;
          case 'rar':
            // RARファイルはサポートされていないため、エラーを表示
            throw Exception('RARファイルの展開はサポートされていません。ZIPまたはTAR形式をご利用ください。');
          default:
            throw Exception('サポートされていないアーカイブ形式です: $extension');
        }
      } catch (e) {
        throw Exception('アーカイブの解凍に失敗しました: $e');
      }

      if (archive == null) {
        throw Exception('アーカイブを解凍できませんでした');
      }

      // 画像ファイルを抽出
      final imageFiles = <ArchiveImageFile>[];
      const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];

      for (final file in archive.files) {
        if (!file.isFile) continue;
        
        final fileName = file.name.toLowerCase();
        final hasImageExtension = imageExtensions.any((ext) => fileName.endsWith('.$ext'));
        
        if (hasImageExtension && file.content != null) {
          final data = file.content as List<int>;
          imageFiles.add(ArchiveImageFile(
            name: file.name,
            data: Uint8List.fromList(data),
            size: data.length,
          ));
        }
      }

      if (imageFiles.isEmpty) {
        throw Exception('アーカイブ内に画像ファイルが見つかりませんでした');
      }

      // ファイル名でソート
      imageFiles.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      state = state.copyWith(
        imageFiles: imageFiles,
        currentIndex: 0,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _loadSingleFile(List<int> data, String originalPath) async {
    // 単一ファイルの場合の処理（必要に応じて実装）
    final fileName = originalPath.split(Platform.pathSeparator).last;
    final imageFiles = [
      ArchiveImageFile(
        name: fileName,
        data: Uint8List.fromList(data),
        size: data.length,
      )
    ];

    state = state.copyWith(
      imageFiles: imageFiles,
      currentIndex: 0,
      isLoading: false,
    );
  }

  void goToNext() {
    if (state.hasNext) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  void goToPrevious() {
    if (state.hasPrevious) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
    }
  }

  void goToIndex(int index) {
    if (index >= 0 && index < state.imageFiles.length) {
      state = state.copyWith(currentIndex: index);
    }
  }
}