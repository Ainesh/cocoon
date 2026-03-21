library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/memory.dart';
import '../../services/firestore_service.dart';
import '../../services/drive_storage_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/image_compressor.dart';
import '../../theme/app_typography.dart';
import '../../widgets/active_card.dart';
import '../../widgets/photo_picker_grid.dart';
import '../../widgets/slide_to_action.dart';

class EditMemoryScreen extends StatefulWidget {
  const EditMemoryScreen({
    super.key,
    required this.spaceId,
    required this.memory,
  });

  final String spaceId;
  final Memory memory;

  @override
  State<EditMemoryScreen> createState() => _EditMemoryScreenState();
}

class _EditMemoryScreenState extends State<EditMemoryScreen> {
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _driveService = DriveStorageService();
  final _imagePicker = ImagePicker();

  // Existing photos kept by user (storage paths)
  late List<String> _existingPhotoPaths = List.from(widget.memory.photoPaths);
  late List<String> _existingThumbPaths = List.from(widget.memory.thumbPaths);

  // Resolved thumbnail URLs for existing photos display
  final _existingThumbUrls = <String>[];

  // Newly picked photos (not yet uploaded)
  final _newPhotos = <Uint8List>[];
  final _newThumbs = <Uint8List>[];

  late final _captionController =
      TextEditingController(text: widget.memory.caption ?? '');
  late final _placeController =
      TextEditingController(text: widget.memory.place ?? '');
  late final _musicController =
      TextEditingController(text: widget.memory.music ?? '');
  late final _titleController =
      TextEditingController(text: widget.memory.title ?? '');

  bool _isSaving = false;
  final _scrollController = ScrollController();

  int get _totalPhotoCount => _existingPhotoPaths.length + _newPhotos.length;
  bool get _isStandalone => widget.memory.isStandalone;
  bool get _useDrive => widget.memory.usesDrive;
  int get _maxPhotos => _useDrive ? kMaxDrivePhotos : kMaxMemoryPhotos;

  List<String> get _editedFields {
    final fields = <String>[];
    final m = widget.memory;
    if (_captionController.text.trim() != (m.caption ?? '')) {
      fields.add('caption');
    }
    if (_placeController.text.trim() != (m.place ?? '')) {
      fields.add('place');
    }
    if (_musicController.text.trim() != (m.music ?? '')) {
      fields.add('music');
    }
    if (_isStandalone && _titleController.text.trim() != (m.title ?? '')) {
      fields.add('title');
    }
    if (_existingPhotoPaths.length != m.photoPaths.length ||
        _newPhotos.isNotEmpty) {
      fields.add('photos');
    }
    return fields;
  }

  @override
  void initState() {
    super.initState();
    _captionController.addListener(() => setState(() {}));
    _placeController.addListener(() => setState(() {}));
    _musicController.addListener(() => setState(() {}));
    _titleController.addListener(() => setState(() {}));
    _resolveExistingThumbs();
  }

