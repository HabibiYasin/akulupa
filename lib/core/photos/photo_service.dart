import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

enum PhotoSource { camera, gallery }

class PreparedPhoto {
  const PreparedPhoto(this.bytes);
  final Uint8List bytes;
  int get kilobytes => (bytes.length / 1024).ceil();
}

abstract interface class PhotoService {
  Future<PreparedPhoto?> pick(PhotoSource source);
  Future<PreparedPhoto?> recover();
  Future<String> store(PreparedPhoto photo);
  Future<void> discard(String path);
}

typedef PhotoEncoder = Future<Uint8List?> Function(
  String path,
  int dimension,
  int quality,
);

class LocalPhotoService implements PhotoService {
  LocalPhotoService({
    ImagePicker? picker,
    PhotoEncoder? encoder,
    Future<Directory> Function()? directory,
  }) : _picker = picker ?? ImagePicker(),
       _encoder = encoder ?? _compress,
       _directory = directory ?? getApplicationDocumentsDirectory;
  final ImagePicker _picker;
  final PhotoEncoder _encoder;
  final Future<Directory> Function() _directory;
  static const maxBytes = 500 * 1024;
  static Future<Uint8List?> _compress(
    String path,
    int dimension,
    int quality,
  ) => FlutterImageCompress.compressWithFile(
    path,
    minWidth: dimension,
    minHeight: dimension,
    quality: quality,
    format: CompressFormat.jpeg,
    keepExif: false,
    autoCorrectionAngle: true,
  );
  @override
  Future<PreparedPhoto?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      requestFullMetadata: false,
    );
    return file == null ? null : prepare(file.path);
  }

  @override
  Future<PreparedPhoto?> recover() async {
    final result = await _picker.retrieveLostData();
    if (result.exception != null) throw result.exception!;
    final file = result.files?.firstOrNull;
    return file == null ? null : prepare(file.path);
  }

  Future<PreparedPhoto> prepare(String path) async {
    for (final option in [(1600, 82), (1280, 72), (960, 60), (720, 45)]) {
      final bytes = await _encoder(path, option.$1, option.$2);
      if (bytes != null && bytes.isNotEmpty && bytes.length <= maxBytes) {
        return PreparedPhoto(bytes);
      }
    }
    throw const FormatException(
      'Foto belum bisa diperkecil sampai 500 KB. Pilih foto lain.',
    );
  }

  @override
  Future<String> store(PreparedPhoto photo) async {
    if (photo.bytes.isEmpty || photo.bytes.length > maxBytes) {
      throw const FormatException('Ukuran foto tidak valid.');
    }
    final directory = Directory('${(await _directory()).path}/photos');
    await directory.create(recursive: true);
    final name =
        '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}.jpg';
    final file = File('${directory.path}/$name');
    try {
      await file.writeAsBytes(photo.bytes, flush: true);
      return file.path;
    } catch (_) {
      if (await file.exists()) await file.delete();
      rethrow;
    }
  }

  @override
  Future<void> discard(String path) async {
    final directory = Directory('${(await _directory()).path}/photos')
        .absolute
        .path;
    final file = File(path).absolute;
    if (file.parent.path != directory) {
      throw ArgumentError('Foto berada di luar penyimpanan aplikasi.');
    }
    if (await file.exists()) await file.delete();
  }
}
