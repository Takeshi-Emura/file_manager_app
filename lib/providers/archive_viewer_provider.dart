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
  final String? archivePath;

  ArchiveViewerState({
    this.imageFiles = const [],
    this.currentIndex = 0,
    this.isLoading = false,
    this.error,
    this.archivePath,
  });

  ArchiveViewerState copyWith({
    List<ArchiveImageFile>? imageFiles,
    int? currentIndex,
    bool? isLoading,
    String? error,
    String? archivePath,
  }) {
    return ArchiveViewerState(
      imageFiles: imageFiles ?? this.imageFiles,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      archivePath: archivePath ?? this.archivePath,
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
      state = state.copyWith(
        isLoading: true, 
        error: null,
        archivePath: archivePath,
      );
      
      final file = File(archivePath);
      if (!await file.exists()) {
        throw Exception('アーカイブファイルが見つかりません');
      }

      // ファイル拡張子で判定
      final extension = archivePath.split('.').last.toLowerCase();
      List<ArchiveImageFile> imageFiles = [];

      switch (extension) {
        case 'zip':
        case 'cbz':
          imageFiles = await _loadZipFiles(file);
          break;
        case 'tar':
          imageFiles = await _loadTarFiles(file);
          break;
        case 'gz':
          if (archivePath.toLowerCase().endsWith('.tar.gz')) {
            imageFiles = await _loadTarGzFiles(file);
          } else {
            throw Exception('サポートされていないファイル形式です');
          }
          break;
        default:
          throw Exception('サポートされていないファイル形式です: $extension');
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

  Future<List<ArchiveImageFile>> _loadZipFiles(File file) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    
    final imageFiles = <ArchiveImageFile>[];
    const imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'};

    for (final archiveFile in archive) {
      if (archiveFile.isFile && archiveFile.content != null) {
        final extension = archiveFile.name.split('.').last.toLowerCase();
        if (imageExtensions.contains(extension)) {
          final data = archiveFile.content as List<int>;
          imageFiles.add(ArchiveImageFile(
            name: archiveFile.name,
            data: Uint8List.fromList(data),
            size: data.length,
          ));
        }
      }
    }

    return imageFiles;
  }

  Future<List<ArchiveImageFile>> _loadTarFiles(File file) async {
    final bytes = await file.readAsBytes();
    final archive = TarDecoder().decodeBytes(bytes);
    
    final imageFiles = <ArchiveImageFile>[];
    const imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'};

    for (final archiveFile in archive) {
      if (archiveFile.isFile && archiveFile.content != null) {
        final extension = archiveFile.name.split('.').last.toLowerCase();
        if (imageExtensions.contains(extension)) {
          final data = archiveFile.content as List<int>;
          imageFiles.add(ArchiveImageFile(
            name: archiveFile.name,
            data: Uint8List.fromList(data),
            size: data.length,
          ));
        }
      }
    }

    return imageFiles;
  }

  Future<List<ArchiveImageFile>> _loadTarGzFiles(File file) async {
    final bytes = await file.readAsBytes();
    final gzipBytes = GZipDecoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(gzipBytes);
    
    final imageFiles = <ArchiveImageFile>[];
    const imageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'};

    for (final archiveFile in archive) {
      if (archiveFile.isFile && archiveFile.content != null) {
        final extension = archiveFile.name.split('.').last.toLowerCase();
        if (imageExtensions.contains(extension)) {
          final data = archiveFile.content as List<int>;
          imageFiles.add(ArchiveImageFile(
            name: archiveFile.name,
            data: Uint8List.fromList(data),
            size: data.length,
          ));
        }
      }
    }

    return imageFiles;
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