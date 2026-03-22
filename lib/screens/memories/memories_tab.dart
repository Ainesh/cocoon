/// Memories tab — image-focused timeline with dual sliders per entry.
///
/// Each card contains: icon + title + date header, a left-aligned photo
/// slider, and a per-member memory detail card slider (current user first,
/// partner peeking from the right).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/memory.dart';
import '../../models/moment.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/date_utils.dart';
import '../../widgets/memory_sliders.dart';
import '../../widgets/moment_type_icon.dart';
import '../../widgets/neumorphic_container.dart';
import '../memory/memory_detail_sheet.dart';
import '../memory/memory_photos_view.dart';
import '../moment/moment_details_sheet.dart';

class MemoriesTab extends StatefulWidget {
  const MemoriesTab({super.key, required this.spaceId});

  final String spaceId;

  @override
  State<MemoriesTab> createState() => _MemoriesTabState();
}

class _MemoriesTabState extends State<MemoriesTab> {
  // ---------------------------------------------------------------------------
  // Services
  // ---------------------------------------------------------------------------

  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  StreamSubscription? _memoriesSub;
  List<Memory> _allMemories = [];
  bool _isLoading = true;

  final _nameCache = <String, String>{};

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void dispose() {
    _memoriesSub?.cancel();
    super.dispose();
  }

  void _subscribe() {
    _memoriesSub = _firestoreService
        .watchMemories(widget.spaceId)
        .listen((memories) async {
      if (!mounted) return;

      final uniqueUserIds = memories.map((m) => m.createdBy).toSet();
      for (final uid in uniqueUserIds) {
        if (!_nameCache.containsKey(uid)) {
          final profile = await _firestoreService.getUserProfile(uid);
          _nameCache[uid] = profile?['name'] as String? ?? 'Someone';
        }
      }

      if (!mounted) return;
      setState(() {
        _allMemories = memories;
        _isLoading = false;
      });
    });
  }

  // ---------------------------------------------------------------------------
  // Timeline Grouping
  // ---------------------------------------------------------------------------

  List<_TimelineEntry> _buildTimeline() {
    final momentGroups = <String, List<Memory>>{};
    final standalones = <Memory>[];

    for (final m in _allMemories) {
      if (!m.hasContent) continue;
      if (m.momentId != null) {
        momentGroups.putIfAbsent(m.momentId!, () => []).add(m);
      } else {
        standalones.add(m);
      }
    }

    final entries = <_TimelineEntry>[];

    for (final group in momentGroups.values) {
      group.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final rep = group.first;
      entries.add(_TimelineEntry(
        sortDate: rep.date,
        header: _GroupHeaderData(
          momentName: rep.momentName ?? '',
          momentType: rep.momentType,
          date: rep.momentDate ?? rep.date,
          place: group.map((m) => m.momentPlace).whereType<String>().firstOrNull,
        ),
        memories: group,
      ));
    }

    for (final m in standalones) {
      entries.add(_TimelineEntry(sortDate: m.date, memories: [m]));
    }

    entries.sort((a, b) => b.sortDate.compareTo(a.sortDate));
    return entries;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _openCreateStandalone() {
    HapticFeedback.mediumImpact();
    context.push('/memory/${widget.spaceId}/create');
  }

  Future<void> _openMemoryDetail(Memory memory) async {
    HapticFeedback.lightImpact();

    if (memory.momentId != null) {
      try {
        final moment = await _firestoreService.getMoment(
          spaceId: widget.spaceId,
          momentId: memory.momentId!,
        );
        if (!mounted || moment == null) return;
        showMomentDetailsSheet(
          context: context,
          moment: moment,
          spaceId: widget.spaceId,
        );
      } catch (_) {
        if (mounted) {
          showMemoryDetailSheet(context,
              spaceId: widget.spaceId, initialMemory: memory);
        }
      }
      return;
    }

    showMemoryDetailSheet(context,
        spaceId: widget.spaceId, initialMemory: memory);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accentRed));
    }
    if (_allMemories.isEmpty) return _buildEmptyState();
    return _buildTimelineList();
  }

  Widget _buildTimelineList() {
    final entries = _buildTimeline();

    return ListView.builder(
      reverse: true,
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.xxl * 3,
        AppSpacing.screenPadding,
        AppSpacing.sm,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _TimelineEntryCard(
          entry: entries[index],
          currentUserId: _authService.currentUser?.uid,
          nameCache: _nameCache,
          spaceId: widget.spaceId,
          onMemoryTap: _openMemoryDetail,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Empty State
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: EmptyState(
          icon: Icons.center_focus_strong_rounded,
          title: 'Your story starts here',
          subtitle: 'Live a moment, create a memory.',
          actionLabel: 'Add a memory',
          onAction: _openCreateStandalone,
        ),
      ),
    );
  }
}

