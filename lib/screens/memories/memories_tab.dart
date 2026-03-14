/// Memories tab — a vertical chronological timeline of sealed memories.
///
/// Groups moment-linked memories under shared headers (FR-5.6.5).
/// Standalone memories appear as individual cards (FR-5.6.6).
/// Newest first (FR-5.6.3). FAB for standalone creation (FR-5.3.2).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/memory.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/memory_card.dart';
import '../../widgets/moment_group_header.dart';
import '../../widgets/neumorphic_container.dart';
import '../memory/memory_detail_sheet.dart';
import '../moment/moment_details_sheet.dart';

/// The Memories tab content — 3rd tab in the main shell.
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

  /// Cache: userId → display name.
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

      // Resolve creator names
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

  /// Builds a flat list of display items: moment group headers + individual cards.
  /// Moment-linked memories are grouped; standalone appear individually.
  /// All sorted by date descending (newest first).
  List<_TimelineEntry> _buildTimeline() {
    final momentGroups = <String, List<Memory>>{};
    final standalones = <Memory>[];

    for (final m in _allMemories) {
      if (m.momentId != null) {
        momentGroups.putIfAbsent(m.momentId!, () => []).add(m);
      } else {
        standalones.add(m);
      }
    }

    final entries = <_TimelineEntry>[];

    for (final group in momentGroups.values) {
      group.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final representative = group.first;
      entries.add(_TimelineEntry(
        sortDate: representative.date,
        header: _GroupHeaderData(
          momentName: representative.momentName ?? '',
          momentType: representative.momentType,
          date: representative.momentDate ?? representative.date,
        ),
        memories: group,
      ));
    }

    for (final m in standalones) {
      entries.add(_TimelineEntry(
        sortDate: m.date,
        memories: [m],
      ));
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

    // For moment-linked memories, open the unified moment sheet
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
        // Fallback to memory detail sheet if moment can't be loaded
        if (mounted) {
          showMemoryDetailSheet(context, spaceId: widget.spaceId, initialMemory: memory);
        }
      }
      return;
    }

    // Standalone memories use the existing detail sheet
    showMemoryDetailSheet(context, spaceId: widget.spaceId, initialMemory: memory);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentRed));
    }
    if (_allMemories.isEmpty) {
      return _buildEmptyState();
    }
    return _buildTimeline_widget();
  }

  Widget _buildTimeline_widget() {
    final entries = _buildTimeline();

    return ListView.builder(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: entries.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Memories',
              style: GoogleFonts.cormorantGaramond(
                fontSize: 36,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                color: AppColors.accentRed,
              ),
            ),
          );
        }
        return _buildTimelineEntry(entries[index - 1]);
      },
    );
  }

  Widget _buildTimelineEntry(_TimelineEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (entry.header != null)
          MomentGroupHeader(
            momentName: entry.header!.momentName,
            momentType: entry.header!.momentType,
            date: entry.header!.date,
          ),
        for (final memory in entry.memories) ...[
          MemoryCard(
            memory: memory,
            creatorName: _nameCache[memory.createdBy] ?? 'Someone',
            currentUserId: _authService.currentUser?.uid,
            onTap: () => _openMemoryDetail(memory),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

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
// Internal Data Structures
// =============================================================================

class _GroupHeaderData {
  const _GroupHeaderData({
    required this.momentName,
    this.momentType,
    required this.date,
  });

  final String momentName;
  final String? momentType;
  final DateTime date;
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
