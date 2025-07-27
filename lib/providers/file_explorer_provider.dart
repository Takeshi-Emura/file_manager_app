import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/file_item.dart';

final fileExplorerProvider = StateNotifierProvider<FileExplorerNotifier, FileExplorerState>((ref) {
  return FileExplorerNotifier();
});

final favoritesProvider = StateNotifierProvider<FavoritesNotifier, List<String>>((ref) {
  return FavoritesNotifier();
});

class FileExplorerState {
  final String currentPath;
  final List<FileItem> files;
  final bool isLoading;
  final String? error;

  FileExplorerState({
    required this.currentPath,
    required this.files,
    this.isLoading = false,
    this.error,
  });

  FileExplorerState copyWith({
    String? currentPath,
    List<FileItem>? files,
    bool? isLoading,
    String? error,
  }) {
    return FileExplorerState(
      currentPath: currentPath ?? this.currentPath,
      files: files ?? this.files,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class FileExplorerNotifier extends StateNotifier<FileExplorerState> {
  FileExplorerNotifier() : super(FileExplorerState(currentPath: '', files: [])) {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Always try to initialize, even if permissions are not granted
      await _requestPermissions();
      
      // Try different directory paths in order of preference
      String? targetPath;
      
      // 1. Try Android standard Documents folder (highest priority)
      if (Platform.isAndroid) {
        const documentsPath = '/storage/emulated/0/Documents';
        final documentsDir = Directory(documentsPath);
        try {
          if (await documentsDir.exists()) {
            // Try to list contents to verify access
            await documentsDir.list(followLinks: false).take(1).toList();
            targetPath = documentsPath;
          }
        } catch (e) {
          // Access denied, continue to next option
        }
      }
      
      // 2. Try external storage directory (app-specific)
      if (targetPath == null) {
        try {
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null && await externalDir.exists()) {
            targetPath = externalDir.path;
          }
        } catch (e) {
          // Continue to next option
        }
      }
      
      // 3. Try application documents directory
      if (targetPath == null) {
        try {
          final appDocDir = await getApplicationDocumentsDirectory();
          if (await appDocDir.exists()) {
            targetPath = appDocDir.path;
          }
        } catch (e) {
          // Continue to next option
        }
      }
      
      // 4. Use internal app directory as fallback
      if (targetPath == null) {
        try {
          final appSupportDir = await getApplicationSupportDirectory();
          if (await appSupportDir.exists()) {
            targetPath = appSupportDir.path;
          }
        } catch (e) {
          // Final fallback will be handled below
        }
      }
      
      if (targetPath != null) {
        await navigateToPath(targetPath);
      } else {
        // Create a demo directory with some sample folders
        await _createDemoStructure();
      }
    } catch (e) {
      // If all else fails, create demo structure
      await _createDemoStructure();
    }
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API level 33+), try different permission strategies
      try {
        // Check current permissions
        final storageStatus = await Permission.storage.status;
        final manageExternalStatus = await Permission.manageExternalStorage.status;
        final mediaLibraryStatus = await Permission.mediaLibrary.status;
        
        // If any permission is already granted, return true
        if (storageStatus.isGranted || 
            manageExternalStatus.isGranted || 
            mediaLibraryStatus.isGranted) {
          return true;
        }
        
        // Try to request storage permission first (works for older Android versions)
        final storageResult = await Permission.storage.request();
        if (storageResult.isGranted) {
          return true;
        }
        
        // For newer Android versions, try media library permission
        final mediaResult = await Permission.mediaLibrary.request();
        if (mediaResult.isGranted) {
          return true;
        }
        
        // If basic permissions failed, try manage external storage (requires special intent)
        final manageResult = await Permission.manageExternalStorage.request();
        if (manageResult.isGranted) {
          return true;
        }
        
        // If all permissions denied, we can still try to access app-specific directories
        return false;
      } catch (e) {
        // If permission request fails, try to continue without permissions
        return false;
      }
    }
    