// =============================================================================
// Timeline Entry Card — owns the sync notifier between the two sliders
// =============================================================================

class _TimelineEntryCard extends StatefulWidget {
  const _TimelineEntryCard({
    required this.entry,
    required this.currentUserId,
    required this.nameCache,
    required this.spaceId,
    required this.onMemoryTap,
  });

  final _TimelineEntry entry;
  final String? currentUserId;
  final Map<String, String> nameCache;
  final String spaceId;
  final ValueChanged<Memory> onMemoryTap;

  @override
  State<_TimelineEntryCard> createState() => _TimelineEntryCardState();
}

class _TimelineEntryCardState extends State<_TimelineEntryCard> {
  final _activeMember = ValueNotifier<int>(0);

  @override
  void dispose() {
    _activeMember.dispose();
    super.dispose();
  }

  List<Memory> _sortedMemories() {
    final sorted = List<Memory>.from(widget.entry.memories);
    if (widget.currentUserId != null) {
      sorted.sort((a, b) {
        if (a.createdBy == widget.currentUserId &&
            b.createdBy != widget.currentUserId) return -1;
        if (a.createdBy != widget.currentUserId &&
            b.createdBy == widget.currentUserId) return 1;
        return a.createdAt.compareTo(b.createdAt);
      });
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedMemories();

    final allPhotoPaths = <String>[];
    final photoOwnerIndices = <int>[];
    final memberFirstPhoto = <int>[];

    for (int mi = 0; mi < sorted.length; mi++) {
      memberFirstPhoto.add(allPhotoPaths.length);
      for (final path in sorted[mi].photoPaths) {
        allPhotoPaths.add(path);
        photoOwnerIndices.add(mi);
      }
    }

    final maxPhotos = sorted.length * 3;
    final showAddCard = allPhotoPaths.length < maxPhotos;
    final hasSliderItems = allPhotoPaths.isNotEmpty || showAddCard;

    final entryTitle = widget.entry.header != null
        ? widget.entry.header!.momentName
        : widget.entry.memories.first.displayTitle;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: GestureDetector(
        onTap: () => widget.onMemoryTap(sorted.first),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.darkCardLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.warmMuted.withValues(alpha: 0.15),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentRed.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildHeader(),
              ),
              if (hasSliderItems)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _PhotoSlider(
                    title: entryTitle,
                    photoPaths: allPhotoPaths,
                    showAddCard: showAddCard,
                    onAddTap: () => widget.onMemoryTap(sorted.first),
                    photoOwnerIndices: photoOwnerIndices,
                    memberFirstPhoto: memberFirstPhoto,
                    activeMemberNotifier: _activeMember,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 12),
                child: _MemberCardSlider(
                  memories: sorted,
                  currentUserId: widget.currentUserId,
                  nameCache: widget.nameCache,
                  spaceId: widget.spaceId,
                  activeMemberNotifier: _activeMember,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final entry = widget.entry;
    final MomentType? type;
    final String title;
    final DateTime date;
    final String? place;

    if (entry.header != null) {
      type = entry.header!.momentType != null
          ? MomentType.fromValue(entry.header!.momentType!)
          : null;
      title = entry.header!.momentName;
      date = entry.header!.date;
      place = entry.header!.place;
    } else {
      type = null;
      title = entry.memories.first.displayTitle;
      date = entry.memories.first.date;
      place = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (type != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accentRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: getMomentTypeIconWidget(
                    type,
                    size: 18,
                    color: AppColors.accentRed,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  color: AppColors.warmLight,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              AppDateFormat.compact(date),
              style: GoogleFonts.inter(
                color: AppColors.accentRed,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (place != null && place.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(
                top: 4, left: type != null ? 48 : 0),
            child: Row(
              children: [
                Icon(Icons.place_outlined,
                    size: 13, color: AppColors.warmDim),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    place,
                    style: GoogleFonts.inter(
                      color: AppColors.warmDim,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// Photo Slider — left-aligned horizontal ListView
// =============================================================================

class _PhotoSlider extends StatefulWidget {
  const _PhotoSlider({
    required this.title,
    required this.photoPaths,
    this.showAddCard = false,
    this.onAddTap,
    required this.photoOwnerIndices,
    required this.memberFirstPhoto,
    required this.activeMemberNotifier,
  });

  final String title;
  final List<String> photoPaths;
  final bool showAddCard;
  final VoidCallback? onAddTap;
  final List<int> photoOwnerIndices;
  final List<int> memberFirstPhoto;
  final ValueNotifier<int> activeMemberNotifier;

  @override
  State<_PhotoSlider> createState() => _PhotoSliderState();
}

class _PhotoSliderState extends State<_PhotoSlider> {
  final _storageService = StorageService();
  final _scrollController = ScrollController();
  List<String> _urls = [];
  bool _loading = false;
  bool _isSyncing = false;
  int _lastReportedMember = 0;

  @override
  void initState() {
    super.initState();
    _resolve();
    widget.activeMemberNotifier.addListener(_onExternalMemberChange);
  }

  @override
  void didUpdateWidget(_PhotoSlider old) {
    super.didUpdateWidget(old);
    if (old.activeMemberNotifier != widget.activeMemberNotifier) {
      old.activeMemberNotifier.removeListener(_onExternalMemberChange);
      widget.activeMemberNotifier.addListener(_onExternalMemberChange);
    }
    if (old.photoPaths.length != widget.photoPaths.length ||
        old.photoPaths.toString() != widget.photoPaths.toString()) {
      _resolve();
    }
  }

  @override
  void dispose() {
    widget.activeMemberNotifier.removeListener(_onExternalMemberChange);
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  void _onExternalMemberChange() {
    if (_isSyncing) return;
    final mi = widget.activeMemberNotifier.value;
    if (mi == _lastReportedMember) return;
    if (mi < 0 || mi >= widget.memberFirstPhoto.length) return;
    final targetPhoto = widget.memberFirstPhoto[mi];
    if (targetPhoto >= widget.photoPaths.length) return;
    if (!_scrollController.hasClients) return;

    final tileWidth = MediaQuery.of(context).size.width * 0.88;
    final targetOffset = targetPhoto * (tileWidth + 8);

    _isSyncing = true;
    _lastReportedMember = mi;
    _scrollController
        .animateTo(
          targetOffset.clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        )
        .then((_) => _isSyncing = false);
  }

  void _onScrollEnd(ScrollMetrics metrics) {
    if (_isSyncing || widget.photoOwnerIndices.isEmpty) return;
    final tileWidth = MediaQuery.of(context).size.width * 0.88;
    final photoIndex = (metrics.pixels / (tileWidth + 8))
        .round()
        .clamp(0, widget.photoOwnerIndices.length - 1);
    final memberIdx = widget.photoOwnerIndices[photoIndex];
    if (memberIdx != _lastReportedMember) {
      _lastReportedMember = memberIdx;
      _isSyncing = true;
      widget.activeMemberNotifier.value = memberIdx;
      _isSyncing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _openGallery(int index) {
    if (_urls.isEmpty) return;
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemoryPhotosView(
          title: widget.title,
          photoUrls: _urls,
          initialIndex: index,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // URL / Height Resolution
  // ---------------------------------------------------------------------------

  Future<void> _resolve() async {
    if (widget.photoPaths.isEmpty) {
      if (mounted) setState(() => _urls = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final urls = await _storageService.resolveUrls(widget.photoPaths);
      if (!mounted) return;
      setState(() {
        _urls = urls;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  int get _itemCount => _urls.length + (widget.showAddCard ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    if (_loading && _urls.isEmpty) {
      return Container(
        height: MediaQuery.of(context).size.width * 0.88 * 1.25,
        margin: const EdgeInsets.only(left: 16, right: 16),
        decoration: BoxDecoration(
          color: AppColors.cardVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        ),
        child: const Center(
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

    if (_itemCount == 0) return const SizedBox.shrink();

    final tileWidth = MediaQuery.of(context).size.width * 0.88;
    final sliderHeight = tileWidth * 1.25;

    return SizedBox(
      height: sliderHeight,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _isSyncing = false;
            HapticFeedback.lightImpact();
          } else if (notification is ScrollEndNotification) {
            if (!_isSyncing) HapticFeedback.selectionClick();
            _onScrollEnd(notification.metrics);
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: SnapScrollPhysics(itemExtent: tileWidth + 8),
          padding: const EdgeInsets.only(left: 16, right: 16),
          itemCount: _itemCount,
          itemBuilder: (context, index) {
            if (index >= _urls.length) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: tileWidth,
                  height: sliderHeight,
                  child: _buildAddCard(),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => _openGallery(index),
                child: SizedBox(
                  width: tileWidth,
                  height: sliderHeight,
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMedium),
                    child: _buildPhoto(_urls[index]),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPhoto(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Container(color: AppColors.cardVariant);
      },
      errorBuilder: (_, e, st) => Container(
        color: AppColors.cardVariant,
        child: const Center(
          child: Icon(
            Icons.broken_image_rounded,
            color: AppColors.warmMuted,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildAddCard() {
    return GestureDetector(
      onTap: widget.onAddTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(
            color: AppColors.warmMuted.withValues(alpha: 0.2),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.warmMuted,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'Add photo',
                style: GoogleFonts.inter(
                  color: AppColors.warmMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Member Card Slider — per-member memory detail cards
// =============================================================================

class _MemberCardSlider extends StatefulWidget {
  const _MemberCardSlider({
    required this.memories,
    required this.currentUserId,
    required this.nameCache,
    required this.spaceId,
    required this.activeMemberNotifier,
  });

  final List<Memory> memories;
  final String? currentUserId;
  final Map<String, String> nameCache;
  final String spaceId;
  final ValueNotifier<int> activeMemberNotifier;

  @override
  State<_MemberCardSlider> createState() => _MemberCardSliderState();
}

class _MemberCardSliderState extends State<_MemberCardSlider> {
  ScrollController? _scrollController;
  bool _isSyncing = false;
  int _lastReportedMember = 0;

  bool get _hasSlider => widget.memories.length > 1;

  @override
  void initState() {
    super.initState();
    if (_hasSlider) {
      _scrollController = ScrollController();
      widget.activeMemberNotifier.addListener(_onExternalMemberChange);
    }
  }

  @override
  void didUpdateWidget(_MemberCardSlider old) {
    super.didUpdateWidget(old);
    if (old.activeMemberNotifier != widget.activeMemberNotifier &&
        _hasSlider) {
      old.activeMemberNotifier.removeListener(_onExternalMemberChange);
      widget.activeMemberNotifier.addListener(_onExternalMemberChange);
    }
  }

  @override
  void dispose() {
    if (_hasSlider) {
      widget.activeMemberNotifier.removeListener(_onExternalMemberChange);
    }
    _scrollController?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  void _onExternalMemberChange() {
    if (_isSyncing) return;
    final mi = widget.activeMemberNotifier.value;
    if (mi == _lastReportedMember) return;
    if (mi < 0 || mi >= widget.memories.length) return;
    if (_scrollController == null || !_scrollController!.hasClients) return;

    final cardWidth = MediaQuery.of(context).size.width * 0.88;
    final targetOffset = mi * (cardWidth + 8);

    _isSyncing = true;
    _lastReportedMember = mi;
    _scrollController!
        .animateTo(
          targetOffset.clamp(
            _scrollController!.position.minScrollExtent,
            _scrollController!.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        )
        .then((_) => _isSyncing = false);
  }

  void _onScrollEnd(ScrollMetrics metrics) {
    if (_isSyncing) return;
    final cardWidth = MediaQuery.of(context).size.width * 0.88;
    final memberIdx = (metrics.pixels / (cardWidth + 8))
        .round()
        .clamp(0, widget.memories.length - 1);
    if (memberIdx != _lastReportedMember) {
      _lastReportedMember = memberIdx;
      _isSyncing = true;
      widget.activeMemberNotifier.value = memberIdx;
      _isSyncing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final sorted = widget.memories;

    if (sorted.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: MemoryMemberCard(
          memory: sorted.first,
          creatorName:
              widget.nameCache[sorted.first.createdBy] ?? 'Someone',
          spaceId: widget.spaceId,
          isCurrentUser: sorted.first.createdBy == widget.currentUserId,
        ),
      );
    }

    final cardWidth = MediaQuery.of(context).size.width * 0.88;

    return SizedBox(
      height: _estimateCardHeight(sorted),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _isSyncing = false;
            HapticFeedback.lightImpact();
          } else if (notification is ScrollEndNotification) {
            if (!_isSyncing) HapticFeedback.selectionClick();
            _onScrollEnd(notification.metrics);
          }
          return false;
        },
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: SnapScrollPhysics(itemExtent: cardWidth + 8),
          padding: const EdgeInsets.only(left: 16, right: 16),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SizedBox(
                width: cardWidth,
                child: MemoryMemberCard(
                  memory: sorted[index],
                  creatorName:
                      widget.nameCache[sorted[index].createdBy] ??
                          'Someone',
                  spaceId: widget.spaceId,
                  isCurrentUser:
                      sorted[index].createdBy == widget.currentUserId,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  double _estimateCardHeight(List<Memory> sorted) {
    double max = 72;
    for (final m in sorted) {
      double h = 72;
      if (m.hasCaption) h += 52;
      if (m.hasMusic) h += 30;
      if (m.hasCheckin) {
        h += 24;
      } else if (m.createdBy == widget.currentUserId) {
        h += 34;
      }
      if (h > max) max = h;
    }
    return max;
  }
}

// =============================================================================
// Internal Data Structures
// =============================================================================

class _GroupHeaderData {
  const _GroupHeaderData({
    required this.momentName,
    this.momentType,
    required this.date,
    this.place,
  });

  final String momentName;
  final String? momentType;
  final DateTime date;
  final String? place;
}

class _TimelineEntry {
  const _TimelineEntry({
    required this.sortDate,
    this.header,
    required this.memories,
  });

  final DateTime sortDate;
  final _GroupHeaderData? header;
  final List<Memory> memories;
}
