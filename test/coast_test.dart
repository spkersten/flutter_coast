import 'dart:async';

import 'package:coast/src/coast.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
        expect(sut.calculateNewTargetPage(offset: 3.0, newSourcePage: 3), null);
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
        expect(sut.calculateStatus(0.0), AnimationStatus.dismissed);
      });

      test('should return completed in case value 1', () {
        expect(sut.calculateStatus(1.0), AnimationStatus.completed);
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
      StreamController<AnimationStatus> animationUpdates;
      TransitionAnimation sut;

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
