library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/memory.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/date_utils.dart';
import '../../widgets/emoji_reaction_picker.dart';

void showMemoryDetailSheet(
  BuildContext context, {
  required String spaceId,
  required Memory initialMemory,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MemoryDetailContent(spaceId: spaceId, initialMemory: initialMemory),
  );
}

class _MemoryDetailContent extends StatefulWidget {
  const _MemoryDetailContent({required this.spaceId, required this.initialMemory});

  final String spaceId;
  final Memory initialMemory;

  @override
  State<_MemoryDetailContent> createState() => _MemoryDetailContentState();
}

class _MemoryDetailContentState extends State<_MemoryDetailContent> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _storageService = StorageService();

  late Memory _memory;
  StreamSubscription? _memorySub;
  final _photoUrls = <String>[];
  bool _loadingPhotos = false;
  bool _isReordering = false;
  List<String> _reorderPhotoPaths = [];
  List<String> _reorderThumbPaths = [];
  List<String> _reorderPhotoUrls = [];
  String _creatorName = '';

  String? get _currentUserId => _authService.currentUser?.uid;
  bool get _isCreator => _currentUserId == _memory.createdBy;

  @override
  void initState() {
    super.initState();
    _memory = widget.initialMemory;
    _loadCreatorName();
    _resolvePhotos();
    _subscribeToMemory();
  }

  @override
  void dispose() {
    _memorySub?.cancel();
    super.dispose();
  }

  void _subscribeToMemory() {
    _memorySub = _firestoreService
        .watchMemory(widget.spaceId, widget.initialMemory.id)
        .listen((memory) {
      if (!mounted || memory == null) return;
      setState(() => _memory = memory);
    });
  }

  Future<void> _loadCreatorName() async {
    final profile = await _firestoreService.getUserProfile(_memory.createdBy);
    if (mounted) setState(() => _creatorName = profile?['name'] as String? ?? 'Someone');
  }

  Future<void> _resolvePhotos() async {
    if (_memory.photoPaths.isEmpty) return;
    setState(() => _loadingPhotos = true);
    try {
      final urls = await _storageService.resolveUrls(_memory.photoPaths);
      if (mounted) setState(() => _photoUrls..clear()..addAll(urls));
    } catch (_) {}
    if (mounted) setState(() => _loadingPhotos = false);
  }

  Future<void> _toggleReaction(String emoji) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      if (_memory.reactions[uid] == emoji) {
        await _firestoreService.removeReaction(
          spaceId: widget.spaceId, memoryId: _memory.id, userId: uid,
        );
      } else {
        await _firestoreService.setReaction(
          spaceId: widget.spaceId, memoryId: _memory.id, userId: uid, emoji: emoji,
        );
        final profile = await _firestoreService.getUserProfile(uid);
        final userName = profile?['name'] as String? ?? 'Someone';
        await _firestoreService.logMemoryReactionActivity(
          spaceId: widget.spaceId, userId: uid, userName: userName,
          memoryId: _memory.id, memoryTitle: _memory.displayTitle, emoji: emoji,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteMemory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.darkCardLight,
        title: Text('Delete this memory?', style: AppTypography.headlineSmall()),
        content: Text(
          'This will permanently remove this memory. This action cannot be undone.',
          style: AppTypography.bodyMedium(color: AppColors.warmDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.warmDim)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _storageService.deleteAllMemoryPhotos(
        spaceId: widget.spaceId, memoryId: _memory.id,
      );
      final profile = await _firestoreService.getUserProfile(_memory.createdBy);
      final actorName = profile?['name'] as String? ?? 'Someone';
      await _firestoreService.deleteMemory(
        spaceId: widget.spaceId, memory: _memory, actorName: actorName,
      );
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Reorder
  // ---------------------------------------------------------------------------

  void _enterReorderMode() {
    if (_photoUrls.length != _memory.photoPaths.length) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isReordering = true;
      _reorderPhotoPaths = [..._memory.photoPaths];
      _reorderThumbPaths = [..._memory.thumbPaths];
      _reorderPhotoUrls = [..._photoUrls];
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final idx = newIndex > oldIndex ? newIndex - 1 : newIndex;
      final path = _reorderPhotoPaths.removeAt(oldIndex);
      _reorderPhotoPaths.insert(idx, path);
      final thumb = _reorderThumbPaths.removeAt(oldIndex);
      _reorderThumbPaths.insert(idx, thumb);
      final url = _reorderPhotoUrls.removeAt(oldIndex);
      _reorderPhotoUrls.insert(idx, url);
    });
    HapticFeedback.selectionClick();
  }

  void _cancelReorder() {
    setState(() => _isReordering = false);
  }

  Future<void> _savePhotoOrder(
    List<String> newPhotoPaths,
    List<String> newThumbPaths,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('spaces')
          .doc(widget.spaceId)
          .collection('memories')
          .doc(_memory.id)
          .update({
        'photoPaths': newPhotoPaths,
        'thumbPaths': newThumbPaths,
      });
      if (mounted) {
        setState(() {
          _memory = _memory.copyWith(
            photoPaths: [...newPhotoPaths],
            thumbPaths: [...newThumbPaths],
          );
          _photoUrls
            ..clear()
            ..addAll(_reorderPhotoUrls);
          _isReordering = false;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reorder: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.pureBlack,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.warmMuted.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildHeader(),
              if (_memory.hasPhotos) ...[const SizedBox(height: 16), _buildPhotoCarousel()],
              if (_memory.hasCaption) ...[const SizedBox(height: 16), _buildCaption()],
              if (_memory.hasPlace || _memory.hasMusic) ...[const SizedBox(height: 12), _buildTags()],
              const SizedBox(height: 20),
              _buildReactionSection(),
              if (_isCreator) ...[const SizedBox(height: 20), _buildCreatorActions()],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _memory.displayTitle.isEmpty ? 'Memory' : _memory.displayTitle,
          style: AppTypography.headlineMedium(),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              'By $_creatorName on ${AppDateFormat.short(_memory.date)}',
              style: AppTypography.bodySmall(color: AppColors.warmDim),
            ),
            if (_memory.isEdited) ...[
              const SizedBox(width: 6),
              Text('(edited)', style: AppTypography.bodySmall(color: AppColors.warmMuted)),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPhotoCarousel() {
    if (_loadingPhotos && _photoUrls.isEmpty) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator(color: AppColors.accentRed)),
      );
    }
    if (_isReordering) return _buildReorderView();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isCreator && _photoUrls.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _enterReorderMode,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.swap_vert, size: 16, color: AppColors.warmDim),
                    const SizedBox(width: 4),
                    Text('Reorder', style: AppTypography.bodySmall(color: AppColors.warmDim)),
                  ],
                ),
              ),
            ),
          ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _photoUrls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                _photoUrls[i], height: 220, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 180, height: 220, color: AppColors.cardVariant,
                  child: const Icon(Icons.broken_image, color: AppColors.warmMuted),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReorderView() {
    final itemCount = _reorderPhotoUrls.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'REORDER PHOTOS',
              style: GoogleFonts.outfit(
                color: AppColors.warmMuted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: _cancelReorder,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('Cancel', style: AppTypography.bodySmall(color: AppColors.warmDim)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _savePhotoOrder(_reorderPhotoPaths, _reorderThumbPaths),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('Done', style: AppTypography.bodySmall(color: AppColors.accentRed)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: itemCount * 72.0,
          child: ReorderableListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            itemCount: itemCount,
            onReorder: _onReorder,
            proxyDecorator: (child, _, __) => Material(
              color: Colors.transparent,
              elevation: 6,
              shadowColor: Colors.black54,
              borderRadius: BorderRadius.circular(10),
              child: child,
            ),
            itemBuilder: (context, index) {
              return Container(
                key: ValueKey(_reorderPhotoPaths[index]),
                height: 68,
                margin: const EdgeInsets.symmetric(vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.darkCardLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _reorderPhotoUrls[index],
                        width: 52, height: 52, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 52, height: 52, color: AppColors.cardVariant,
                          child: const Icon(Icons.broken_image, size: 20, color: AppColors.warmMuted),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text('Photo ${index + 1}', style: AppTypography.bodySmall()),
                    const Spacer(),
                    const Icon(Icons.drag_handle, color: AppColors.warmMuted),
                    const SizedBox(width: 12),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCaption() {
    return Text(_memory.caption!, style: AppTypography.bodyMedium());
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (_memory.hasPlace)
          _buildTag(Icons.place_outlined, _memory.place!),
        if (_memory.hasMusic)
          _buildTag(Icons.music_note_outlined, _memory.music!),
      ],
    );
  }

  Widget _buildTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.warmMuted),
          const SizedBox(width: 5),
          Text(text, style: GoogleFonts.inter(fontSize: 13, color: AppColors.warmDim)),
        ],
      ),
    );
  }

  Widget _buildReactionSection() {
    final uid = _currentUserId;
    final myReaction = uid != null ? _memory.reactions[uid] : null;
    final partnerReaction = _memory.reactions.entries
        .where((e) => e.key != uid)
        .map((e) => e.value)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (partnerReaction != null) ...[
          Row(
            children: [
              Text(partnerReaction, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Text('Partner reacted', style: AppTypography.bodySmall(color: AppColors.warmDim)),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Text('REACT', style: GoogleFonts.outfit(
          color: AppColors.warmMuted, fontSize: 10,
          fontWeight: FontWeight.w600, letterSpacing: 1.5,
        )),
        const SizedBox(height: 8),
        EmojiReactionPicker(
          selectedEmoji: myReaction,
          onSelected: _toggleReaction,
        ),
      ],
    );
  }

  Widget _buildCreatorActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              context.push('/memory/${widget.spaceId}/${_memory.id}/edit', extra: _memory);
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.lightText,
              side: BorderSide(color: AppColors.warmMuted.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _deleteMemory,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Delete'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
