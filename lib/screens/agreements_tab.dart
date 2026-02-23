/// Agreements tab placeholder for Couple Space app.
///
/// Placeholder screen for future agreements feature with premium neumorphic UI.
library;

import 'package:flutter/material.dart';

import '../widgets/neumorphic_container.dart';

// Theme constants for premium styling
const _refinedRed = Color(0xFFFF4444);
const _lightText = Color(0xFFF5F5F5);
const _bodyGray = Color(0xFFD1D5DB);
const _dimText = Color(0xFF9CA3AF);
const _cardVariant = Color(0xFF2A2A2A);

/// Agreements tab placeholder.
class AgreementsTab extends StatelessWidget {
  const AgreementsTab({super.key, required this.spaceId});

  final String spaceId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon with glow
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _cardVariant,
                shape: BoxShape.circle,
                border: Border.all(color: _refinedRed.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: _refinedRed.withValues(alpha: 0.15),
                    blurRadius: 24,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.handshake_outlined,
                size: 64,
                color: _dimText,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            const Text(
              'Agreements',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _lightText,
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            const Text(
              'Create shared agreements with your partner.\nTrack commitments and relationship boundaries.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: _bodyGray, height: 1.5),
            ),
            const SizedBox(height: 24),

            // Coming soon badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: _refinedRed.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _refinedRed.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: _refinedRed.withValues(alpha: 0.1),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.construction_rounded,
                    color: _refinedRed,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Coming soon',
                    style: TextStyle(
                      fontSize: 14,
                      color: _refinedRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Preview card
            PremiumCard(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Example Agreements',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _dimText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildExampleItem('📅', 'Weekly date night on Saturdays'),
                  _buildExampleItem('📱', 'No phones during dinner'),
                  _buildExampleItem(
                    '💬',
                    'Check in before making big purchases',
                  ),
                  _buildExampleItem('🏠', 'Split household chores fairly'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _cardVariant,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _refinedRed.withValues(alpha: 0.1)),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 15, color: _bodyGray),
            ),
          ),
        ],
      ),
    );
  }
}
