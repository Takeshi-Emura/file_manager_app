import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:archive/archive.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:isolate';

final archiveViewerProvider = StateNotifierProvider<ArchiveViewerNotifier, ArchiveViewerState>((ref) {
  return ArchiveViewerNotifier();
});

class ArchiveViewerState {
  final List<ArchiveImageInfo> imageInfos;
  final Map<int, Uint8List> imageCache;
  final int currentIndex;
  final bool isLoading;
  final String? error;
  final String? archivePath;

  ArchiveViewerState({
    this.imageInfos = const [],
    this.imageCache = const {},
    this.currentIndex = 0,
    this.isLoading = false,
    this.error,
    this.archivePath,
  });

  ArchiveViewerState copyWith({
    List<ArchiveImageInfo>? imageInfos,
    Map<int, Uint8List>? imageCache,
    int? currentIndex,
    bool? isLoading,
    String? error,
    String? archivePath,
  }) {
    return ArchiveViewerState(
      imageInfos: imageInfos ?? this.imageInfos,
      imageCache: imageCache ?? this.imageCache,
      currentIndex: currentIndex ?? this.currentIndex,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      archivePath: archivePath ?? this.archivePath,
    );
  }

  ArchiveImageInfo? get currentImage => imageInfos.isNotEmpty ? imageInfos[currentIndex] : null;
  bool get hasNext => currentIndex < imageInfos.length - 1;
  bool get hasPrevious => currentIndex > 0;
  
  // 後方互換性のため
  List<ArchiveImageFile> get imageFiles => imageInfos.map((info) {
    final data = imageCache[imageInfos.indexOf(info)] ?? Uint8List(0);
    return ArchiveImageFile(
      name: info.name,
      data: data,
      size: info.size,
    );
  }).toList();
}

class ArchiveImageInfo {
  final String name;
  final int size;
  final int offsetInArchive;

  ArchiveImageInfo({
    required this.name,
    required this.size,
    required this.offsetInArchive,
  });
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
  static const int maxCacheSize = 10; // 最大10枚の画像をメモリにキャッシュ
  
  ArchiveViewerNotifier() : super(ArchiveViewerState());

