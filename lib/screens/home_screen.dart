import 'dart:async';
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
import '../widgets/app_tab_bar.dart';
import '../widgets/motion.dart';
import '../widgets/primary_button.dart';
import 'history_sheet.dart';
import 'settings_screen.dart';

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
    this.uriLauncher,
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
  final ExternalUriLauncher? uriLauncher;
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
  bool _isExitDialogOpen = false;

  /// Which destination of the shell is showing. The extracted text lives on its
  /// own tab, so a successful extract jumps the user there.
  AppTab _tab = AppTab.scan;

  ImageSelectionState get imageState => _imageState;
  String? get selectedImagePath => _selectedImagePath;
  Uint8List? get selectedBitmapBytes => _selectedBitmapBytes;
  TextEditingController get textController => _textController;
  bool get isExtracting => _isExtracting;
  AppTab get tab => _tab;

  /// Lets the screenshot harness (and tests) land on a specific tab without
  /// synthesising a tap.
  void switchTabForShot(AppTab tab) => setState(() => _tab = tab);

  @override
  void initState() {
    super.initState();
    _selectedImagePath = widget.initialImagePath;
    _selectedBitmapBytes = widget.initialBitmapBytes;
    _textFocusNode.addListener(_handleTextFocusChanged);
  }

  void _handleTextFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _textController.dispose();
    _outerScrollController.dispose();
    _textScrollController.dispose();
    _textFocusNode.removeListener(_handleTextFocusChanged);
    _textFocusNode.dispose();
    super.dispose();
  }

  void _setUriState(String path) {
    setState(() {
      _imageState = ImageSelectionState.uri;
      _selectedImagePath = path;
      _selectedBitmapBytes = null;
      _textController.clear();
      _tab = AppTab.scan;
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
        setState(() => _tab = AppTab.text);
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
        // Extracting only ever happens in order to read the result, so take the
        // user to it instead of making them find the tab.
        setState(() => _tab = AppTab.text);
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

  // Kept for the pushed-route style; the shell now switches tabs instead.
  // ignore: unused_element
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

  Future<void> _handleSystemBack() async {
    if (_tab != AppTab.scan) {
      setState(() => _tab = AppTab.scan);
      return;
    }
    if (_isExitDialogOpen) return;

    _isExitDialogOpen = true;
    try {
      final l10n = AppLocalizations.of(context);
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.exitTitle),
          content: Text(l10n.exitMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.exit),
            ),
          ],
        ),
      );
      if (shouldExit == true && mounted) {
        await SystemNavigator.pop();
      }
    } finally {
      _isExitDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleSystemBack());
      },
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                // Only the selected tab is built. History re-reads its store on
                // mount, which is exactly what we want after a new scan lands.
                child: _buildTabBody(context, isDark, l10n, _tab),
              ),
              AppTabBar(
                current: _tab,
                onSelect: (tab) => setState(() => _tab = tab),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBody(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
    AppTab tab,
  ) {
    switch (tab) {
      case AppTab.scan:
        return _buildScanTab(context, isDark, l10n);
      case AppTab.text:
        return _buildTextTab(context, isDark, l10n);
      case AppTab.history:
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: ScanHistorySheet(
            historyService: _historyService,
            onSelectText: (restoredText) {
              setState(() {
                _textController.value = TextEditingValue(
                  text: restoredText,
                  selection:
                      TextSelection.collapsed(offset: restoredText.length),
                );
                _tab = AppTab.text;
              });
              AppToast.showShort(context, AppStrings.toastTextExtracted);
            },
            onCopyText: _copyTextValue,
            embedded: true,
          ),
        );
      case AppTab.settings:
        return SettingsScreen(
          embedded: true,
          currentThemeMode:
              AppShellTheme.of(context)?.themeMode ?? ThemeMode.system,
          currentLocale: Localizations.localeOf(context),
          onThemeModeChanged: (mode) =>
              AppShellTheme.of(context)?.onThemeModeChanged(mode),
          onLocaleChanged: (locale) =>
              AppShellTheme.of(context)?.onLocaleChanged(locale),
          uriLauncher: widget.uriLauncher,
          onBack: () => setState(() => _tab = AppTab.scan),
        );
    }
  }

  // ── Tab 1: Scan ──────────────────────────────────────────────────────────

  Widget _buildScanTab(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final hasImage = _imageState != ImageSelectionState.none;

    return SingleChildScrollView(
      controller: _outerScrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredReveal(
            index: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.appName,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: AppTheme.text(isDark),
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
                _GhostCircleButton(
                  icon: Icons.history_rounded,
                  tooltip: l10n.scanHistory,
                  onTap: () => setState(() => _tab = AppTab.history),
                ),
                const SizedBox(width: 8),
                _GhostCircleButton(
                  key: const Key('settings_button'),
                  icon: Icons.settings_rounded,
                  tooltip: l10n.settings,
                  onTap: () {
                    setState(() => _tab = AppTab.settings);
                    widget.onOpenSettings();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          StaggeredReveal(
            index: 1,
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.42,
              child: hasImage
                  ? _buildSelectedImagePreview(isDark)
                  : AnimatedScanFrame(
                      key: const Key('empty_image_state'),
                      title: l10n.noImageSelected,
                      caption: l10n.chooseImageHint,
                      badge: 'AUTO',
                    ),
            ),
          ),
          const SizedBox(height: 14),
          StaggeredReveal(
            index: 2,
            child: PrimaryActionButton(
              key: const Key('camera_button'),
              label: l10n.camera,
              icon: Icons.camera_alt_rounded,
              onPressed: _handleCamera,
            ),
          ),
          const SizedBox(height: 10),
          StaggeredReveal(
            index: 3,
            child: SecondaryActionButton(
              key: const Key('gallery_button'),
              label: l10n.gallery,
              icon: Icons.photo_library_rounded,
              onPressed: _handleGallery,
            ),
          ),
          const SizedBox(height: 6),
          StaggeredReveal(
            index: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _QuietTextAction(
                  key: const Key('batch_scan_button'),
                  icon: Icons.collections_bookmark_rounded,
                  label: 'Batch scan',
                  onTap: _handleBatchGalleryScan,
                ),
                _Dot(isDark: isDark),
                _QuietTextAction(
                  key: const Key('crop_button'),
                  icon: Icons.crop_rounded,
                  label: l10n.crop,
                  onTap: _handleCrop,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          StaggeredReveal(
            index: 5,
            child: Row(
              children: [
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
          ),
          if (_isExtracting) ..._buildExtractingRow(isDark),
        ],
      ),
    );
  }

  List<Widget> _buildExtractingRow(bool isDark) {
    return [
      const SizedBox(height: 14),
      Row(
        key: const Key('ocr_progress_spinner'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'Reading 5 scripts…',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted(isDark)),
          ),
        ],
      ),
    ];
  }

  // ── Tab 2: Text ──────────────────────────────────────────────────────────

  Widget _buildTextTab(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredReveal(
            index: 0,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionEyebrow(label: 'Result'),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.extractedText,
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          color: AppTheme.text(isDark),
                        ),
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _textController,
                      builder: (context, value, _) {
                        final len = value.text.trim().length;
                        if (len == 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.accentSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$len chars',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accentText(isDark),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          StaggeredReveal(
            index: 1,
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _textController,
              builder: (context, value, _) {
                final hasText = value.text.trim().isNotEmpty;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedContainer(
                      key: const Key('text_editor_card'),
                      duration: const Duration(milliseconds: 180),
                      height: hasText
                          ? MediaQuery.sizeOf(context).height * 0.44
                          : AppTheme.textCardHeight,
                      decoration: BoxDecoration(
                        color: AppTheme.surface(isDark),
                        borderRadius:
                            BorderRadius.circular(AppTheme.textCardRadius),
                        border: Border.all(color: AppTheme.border(isDark)),
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
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
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  maxLines: null,
                                  expands: true,
                                  textAlignVertical: hasText
                                      ? TextAlignVertical.top
                                      : TextAlignVertical.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    height: 1.5,
                                    color: AppTheme.text(isDark),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: hasText || _textFocusNode.hasFocus
                                        ? l10n.extractedTextHint
                                        : null,
                                    hintStyle: TextStyle(
                                      fontSize: 15,
                                      color: AppTheme.textMuted(isDark),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.all(16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (!hasText && !_textFocusNode.hasFocus)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentSoft,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Icon(
                                            Icons.document_scanner_outlined,
                                            size: 27,
                                            color: AppTheme.accentText(isDark),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          l10n.emptyTextTitle,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.text(isDark),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          l10n.emptyTextHint,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: AppTheme.textMuted(isDark),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!hasText) ...[
                      const SizedBox(height: 12),
                      Text(
                        l10n.chooseImageHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted(isDark),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryActionButton(
                              key: const Key('empty_camera_button'),
                              label: l10n.camera,
                              icon: Icons.camera_alt_rounded,
                              onPressed: _handleCamera,
                            ),
                          ),
                          const SizedBox(width: AppTheme.buttonGap),
                          Expanded(
                            child: SecondaryActionButton(
                              key: const Key('empty_gallery_button'),
                              label: l10n.gallery,
                              icon: Icons.photo_library_rounded,
                              onPressed: _handleGallery,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textController,
            builder: (context, value, _) {
              final entities = SmartEntityService.detectEntities(value.text);
              if (value.text.trim().isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 10),
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
          const SizedBox(height: 14),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textController,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              return StaggeredReveal(
                index: 2,
                child: Row(
                  children: [
                    Expanded(
                      child: PrimaryActionButton(
                        key: const Key('copy_button'),
                        label: l10n.copy,
                        icon: Icons.copy_rounded,
                        onPressed: _handleCopy,
                        enabled: hasText,
                      ),
                    ),
                    const SizedBox(width: AppTheme.buttonGap),
                    Expanded(
                      child: SecondaryActionButton(
                        key: const Key('share_button'),
                        label: l10n.share,
                        icon: Icons.share_rounded,
                        onPressed: hasText ? _handleShare : null,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textController,
            builder: (context, value, _) => Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  key: const Key('clear_button'),
                  onPressed: value.text.trim().isNotEmpty ? _handleClear : null,
                  icon: const Icon(Icons.delete_outline_rounded, size: 17),
                  label: Text(l10n.clear),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textMuted(isDark),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.footerCopyright,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textMuted(isDark)),
          ),
        ],
      ),
    );
  }

  // ── Shared pieces ────────────────────────────────────────────────────────

  Widget _buildSelectedImagePreview(bool isDark) {
    Widget preview;
    if (_imageState == ImageSelectionState.bitmap &&
        _selectedBitmapBytes != null) {
      preview = Image.memory(
        _selectedBitmapBytes!,
        key: const Key('image_preview_bitmap'),
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_rounded, size: 40),
        ),
      );
    } else {
      preview = Image.file(
        File(_selectedImagePath!),
        key: const Key('image_preview_uri'),
        fit: BoxFit.contain,
        width: double.infinity,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.image_outlined, size: 40),
        ),
      );
    }

    return Container(
      key: const Key('image_preview'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : const Color(0xFF111113),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF35353B) : const Color(0xFFE4E4E7),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: Center(child: preview)),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 13,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _imageState == ImageSelectionState.bitmap
                        ? 'Cropped'
                        : 'Ready',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
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
}

/// Circular ghost icon button used in headers.
class _GhostCircleButton extends StatelessWidget {
  const _GhostCircleButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.border(isDark)),
            ),
            child: Icon(icon, size: 19, color: AppTheme.textMuted(isDark)),
          ),
        ),
      ),
    );
  }
}

/// Low-emphasis icon+label pair, e.g. "Batch scan".
class _QuietTextAction extends StatelessWidget {
  const _QuietTextAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: AppTheme.textMuted(isDark)),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.textMuted(isDark),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        minimumSize: const Size(0, 40),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Text(
      '·',
      style: TextStyle(color: AppTheme.textMuted(isDark), fontSize: 13),
    );
  }
}

/// Bridges the shell's theme state down to the tabs that change it, so a tab
/// can switch dark mode without a Navigator push.
class AppShellTheme extends InheritedWidget {
  const AppShellTheme({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    required super.child,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale> onLocaleChanged;

  static AppShellTheme? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppShellTheme>();

  @override
  bool updateShouldNotify(AppShellTheme oldWidget) =>
      oldWidget.themeMode != themeMode;
}
