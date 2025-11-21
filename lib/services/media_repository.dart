import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

class UploadedMedia {
  const UploadedMedia({
    required this.url,
    required this.type,
    required this.publicId,
    required this.bytes,
    this.duration,
    this.format,
  });

  final String url;
  final String type;
  final String publicId;
  final int bytes;
  final double? duration;
  final String? format;

  bool get isVideo => type == 'video';
  bool get isImage => type == 'image';

  factory UploadedMedia.fromJson(Map<String, dynamic> json) {
    final bytesRaw = json['bytes'];
    final durationRaw = json['duration'];

    return UploadedMedia(
      url: json['url'] as String,
      type: json['type'] as String,
      publicId: json['publicId'] as String,
      bytes: bytesRaw is num
          ? bytesRaw.toInt()
          : int.tryParse(bytesRaw?.toString() ?? '') ?? 0,
      duration: durationRaw is num
          ? durationRaw.toDouble()
          : double.tryParse(durationRaw?.toString() ?? ''),
      format: json['format'] as String?,
    );
  }
}

class MediaRepository {
  MediaRepository(this._dio);

  final Dio _dio;

  Future<List<UploadedMedia>> uploadMedia(List<XFile> files) async {
    if (files.isEmpty) {
      throw ArgumentError('Select at least one file to upload.');
    }

    final formData = FormData();

    for (final file in files) {
      final mime = file.mimeType ??
          lookupMimeType(file.path) ??
          lookupMimeType(file.name) ??
          'application/octet-stream';
      final mediaType = MediaType.parse(mime);
      final multipart = await _buildMultipartFile(file, mediaType);
      formData.files.add(MapEntry('files', multipart));
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/media',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    final payload = response.data?['attachments'];
    if (payload is! List) {
      throw StateError('Unexpected upload response');
    }

    return payload
        .map((dynamic item) => UploadedMedia.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<MultipartFile> _buildMultipartFile(
    XFile file,
    MediaType mediaType,
  ) async {
    if (kIsWeb || file.path.isEmpty) {
      final bytes = await file.readAsBytes();
      return MultipartFile.fromBytes(
        bytes,
        filename: file.name,
        contentType: mediaType,
      );
    }

    try {
      return await MultipartFile.fromFile(
        file.path,
        filename: file.name,
        contentType: mediaType,
      );
    } catch (_) {
      final bytes = await file.readAsBytes();
      return MultipartFile.fromBytes(
        bytes,
        filename: file.name,
        contentType: mediaType,
      );
    }
  }
}
