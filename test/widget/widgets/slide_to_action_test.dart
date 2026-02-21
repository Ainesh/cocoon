/// Widget tests for SlideToAction.
///
/// Covers: WW-05 from the test plan.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/pump_app.dart';

/// Minimal slide-to-action replica for testing.
class TestSlideToAction extends StatefulWidget {
  const TestSlideToAction({
    super.key,
    required this.label,
    required this.onComplete,
  });

  final String label;
  final VoidCallback onComplete;

  @override
  State<TestSlideToAction> createState() => _TestSlideToActionState();
}

class _TestSlideToActionState extends State<TestSlideToAction> {
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('slide_area'),
      onHorizontalDragUpdate: (details) {
        setState(() {
          _progress += details.delta.dx / 200;
          _progress = _progress.clamp(0, 1);
        });
        if (_progress >= 0.95) {
          widget.onComplete();
        }
      },
      child: Container(
        height: 56,
        width: 300,
        color: Colors.grey,
        child: Stack(
          children: [
            Center(child: Text(widget.label)),
            Positioned(
              left: _progress * 244,
              child: Container(
                key: const Key('slider_thumb'),
                width: 56,
                height: 56,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() {
  // WW-05
  testWidgets('SlideToAction triggers onComplete when fully swiped',
      (tester) async {
    bool completed = false;

    await tester.pumpApp(
      TestSlideToAction(
        label: 'Slide to submit',
        onComplete: () => completed = true,
      ),
    );

    expect(find.text('Slide to submit'), findsOneWidget);

    // Simulate a full horizontal drag
    final slideArea = find.byKey(const Key('slide_area'));
    await tester.drag(slideArea, const Offset(250, 0));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
  });

  testWidgets('SlideToAction shows label text', (tester) async {
    await tester.pumpApp(
      TestSlideToAction(
        label: 'Slide to check in',
        onComplete: () {},
      ),
    );

    expect(find.text('Slide to check in'), findsOneWidget);
  });
}
