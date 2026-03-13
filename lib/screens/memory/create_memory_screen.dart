/// Create Memory screen for Kairos app.
///
/// A single scrollable form with progressive reveal for capturing memories:
/// - From a lived moment (pre-filled with moment context)
/// - Standalone (user provides title and date)
///
/// Content fields: photos, caption, place, music, embedded pulse check-in.
/// Seal action uses [SlideToAction] with atomic batch write.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/memory.dart';
import '../../models/moment.dart';
import '../../models/pulse_config.dart';
import '../../scoring/score_models.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/date_utils.dart';
import '../../widgets/active_card.dart';
import '../../widgets/app_calendar.dart';
import '../../widgets/dotted_slider.dart' show VerticalBarSlider;
import '../../widgets/moment_type_icon.dart';
import '../../widgets/photo_picker_grid.dart';
import '../../widgets/slide_to_action.dart';

/// Screen for creating a new memory.
///
/// When [moment] is non-null, creates a memory linked to that moment.
/// When [moment] is null, creates a standalone memory.
class CreateMemoryScreen extends StatefulWidget {
  const CreateMemoryScreen({
    super.key,
    required this.spaceId,
    this.moment,
  });

  final String spaceId;
  final Moment? moment;

  @override
  State<CreateMemoryScreen> createState() => _CreateMemoryScreenState();
}

class _CreateMemoryScreenState extends State<CreateMemoryScreen> {
  // ---------------------------------------------------------------------------
  // Services
  // ---------------------------------------------------------------------------

  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _imagePicker = ImagePicker();

  // ---------------------------------------------------------------------------
  // State — Content
  // ---------------------------------------------------------------------------

  final _photos = <File>[];
  final _thumbs = <File>[];
  final _captionController = TextEditingController();
  final _placeController = TextEditingController();
  final _musicController = TextEditingController();
  final _titleController = TextEditingController();
  DateTime? _date;

  // ---------------------------------------------------------------------------
  // State — Pulse Check-in
  // ---------------------------------------------------------------------------

  final Map<String, double> _scores = {};
  PulseConfig? _pulseConfig;
  StreamSubscription<PulseConfig>? _configSub;
  bool _slidersInteracted = false;

  // ---------------------------------------------------------------------------
  // State — UI
  // ---------------------------------------------------------------------------

  bool _isSealing = false;
  final _scrollController = ScrollController();

  // ---------------------------------------------------------------------------
  // Computed
  // ---------------------------------------------------------------------------

  bool get _isStandalone => widget.moment == null;

