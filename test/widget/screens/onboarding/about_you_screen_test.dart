/// Widget tests for AboutYouScreen (Screen 2 — You).
///
/// Uses a lightweight wrapper that avoids Firebase dependencies.
/// Covers: entrance, name input, attribute selection, overlap subtitle.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:couple_space/models/pulse_config.dart';
import 'package:couple_space/theme/app_colors.dart';
import 'package:couple_space/theme/app_spacing.dart';
import 'package:couple_space/theme/app_typography.dart';

import '../../../helpers/pump_app.dart';

/// Minimal version of AboutYouScreen that tests the UI without Firebase.
/// Mirrors the real screen's Phase 0→1→2 flow.
class _TestAboutYouScreen extends StatefulWidget {
  const _TestAboutYouScreen({required this.onDone});
  final void Function(String name, List<String> picks) onDone;

  @override
  State<_TestAboutYouScreen> createState() => _TestAboutYouScreenState();
}

class _TestAboutYouScreenState extends State<_TestAboutYouScreen> {
  final _nameController = TextEditingController();
  final _selectedAttrs = <String>{};
  bool _showAttributes = false;
  bool _hasName = false;
  bool _showField = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggleAttribute(String id) {
    setState(() {
      if (_selectedAttrs.contains(id)) {
        _selectedAttrs.remove(id);
      } else if (_selectedAttrs.length < 3) {
        _selectedAttrs.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'You',
              style: GoogleFonts.outfit(
                fontSize: 56,
                fontWeight: FontWeight.w700,
                color: AppColors.lightText,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!_showAttributes && !_showField)
              Column(
                children: [
                  Text(
                    'Next, establish your\npresence in the space',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLarge(color: AppColors.warmDim),
                  ),
                  const SizedBox(height: AppSpacing.xxxl),
                  GestureDetector(
                    onTap: () => setState(() => _showField = true),
                    child: Text(
                      'tap to enter your name',
                      style: AppTypography.bodyLarge(
                        color: AppColors.refinedRed,
                      ),
                    ),
                  ),
                ],
              ),
            if (!_showAttributes && _showField)
              SizedBox(
                width: 220,
                child: TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  onChanged: (v) {
                    setState(() => _hasName = v.trim().isNotEmpty);
                  },
                  onFieldSubmitted: (_) {
                    if (_hasName) setState(() => _showAttributes = true);
                  },
                ),
              ),
            if (_showAttributes) ...[
              Text(_nameController.text.trim()),
              const SizedBox(height: 16),
              Text(
                'Select what pulse attributes\nare the most important\nto you',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final attr in PulseAttribute.values)
                    GestureDetector(
                      onTap: () => _toggleAttribute(attr.id),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: _selectedAttrs.contains(attr.id)
                            ? AppColors.accentRed
                            : AppColors.cardVariant,
                        child: Text(attr.displayName),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('${_selectedAttrs.length} of 3'),
              if (_selectedAttrs.length == 3) ...[
                const SizedBox(height: 8),
                const Text(
                  'All members get to pick these.\nOverlapping attributes are\nconsidered more important',
                  textAlign: TextAlign.center,
                ),
              ],
              if (_selectedAttrs.isNotEmpty)
                TextButton(
                  onPressed: () => widget.onDone(
                    _nameController.text.trim(),
                    _selectedAttrs.toList(),
                  ),
                  child: const Text('tap to continue'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

void main() {
  group('AboutYouScreen (test wrapper)', () {
    late String? doneName;
    late List<String>? donePicks;

    setUp(() {
      doneName = null;
      donePicks = null;
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpApp(
        _TestAboutYouScreen(
          onDone: (name, picks) {
            doneName = name;
            donePicks = picks;
          },
        ),
      );
    }

    testWidgets('shows title "You" always', (tester) async {
      await pump(tester);
      expect(find.text('You'), findsOneWidget);
    });

    testWidgets('shows subtitle and prompt initially', (tester) async {
      await pump(tester);
      expect(
        find.text('Next, establish your\npresence in the space'),
        findsOneWidget,
      );
      expect(find.text('tap to enter your name'), findsOneWidget);
    });

    testWidgets('tapping prompt reveals text field', (tester) async {
      await pump(tester);
      await tester.tap(find.text('tap to enter your name'));
      await tester.pump();
      expect(find.byType(TextFormField), findsOneWidget);
    });

    testWidgets('entering name and submitting shows attribute grid', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('tap to enter your name'));
      await tester.pump();

      await tester.enterText(find.byType(TextFormField), 'Alice');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.text('Alice'), findsOneWidget);
      expect(
        find.text(
          'Select what pulse attributes\nare the most important\nto you',
        ),
        findsOneWidget,
      );
    });

    testWidgets('all 8 pulse attributes are displayed', (tester) async {
      await pump(tester);
      await tester.tap(find.text('tap to enter your name'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), 'Alice');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      for (final attr in PulseAttribute.values) {
        expect(find.text(attr.displayName), findsOneWidget);
      }
    });

    testWidgets('selecting 3 attributes shows overlap subtitle', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('tap to enter your name'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), 'Alice');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Select 3 attributes
      await tester.tap(find.text('Connection'));
      await tester.pump();
      await tester.tap(find.text('Trust'));
      await tester.pump();
      await tester.tap(find.text('Growth'));
      await tester.pump();

      expect(find.text('3 of 3'), findsOneWidget);
      expect(
        find.text(
          'All members get to pick these.\nOverlapping attributes are\nconsidered more important',
        ),
        findsOneWidget,
      );
    });

    testWidgets('cannot select more than 3 attributes', (tester) async {
      await pump(tester);
      await tester.tap(find.text('tap to enter your name'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), 'Alice');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      await tester.tap(find.text('Connection'));
      await tester.pump();
      await tester.tap(find.text('Trust'));
      await tester.pump();
      await tester.tap(find.text('Growth'));
      await tester.pump();
      await tester.tap(find.text('Fun'));
      await tester.pump();

      expect(find.text('3 of 3'), findsOneWidget);
    });

    testWidgets('tap to continue calls onDone with name + picks', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('tap to enter your name'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), 'Alice');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      await tester.tap(find.text('Connection'));
      await tester.pump();
      await tester.tap(find.text('Trust'));
      await tester.pump();

      await tester.tap(find.text('tap to continue'));
      await tester.pump();

      expect(doneName, 'Alice');
      expect(donePicks, containsAll(['connection', 'trust']));
    });

    testWidgets('deselecting attribute updates counter', (tester) async {
      await pump(tester);
      await tester.tap(find.text('tap to enter your name'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), 'Alice');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      await tester.tap(find.text('Connection'));
      await tester.pump();
      await tester.tap(find.text('Trust'));
      await tester.pump();

      expect(find.text('2 of 3'), findsOneWidget);

      // Deselect
      await tester.tap(find.text('Trust'));
      await tester.pump();

      expect(find.text('1 of 3'), findsOneWidget);
    });
  });
}
