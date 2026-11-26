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
import '../services/smart_entity_service.dart';
import '../widgets/app_toast.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/primary_button.dart';
import 'history_sheet.dart';

typedef ShareTextCallback = Future<void> Function(String text,
    {String? subject});
typedef ClipboardCopyCallback = Future<void> Function(String text,
    {String label});

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

  Future<void> _handleBatchGalleryScan() async {
    try {
      final paths = await _imageService.pickMultipleFromGallery();
      if (!mounted || paths.isEmpty) {
        return;
      }
      _setUriState(paths.first);
      setState(() {
        _isExtracting = true;
      });
      final combinedText =
          await _ocrService.extractFromMultipleFilePaths(paths);
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
      });
      if (combinedText == null || combinedText.trim().isEmpty) {
        _textController.clear();
        AppToast.showShort(context, AppStrings.toastNoTextDetected);
      } else {
        _textController.value = TextEditingValue(
          text: combinedText,
          selection: TextSelection.collapsed(offset: combinedText.length),
        );
        await _historyService.addEntry(
          text: combinedText,
          source: 'batch_${paths.length}',
          score: calculateOcrScore(combinedText),
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

  void _handleCleanText() {
    final raw = _textController.text;
    if (raw.trim().isEmpty) return;
    final cleaned = SmartEntityService.cleanOcrText(raw);
    _textController.value = TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
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
                    _buildImageCard(context, isDark, l10n),
                    const SizedBox(height: 12),
                    // Two rows, four actions, one accent. Camera and Extract
                    // are filled because they are the verbs; Gallery and Crop
                    // are outlined because they only prepare the input.
                    Row(
                      children: [
                        Expanded(
                          child: PrimaryActionButton(
                            key: const Key('camera_button'),
                            label: l10n.camera,
                            icon: Icons.camera_alt_rounded,
                            onPressed: _handleCamera,
                          ),
                        ),
                        const SizedBox(width: AppTheme.buttonGap),
                        Expanded(
                          child: SecondaryActionButton(
                            key: const Key('gallery_button'),
                            label: l10n.gallery,
                            icon: Icons.photo_library_rounded,
                            onPressed: _handleGallery,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.buttonGap),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryActionButton(
                            key: const Key('crop_button'),
                            label: l10n.crop,
                            icon: Icons.crop_rounded,
                            onPressed: _handleCrop,
                          ),
                        ),
                        const SizedBox(width: AppTheme.buttonGap),
                        Expanded(
                          child: PrimaryActionButton(
                            key: const Key('extract_button'),
                            label: l10n.extractText,
                            icon: Icons.auto_fix_high_rounded,
                            onPressed: _handleExtractText,
                          ),
                        ),
                      ],
                    ),
                    if (_isExtracting) ...[
                      const SizedBox(height: 14),
                      Row(
                        key: const Key('ocr_progress_spinner'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Extracting text…',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textMuted(isDark),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    _buildExtractedTextSection(context, isDark, l10n),
                  ],
                ),
              ),
            ),
            const BannerAdSlot(),
          ],
        ),
      ),
    );
  }

  /// Header — title, one line of context, history and settings. No gradient
  /// banner, no mascot badge competing with the content below it.
  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.screenPadding,
        10,
        AppTheme.screenPadding,
        6,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.appName,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.text(isDark),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.mainSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted(isDark),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('bottom_nav_history'),
            tooltip: l10n.scanHistory,
            onPressed: _openHistorySheet,
            icon: Icon(
              Icons.history_rounded,
              color: AppTheme.textMuted(isDark),
            ),
          ),
          IconButton(
            key: const Key('settings_button'),
            tooltip: l10n.settings,
            onPressed: widget.onOpenSettings,
            icon: Icon(
              Icons.settings_rounded,
              color: AppTheme.textMuted(isDark),
            ),
          ),
        ],
      ),
    );
  }

  /// The image target. Flat surface, one muted line of copy, and the mascot
  /// only as a small mark — the previous 300dp illustrated hero pushed the
  /// actual buttons below the fold on a 390x844 phone.
  Widget _buildImageCard(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final hasImage = _imageState != ImageSelectionState.none;

    return Container(
      key: const Key('image_card'),
      height: AppTheme.imageCardHeight,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.surface(isDark),
        borderRadius: BorderRadius.circular(AppTheme.imageCardRadius),
        border: Border.all(color: AppTheme.border(isDark)),
      ),
      child: hasImage
          ? _buildSelectedImagePreview(isDark)
          : _buildEmptyState(l10n, isDark),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, bool isDark) {
    return Center(
      key: const Key('empty_image_state'),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/mascot_avatar.png',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.image_outlined,
                  size: 30,
                  color: AppTheme.textMuted(isDark),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.noImageSelected,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.text(isDark),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                l10n.chooseImageHint,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppTheme.textMuted(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
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
          child: Icon(Icons.broken_image_rounded, size: 40),
        ),
      );
    } else {
      previewWidget = Image.file(
        File(_selectedImagePath!),
        key: const Key('image_preview_uri'),
        fit: BoxFit.contain,
        width: double.infinity,
        height: AppTheme.imageCardHeight,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.image_outlined, size: 40),
        ),
      );
    }

    return Container(
      key: const Key('image_preview'),
      color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
      child: Center(child: previewWidget),
    );
  }

  /// Extracted text: one heading, the field, then the actions that only make
  /// sense once there is text. Chips stay because they are the fastest way to
  /// grab an email or amount, but they are muted and only appear when the
  /// detector actually finds something.
  Widget _buildExtractedTextSection(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              l10n.extractedText,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.text(isDark),
              ),
            ),
            const Spacer(),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _textController,
              builder: (context, value, _) {
                final len = value.text.trim().length;
                if (len == 0) return const SizedBox.shrink();
                return Text(
                  '$len chars',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted(isDark),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: AppTheme.textCardHeight,
          decoration: BoxDecoration(
            color: AppTheme.surface(isDark),
            borderRadius: BorderRadius.circular(AppTheme.textCardRadius),
            border: Border.all(color: AppTheme.border(isDark)),
          ),
          child: Listener(
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
                  fontSize: 15,
                  height: 1.45,
                  color: AppTheme.text(isDark),
                ),
                decoration: InputDecoration(
                  hintText: l10n.extractedTextHint,
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: AppTheme.textMuted(isDark),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),
          ),
        ),
        // Entity chips + Clean Text, only once there is text to act on.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _textController,
          builder: (context, value, _) {
            final entities = SmartEntityService.detectEntities(value.text);
            if (value.text.trim().isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    key: const Key('smart_clean_text_chip'),
                    avatar: Icon(
                      Icons.auto_fix_normal_rounded,
                      size: 15,
                      color: AppTheme.accentText(isDark),
                    ),
                    label: const Text('Clean text'),
                    visualDensity: VisualDensity.compact,
                    onPressed: _handleCleanText,
                  ),
                  ...entities.take(4).map((entity) {
                    return ActionChip(
                      key: Key('entity_chip_${entity.value}'),
                      avatar: Icon(
                        entity.kind.icon,
                        size: 14,
                        color: AppTheme.textMuted(isDark),
                      ),
                      label: Text(entity.value),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _copyTextValue(entity.value),
                    );
                  }),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SecondaryActionButton(
                key: const Key('copy_button'),
                label: l10n.copy,
                icon: Icons.copy_rounded,
                onPressed: _handleCopy,
              ),
            ),
            const SizedBox(width: AppTheme.buttonGap),
            Expanded(
              child: SecondaryActionButton(
                key: const Key('share_button'),
                label: l10n.share,
                icon: Icons.share_rounded,
                onPressed: _handleShare,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // Batch scan and Clear are occasional, so they sit as quiet text
        // buttons instead of competing with the four actions above.
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              key: const Key('batch_scan_button'),
              onPressed: _handleBatchGalleryScan,
              icon: const Icon(Icons.collections_bookmark_rounded, size: 17),
              label: const Text('Batch scan'),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textMuted(isDark),
              ),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              key: const Key('clear_button'),
              onPressed: _handleClear,
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              label: Text(l10n.clear),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textMuted(isDark),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.footerCopyright,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.textMuted(isDark),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
