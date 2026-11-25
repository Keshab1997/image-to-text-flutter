import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../constants/app_localizations.dart';
import '../constants/app_strings.dart';
import '../constants/app_theme.dart';
import '../services/history_service.dart';
import '../services/image_service.dart';
import '../services/ocr_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/primary_button.dart';
import 'history_sheet.dart';

typedef ShareTextCallback = Future<void> Function(String text, {String? subject});
typedef ClipboardCopyCallback = Future<void> Function(String text, {String label});

/// Screen 1 — Home Screen of SnapText OCR.
///
/// Implements the complete functional contract from docs/IMPLEMENTATION_SPEC.md §2
/// styled with Keshab's selected 3D Robot-Scholar Mascot UI redesign,
/// live 21-language localization, and local Scan History.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenSettings,
    this.imageService,
    this.ocrService,
    this.historyService,
    this.shareHandler,
    this.clipboardHandler,
    this.initialImageState = ImageSelectionState.none,
    this.initialImagePath,
    this.initialBitmapBytes,
  });

  final VoidCallback onOpenSettings;
  final ImageService? imageService;
  final OcrService? ocrService;
  final HistoryService? historyService;
  final ShareTextCallback? shareHandler;
  final ClipboardCopyCallback? clipboardHandler;
  final ImageSelectionState initialImageState;
  final String? initialImagePath;
  final Uint8List? initialBitmapBytes;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late final ImageService _imageService = widget.imageService ?? ImageService();
  late final OcrService _ocrService = widget.ocrService ?? OcrService();
  late final HistoryService _historyService =
      widget.historyService ?? HistoryService();
  late final TextEditingController _textController = TextEditingController();
  late final ScrollController _outerScrollController = ScrollController();
  late final ScrollController _textScrollController = ScrollController();
  late final FocusNode _textFocusNode = FocusNode();

  late ImageSelectionState _imageState = widget.initialImageState;
  String? _selectedImagePath;
  Uint8List? _selectedBitmapBytes;
  bool _isExtracting = false;
  bool _textBoxPointerActive = false;

  ImageSelectionState get imageState => _imageState;
  String? get selectedImagePath => _selectedImagePath;
  Uint8List? get selectedBitmapBytes => _selectedBitmapBytes;
  TextEditingController get textController => _textController;
  bool get isExtracting => _isExtracting;

  @override
  void initState() {
    super.initState();
    _selectedImagePath = widget.initialImagePath;
    _selectedBitmapBytes = widget.initialBitmapBytes;
  }

  @override
  void dispose() {
    _textController.dispose();
    _outerScrollController.dispose();
    _textScrollController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  void _setUriState(String path) {
    setState(() {
      _imageState = ImageSelectionState.uri;
      _selectedImagePath = path;
      _selectedBitmapBytes = null;
      _textController.clear();
    });
  }

  void _setBitmapState(Uint8List bytes) {
    setState(() {
      _imageState = ImageSelectionState.bitmap;
      _selectedBitmapBytes = bytes;
      _selectedImagePath = null;
      _textController.clear();
    });
  }

  Future<void> _handleCamera() async {
    try {
      final path = await _imageService.captureFromCamera();
      if (!mounted) return;
      _setUriState(path);
      AppToast.showShort(context, AppStrings.toastPhotoCaptured);
    } on CameraPermissionDeniedException {
      if (!mounted) return;
      AppToast.showLong(context, AppStrings.toastCameraPermissionRequired);
    } on CameraCaptureCancelledException {
      if (!mounted) return;
      AppToast.showShort(context, AppStrings.toastCameraCancelled);
    } on CameraOpenException catch (e) {
      if (!mounted) return;
      AppToast.showLong(context, AppStrings.toastCameraOpenError(e.message));
    } catch (e) {
      if (!mounted) return;
      AppToast.showLong(
        context,
        AppStrings.toastCameraOpenError(e.toString()),
      );
    }
  }

  Future<void> _handleGallery() async {
    try {
      final path = await _imageService.pickFromGallery();
      if (!mounted || path == null || path.trim().isEmpty) {
        // Gallery cancellation is silent per Spec §2.3.
        return;
      }
      _setUriState(path);
    } catch (_) {
      // Keep gallery cancellation/errors non-disruptive.
    }
  }

  Future<void> _handleCrop() async {
    if (_imageState == ImageSelectionState.none) {
      AppToast.showShort(context, AppStrings.toastCropNoImage);
      return;
    }

    try {
      final sourcePath = await _imageService.resolveSourceFileForCrop(
        currentImagePath:
            _imageState == ImageSelectionState.uri ? _selectedImagePath : null,
        currentBitmapBytes: _imageState == ImageSelectionState.bitmap
            ? _selectedBitmapBytes
            : null,
      );

      if (!mounted) return;
      if (sourcePath == null) {
        AppToast.showShort(context, AppStrings.toastCropNoImage);
        return;
      }

      final croppedBytes = await _imageService.cropAndDecodeBitmap(sourcePath);
      if (!mounted) return;
      _setBitmapState(croppedBytes);
      AppToast.showShort(context, AppStrings.toastCropSuccess);
    } on CropNoOutputException {
      if (!mounted) return;
      AppToast.showShort(context, AppStrings.toastCropNoOutput);
    } on CropFailedException catch (e) {
      if (!mounted) return;
      AppToast.showLong(context, AppStrings.toastCropFailed(e.message));
    } on CropDecodeException catch (e) {
      if (!mounted) return;
      AppToast.showLong(context, AppStrings.toastCropDecodeError(e.message));
    } catch (e) {
      if (!mounted) return;
      AppToast.showLong(context, AppStrings.toastCropFailed(e.toString()));
    }
  }

  Future<void> _handleExtractText() async {
    if (_imageState == ImageSelectionState.none) {
      AppToast.showShort(context, AppStrings.toastExtractNoImage);
      return;
    }

    setState(() {
      _isExtracting = true;
    });

    try {
      String? bestText;
      if (_imageState == ImageSelectionState.bitmap &&
          _selectedBitmapBytes != null) {
        bestText =
            await _ocrService.extractFromBitmapBytes(_selectedBitmapBytes!);
      } else if (_imageState == ImageSelectionState.uri &&
          _selectedImagePath != null) {
        bestText = await _ocrService.extractFromFilePath(_selectedImagePath!);
      }

      if (!mounted) return;
      setState(() {
        _isExtracting = false;
      });

      if (bestText == null || bestText.trim().isEmpty) {
        _textController.clear();
        AppToast.showShort(context, AppStrings.toastNoTextDetected);
      } else {
        _textController.value = TextEditingValue(
          text: bestText,
          selection: TextSelection.collapsed(offset: bestText.length),
        );
        await _historyService.addEntry(
          text: bestText,
          source: _imageState == ImageSelectionState.bitmap ? 'cropped' : 'uri',
          score: calculateOcrScore(bestText),
        );
        if (!mounted) return;
        AppToast.showShort(context, AppStrings.toastTextExtracted);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
      });
      final cleanMsg = e.toString().replaceFirst('Exception: ', '').trim();
      AppToast.showLong(context, AppStrings.toastProcessImageError(cleanMsg));
    }
  }

  Future<void> _copyTextValue(String text) async {
    final handler = widget.clipboardHandler;
    if (handler != null) {
      await handler(text, label: AppStrings.clipboardLabel);
    } else {
      await Clipboard.setData(ClipboardData(text: text));
    }
    if (!mounted) return;
    AppToast.showShort(context, AppStrings.toastTextCopied);
  }

  Future<void> _handleCopy() async {
    final text = _textController.text;
    if (text.trim().isEmpty) {
      AppToast.showShort(context, AppStrings.toastCopyEmpty);
      return;
    }
    await _copyTextValue(text);
  }

  Future<void> _handleShare() async {
    final text = _textController.text;
    if (text.trim().isEmpty) {
      AppToast.showShort(context, AppStrings.toastShareEmpty);
      return;
    }

    final handler = widget.shareHandler;
    if (handler != null) {
      await handler(text, subject: AppStrings.shareChooserTitle);
    } else {
      await Share.share(
        text,
        subject: AppStrings.shareChooserTitle,
      );
    }
  }

  void _handleClear() {
    setState(() {
      _imageState = ImageSelectionState.none;
      _selectedImagePath = null;
      _selectedBitmapBytes = null;
      _isExtracting = false;
      _textController.clear();
    });
    AppToast.showShort(context, AppStrings.toastCleared);
  }

  Future<void> _openHistorySheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ScanHistorySheet(
        historyService: _historyService,
        onSelectText: (restoredText) {
          setState(() {
            _textController.value = TextEditingValue(
              text: restoredText,
              selection: TextSelection.collapsed(offset: restoredText.length),
            );
          });
          AppToast.showShort(context, AppStrings.toastTextExtracted);
        },
        onCopyText: _copyTextValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark, l10n),
            Expanded(
              child: SingleChildScrollView(
                controller: _outerScrollController,
                physics: _textBoxPointerActive
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(AppTheme.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroImageCard(context, isDark, l10n),
                    const SizedBox(height: 14),
                    // Row 1: Camera & Gallery equal-width bento buttons (6dp+ gap)
                    Row(
                      children: [
                        Expanded(
                          child: BentoActionTile(
                            key: const Key('camera_button'),
                            title: l10n.camera,
                            subtitle: l10n.cameraSub,
                            icon: Icons.camera_alt_rounded,
                            gradientColors: const [
                              AppTheme.cameraOrangeStart,
                              AppTheme.cameraOrangeEnd,
                            ],
                            onTap: _handleCamera,
                          ),
                        ),
                        const SizedBox(width: AppTheme.buttonGap),
                        Expanded(
                          child: BentoActionTile(
                            key: const Key('gallery_button'),
                            title: l10n.gallery,
                            subtitle: l10n.gallerySub,
                            icon: Icons.photo_library_rounded,
                            gradientColors: const [
                              AppTheme.galleryTealStart,
                              AppTheme.galleryTealEnd,
                            ],
                            onTap: _handleGallery,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Row 2: Crop & Extract Text equal-width pill buttons (6dp+ gap)
                    Row(
                      children: [
                        Expanded(
                          child: SmartPillButton(
                            key: const Key('crop_button'),
                            label: l10n.crop,
                            icon: Icons.crop_rounded,
                            backgroundColor: isDark
                                ? const Color(0xFF281C54)
                                : const Color(0xFFE8E2F8),
                            foregroundColor: isDark
                                ? Colors.white
                                : const Color(0xFF33206E),
                            borderColor: isDark
                                ? Colors.white.withValues(alpha: 0.14)
                                : const Color(0xFFD1C4E9),
                            elevation: 0,
                            onPressed: _handleCrop,
                          ),
                        ),
                        const SizedBox(width: AppTheme.buttonGap),
                        Expanded(
                          child: SmartPillButton(
                            key: const Key('extract_button'),
                            label: l10n.extractText,
                            trailingIcon: Icons.auto_fix_high_rounded,
                            gradientColors: const [
                              AppTheme.royalViolet,
                              AppTheme.electricIndigo,
                            ],
                            onPressed: _handleExtractText,
                          ),
                        ),
                      ],
                    ),
                    if (_isExtracting) ...[
                      const SizedBox(height: 16),
                      Center(
                        child: Column(
                          key: const Key('ocr_progress_spinner'),
                          children: [
                            const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Running 5-script AI OCR engine...',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFFB388FF)
                                    : AppTheme.royalViolet,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildExtractedTextStudioCard(context, isDark, l10n),
                  ],
                ),
              ),
            ),
            _buildMockupBottomNavBar(isDark, l10n),
            const BannerAdSlot(),
          ],
        ),
      ),
    );
  }

  /// Header — padding 20dp horizontal, 12dp vertical (Spec §2.1 + v2 Mockup).
  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF2B1964), Color(0xFF1A0F42)]
              : const [Color(0xFF512DA8), Color(0xFF673AB7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.royalViolet.withValues(alpha: 0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mascot Avatar Badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF80D8FF),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7C4DFF).withValues(alpha: 0.45),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/mascot_avatar.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  AppStrings.appName,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.mainSubtitle,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          // Right: circular icon button 56x56dp, blue #1976d2, stroke #64b5f6, white settings icon 30dp
          Tooltip(
            message: l10n.settings,
            child: Semantics(
              label: l10n.settings,
              button: true,
              child: SizedBox(
                width: AppTheme.settingsFabSize,
                height: AppTheme.settingsFabSize,
                child: Material(
                  color: AppTheme.settingsFabBlue,
                  elevation: 6,
                  shape: const CircleBorder(
                    side: BorderSide(
                      color: AppTheme.settingsFabStroke,
                      width: 2,
                    ),
                  ),
                  child: InkWell(
                    key: const Key('settings_button'),
                    customBorder: const CircleBorder(),
                    onTap: widget.onOpenSettings,
                    child: const Center(
                      child: Icon(
                        Icons.settings_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Image Card: 300dp tall, radius 20dp, elevation 2dp (Spec §2.1 + v2 Mockup).
  Widget _buildHeroImageCard(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final hasImage = _imageState != ImageSelectionState.none;

    return Card(
      key: const Key('image_card'),
      elevation: 2,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.imageCardRadius),
      ),
      child: SizedBox(
        height: AppTheme.imageCardHeight,
        width: double.infinity,
        child: hasImage
            ? _buildSelectedImagePreview(isDark)
            : _buildMascotEmptyState(l10n),
      ),
    );
  }

  Widget _buildMascotEmptyState(AppLocalizations l10n) {
    return Stack(
      key: const Key('empty_image_state'),
      fit: StackFit.expand,
      children: [
        // Background 3D Robot-Scholar Mascot Hero Illustration
        Image.asset(
          'assets/images/mascot_hero.png',
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
          errorBuilder: (_, __, ___) => Container(
            color: AppTheme.deepCosmic,
          ),
        ),
        // Subtle gradient scrim on the left so text is super legible
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF120831).withValues(alpha: 0.92),
                const Color(0xFF190C40).withValues(alpha: 0.72),
                Colors.transparent,
              ],
              stops: const [0.0, 0.54, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gallery icon 64dp at 55% opacity (Spec §2.1)
                Opacity(
                  opacity: 0.55,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.noImageSelected,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 230),
                  child: Text(
                    l10n.chooseImageHint,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C4DFF).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF80D8FF).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    l10n.heroDropPrompt,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedImagePreview(bool isDark) {
    Widget previewWidget;
    if (_imageState == ImageSelectionState.bitmap &&
        _selectedBitmapBytes != null) {
      previewWidget = Image.memory(
        _selectedBitmapBytes!,
        key: const Key('image_preview_bitmap'),
        fit: BoxFit.contain,
        width: double.infinity,
        height: AppTheme.imageCardHeight,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_rounded, size: 56),
        ),
      );
    } else if (_imageState == ImageSelectionState.uri &&
        _selectedImagePath != null) {
      previewWidget = Image.file(
        File(_selectedImagePath!),
        key: const Key('image_preview_uri'),
        fit: BoxFit.contain,
        width: double.infinity,
        height: AppTheme.imageCardHeight,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.image_outlined, size: 56),
        ),
      );
    } else {
      previewWidget = const SizedBox.shrink();
    }

    return Container(
      key: const Key('image_preview'),
      color: isDark ? const Color(0xFF140B30) : const Color(0xFF1B103D),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: previewWidget),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF80D8FF).withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF00E676),
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _imageState == ImageSelectionState.bitmap
                        ? 'Cropped Image'
                        : 'Image Ready',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Extracted Text studio container matching Spec §2.1 + v2 Mockup.
  Widget _buildExtractedTextStudioCard(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final studioBg = isDark ? const Color(0xFF1B123E) : Colors.white;
    final innerFieldBg =
        isDark ? const Color(0xFF120B2B) : const Color(0xFFF7F4FD);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: studioBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2DAF5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.extractedText,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1A103D),
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _textController,
                builder: (context, value, _) {
                  final len = value.text.trim().length;
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.royalViolet.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      len == 0 ? 'Ready' : '$len chars',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFB388FF)
                            : AppTheme.royalViolet,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
              // `...` History button in top-right of Extracted Text card (matching v2 mockup)
              IconButton(
                key: const Key('studio_history_button'),
                tooltip: l10n.scanHistory,
                visualDensity: VisualDensity.compact,
                onPressed: _openHistorySheet,
                icon: Icon(
                  Icons.more_horiz_rounded,
                  color: isDark ? Colors.white70 : const Color(0xFF42366E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Text card: 260dp tall, radius 16dp; editable, scrollable multiline TextField
          // Keeps touch scrolling for itself inside the scrollable body (Spec §2.1)
          Listener(
            onPointerDown: (_) {
              if (!_textBoxPointerActive) {
                setState(() => _textBoxPointerActive = true);
              }
            },
            onPointerUp: (_) {
              if (_textBoxPointerActive) {
                setState(() => _textBoxPointerActive = false);
              }
            },
            onPointerCancel: (_) {
              if (_textBoxPointerActive) {
                setState(() => _textBoxPointerActive = false);
              }
            },
            child: Card(
              key: const Key('extracted_text_card'),
              elevation: 1,
              margin: EdgeInsets.zero,
              color: innerFieldBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.textCardRadius),
                side: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : const Color(0xFFDAD0F2),
                ),
              ),
              child: SizedBox(
                height: AppTheme.textCardHeight,
                child: Scrollbar(
                  controller: _textScrollController,
                  thumbVisibility: true,
                  child: TextField(
                    key: const Key('extracted_text_field'),
                    controller: _textController,
                    scrollController: _textScrollController,
                    focusNode: _textFocusNode,
                    scrollPhysics: const ClampingScrollPhysics(),
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.45,
                      color: isDark ? Colors.white : const Color(0xFF1C1338),
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.extractedTextHint,
                      hintStyle: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Row 3: Copy & Share equal-width buttons
          Row(
            children: [
              Expanded(
                child: SmartPillButton(
                  key: const Key('copy_button'),
                  label: l10n.copy,
                  icon: Icons.copy_rounded,
                  gradientColors: const [
                    AppTheme.copyPurpleStart,
                    AppTheme.copyPurpleEnd,
                  ],
                  onPressed: _handleCopy,
                ),
              ),
              const SizedBox(width: AppTheme.buttonGap),
              Expanded(
                child: SmartPillButton(
                  key: const Key('share_button'),
                  label: l10n.share,
                  icon: Icons.share_rounded,
                  gradientColors: const [
                    AppTheme.shareTealStart,
                    AppTheme.shareTealEnd,
                  ],
                  onPressed: _handleShare,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Full-width outlined Clear button (Spec §2.1 + warm orange accent from v2 mockup)
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              key: const Key('clear_button'),
              onPressed: _handleClear,
              icon: const Icon(Icons.delete_sweep_rounded, size: 20),
              label: Text(
                l10n.clear,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.clearOrangeEnd,
                side: const BorderSide(
                  color: AppTheme.clearOrangeEnd,
                  width: 1.6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.pillRadius),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Footer copyright 15sp bold centred
          Text(
            AppStrings.footerCopyright,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF42366E),
            ),
          ),
        ],
      ),
    );
  }

  /// Bottom navigation bar matching the selected v2 UI design mockup
  /// (Home / History / Settings).
  Widget _buildMockupBottomNavBar(bool isDark, AppLocalizations l10n) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF1F1147), Color(0xFF34186B)]
              : const [Color(0xFF311B92), Color(0xFF512DA8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            key: const Key('bottom_nav_home'),
            tooltip: l10n.homeTab,
            onPressed: () {
              _outerScrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
              );
            },
            icon: const Icon(
              Icons.home_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          IconButton(
            key: const Key('bottom_nav_history'),
            tooltip: l10n.scanHistory,
            onPressed: _openHistorySheet,
            icon: Icon(
              Icons.history_rounded,
              color: Colors.white.withValues(alpha: 0.85),
              size: 24,
            ),
          ),
          IconButton(
            key: const Key('bottom_nav_settings'),
            tooltip: l10n.settings,
            onPressed: widget.onOpenSettings,
            icon: Icon(
              Icons.person_outline_rounded,
              color: Colors.white.withValues(alpha: 0.85),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}