    // For other platforms, assume permission is granted
    return true;
  }

  Future<void> _createDemoStructure() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final demoDir = Directory('${appDir.path}/デモフォルダ');
      
      if (!await demoDir.exists()) {
        await demoDir.create(recursive: true);
        
        // Create some sample folders
        await Directory('${demoDir.path}/画像').create();
        await Directory('${demoDir.path}/音楽').create();
        await Directory('${demoDir.path}/ドキュメント').create();
        
        // Create sample files
        await File('${demoDir.path}/sample.txt').writeAsString('サンプルテキストファイル');
        await File('${demoDir.path}/readme.md').writeAsString('# デモファイルマネージャー\n\nこれはサンプルファイルです。');
      }
      
      await navigateToPath(demoDir.path);
    } catch (e) {
      state = state.copyWith(error: 'デモ構造の作成に失敗しました: $e');
    }
  }

  Future<void> navigateToPath(String path) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final directory = Directory(path);
      if (!await directory.exists()) {
        state = state.copyWith(
          isLoading: false,
          error: 'フォルダが存在しません',
        );
        return;
      }

      final entities = await directory.list().toList();
      final files = entities
          .map((entity) => FileItem.fromFileSystemEntity(entity))
          .toList();
      
      files.sort((a, b) {
        if (a.type == FileType.directory && b.type != FileType.directory) {
          return -1;
        } else if (a.type != FileType.directory && b.type == FileType.directory) {
          return 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      state = state.copyWith(
        currentPath: path,
        files: files,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'フォルダを開けませんでした: $e',
      );
    }
  }

  Future<void> navigateUp() async {
    if (state.currentPath.isEmpty) return;
    
    final parentPath = Directory(state.currentPath).parent.path;
    await navigateToPath(parentPath);
  }

  void refresh() {
    navigateToPath(state.currentPath);
  }

  Future<bool> createFolder(String folderName) async {
    try {
      if (state.currentPath.isEmpty) {
        state = state.copyWith(error: 'フォルダのパスが指定されていません');
        return false;
      }

      if (folderName.trim().isEmpty) {
        state = state.copyWith(error: 'フォルダ名を入力してください');
        return false;
      }

      if (folderName.contains('/') || folderName.contains('\\') || 
          folderName.contains(':') || folderName.contains('*') ||
          folderName.contains('?') || folderName.contains('"') ||
          folderName.contains('<') || folderName.contains('>') ||
          folderName.contains('|')) {
        state = state.copyWith(error: '無効な文字が含まれています');
        return false;
      }

      final newFolderPath = '${state.currentPath}/$folderName';
      final directory = Directory(newFolderPath);
      
      if (await directory.exists()) {
        state = state.copyWith(error: '同名のフォルダが既に存在しています');
        return false;
      }

      final currentDir = Directory(state.currentPath);
      if (!await currentDir.exists()) {
        state = state.copyWith(error: '現在のフォルダが存在しません');
        return false;
      }

      await directory.create(recursive: true);
      
      refresh();
      return true;
    } catch (e) {
      if (e.toString().contains('Permission denied')) {
        state = state.copyWith(error: 'フォルダ作成の権限がありません');
      } else if (e.toString().contains('No space left')) {
        state = state.copyWith(error: 'ストレージの容量が不足しています');
      } else {
        state = state.copyWith(error: 'フォルダの作成に失敗しました: ${e.toString()}');
      }
      return false;
    }
  }
}

class FavoritesNotifier extends StateNotifier<List<String>> {
  FavoritesNotifier() : super([]);

  void addFavorite(String path) {
    if (!state.contains(path)) {
      state = [...state, path];
    }
  }

  void removeFavorite(String path) {
    state = state.where((item) => item != path).toList();
  }

  bool isFavorite(String path) {
    return state.contains(path);
  }
}