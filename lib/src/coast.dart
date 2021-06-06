import 'dart:math';

import 'package:flutter/foundation.dart';
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
  })  : assert(beaches.length > 0),
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

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IterableProperty<Beach>('beaches', beaches))
      ..add(IterableProperty<CoastObserver>('observers', observers))
      ..add(DiagnosticsProperty<CoastController>('controller', controller))
      ..add(DiagnosticsProperty<ScrollPhysics?>('physics', physics))
      ..add(DiagnosticsProperty<bool>('allowImplicitScrolling', allowImplicitScrolling))
      ..add(StringProperty('restorationId', restorationId))
      ..add(EnumProperty<Axis>('scrollDirection', scrollDirection))
      ..add(DiagnosticsProperty<bool>('reverse', reverse))
      ..add(ObjectFlagProperty<ValueChanged<int>?>.has('onPageChanged', onPageChanged))
      ..add(EnumProperty<DragStartBehavior>('dragStartBehavior', dragStartBehavior))
      ..add(EnumProperty<Clip>('clipBehavior', clipBehavior));
  }
}

class CoastController {
  CoastController({int initialPage = 0}) : _pageController = PageController(initialPage: initialPage);

  final PageController _pageController;

  double? get beach => _pageController.page;

  void dispose() {
    _pageController.dispose();
  }

  Future<void> animateTo({
    required int beach,
    Duration duration = const Duration(milliseconds: 200),
    Curve curve = Curves.fastOutSlowIn,
  }) async {
    await _pageController.animateToPage(beach, duration: duration, curve: curve);
  }
}

class CoastState extends State<Coast> {
  late double _previousOffset;
  TransitionAnimation? progress;
  int _sourcePage = 0;
  int? _targetPage;

  final _overlayKey = GlobalKey<OverlayState>(debugLabel: "CoastState's Overlay");

  OverlayState? get overlay => _overlayKey.currentState;

  PageController get _pageController => widget.controller._pageController;

  double _round(double value, int precision) {
    final f = pow(10, precision);
    return (value * f).round() / f;
  }

  @override
  void initState() {
    super.initState();

    _sourcePage = _pageController.initialPage;
    _previousOffset = 0.0;

    _pageController.addListener(() {
      // Get rid of over-scrolling
      final offset = _round(_pageController.page!.clamp(0.0, widget.beaches.length - 1).toDouble(), 6);
      if (offset == _previousOffset) {
        return;
      }

      // Determine between which two pages we are scrolling
      final newSourcePage = calculateNewSourcePage(offset: offset, sourcePage: _sourcePage);

      final newTargetPage = calculateNewTargetPage(offset: offset, newSourcePage: newSourcePage);

      if (shouldFinishTransition(newTargetPage: newTargetPage, newSourcePage: newSourcePage)) {
        // Finish previous transition
        progress
          ?..value = (newSourcePage < _sourcePage) ? 0.0 : 1.0
          ..dispose();
        progress = null;
        _targetPage = null;
      }

      _sourcePage = newSourcePage;

      if (shouldStartNewTransition(newTargetPage: newTargetPage)) {
        // Start new a transition
        _targetPage = newTargetPage;

        final direction = _targetPage! > _sourcePage ? BeachTransitionDirection.right : BeachTransitionDirection.left;

        progress = TransitionAnimation();

        for (final observer in widget.observers ?? <CoastObserver>[]) {
          observer
            ..coast = this
            ..startTransition(widget.beaches[_targetPage!], widget.beaches[_sourcePage], direction, progress);
        }
      }

      // Update progress of the transition that is in progress
      if (progress != null) {
        if (_targetPage! > _sourcePage) {
          progress!.value = offset - _sourcePage;
        } else {
          progress!.value = _sourcePage - offset;
        }
      }

      _previousOffset = offset;
    });
  }

  @visibleForTesting
  int calculateNewSourcePage({required double offset, required int sourcePage}) {
    if (offset >= (sourcePage + 1)) {
      return sourcePage + (offset - sourcePage).floor();
    } else if (offset <= (sourcePage - 1)) {
      return sourcePage - (sourcePage - offset).floor();
    } else {
      return sourcePage;
    }
  }

  @visibleForTesting
  int? calculateNewTargetPage({required double offset, required int newSourcePage}) {
    if (offset > newSourcePage) {
      return newSourcePage + 1;
    } else if (offset < newSourcePage) {
      return newSourcePage - 1;
    } else {
      return null;
    }
  }

  @visibleForTesting
  bool shouldFinishTransition({int? newTargetPage, int? newSourcePage}) =>
      progress != null && (_targetPage != newTargetPage || _sourcePage != newSourcePage);

  @visibleForTesting
  bool shouldStartNewTransition({int? newTargetPage}) => progress == null && newTargetPage != null;

  @override
  Widget build(BuildContext context) => _DeclarativeOverlay(
        overlayKey: _overlayKey,
        child: LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            /* PageView issue on flutter https://github.com/flutter/flutter/issues/24763
            Temporary fix to round the width till the issue is fixed */
            width: constraints.maxWidth.roundToDouble(),
            child: PageView(
              controller: _pageController,
              physics: widget.physics,
              allowImplicitScrolling: widget.allowImplicitScrolling,
              restorationId: widget.restorationId,
              scrollDirection: widget.scrollDirection,
              reverse: widget.reverse,
              pageSnapping: true,
              onPageChanged: widget.onPageChanged,
              dragStartBehavior: widget.dragStartBehavior,
              clipBehavior: widget.clipBehavior,
              children: widget.beaches.map((beach) => beach.build(context)).toList(),
            ),
          ),
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DiagnosticsProperty<TransitionAnimation?>('progress', progress))
      ..add(DiagnosticsProperty<OverlayState?>('overlay', overlay));
  }
}

class _DeclarativeOverlay extends StatefulWidget {
  const _DeclarativeOverlay({required this.child, required this.overlayKey, Key? key}) : super(key: key);

  final Widget child;
  final Key overlayKey;

  @override
  _DeclarativeOverlayState createState() => _DeclarativeOverlayState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Key>('overlayKey', overlayKey));
  }
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
    if (oldWidget.child != widget.child) {
      _childEntry.markNeedsBuild();
    }
  }

  @override
  Widget build(BuildContext context) => Overlay(
        key: widget.overlayKey,
        initialEntries: [_childEntry],
      );
}

/// See [Coast]
class Beach {
  Beach({required this.builder});

  final WidgetBuilder builder;

  final GlobalKey _subtreeKey = GlobalKey();

  BuildContext? get subtreeContext => _subtreeKey.currentContext;

  Widget build(BuildContext context) => RepaintBoundary(key: _subtreeKey, child: Builder(builder: builder));
}

class CoastObserver {
  late CoastState coast;

  /// [progress] will animate between 0 and 1. It will always start at 0, and end either at 1 (when the transition
  /// completes) or at 0 (when the transition is cancelled).
  void startTransition(
      Beach beach, Beach previousBeach, BeachTransitionDirection direction, Animation<double>? progress) {}
}

enum BeachTransitionDirection { left, right }

class TransitionAnimation extends Animation<double>
    with AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin, AnimationEagerListenerMixin {
  double _value = 0;
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