  @override
  void dispose() {
    _captionController.dispose();
    _placeController.dispose();
    _musicController.dispose();
    _titleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _resolveExistingThumbs() async {
    if (_existingThumbPaths.isEmpty) return;
    try {
      final urls = await _storageService.resolveUrls(_existingThumbPaths);
      if (mounted) {
        setState(() => _existingThumbUrls
          ..clear()
          ..addAll(urls));
      }
    } catch (_) {}
  }

  Future<void> _pickPhotos() async {
    FocusScope.of(context).unfocus();
    final remaining = _maxPhotos - _totalPhotoCount;
    if (remaining <= 0) return;

    try {
      final picked = await _imagePicker.pickMultiImage(
        limit: remaining,
        imageQuality: 90,
      );
      if (picked.isEmpty || !mounted) return;

      for (final xfile in picked.take(remaining)) {
        final bytes = await xfile.readAsBytes();
        _newPhotos.add(await ImageCompressor.compressFull(bytes));
        _newThumbs.add(await ImageCompressor.compressThumb(bytes));
      }
      if (mounted) setState(() {});
    } catch (_) {
      // Gallery permission denied or other error
    }
  }

  void _removeExistingPhoto(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _existingPhotoPaths.removeAt(index);
      _existingThumbPaths.removeAt(index);
      if (index < _existingThumbUrls.length) {
        _existingThumbUrls.removeAt(index);
      }
    });
  }

  void _removeNewPhoto(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _newPhotos.removeAt(index);
      _newThumbs.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final removedPaths = widget.memory.photoPaths
          .where((p) => !_existingPhotoPaths.contains(p))
          .toList();
      final removedThumbs = widget.memory.thumbPaths
          .where((p) => !_existingThumbPaths.contains(p))
          .toList();
      if (removedPaths.isNotEmpty || removedThumbs.isNotEmpty) {
        final allRemoved = [...removedPaths, ...removedThumbs];
        if (_useDrive) {
          await _driveService.deleteFiles(allRemoved);
        } else {
          await _storageService.deleteFiles(allRemoved);
        }
      }

      var newPhotoPaths = <String>[];
      var newThumbPaths = <String>[];
      if (_newPhotos.isNotEmpty) {
        if (_useDrive) {
          final space = await _firestoreService.getSpaceWithMembers(widget.spaceId);
          final spaceName = space?['name'] as String? ?? 'Kairos';
          final result = await _driveService.uploadPhotos(
            spaceName: spaceName,
            memoryId: widget.memory.id,
            fullPhotos: _newPhotos,
            thumbPhotos: _newThumbs,
            startIndex: _existingPhotoPaths.length,
          );
          if (result != null) {
            newPhotoPaths = result.photoIds;
            newThumbPaths = result.thumbIds;
          }
        } else {
          final result = await _storageService.uploadMemoryPhotos(
            spaceId: widget.spaceId,
            memoryId: widget.memory.id,
            fullPhotos: _newPhotos,
            thumbPhotos: _newThumbs,
            startIndex: _existingPhotoPaths.length,
          );
          newPhotoPaths = result.photoPaths;
          newThumbPaths = result.thumbPaths;
        }
      }

      final updatedMemory = widget.memory.copyWith(
        photoPaths: [..._existingPhotoPaths, ...newPhotoPaths],
        thumbPaths: [..._existingThumbPaths, ...newThumbPaths],
        caption: _captionController.text.trim().isEmpty
            ? null
            : _captionController.text.trim(),
        place: _placeController.text.trim().isEmpty
            ? null
            : _placeController.text.trim(),
        music: _musicController.text.trim().isEmpty
            ? null
            : _musicController.text.trim(),
        title: _isStandalone ? _titleController.text.trim() : null,
      );

      final profile =
          await _firestoreService.getUserProfile(widget.memory.createdBy);
      final actorName = profile?['name'] as String? ?? 'Someone';
      await _firestoreService.updateMemory(
        spaceId: widget.spaceId,
        updatedMemory: updatedMemory,
        editedFields: _editedFields,
        actorName: actorName,
      );

      HapticFeedback.heavyImpact();
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
          title: Text('Edit Memory', style: AppTypography.headlineSmall()),
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
                  if (_isStandalone) _buildTitleField(),
                  if (_isStandalone) const SizedBox(height: 12),
                  _buildPhotoSection(),
                  const SizedBox(height: 12),
                  _buildCaptionField(),
                  const SizedBox(height: 12),
                  _buildPlaceField(),
                  const SizedBox(height: 12),
                  _buildMusicField(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: SlideToAction(
                label: 'Save changes',
                loadingLabel: 'Saving...',
                isLoading: _isSaving,
                onConfirm: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return ActiveCard(
      heading: 'Title',
      isActive: _titleController.text.trim().isNotEmpty,
      child: TextField(
        controller: _titleController,
        style: AppTypography.bodyMedium(),
        maxLength: 100,
        decoration: InputDecoration(
          hintText: 'Memory title',
          hintStyle: AppTypography.bodyMedium(color: AppColors.warmMuted),
          border: InputBorder.none,
          counterStyle: TextStyle(color: AppColors.warmMuted, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return ActiveCard(
      heading: 'Photos',
      isActive: _totalPhotoCount > 0,
      helperText: 'Add up to $_maxPhotos photos',
      child: PhotoPickerGrid(
        existingThumbUrls: _existingThumbUrls,
        newPhotos: _newPhotos,
        onPickPhotos: _pickPhotos,
        onRemoveExisting: _removeExistingPhoto,
        onRemoveNew: _removeNewPhoto,
        maxPhotos: _maxPhotos,
      ),
    );
  }

  Widget _buildCaptionField() {
    return ActiveCard(
      heading: 'Caption',
      isActive: _captionController.text.isNotEmpty,
      child: TextField(
        controller: _captionController,
        style: AppTypography.bodyMedium(),
        maxLength: 280,
        maxLines: 3,
        minLines: 1,
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
      child: TextField(
        controller: _placeController,
        style: AppTypography.bodyMedium(),
        maxLength: 100,
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
      child: TextField(
        controller: _musicController,
        style: AppTypography.bodyMedium(),
        maxLength: 100,
        decoration: InputDecoration(
          hintText: 'A song that reminds you of this',
          hintStyle: AppTypography.bodyMedium(color: AppColors.warmMuted),
          border: InputBorder.none,
          counterText: '',
        ),
      ),
    );
  }
}