  bool get _canSeal {
    if (_isStandalone) {
      return _titleController.text.trim().isNotEmpty && _date != null;
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _date = widget.moment?.startDate;
    _titleController.addListener(() => setState(() {}));
    _subscribeToPulseConfig();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _placeController.dispose();
    _musicController.dispose();
    _titleController.dispose();
    _scrollController.dispose();
    _configSub?.cancel();
    super.dispose();
  }

  void _subscribeToPulseConfig() {
    _configSub = _firestoreService
        .watchPulseConfig(widget.spaceId)
        .listen((config) {
      if (!mounted) return;
      setState(() {
        _pulseConfig = config;
        if (_scores.isEmpty) {
          for (final attr in config.activeAttributes) {
            _scores[attr] = 50;
          }
        }
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _pickPhotos() async {
    FocusScope.of(context).unfocus();
    final remaining = kMaxMemoryPhotos - _photos.length;
    if (remaining <= 0) return;

    try {
      final picked = await _imagePicker.pickMultiImage(
        limit: remaining,
        imageQuality: 90,
      );
      if (picked.isEmpty || !mounted) return;

      final toProcess = picked.take(remaining).toList();

      for (final xfile in toProcess) {
        final bytes = await xfile.readAsBytes();

        final fullBytes = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 1920,
          minHeight: 1920,
          quality: 80,
          format: CompressFormat.jpeg,
        );
        final thumbBytes = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 300,
          minHeight: 300,
          quality: 80,
          format: CompressFormat.jpeg,
        );

        final fullFile = File('${Directory.systemTemp.path}/mem_full_${DateTime.now().millisecondsSinceEpoch}.jpg')
          ..writeAsBytesSync(fullBytes);
        final thumbFile = File('${Directory.systemTemp.path}/mem_thumb_${DateTime.now().millisecondsSinceEpoch}.jpg')
          ..writeAsBytesSync(thumbBytes);

        _photos.add(fullFile);
        _thumbs.add(thumbFile);
      }

      if (mounted) setState(() {});
    } catch (_) {
      // Gallery permission denied or other error — silently ignore
    }
  }

  void _removePhoto(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _photos.removeAt(index);
      _thumbs.removeAt(index);
    });
  }

  void _selectDate(DateTime date) {
    FocusScope.of(context).unfocus();
    setState(() => _date = AppDateFormat.toUtcDate(date));
  }

  void _onSliderChanged(String attrId, double value) {
    setState(() {
      _scores[attrId] = value;
      _slidersInteracted = true;
    });
  }

  Future<void> _seal() async {
    if (_isSealing || !_canSeal) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() => _isSealing = true);

    try {
      final userId = _authService.currentUser!.uid;
      final memoryId = _firestoreService.generateMemoryId(
        spaceId: widget.spaceId,
        momentId: widget.moment?.id,
        userId: userId,
      );

      // Step 1: Upload photos
      var photoPaths = <String>[];
      var thumbPaths = <String>[];
      if (_photos.isNotEmpty) {
        final result = await _storageService.uploadMemoryPhotos(
          spaceId: widget.spaceId,
          memoryId: memoryId,
          fullPhotos: _photos,
          thumbPhotos: _thumbs,
        );
        photoPaths = result.photoPaths;
        thumbPaths = result.thumbPaths;
      }

      // Step 2: Submit embedded check-in (if sliders interacted)
      String? checkinId;
      if (_slidersInteracted && _pulseConfig != null) {
        final activeScores = <String, int>{};
        for (final attrId in _pulseConfig!.activeAttributes) {
          activeScores[attrId] = (_scores[attrId] ?? 50).round();
        }
        final snapshot = ConfigSnapshot(
          activeAttributes: _pulseConfig!.activeAttributes,
          weights: _pulseConfig!.weights,
        );
        checkinId = await _firestoreService.submitCheckIn(
          spaceId: widget.spaceId,
          userId: userId,
          scores: activeScores,
          configSnapshot: snapshot,
          notes: '',
        );
      }

      // Step 3: Atomic batch — memory + moment status + activity
      final memory = Memory(
        id: memoryId,
        createdBy: userId,
        date: _date!,
        createdAt: DateTime.now(),
        momentId: widget.moment?.id,
        momentName: widget.moment?.name,
        momentType: widget.moment?.type.value,
        momentDate: widget.moment?.startDate,
        title: _isStandalone ? _titleController.text.trim() : null,
        photoPaths: photoPaths,
        thumbPaths: thumbPaths,
        caption: _captionController.text.trim().isEmpty
            ? null
            : _captionController.text.trim(),
        place: _placeController.text.trim().isEmpty
            ? null
            : _placeController.text.trim(),
        music: _musicController.text.trim().isEmpty
            ? null
            : _musicController.text.trim(),
        checkinId: checkinId,
      );

      final profile = await _firestoreService.getUserProfile(userId);
      final userName = profile?['name'] as String? ?? 'Someone';

      await _firestoreService.sealMemory(
        spaceId: widget.spaceId,
        memory: memory,
        actorName: userName,
      );

      HapticFeedback.heavyImpact();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to seal memory: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSealing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.pureBlack,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.lightText),
            onPressed: () => context.pop(),
          ),
          title: Text(
            _isStandalone ? 'New Memory' : 'Seal a Memory',
            style: AppTypography.headlineSmall(),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 8),
                  _buildHeader(),
                  const SizedBox(height: 12),
                  _buildPhotoSection(),
                  const SizedBox(height: 12),
                  _buildCaptionField(),
                  const SizedBox(height: 12),
                  _buildPlaceField(),
                  const SizedBox(height: 12),
                  _buildMusicField(),
                  const SizedBox(height: 12),
                  if (_pulseConfig != null) ...[
                    _buildPulseSection(),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
            _buildStickyBottom(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build — Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    if (!_isStandalone) {
      return _buildMomentHeader();
    }
    return _buildStandaloneHeader();
  }

  Widget _buildMomentHeader() {
    final moment = widget.moment!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.darkCardLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          getMomentTypeIconWidget(moment.type, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  moment.name,
                  style: AppTypography.headlineSmall(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  AppDateFormat.short(moment.startDate),
                  style: AppTypography.bodySmall(color: AppColors.warmDim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandaloneHeader() {
    return Column(
      children: [
        ActiveCard(
          heading: 'Title',
          isActive: _titleController.text.trim().isNotEmpty,
          helperText: 'What happened?',
          child: TextField(
            controller: _titleController,
            style: AppTypography.bodyMedium(),
            maxLength: 100,
            decoration: InputDecoration(
              hintText: 'Surprise dinner, spontaneous road trip...',
              hintStyle: AppTypography.bodyMedium(color: AppColors.warmMuted),
              border: InputBorder.none,
              counterStyle: TextStyle(color: AppColors.warmMuted, fontSize: 11),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ActiveCard(
          heading: 'Date',
          isActive: _date != null,
          helperText: 'When did it happen?',
          child: AppDateCalendar(
            selectedDay: _date,
            focusedDay: _date ?? DateTime.now(),
            onDaySelected: (selected, _) => _selectDate(selected),
            firstDay: DateTime.utc(2020),
            lastDay: DateTime.now(),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Build — Photos
  // ---------------------------------------------------------------------------

  Widget _buildPhotoSection() {
    return ActiveCard(
      heading: 'Photos',
      isActive: _photos.isNotEmpty,
      helperText: 'Add up to 3 photos',
      child: PhotoPickerGrid(
        newPhotos: _photos,
        onPickPhotos: _pickPhotos,
        onRemoveNew: _removePhoto,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build — Text Fields
  // ---------------------------------------------------------------------------

  Widget _buildCaptionField() {
    return ActiveCard(
      heading: 'Caption',
      isActive: _captionController.text.isNotEmpty,
      helperText: 'How was it?',
      child: TextField(
        controller: _captionController,
        style: AppTypography.bodyMedium(),
        maxLength: 280,
        maxLines: 3,
        minLines: 1,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'How was it?',
          hintStyle: AppTypography.bodyMedium(color: AppColors.warmMuted),
          border: InputBorder.none,
          counterStyle: TextStyle(color: AppColors.warmMuted, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildPlaceField() {
    return ActiveCard(
      heading: 'Place',
      isActive: _placeController.text.isNotEmpty,
      helperText: 'Where were you?',
      child: TextField(
        controller: _placeController,
        style: AppTypography.bodyMedium(),
        maxLength: 100,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Where were you?',
          hintStyle: AppTypography.bodyMedium(color: AppColors.warmMuted),
          border: InputBorder.none,
          counterText: '',
        ),
      ),
    );
  }

  Widget _buildMusicField() {
    return ActiveCard(
      heading: 'Music',
      isActive: _musicController.text.isNotEmpty,
      helperText: 'A song that reminds you of this',
      child: TextField(
        controller: _musicController,
        style: AppTypography.bodyMedium(),
        maxLength: 100,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'A song that reminds you of this',
          hintStyle: AppTypography.bodyMedium(color: AppColors.warmMuted),
          border: InputBorder.none,
          counterText: '',
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build — Pulse Check-in
  // ---------------------------------------------------------------------------

  Widget _buildPulseSection() {
    final config = _pulseConfig;
    if (config == null) return const SizedBox.shrink();

    final attrs = config.activeAttributes;

    return ActiveCard(
      heading: 'Pulse Check-in',
      isActive: _slidersInteracted,
      helperText: 'How are you feeling?',
      child: SizedBox(
        height: 180,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final attrId in attrs) ...[
              Expanded(
                child: VerticalBarSlider(
                  value: _scores[attrId] ?? 50,
                  onChanged: (v) => _onSliderChanged(attrId, v),
                  label: PulseAttribute.fromId(attrId)?.displayName ?? attrId,
                  icon: _getAttrIcon(attrId),
                  iconAsset: _getAttrIconAsset(attrId),
                ),
              ),
              if (attrId != attrs.last)
                SizedBox(width: attrs.length <= 3 ? 24 : 12),
            ],
          ],
        ),
      ),
    );
  }

  IconData? _getAttrIcon(String attrId) {
    return PulseAttribute.fromId(attrId)?.icon;
  }

  String? _getAttrIconAsset(String attrId) {
    return PulseAttribute.fromId(attrId)?.iconAsset;
  }

  // ---------------------------------------------------------------------------
  // Build — Sticky Bottom
  // ---------------------------------------------------------------------------

  Widget _buildStickyBottom() {
    if (!_canSeal) {
      return const SizedBox(height: 16);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: SlideToAction(
        label: 'Seal this memory',
        loadingLabel: 'Sealing...',
        isLoading: _isSealing,
        onConfirm: _seal,
      ),
    );
  }
}
