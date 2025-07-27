// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'file_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$FileItemImpl _$$FileItemImplFromJson(Map<String, dynamic> json) =>
    _$FileItemImpl(
      name: json['name'] as String,
      path: json['path'] as String,
      type: $enumDecode(_$FileTypeEnumMap, json['type']),
      size: (json['size'] as num).toInt(),
      lastModified: DateTime.parse(json['lastModified'] as String),
      isFavorite: json['isFavorite'] as bool? ?? false,
    );

Map<String, dynamic> _$$FileItemImplToJson(_$FileItemImpl instance) =>
    <String, dynamic>{
      'name': instance.name,
      'path': instance.path,
      'type': _$FileTypeEnumMap[instance.type]!,
      'size': instance.size,
      'lastModified': instance.lastModified.toIso8601String(),
      'isFavorite': instance.isFavorite,
    };

const _$FileTypeEnumMap = {
  FileType.directory: 'directory',
  FileType.image: 'image',
  FileType.audio: 'audio',
  FileType.video: 'video',
  FileType.document: 'document',
  FileType.archive: 'archive',
  FileType.unknown: 'unknown',
};
