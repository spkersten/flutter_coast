import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A wrapper of [PageView] that support observation of transitions between pages.
class Coast extends StatefulWidget {
  const Coast({
    required this.beaches,
    required this.controller,
    this.observers,
    this.physics,
    this.allowImplicitScrolling = false,
    this.restorationId,
    this.scrollDirection = Axis.horizontal,
    this.reverse = false,
    this.onPageChanged,
    this.dragStartBehavior = DragStartBehavior.start,
    this.clipBehavior = Clip.hardEdge,
    Key? key,
  })  : assert(beaches != null),
        assert(beaches.length > 0),
        assert(controller != null),
        assert(allowImplicitScrolling != null),
        super(key: key);

  final List<Beach> beaches;
  final List<CoastObserver>? observers;
  final CoastController controller;

  /// See [PageView]
  final ScrollPhysics? physics;
  final bool allowImplicitScrolling;
  final String? restorationId;
  final Axis scrollDirection;
  final bool reverse;
  final ValueChanged<int>? onPageChanged;
  final DragStartBehavior dragStartBehavior;
  final Clip clipBehavior;

  @override
  State<StatefulWidget> createState() => CoastState();
}

class CoastController {
  double? get beach => _pageController.page;

  void dispose() {
    _pageController.dispose();
  }

  Future<void> animateTo({
    required int beach,
    Duration duration = const Duration(milliseconds: 200),
    Curve curve = Curves.fastOutSlowIn,
  }) async {
    await _pageController.animateToPage(beach,
        duration: duration, curve: curve);
  }

  final _pageController = PageController(keepPage: true);
}

class CoastState extends State<Coast> {
  late double _previousOffset;
  TransitionAnimation? progress;
  int? _sourcePage;
  int? _targetPage;

  final _overlayKey =
      GlobalKey<OverlayState>(debugLabel: "CoastState's Overlay");

  OverlayState? get overlay => _overlayKey.currentState;

  PageController get pageController => widget.controller._pageController;

  double _round(double value, int precision) {
    final f = pow(10, precision);
    return (value * f).round() / f;
  }

  @override
  void initState() {
    super.initState();

    _sourcePage = 0;
    _previousOffset = 0.0;

    pageController.addListener(() {
      if (context != null) {
        // Get rid of over-scrolling
        final offset = _round(
            pageController.page!
                .clamp(0.0, widget.beaches.length - 1)
                .toDouble(),
            6);
        if (offset == _previousOffset) return;

        // Determine between which two pages we are scrolling
        final newSourcePage = calculateNewSourcePage(
            offset: offset, sourcePage: _sourcePage ?? 0);

        final newTargetPage = calculateNewTargetPage(
            offset: offset, newSourcePage: newSourcePage);

        if (shouldFinishTransition(
            newTargetPage: newTargetPage, newSourcePage: newSourcePage)) {
          // Finish previous transition
          progress
            ?..value = (newSourcePage < (_sourcePage ?? 0)) ? 0.0 : 1.0
            ..dispose();
          progress = null;
          _targetPage = null;
        }

        _sourcePage = newSourcePage;

        if (shouldStartNewTransition(newTargetPage: newTargetPage)) {
          // Start new a transition
          _targetPage = newTargetPage;

          final direction = _targetPage! > (_sourcePage ?? 0)
              ? BeachTransitionDirection.right
              : BeachTransitionDirection.left;

          progress = TransitionAnimation();

          for (final observer in widget.observers ?? <CoastObserver>[]) {
            observer.coast = this;
            observer.startTransition(widget.beaches[_targetPage!],
                widget.beaches[(_sourcePage ?? 0)], direction, progress);
          }
        }

        // Update progress of the transition that is in progress
        if (progress != null) {
          if (_sourcePage == null) {
            _sourcePage = 0;
          }
          if (_targetPage! > _sourcePage!)
            progress!.value = offset - _sourcePage!;
          else
            progress!.value = _sourcePage! - offset;
        }

        _previousOffset = offset;
      }
    });
  }

  @visibleForTesting
  int calculateNewSourcePage(
      {required double offset, required int sourcePage}) {
    if (offset >= (sourcePage + 1))
      return sourcePage + (offset - sourcePage).floor();
    else if (offset <= (sourcePage - 1))
      return sourcePage - (sourcePage - offset).floor();
    else
      return sourcePage;
  }

