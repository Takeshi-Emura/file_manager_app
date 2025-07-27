import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

final imageViewerProvider = StateNotifierProvider<ImageViewerNotifier, ImageViewerState>((ref) {
  return ImageViewerNotifier();
});

class ImageViewerState {
  final List<String> imageList;
  final int currentIndex;
  final String? error;

  ImageViewerState({
    this.imageList = const [],
    this.currentIndex = 0,
    this.error,
  });

  ImageViewerState copyWith({
    List<String>? imageList,
    int? currentIndex,
    String? error,
  }) {
    return ImageViewerState(
      imageList: imageList ?? this.imageList,
      currentIndex: currentIndex ?? this.currentIndex,
      error: error,
    );
  }

  String? get currentImage => imageList.isNotEmpty ? imageList[currentIndex] : null;
  bool get hasNext => currentIndex < imageList.length - 1;
  bool get hasPrevious => currentIndex > 0;
}

class ImageViewerNotifier extends StateNotifier<ImageViewerState> {
  ImageViewerNotifier() : super(ImageViewerState());

  Future<void> loadImagesFromFolder(String imagePath) async {
    try {
      final file = File(imagePath);
      final directory = file.parent;
      
      const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
      
      final entities = await directory.list().toList();
      final imageFiles = entities
          .whereType<File>()
          .where((file) {
            final extension = file.path.split('.').last.toLowerCase();
            return imageExtensions.contains(extension);
          })
          .map((file) => file.path)
          .toList();
      
      // Sort files alphabetically
      imageFiles.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      
      // Find current file index
      final currentIndex = imageFiles.indexOf(imagePath);
      
      state = state.copyWith(
        imageList: imageFiles,
        currentIndex: currentIndex >= 0 ? currentIndex : 0,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        imageList: [imagePath],
        currentIndex: 0,
        error: null,
      );
    }
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
    if (index >= 0 && index < state.imageList.length) {
      state = state.copyWith(currentIndex: index);
    }
  }
}