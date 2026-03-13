/// Lightweight page that loads a memory by ID and shows the detail sheet.
///
/// Used as a route target for deep links (notification taps, activity trail).
/// Immediately opens the bottom sheet on load and pops when dismissed.
library;

import 'package:flutter/material.dart';

import '../../services/firestore_service.dart';
import '../../theme/app_colors.dart';
import 'memory_detail_sheet.dart';

class MemoryDetailPage extends StatefulWidget {
  const MemoryDetailPage({
    super.key,
    required this.spaceId,
    required this.memoryId,
  });

  final String spaceId;
  final String memoryId;

  @override
  State<MemoryDetailPage> createState() => _MemoryDetailPageState();
}

class _MemoryDetailPageState extends State<MemoryDetailPage> {
  final _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _loadAndShowDetail();
  }

  Future<void> _loadAndShowDetail() async {
    try {
      final memory = await _firestoreService.getMemory(
        spaceId: widget.spaceId,
        memoryId: widget.memoryId,
      );
      if (!mounted) return;

      if (memory == null) {
        Navigator.of(context).pop();
        return;
      }

      showMemoryDetailSheet(
        context,
        spaceId: widget.spaceId,
        initialMemory: memory,
      );
    } catch (_) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.pureBlack,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.accentRed),
      ),
    );
  }
}
