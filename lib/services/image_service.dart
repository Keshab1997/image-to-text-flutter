import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../constants/app_strings.dart';
import '../constants/app_theme.dart';

/// Exclusive three-state model specified in IMPLEMENTATION_SPEC.md §2.2.
enum ImageSelectionState {
  /// No image selected; empty state shown, preview hidden.
  none,

  /// Picked or captured image referenced by a file URI/path.
  uri,

  /// Cropped image held in memory (`selectedImageUri` cleared).
  bitmap,
}

class CameraPermissionDeniedException implements Exception {
  const CameraPermissionDeniedException();
}

class CameraCaptureCancelledException implements Exception {
  const CameraCaptureCancelledException();
}

class CameraOpenException implements Exception {
  const CameraOpenException(this.message);
  final String message;
}

class CropNoOutputException implements Exception {
  const CropNoOutputException();
}

class CropFailedException implements Exception {
  const CropFailedException(this.message);
  final String message;
}

class CropDecodeException implements Exception {
  const CropDecodeException(this.message);
  final String message;
}

typedef PermissionCheckCallback = Future<bool> Function();
typedef FilePickCallback = Future<String?> Function();
typedef FileCropCallback = Future<String?> Function(String sourcePath);
typedef BitmapValidatorCallback = Future<Uint8List> Function(
    String croppedPath);
typedef TempDirCallback = Future<Directory> Function();

/// Handles Camera capture, Gallery pick, uCrop cropping, and temp-file management.
class ImageService {
  ImageService({
    PermissionCheckCallback? cameraPermissionRequester,
    FilePickCallback? cameraPicker,
    FilePickCallback? galleryPicker,
    FileCropCallback? cropperRunner,
    BitmapValidatorCallback? bitmapLoader,
    TempDirCallback? tempDirProvider,
  })  : _cameraPermissionRequester =
            cameraPermissionRequester ?? _defaultRequestCameraPermission,
        _cameraPicker = cameraPicker ?? _defaultPickCamera,
        _galleryPicker = galleryPicker ?? _defaultPickGallery,
        _cropperRunner = cropperRunner ?? _defaultCropImage,
        _bitmapLoader = bitmapLoader ?? _defaultLoadAndValidateBitmap,
        _tempDirProvider = tempDirProvider ?? getTemporaryDirectory;

  final PermissionCheckCallback _cameraPermissionRequester;
  final FilePickCallback _cameraPicker;
  final FilePickCallback _galleryPicker;
  final FileCropCallback _cropperRunner;
  final BitmapValidatorCallback _bitmapLoader;
  final TempDirCallback _tempDirProvider;

  static final ImagePicker _picker = ImagePicker();

  static Future<bool> _defaultRequestCameraPermission() async {
    final current = await Permission.camera.status;
    if (current.isGranted) {
      return true;
    }
    final requested = await Permission.camera.request();
    return requested.isGranted;
  }

  static Future<String?> _defaultPickCamera() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 95,
    );
    return picked?.path;
  }

  static Future<String?> _defaultPickGallery() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
    );
    return picked?.path;
  }

  static Future<String?> _defaultCropImage(String sourcePath) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95,
      maxWidth: 4096,
      maxHeight: 4096,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: AppStrings.cropToolbarTitle,
          toolbarColor: AppTheme.royalViolet,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppTheme.electricIndigo,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          showCropGrid: true,
          hideBottomControls: false,
        ),
      ],
    );
    return cropped?.path;
  }

  static Future<Uint8List> _defaultLoadAndValidateBitmap(
    String croppedPath,
  ) async {
    final file = File(croppedPath);
    if (!file.existsSync()) {
      throw const FileSystemException('Cropped file does not exist');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('Cropped image stream is empty');
    }
    // Decode stream via Flutter engine codec to verify valid bitmap data
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    frame.image.dispose();
    codec.dispose();
    return bytes;
  }

  /// Captures a photo from the camera following Spec §2.3 & Reverse Eng §4.4:
  /// 1. Requests camera permission if needed; throws [CameraPermissionDeniedException] if denied.
  /// 2. Creates `temp/camera_<epochMillis>.jpg`.
  /// 3. Launches camera capture; if cancelled, deletes the temp file and throws [CameraCaptureCancelledException].
  /// 4. On error, cleans up temp file and throws [CameraOpenException].
  Future<String> captureFromCamera() async {
    final granted = await _cameraPermissionRequester();
    if (!granted) {
      throw const CameraPermissionDeniedException();
    }

    File? tempCameraFile;
    try {
      final tempDir = await _tempDirProvider();
      final ts = DateTime.now().millisecondsSinceEpoch;
      tempCameraFile = File('${tempDir.path}/camera_$ts.jpg');
      // Pre-create temp file as in original FileProvider flow
      tempCameraFile.writeAsBytesSync(const <int>[], flush: true);

      final capturedPath = await _cameraPicker();
      if (capturedPath == null || capturedPath.trim().isEmpty) {
        if (tempCameraFile.existsSync()) {
          tempCameraFile.deleteSync();
        }
        throw const CameraCaptureCancelledException();
      }

      if (capturedPath != tempCameraFile.path) {
        final capturedFile = File(capturedPath);
        if (capturedFile.existsSync()) {
          capturedFile.copySync(tempCameraFile.path);
        }
      }
      return tempCameraFile.path;
    } on CameraCaptureCancelledException {
      rethrow;
    } catch (e) {
      if (tempCameraFile != null && tempCameraFile.existsSync()) {
        try {
          tempCameraFile.deleteSync();
        } catch (_) {}
      }
      throw CameraOpenException(e.toString());
    }
  }

  /// Picks an image from the gallery (`image/*`).
  /// Returns `null` silently if the user cancels.
  Future<String?> pickFromGallery() async {
    return _galleryPicker();
  }

  /// Resolves a file path for cropping:
  /// - If [currentImagePath] is non-null (state `uri`), returns it directly.
  /// - Otherwise if [currentBitmapBytes] is non-null (state `bitmap`), writes
  ///   the bitmap to `temp/camera_<epochMillis>.jpg` first (per Spec §2.3)
  ///   and returns that file's path.
  Future<String?> resolveSourceFileForCrop({
    required String? currentImagePath,
    required Uint8List? currentBitmapBytes,
  }) async {
    if (currentImagePath != null && currentImagePath.isNotEmpty) {
      return currentImagePath;
    }
    if (currentBitmapBytes != null && currentBitmapBytes.isNotEmpty) {
      final tempDir = await _tempDirProvider();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/camera_$ts.jpg');
      file.writeAsBytesSync(currentBitmapBytes, flush: true);
      return file.path;
    }
    return null;
  }

  /// Crops the image at [sourcePath] and decodes the result into memory (`Uint8List`).
  ///
  /// - Throws [CropNoOutputException] if the cropper returns no output path.
  /// - Throws [CropFailedException] if the cropper itself throws an error.
  /// - Throws [CropDecodeException] if decoding the cropped output fails.
  Future<Uint8List> cropAndDecodeBitmap(String sourcePath) async {
    String? croppedPath;
    try {
      croppedPath = await _cropperRunner(sourcePath);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      throw CropFailedException(msg.isEmpty ? 'Unknown error' : msg);
    }

    if (croppedPath == null || croppedPath.trim().isEmpty) {
      throw const CropNoOutputException();
    }

    try {
      return await _bitmapLoader(croppedPath);
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '').trim();
      throw CropDecodeException(msg.isEmpty ? 'Invalid bitmap' : msg);
    }
  }
}
