import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'coast.dart';

/// Analogue of [Hero] but for [Coast] and [Beach]'s instead of for [Navigator] and [Route]'s. The implementation is
/// mostly adapted for [Hero] and related classes.
class Crab extends StatefulWidget {
  const Crab({
    required this.tag,
    required this.child,
    this.placeholderBuilder,
    this.flightShuttleBuilder,
    Key? key,
  }) : super(key: key);

  final String tag;
  final Widget child;
  final TransitionBuilder? placeholderBuilder;
  final CrabFlightShuttleBuilder? flightShuttleBuilder;

  @override
  State<StatefulWidget> createState() => _CrabState();

  static Map<Object, _CrabState> _allCrabsFor(BuildContext context) {
    final result = <Object, _CrabState>{};
    void visitor(Element element) {
      if (element.widget is Crab) {
        final crab = element as StatefulElement;
        final crabWidget = element.widget as Crab;
        final Object tag = crabWidget.tag;
        assert(() {
          if (result.containsKey(tag)) {
            throw FlutterError('There are multiple crabs that share the same tag within a subtree.\n'
                'Within each subtree for which carbs are to be animated (typically a Beach subtree), '
                'each Crab must have a unique non-null tag.\n'
                'In this case, multiple carbs had the following tag: $tag\n'
                'Here is the subtree for one of the offending carbs:\n'
                '${element.toStringDeep(prefixLineOne: '# ')}');
          }
          return true;
        }());
        final crabState = crab.state as _CrabState;
        result[tag] = crabState;
      }
      // Don't perform transitions across different Coasts.
      if (element.widget is Navigator) {
        return;
      }
      element.visitChildren(visitor);
    }

    context.visitChildElements(visitor);
    return result;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('tag', tag))
      ..add(ObjectFlagProperty<TransitionBuilder?>.has('placeholderBuilder', placeholderBuilder))
      ..add(ObjectFlagProperty<CrabFlightShuttleBuilder?>.has('flightShuttleBuilder', flightShuttleBuilder));
  }
}

class _CrabState extends State<Crab> {
  final GlobalKey _key = GlobalKey();
  Size? _placeholderSize;

  void startWalk() {
    assert(mounted);
    final box = context.findRenderObject() as RenderBox?;
    assert(box != null && box.hasSize);
    setState(() {
      _placeholderSize = box!.size;
    });
  }

  void endWalk() {
    if (mounted) {
      setState(() {
        _placeholderSize = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_placeholderSize != null) {
      if (widget.placeholderBuilder == null) {
        return SizedBox(width: _placeholderSize!.width, height: _placeholderSize!.height);
      } else {
        return widget.placeholderBuilder!(context, widget.child);
      }
    }
    return KeyedSubtree(
      key: _key,
      child: widget.child,
    );
  }
}

/// A function that lets [Crab]s self supply a [Widget] that is shown during the
/// crabs's walk from one beach to another instead of default (which is to
/// show the destination beach's instance of the Crab).
typedef CrabFlightShuttleBuilder = Widget Function(
  BuildContext flightContext,
  Animation<double> animation,
  BeachTransitionDirection direction,
  BuildContext fromCrabContext,
  BuildContext? toCrabContext,
);

/// Adapted from [HeroController], animates matching [Crab]'s when transitioning between [Beach]es.
class CrabController extends CoastObserver {
  CrabController() : _walks = {};

  final Map<Object, _CrabWalk> _walks;

  @override
  void startTransition(
    Beach beach,
    Beach previousBeach,
    BeachTransitionDirection direction,
    Animation<double>? progress,
  ) {
    if (previousBeach.subtreeContext == null) {
      return;
    }

    final fromCrabs = Crab._allCrabsFor(previousBeach.subtreeContext!);

    final overlay = coast.overlay!;
    final overlayRect = _globalBoundingBoxFor(overlay.context);

    /// Because [beach] hasn't been laid out yet, we don't know the rects of that Crabs
    /// on that Beach. Therefore we have to create the crab walk in a post frame callback.
    /// To prevent the [Crab] from moving with [previousBeach] in the current frame, we
    /// start a walk for all [Crabs] to the same position on screen, keeping them stationary.
    /// In the post frame callback, we update the walk with the target rect for the Crab.
    for (final tag in fromCrabs.keys) {
      final fromShuttleBuilder = fromCrabs[tag]!.widget.flightShuttleBuilder;
      final shuttleBuilder = fromShuttleBuilder ?? _defaultHeroFlightShuttleBuilder;

      _walks[tag] = _CrabWalk(
        fromCrab: fromCrabs[tag]!,
        toCrab: null,
        progress: progress!,
        overlay: overlay,
        overlayRect: overlayRect,
        direction: direction,
        fromCrabContext: previousBeach.subtreeContext!,
        toCrabContext: beach.subtreeContext,
        shuttleBuilder: shuttleBuilder,
      )..start();
    }

    WidgetsBinding.instance!.addPostFrameCallback((value) {
      final toCrabs = Crab._allCrabsFor(beach.subtreeContext!);

      for (final tag in _walks.keys) {
        if (toCrabs[tag] != null) {
          _walks[tag]!.update(toCrabs[tag]!, beach.subtreeContext!);
        }
      }
    });
  }

  Widget _defaultHeroFlightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    BeachTransitionDirection flightDirection,
    BuildContext fromCrabContext,
    BuildContext? toCrabContext,
  ) {
    if (toCrabContext != null) {
      final toCrab = toCrabContext.widget as Crab;
      return toCrab.child;
    } else {
      final fromCrab = fromCrabContext.widget as Crab;
      return fromCrab.child;
    }
  }
}

class _CrabWalk {
  _CrabWalk({
    required this.fromCrab,
    required this.toCrab,
    required this.progress,
    required this.overlay,
    required this.overlayRect,
    required this.direction,
    required this.fromCrabContext,
    required this.toCrabContext,
    required this.shuttleBuilder,
  });

