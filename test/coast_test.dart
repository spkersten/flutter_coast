import 'dart:async';

import 'package:coast/coast.dart';
import 'package:coast/src/coast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test_ui/flutter_test_ui.dart';

void main() {
  group('$Coast', () {
    group('two beaches, one crab', () {
      const startRect = Rect.fromLTWH(0, 0, 40, 40);
      const endRect = Rect.fromLTWH(400 - 80, 400 - 80, 80, 80);

      late CoastController coastController;

      setUpUI((tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 400));

        coastController = CoastController();

        await tester.pumpWidget(MaterialApp(
          home: Coast(
            controller: coastController,
            observers: [
              CrabController(),
            ],
            beaches: [
              Beach(
                builder: (context) => Align(
                  alignment: Alignment.topLeft,
                  child: Crab(
                    tag: 'crab',
                    child: Container(color: Colors.red, width: 40, height: 40),
                  ),
                ),
              ),
              Beach(
                builder: (context) => Align(
                  alignment: Alignment.bottomRight,
                  child: Crab(
                    tag: 'crab',
                    child: Container(color: Colors.red, width: 80, height: 80),
                  ),
                ),
              ),
            ],
          ),
        ));
      });

      testUI('initially at the first beach, with the crab at the starting position', (tester) async {
        expect(coastController.beach, 0.0);

        expect(
          tester.getRect(find.byType(Container)),
          startRect,
        );
      });

      group('drag halfway to the second beach', () {
        late TestGesture drag;

        setUpUI((tester) async {
          drag = await tester.startGesture(const Offset(200, 200));
          await drag.moveBy(const Offset(-100, 0));
          await tester.pump();
          await drag.moveBy(const Offset(-100, 0));
          await tester.pump();
        });

        testUI('the crab is halfway between the start and end position', (tester) async {
          expect(coastController.beach, 0.5);

          expect(
            tester.getRect(find.byType(Container)),
            Rect.lerp(startRect, endRect, 0.5),
          );
        });

        group('let the coast snap to the second beach', () {
          setUpUI((tester) async {
            await drag.moveBy(const Offset(-100, 0));
            await drag.up();
            await tester.pumpAndSettle();
          });

          testUI('the crab is at the final position', (tester) async {
            expect(coastController.beach, 1);

            expect(
              tester.getRect(find.byType(Container)),
              endRect,
            );

            expect(find.byType(Container), findsOneWidget);
          });
        });

        group('let the coast snap back to the first beach', () {
          setUpUI((tester) async {
            await drag.moveBy(const Offset(100, 0));
            await drag.up();
            await tester.pumpAndSettle();
          });

          testUI('the crab is at the final position', (tester) async {
            expect(coastController.beach, 0);

            expect(
              tester.getRect(find.byType(Container)),
              startRect,
            );

            expect(find.byType(Container), findsOneWidget);
          });
        });
      });
    });
  });

  group('$CoastState', () {
    group('calculate NewSourcePage', () {
      final sut = CoastState();

      test('offset bit bigger then source page should return current source page', () {
        expect(sut.calculateNewSourcePage(offset: 4.6, sourcePage: 4), 4);
      });

      test('offset much bigger then source page should recalculate source page', () {
        expect(sut.calculateNewSourcePage(offset: 4.9, sourcePage: 2), 4);
      });

      test('offset much smaller then source page should calculate source page based on offset', () {
        expect(sut.calculateNewSourcePage(offset: 1.9, sourcePage: 3), 2);
      });

      test('offset bit smaller then source page should return current source page', () {
        expect(sut.calculateNewSourcePage(offset: 2.3, sourcePage: 3), 3);
      });
    });

    group('calculate NewTargetPage', () {
      final sut = CoastState();

      test('offset is bigger then source page and should determine new target page correctly', () {
        expect(sut.calculateNewTargetPage(offset: 4.6, newSourcePage: 3), 4);
      });

      test('offset is smaller then source page and should determine new target page correctly', () {
        expect(sut.calculateNewTargetPage(offset: 2.6, newSourcePage: 3), 2);
      });

      test('return null when offset equals sourcePage', () {
        expect(sut.calculateNewTargetPage(offset: 3, newSourcePage: 3), null);
      });
    });

    group('finish transition', () {
      final sut = CoastState();

      test('should finish transition in case new target page is not equal to current target page', () {
        sut.progress = TransitionAnimation();
        expect(sut.shouldFinishTransition(newTargetPage: 1, newSourcePage: null), true);
      });

      test('should finish transition in case new source page is not equal to current source page', () {
        sut.progress = TransitionAnimation();
        expect(sut.shouldFinishTransition(newTargetPage: null, newSourcePage: 1), true);
      });

      test('should not finish transition in case ', () {
        sut.progress = null;
        expect(sut.shouldFinishTransition(newTargetPage: null, newSourcePage: null), false);
      });
    });

    group('start new transition', () {
      final sut = CoastState();

      test('Should not start transition when target page and progress is null', () {
        sut.progress = null;
        expect(sut.shouldStartNewTransition(newTargetPage: null), false);
      });

      test('should start new transition in case target page has value', () {
        sut.progress = null;
        expect(sut.shouldStartNewTransition(newTargetPage: 2), true);
      });

      test('should start not start new transition in case progress has value', () {
        sut.progress = TransitionAnimation();
        expect(sut.shouldStartNewTransition(newTargetPage: null), false);
      });
    });
  });

  group('TransitionAnimation', () {
    group('Calculate animation status', () {
      final sut = TransitionAnimation();

      test('should return dismissed in case value 0', () {
        expect(sut.calculateStatus(0), AnimationStatus.dismissed);
      });

      test('should return completed in case value 1', () {
        expect(sut.calculateStatus(1), AnimationStatus.completed);
      });

      test('should return forward in case newvalue is bigger then previous value', () {
        sut.value = 0.5;

        expect(sut.calculateStatus(0.7), AnimationStatus.forward);
      });

      test('should return reverse in case newvalue is bigger then previous value', () {
        sut.value = 0.5;

        expect(sut.calculateStatus(0.3), AnimationStatus.reverse);
      });
    });

    group('Event handling', () {
      final updates = <AnimationStatus>[];
      late StreamController<AnimationStatus> animationUpdates;
      late TransitionAnimation sut;

      setUp(() async {
        animationUpdates = StreamController<AnimationStatus>(sync: true);
        animationUpdates.stream.listen(updates.add);
        sut = TransitionAnimation()..addStatusListener(animationUpdates.add);
      });

      tearDown(() async {
        updates.clear();
        await animationUpdates.close();
      });

      test('Should notify listener only once with new status', () async {
        sut.value = 1.0;

        expect(updates.length, 1);
      });

      test('Should notify listener on each value change', () async {
        sut
          ..value = 1.0
          ..value = 0.5;

        expect(updates.length, 2);
      });

      test('Should dispatch correct status update object to listener', () async {
        sut.value = 1.0;

        expect(updates.first, AnimationStatus.completed);
      });
    });
  });
}
