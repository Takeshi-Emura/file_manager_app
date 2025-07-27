import 'dart:io';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'file_item.freezed.dart';
part 'file_item.g.dart';

@freezed
class FileItem with _$FileItem {
  const factory FileItem({
    required String name,
    required String path,
    required FileType type,
    required int size,
    required DateTime lastModified,
    @Default(false) bool isFavorite,
  }) = _FileItem;

  factory FileItem.fromJson(Map<String, dynamic> json) => _$FileItemFromJson(json);
  
  factory FileItem.fromFileSystemEntity(FileSystemEntity entity) {
    final stat = entity.statSync();
    final name = entity.path.split(Platform.pathSeparator).last;
    
    FileType type;
    if (entity is Directory) {
      type = FileType.directory;
    } else if (entity is File) {
      final extension = name.split('.').last.toLowerCase();
      type = _getFileTypeFromExtension(extension);
    } else {
      type = FileType.unknown;
    }
    
    return FileItem(
      name: name,
      path: entity.path,
      type: type,
      size: stat.size,
      lastModified: stat.modified,
    );
  }
}

enum FileType {
  directory,
  image,
  audio,
  video,
  document,
  archive,
  unknown,
}

FileType _getFileTypeFromExtension(String extension) {
  const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'];
  const audioExtensions = ['mp3', 'wav', 'flac', 'aac', 'm4a', 'ogg'];
  const videoExtensions = ['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv'];
  const documentExtensions = ['pdf', 'doc', 'docx', 'txt', 'rtf'];
  const archiveExtensions = ['zip', 'rar', '7z', 'tar', 'gz', 'cbz'];
  
  if (imageExtensions.contains(extension)) return FileType.image;
  if (audioExtensions.contains(extension)) return FileType.audio;
  if (videoExtensions.contains(extension)) return FileType.video;
  if (documentExtensions.contains(extension)) return FileType.document;
  if (archiveExtensions.contains(extension)) return FileType.archive;
  
  return FileType.unknown;
}