  final _CrabState fromCrab;
  _CrabState? toCrab;
  final Animation<double> progress;
  final OverlayState overlay;
  final Rect overlayRect;
  final BeachTransitionDirection direction;
  final BuildContext fromCrabContext;
  BuildContext? toCrabContext;
  final CrabFlightShuttleBuilder shuttleBuilder;

  OverlayEntry? _overlayEntry;

  late Tween<Rect?> _crabRectTween;

  void start() {
    progress.addStatusListener(_handleAnimationStatusUpdates);

    _crabRectTween = RectTween(
      begin: _globalBoundingBoxFor(fromCrab.context, ancestor: fromCrabContext.findRenderObject()),
      end: _globalBoundingBoxFor(fromCrab.context, ancestor: fromCrabContext.findRenderObject()),
    );

    fromCrab.startWalk();

    _overlayEntry = _createOverlayEntry();
    overlay.insert(_overlayEntry!);
  }

  void update(_CrabState newToCrab, BuildContext newToCrabContext) {
    toCrab = newToCrab;
    toCrabContext = newToCrabContext;

    toCrab!.startWalk();

    _crabRectTween = RectTween(
      begin: _globalBoundingBoxFor(fromCrab.context, ancestor: fromCrabContext.findRenderObject()),
      end: _globalBoundingBoxFor(toCrab!.context, ancestor: toCrabContext!.findRenderObject()),
    );

    _overlayEntry?.remove();
    _overlayEntry = _createOverlayEntry();
    overlay.insert(_overlayEntry!);
  }

  OverlayEntry _createOverlayEntry() => OverlayEntry(
        builder: (context) {
          final shuttle = shuttleBuilder(context, progress, direction, fromCrab.context, toCrab?.context);

          return AnimatedBuilder(
            animation: progress,
            builder: (context, child) {
              final rect = _crabRectTween.evaluate(progress)!;
              final size = overlayRect.size;
              final offsets = RelativeRect.fromSize(rect, size);

              return Positioned(
                top: offsets.top,
                left: offsets.left,
                bottom: offsets.bottom,
                right: offsets.right,
                child: IgnorePointer(
                  child: child,
                ),
              );
            },
            child: shuttle,
          );
        },
      );

  void _handleAnimationStatusUpdates(AnimationStatus status) {
    if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
      _overlayEntry!.remove();
      _overlayEntry = null;

      fromCrab.endWalk();
      toCrab?.endWalk();
    }
  }
}

Rect _globalBoundingBoxFor(BuildContext context, {RenderObject? ancestor}) {
  final box = (context.findRenderObject() as RenderBox?)!;
  assert(box.hasSize);
  return MatrixUtils.transformRect(box.getTransformTo(ancestor), Offset.zero & box.size);
}
