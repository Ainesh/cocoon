/// Memory card widget for the timeline.
///
/// Displays a single memory with thumbnail strip, caption snippet,
/// place/music tags, reaction badge, creator name, and date.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/memory.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/date_utils.dart';

/// A card displaying a single memory in the timeline.
class MemoryCard extends StatefulWidget {
  const MemoryCard({
    super.key,
    required this.memory,
    required this.creatorName,
    this.currentUserId,
    this.onTap,
  });

  final Memory memory;
  final String creatorName;
  final String? currentUserId;
  final VoidCallback? onTap;

  @override
  State<MemoryCard> createState() => _MemoryCardState();
}

class _MemoryCardState extends State<MemoryCard> {
  final _storageService = StorageService();
  final _thumbUrls = <String>[];
  bool _loadingThumbs = false;

  @override
  void initState() {
    super.initState();
    _resolveThumbnails();
  }

  @override
  void didUpdateWidget(MemoryCard old) {
    super.didUpdateWidget(old);
    if (old.memory.thumbPaths != widget.memory.thumbPaths) {
      _resolveThumbnails();
    }
  }

  Future<void> _resolveThumbnails() async {
    if (widget.memory.thumbPaths.isEmpty) return;
    setState(() => _loadingThumbs = true);
    try {
      final urls = await _storageService.resolveUrls(widget.memory.thumbPaths);
      if (mounted) setState(() => _thumbUrls
        ..clear()
        ..addAll(urls));
    } catch (_) {
      // URL resolution failed; show placeholders
    } finally {
      if (mounted) setState(() => _loadingThumbs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.memory;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.darkCardLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.warmMuted.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail strip
            if (m.hasPhotos) ...[
              _buildThumbnailStrip(),
              const SizedBox(height: 10),
            ],

            // Caption
            if (m.hasCaption)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  m.caption!,
                  style: AppTypography.bodyMedium(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Tags row
            _buildTags(m),

            const SizedBox(height: 8),

            // Footer: creator + date + reaction
            _buildFooter(m),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailStrip() {
    if (_loadingThumbs && _thumbUrls.isEmpty) {
      return SizedBox(
        height: 80,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.warmMuted,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _thumbUrls.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) => ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            _thumbUrls[i],
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 80,
              height: 80,
              color: AppColors.cardVariant,
              child: Icon(Icons.broken_image, color: AppColors.warmMuted, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTags(Memory m) {
    final tags = <Widget>[];

    if (m.hasPlace) {
      tags.add(_Tag(icon: Icons.place_outlined, text: m.place!));
    }
    if (m.hasMusic) {
      tags.add(_Tag(icon: Icons.music_note_outlined, text: m.music!));
    }

    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: tags,
    );
  }

  Widget _buildFooter(Memory m) {
    final reactionEmoji = _partnerReaction(m);

    return Row(
      children: [
        Text(
          widget.creatorName,
          style: AppTypography.bodySmall(color: AppColors.warmDim),
        ),
        const SizedBox(width: 6),
        Text(
          '·',
          style: AppTypography.bodySmall(color: AppColors.warmMuted),
        ),
        const SizedBox(width: 6),
        Text(
          AppDateFormat.compact(m.date),
          style: AppTypography.bodySmall(color: AppColors.warmMuted),
        ),
        if (m.isEdited) ...[
          const SizedBox(width: 6),
          Text(
            '· Edited',
            style: AppTypography.bodySmall(color: AppColors.warmMuted),
          ),
        ],
        const Spacer(),
        if (reactionEmoji != null)
          Text(reactionEmoji, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  String? _partnerReaction(Memory m) {
    final uid = widget.currentUserId;
    if (uid == null || m.reactions.isEmpty) return null;
    for (final entry in m.reactions.entries) {
      if (entry.key != uid) return entry.value;
    }
    return null;
  }
}

/// A small chip showing an icon + text for place/music tags.
class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.cardVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.warmMuted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.warmDim,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
