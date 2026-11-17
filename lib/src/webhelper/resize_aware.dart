part of 'lib.dart';

/// Legacy window-resize integration for a full-screen canvas.
///
/// Owns its resize subscription and borrows the perspective and render
/// resources. [dispose] only stops resizing; the pass can still be inspected
/// and drawn. Prefer [CanvasViewport] for element sizing and pixel density.
@Deprecated('Use CanvasViewport with RenderPass instead.')
class RenderPhaseResizeAware extends RenderPass {
  RenderPhaseResizeAware(
    super.name,
    super.cgl,
    Object canvas,
    this._perspective,
  ) : _canvas = JSObject.fromInteropObject(canvas) as web.HTMLCanvasElement {
    resolutionChange(null);
    _resizeSubscription = web.EventStreamProviders.resizeEvent
        .forTarget(web.window)
        .listen((event) {
          if (!_isDisposed) resolutionChange(event);
        });
  }

  final web.HTMLCanvasElement _canvas;
  final Perspective _perspective;
  late final StreamSubscription<web.Event> _resizeSubscription;
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  void resolutionChange(Object? event) {
    if (_isDisposed) throw StateError('Resize helper has been disposed');
    final w = _canvas.clientWidth;
    final h = _canvas.clientHeight;
    _canvas.width = w;
    _canvas.height = h;
    _perspective.adjustAspect(w, h);
    viewPortW = w;
    viewPortH = h;
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    unawaited(_resizeSubscription.cancel());
  }
}

/// Legacy window-resize integration that also installs the WebGL viewport.
///
/// Owns its subscription and borrows the canvas, context and camera. Disposing
/// stops resizing while leaving projection reads available. Prefer
/// [CanvasViewport] for new applications.
@Deprecated('Use CanvasViewport with a mathematical camera instead.')
class PerspectiveResizeAware extends Perspective {
  PerspectiveResizeAware(
    this._cgl,
    Object canvas,
    Spatial camera,
    double near,
    double far,
  ) : _canvas = JSObject.fromInteropObject(canvas) as web.HTMLCanvasElement,
      super(camera, near, far) {
    resolutionChange(null);
    _resizeSubscription = web.EventStreamProviders.resizeEvent
        .forTarget(web.window)
        .listen((event) {
          if (!_isDisposed) resolutionChange(event);
        });
  }

  final web.HTMLCanvasElement _canvas;
  final ChronosGL _cgl;
  late final StreamSubscription<web.Event> _resizeSubscription;
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  void resolutionChange(Object? event) {
    if (_isDisposed) throw StateError('Resize helper has been disposed');
    final w = _canvas.clientWidth;
    final h = _canvas.clientHeight;
    _canvas.width = w;
    _canvas.height = h;
    adjustAspect(w, h);
    _cgl.viewport(0, 0, w, h);
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    unawaited(_resizeSubscription.cancel());
  }
}