  Future<void> loadArchive(String archivePath) async {
    try {
      state = state.copyWith(
        isLoading: true, 
        error: null,
        archivePath: archivePath,
        imageCache: {},
      );
      
      final file = File(archivePath);
      if (!await file.exists()) {
        throw Exception('アーカイブファイルが見つかりません');
      }

      // ファイルサイズをチェック
      final fileSize = await file.length();
      if (fileSize > 500 * 1024 * 1024) { // 500MB以上の場合は警告
        print('大きなアーカイブファイルです。読み込みに時間がかかる場合があります。');
      }

      final imageInfos = await _extractImageInfos(archivePath);
      
      if (imageInfos.isEmpty) {
        throw Exception('アーカイブ内に画像ファイルが見つかりませんでした');
      }

      // 最初の画像を読み込み
      final firstImageData = await _loadImageData(archivePath, imageInfos[0]);
      final initialCache = <int, Uint8List>{0: firstImageData};

      state = state.copyWith(
        imageInfos: imageInfos,
        imageCache: initialCache,
        currentIndex: 0,
        isLoading: false,
      );

      // 前後の画像を先読み
      _preloadAdjacentImages(0);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<List<ArchiveImageInfo>> _extractImageInfos(String archivePath) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(_extractImageInfosIsolate, {
      'sendPort': receivePort.sendPort,
      'archivePath': archivePath,
    });

    final result = await receivePort.first;
    isolate.kill();

    if (result['error'] != null) {
      throw Exception(result['error']);
    }

    return (result['imageInfos'] as List)
        .map((info) => ArchiveImageInfo(
              name: info['name'],
              size: info['size'],
              offsetInArchive: info['offsetInArchive'],
            ))
        .toList();
  }

  static void _extractImageInfosIsolate(Map<String, dynamic> params) async {
    final sendPort = params['sendPort'] as SendPort;
    final archivePath = params['archivePath'] as String;

    try {
      final extension = archivePath.split('.').last.toLowerCase();
      List<Map<String, dynamic>> imageInfos = [];

      switch (extension) {
        case 'zip':
        case 'cbz':
          imageInfos = await _extractZipImageInfos(archivePath);
          break;
        case 'tar':
        case 'gz':
          // TARファイルは先頭から順次読む必要があるため、小さいサイズでのみ処理
          final file = File(archivePath);
          final fileSize = await file.length();
          if (fileSize > 100 * 1024 * 1024) { // 100MB超える場合はエラー
            throw Exception('TARファイルが大きすぎます。ZIPファイルを使用してください。');
          }
          imageInfos = await _extractTarImageInfos(archivePath);
          break;
        default:
          throw Exception('サポートされていないアーカイブ形式です: $extension');
      }

      // ファイル名でソート
      imageInfos.sort((a, b) => 
          (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));

      sendPort.send({
        'imageInfos': imageInfos,
        'error': null,
      });
    } catch (e) {
      sendPort.send({
        'imageInfos': null,
        'error': e.toString(),
      });
    }
  }

  static Future<List<Map<String, dynamic>>> _extractZipImageInfos(String archivePath) async {
    final imageInfos = <Map<String, dynamic>>[];
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    
    final file = File(archivePath);
    final randomAccessFile = await file.open();
    
    try {
      // ZIPファイルの中央ディレクトリを読み込む
      final fileSize = await randomAccessFile.length();
      
      // End of Central Directory Record (EOCD) を探す
      const eocdSize = 22;
      final searchStart = fileSize > 65557 ? fileSize - 65557 : 0;
      await randomAccessFile.setPosition(searchStart);
      
      final searchData = await randomAccessFile.read((fileSize - searchStart).toInt());
      int eocdPos = -1;
      
      // EOCD signature (0x06054b50) を逆順で探す
      for (int i = searchData.length - eocdSize; i >= 0; i--) {
        if (
            searchData[i] == 0x50 && searchData[i + 1] == 0x4b && 
            searchData[i + 2] == 0x05 && searchData[i + 3] == 0x06) {
          eocdPos = searchStart + i;
          break;
        }
      }
      
      if (eocdPos == -1) {
        throw Exception('有効なZIPファイルではありません');
      }
      
      // EOCD から中央ディレクトリの情報を読み取る
      await randomAccessFile.setPosition(eocdPos + 16);
      final centralDirSizeBytes = await randomAccessFile.read(4);
      final centralDirSize = _bytesToInt32(centralDirSizeBytes);
      
      final centralDirOffsetBytes = await randomAccessFile.read(4);
      final centralDirOffset = _bytesToInt32(centralDirOffsetBytes);
      
      // 中央ディレクトリを読み込む
      await randomAccessFile.setPosition(centralDirOffset);
      final centralDirData = await randomAccessFile.read(centralDirSize);
      
      int pos = 0;
      while (pos < centralDirData.length - 46) {
        // Central Directory File Header signature をチェック
        if (_bytesToInt32(centralDirData.sublist(pos, pos + 4)) != 0x02014b50) {
          break;
        }
        
        final compressedSize = _bytesToInt32(centralDirData.sublist(pos + 20, pos + 24));
        final uncompressedSize = _bytesToInt32(centralDirData.sublist(pos + 24, pos + 28));
        final fileNameLength = _bytesToInt16(centralDirData.sublist(pos + 28, pos + 30));
        final extraFieldLength = _bytesToInt16(centralDirData.sublist(pos + 30, pos + 32));
        final fileCommentLength = _bytesToInt16(centralDirData.sublist(pos + 32, pos + 34));
        final localHeaderOffset = _bytesToInt32(centralDirData.sublist(pos + 42, pos + 46));
        
        if (pos + 46 + fileNameLength > centralDirData.length) break;
        
        final fileName = String.fromCharCodes(centralDirData.sublist(pos + 46, pos + 46 + fileNameLength));
        final fileNameLower = fileName.toLowerCase();
        
        // ディレクトリかどうかチェック（最後が/で終わる）
        if (!fileName.endsWith('/')) {
          final hasImageExtension = imageExtensions.any((ext) => fileNameLower.endsWith('.$ext'));
          
          if (hasImageExtension) {
            imageInfos.add({
              'name': fileName,
              'size': uncompressedSize,
              'offsetInArchive': localHeaderOffset,
              'compressedSize': compressedSize,
            });
          }
        }
        
        pos += 46 + fileNameLength + extraFieldLength + fileCommentLength;
      }
      
    } finally {
      await randomAccessFile.close();
    }
    
    return imageInfos;
  }

  static Future<List<Map<String, dynamic>>> _extractTarImageInfos(String archivePath) async {
    final imageInfos = <Map<String, dynamic>>[];
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
    
    final file = File(archivePath);
    final bytes = await file.readAsBytes(); // TARは全読み込み（小さいファイルのみ）
    
    Archive? archive;
    final extension = archivePath.split('.').last.toLowerCase();
    
    if (extension == 'gz' && archivePath.toLowerCase().endsWith('.tar.gz')) {
      final gzipBytes = GZipDecoder().decodeBytes(bytes);
      archive = TarDecoder().decodeBytes(gzipBytes);
    } else if (extension == 'tar') {
      archive = TarDecoder().decodeBytes(bytes);
    }
    
    if (archive != null) {
      int offset = 0;
      for (final file in archive.files) {
        if (!file.isFile) continue;
        
        final fileName = file.name.toLowerCase();
        final hasImageExtension = imageExtensions.any((ext) => fileName.endsWith('.$ext'));
        
        if (hasImageExtension && file.content != null) {
          imageInfos.add({
            'name': file.name,
            'size': file.size,
            'offsetInArchive': offset,
          });
        }
        offset++;
      }
    }
    
    return imageInfos;
  }

  static int _bytesToInt32(List<int> bytes) {
    return bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
  }

  static int _bytesToInt16(List<int> bytes) {
    return bytes[0] | (bytes[1] << 8);
  }

  Future<Uint8List> _loadImageData(String archivePath, ArchiveImageInfo imageInfo) async {
    final receivePort = ReceivePort();
    final isolate = await Isolate.spawn(_loadImageDataIsolate, {
      'sendPort': receivePort.sendPort,
      'archivePath': archivePath,
      'imageName': imageInfo.name,
    });

    final result = await receivePort.first;
    isolate.kill();

    if (result['error'] != null) {
      throw Exception(result['error']);
    }

    return result['data'] as Uint8List;
  }

  static void _loadImageDataIsolate(Map<String, dynamic> params) async {
    final sendPort = params['sendPort'] as SendPort;
    final archivePath = params['archivePath'] as String;
    final imageName = params['imageName'] as String;

    try {
      final extension = archivePath.split('.').last.toLowerCase();
      Uint8List? imageData;

      switch (extension) {
        case 'zip':
        case 'cbz':
          imageData = await _loadZipImageData(archivePath, imageName);
          break;
        case 'tar':
        case 'gz':
          imageData = await _loadTarImageData(archivePath, imageName);
          break;
        default:
          throw Exception('サポートされていないアーカイブ形式です: $extension');
      }

      if (imageData != null) {
        sendPort.send({
          'data': imageData,
          'error': null,
        });
      } else {
        sendPort.send({
          'data': null,
          'error': '画像が見つかりませんでした: $imageName',
        });
      }
    } catch (e) {
      sendPort.send({
        'data': null,
        'error': e.toString(),
      });
    }
  }

  static Future<Uint8List?> _loadZipImageData(String archivePath, String imageName) async {
    final file = File(archivePath);
    final randomAccessFile = await file.open();
    
    try {
      // ZIPファイルの中央ディレクトリから画像ファイルの情報を取得
      final fileSize = await randomAccessFile.length();
      
      // End of Central Directory Record (EOCD) を探す
      const eocdSize = 22;
      final searchStart = fileSize > 65557 ? fileSize - 65557 : 0;
      await randomAccessFile.setPosition(searchStart);
      
      final searchData = await randomAccessFile.read((fileSize - searchStart).toInt());
      int eocdPos = -1;
      
      for (int i = searchData.length - eocdSize; i >= 0; i--) {
        if (
            searchData[i] == 0x50 && searchData[i + 1] == 0x4b && 
            searchData[i + 2] == 0x05 && searchData[i + 3] == 0x06) {
          eocdPos = searchStart + i;
          break;
        }
      }
      
      if (eocdPos == -1) return null;
      
      // 中央ディレクトリの情報を読み取る
      await randomAccessFile.setPosition(eocdPos + 16);
      final centralDirSizeBytes = await randomAccessFile.read(4);
      final centralDirSize = _bytesToInt32(centralDirSizeBytes);
      
      final centralDirOffsetBytes = await randomAccessFile.read(4);
      final centralDirOffset = _bytesToInt32(centralDirOffsetBytes);
      
      // 中央ディレクトリを読み込む
      await randomAccessFile.setPosition(centralDirOffset);
      final centralDirData = await randomAccessFile.read(centralDirSize);
      
      // 指定された画像ファイルを探す
      int pos = 0;
      while (pos < centralDirData.length - 46) {
        if (_bytesToInt32(centralDirData.sublist(pos, pos + 4)) != 0x02014b50) {
          break;
        }
        
        final compressedSize = _bytesToInt32(centralDirData.sublist(pos + 20, pos + 24));
        final uncompressedSize = _bytesToInt32(centralDirData.sublist(pos + 24, pos + 28));
        final fileNameLength = _bytesToInt16(centralDirData.sublist(pos + 28, pos + 30));
        final extraFieldLength = _bytesToInt16(centralDirData.sublist(pos + 30, pos + 32));
        final fileCommentLength = _bytesToInt16(centralDirData.sublist(pos + 32, pos + 34));
        final localHeaderOffset = _bytesToInt32(centralDirData.sublist(pos + 42, pos + 46));
        final compressionMethod = _bytesToInt16(centralDirData.sublist(pos + 10, pos + 12));
        
        if (pos + 46 + fileNameLength > centralDirData.length) break;
        
        final fileName = String.fromCharCodes(centralDirData.sublist(pos + 46, pos + 46 + fileNameLength));
        
        if (fileName == imageName) {
          // ローカルファイルヘッダーを読み込む
          await randomAccessFile.setPosition(localHeaderOffset);
          final localHeaderData = await randomAccessFile.read(30);
          
          if (_bytesToInt32(localHeaderData.sublist(0, 4)) != 0x04034b50) {
            throw Exception('無効なローカルファイルヘッダー');
          }
          
          final localFileNameLength = _bytesToInt16(localHeaderData.sublist(26, 28));
          final localExtraFieldLength = _bytesToInt16(localHeaderData.sublist(28, 30));
          
          // ファイルデータの開始位置
          final dataOffset = localHeaderOffset + 30 + localFileNameLength + localExtraFieldLength;
          
          // 圧縮されたデータを読み込む
          await randomAccessFile.setPosition(dataOffset);
          final compressedData = await randomAccessFile.read(compressedSize);
          
          // データを展開
          if (compressionMethod == 0) {
            // 無圧縮
            return Uint8List.fromList(compressedData);
          } else if (compressionMethod == 8) {
            // Deflate圧縮
            final inflater = Inflate(compressedData);
            final decompressedData = inflater.getBytes();
            return Uint8List.fromList(decompressedData);
          } else {
            throw Exception('サポートされていない圧縮方式: $compressionMethod');
          }
        }
        
        pos += 46 + fileNameLength + extraFieldLength + fileCommentLength;
      }
      
    } finally {
      await randomAccessFile.close();
    }
    
    return null;
  }

  static Future<Uint8List?> _loadTarImageData(String archivePath, String imageName) async {
    // TARファイルは全読み込みが必要（構造上の制限）
    final file = File(archivePath);
    final bytes = await file.readAsBytes();
    
    Archive? archive;
    final extension = archivePath.split('.').last.toLowerCase();
    
    if (extension == 'gz' && archivePath.toLowerCase().endsWith('.tar.gz')) {
      final gzipBytes = GZipDecoder().decodeBytes(bytes);
      archive = TarDecoder().decodeBytes(gzipBytes);
    } else if (extension == 'tar') {
      archive = TarDecoder().decodeBytes(bytes);
    }
    
    if (archive != null) {
      for (final file in archive.files) {
        if (file.name == imageName && file.content != null) {
          final data = file.content as List<int>;
          return Uint8List.fromList(data);
        }
      }
    }
    
    return null;
  }

  void _preloadAdjacentImages(int currentIndex) {
    // 現在の画像の前後2枚ずつを先読み
    final indicesToPreload = <int>[];
    for (int i = currentIndex - 2; i <= currentIndex + 2; i++) {
      if (i >= 0 && i < state.imageInfos.length && i != currentIndex) {
        indicesToPreload.add(i);
      }
    }

    for (final index in indicesToPreload) {
      if (!state.imageCache.containsKey(index)) {
        _loadImageAsync(index);
      }
    }

    // キャッシュサイズを制限
    _limitCacheSize();
  }

  void _loadImageAsync(int index) async {
    if (index < 0 || index >= state.imageInfos.length) return;
    if (state.imageCache.containsKey(index)) return;

    try {
      final imageInfo = state.imageInfos[index];
      final imageData = await _loadImageData(state.archivePath!, imageInfo);
      
      final newCache = Map<int, Uint8List>.from(state.imageCache);
      newCache[index] = imageData;
      
      state = state.copyWith(imageCache: newCache);
    } catch (e) {
      print('画像の先読みに失敗しました: $e');
    }
  }

  void _limitCacheSize() {
    if (state.imageCache.length <= maxCacheSize) return;

    final newCache = Map<int, Uint8List>.from(state.imageCache);
    final currentIndex = state.currentIndex;
    
    // 現在の画像から遠いものから削除
    final sortedKeys = newCache.keys.toList()
      ..sort((a, b) => (a - currentIndex).abs().compareTo((b - currentIndex).abs()));
    
    while (newCache.length > maxCacheSize) {
      final keyToRemove = sortedKeys.removeLast();
      newCache.remove(keyToRemove);
    }

    state = state.copyWith(imageCache: newCache);
  }

  Future<void> goToNext() async {
    if (state.hasNext) {
      final newIndex = state.currentIndex + 1;
      await _ensureImageLoaded(newIndex);
      state = state.copyWith(currentIndex: newIndex);
      _preloadAdjacentImages(newIndex);
    }
  }

  Future<void> goToPrevious() async {
    if (state.hasPrevious) {
      final newIndex = state.currentIndex - 1;
      await _ensureImageLoaded(newIndex);
      state = state.copyWith(currentIndex: newIndex);
      _preloadAdjacentImages(newIndex);
    }
  }

  Future<void> goToIndex(int index) async {
    if (index >= 0 && index < state.imageInfos.length) {
      await _ensureImageLoaded(index);
      state = state.copyWith(currentIndex: index);
      _preloadAdjacentImages(index);
    }
  }

  Future<void> _ensureImageLoaded(int index) async {
    if (!state.imageCache.containsKey(index)) {
      final imageInfo = state.imageInfos[index];
      final imageData = await _loadImageData(state.archivePath!, imageInfo);
      
      final newCache = Map<int, Uint8List>.from(state.imageCache);
      newCache[index] = imageData;
      state = state.copyWith(imageCache: newCache);
    }
  }

  Future<void> _loadSingleFile(List<int> data, String originalPath) async {
    final fileName = originalPath.split(Platform.pathSeparator).last;
    final imageInfo = ArchiveImageInfo(
      name: fileName,
      size: data.length,
      offsetInArchive: 0,
    );

    state = state.copyWith(
      imageInfos: [imageInfo],
      imageCache: {0: Uint8List.fromList(data)},
      currentIndex: 0,
      isLoading: false,
      archivePath: originalPath,
    );
  }
}