import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishisetu/features/farmer/presentation/krishi_assistant_button.dart';

void main() {
  group('KrishiAssistantSideButton Widget Tests', () {
    testWidgets('renders leaf icon logo and compact assistant label', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  right: 12,
                  bottom: 85,
                  child: KrishiAssistantSideButton(
                    onTap: () => tapped = true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Verify the leaf icon is present
      expect(find.byIcon(Icons.eco_rounded), findsOneWidget);

      // Verify compact label is present
      expect(find.text('Sahayak'), findsOneWidget);

      // Tap the button
      await tester.tap(find.byType(KrishiAssistantSideButton));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify callback triggered
      expect(tapped, true);
    });

    testWidgets('renders smoothly on small screen without overflow', (tester) async {
      // Simulate compact mobile screen (320x640)
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  right: 12,
                  bottom: 85,
                  child: KrishiAssistantSideButton(),
                ),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.eco_rounded), findsOneWidget);
    });
  });
}
