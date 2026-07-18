import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class ImageUploadService {
  static final ImagePicker _picker = ImagePicker();
  static const double _maxImageDimension = 2048;
  static const int _imageQuality = 82;

  static Future<List<XFile>> pickImages({int max = 5}) async {
    final files = await _picker.pickMultiImage(
      imageQuality: _imageQuality,
      maxWidth: _maxImageDimension,
      maxHeight: _maxImageDimension,
    );
    return files.take(max).toList();
  }

  static Future<XFile?> pickImage({required ImageSource source}) =>
      _picker.pickImage(
        source: source,
        imageQuality: _imageQuality,
        maxWidth: _maxImageDimension,
        maxHeight: _maxImageDimension,
      );

  static Future<String> upload(XFile file, String folder) async {
    final bytes = await file.readAsBytes();
    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance.ref('$folder/$stamp-$safeName');
    final task = await ref.putData(
      bytes,
      SettableMetadata(contentType: _contentType(file.name)),
    );
    return task.ref.getDownloadURL();
  }

  static String _contentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
