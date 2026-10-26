import 'dart:io';
import 'package:image_picker/image_picker.dart';

class PhotoService {
  static final ImagePicker _picker = ImagePicker();

  static Future<File?> takePhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 72,
      maxWidth: 1600,
    );
    return photo == null ? null : File(photo.path);
  }

  static Future<File?> pickFromGallery() async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 72,
      maxWidth: 1600,
    );
    return photo == null ? null : File(photo.path);
  }
}