  @visibleForTesting
  int? calculateNewTargetPage(
      {required double offset, required int newSourcePage}) {
    if (offset > newSourcePage)
      return newSourcePage + 1;
    else if (offset < newSourcePage)
      return newSourcePage - 1;
    else
      return null; // ignore: avoid_returning_null
  }

  @visibleForTesting
  bool shouldFinishTransition({int? newTargetPage, int? newSourcePage}) =>
      progress != null &&
      (_targetPage != newTargetPage || _sourcePage != newSourcePage);

  @visibleForTesting
  bool shouldStartNewTransition({int? newTargetPage}) =>
      progress == null && newTargetPage != null;

  @override
  Widget build(BuildContext context) => _DeclarativeOverlay(
        overlayKey: _overlayKey,
        child: LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            /* PageView issue on flutter https://github.com/flutter/flutter/issues/24763
            Temporary fix to round the width till the issue is fixed */
            width: constraints.maxWidth.roundToDouble(),
            child: PageView(
              controller: pageController,
              physics: widget.physics,
              children:
                  widget.beaches.map((beach) => beach.build(context)).toList(),
              allowImplicitScrolling: widget.allowImplicitScrolling,
              restorationId: widget.restorationId,
              scrollDirection: widget.scrollDirection,
              reverse: widget.reverse,
              pageSnapping: true,
              onPageChanged: widget.onPageChanged,
              dragStartBehavior: widget.dragStartBehavior,
              clipBehavior: widget.clipBehavior,
            ),
          ),
        ),
      );
}

class _DeclarativeOverlay extends StatefulWidget {
  const _DeclarativeOverlay(
      {required this.child, required this.overlayKey, Key? key})
      : assert(child != null),
        assert(overlayKey != null),
        super(key: key);

  final Widget child;
  final Key overlayKey;

  @override
  _DeclarativeOverlayState createState() => _DeclarativeOverlayState();
}

class _DeclarativeOverlayState extends State<_DeclarativeOverlay> {
  late OverlayEntry _childEntry;

  @override
  void initState() {
    super.initState();
    _childEntry = OverlayEntry(
      maintainState: true,
      builder: (context) => widget.child,
    );
  }

  @override
  void didUpdateWidget(_DeclarativeOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.child != widget.child) _childEntry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) => Overlay(
        key: widget.overlayKey,
        initialEntries: [_childEntry],
      );
}

/// See [Coast]
class Beach {
  Beach({required this.builder}) : assert(builder != null);

  final WidgetBuilder builder;

  final GlobalKey _subtreeKey = GlobalKey();

  BuildContext? get subtreeContext => _subtreeKey.currentContext;

  Widget build(BuildContext context) =>
      RepaintBoundary(key: _subtreeKey, child: Builder(builder: builder));
}

class CoastObserver {
  late CoastState coast;

  /// [progress] will animate between 0 and 1. It will always start at 0, and end either at 1 (when the transition
  /// completes) or at 0 (when the transition is cancelled).
  void startTransition(Beach beach, Beach previousBeach,
      BeachTransitionDirection direction, Animation<double>? progress) {}
}

enum BeachTransitionDirection { left, right }

class TransitionAnimation extends Animation<double>
    with
        AnimationLocalListenersMixin,
        AnimationLocalStatusListenersMixin,
        AnimationEagerListenerMixin {
  double _value = 0.0;
  AnimationStatus? _status = AnimationStatus.dismissed;

  @override
  AnimationStatus get status => _status!;

  @override
  double get value => _value;

  set value(double newValue) {
    _status = calculateStatus(newValue);
    _value = newValue;
    notifyListeners();
    _checkStatusChanged();
  }

  AnimationStatus _lastReportedStatus = AnimationStatus.dismissed;

  @visibleForTesting
  AnimationStatus? calculateStatus(double newValue) {
    if (newValue == 0.0) {
      return AnimationStatus.dismissed;
    } else if (newValue == 1.0) {
      return AnimationStatus.completed;
    } else if (newValue > _value) {
      return AnimationStatus.forward;
    } else if (newValue < _value) {
      return AnimationStatus.reverse;
    } else {
      //this can never happen but is a fallback scenario
      return AnimationStatus.dismissed;
    }
  }

  void _checkStatusChanged() {
    final newStatus = status;
    if (_lastReportedStatus != newStatus) {
      _lastReportedStatus = newStatus;
      notifyStatusListeners(newStatus);
    }
  }
}
