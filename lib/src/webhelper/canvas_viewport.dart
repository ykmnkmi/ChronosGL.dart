import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../camera/camera.dart';
import '../core/lib.dart';
import '../scene/lib.dart';

/// Synchronizes a canvas drawing buffer, viewport and camera projection.
///
/// The canvas, context, camera and optional screen [renderPhase] are borrowed.
/// Set the canvas CSS dimensions independently of its width/height attributes.
/// CSS content-box dimensions are multiplied by [pixelRatio], rounded once,
/// and then the actual WebGL drawing-buffer dimensions are used. Perspective
/// aspect follows the viewport; explicit orthographic bounds are preserved.
/// Offscreen framebuffers have their own attachment sizes and are not managed.
///
/// Call [update] before drawing and skip drawing when it returns false. A hidden
/// or zero-sized canvas preserves the last valid projection. Resize observers,
/// window resize and device-pixel-ratio changes also synchronize automatically.
class CanvasViewport {
  /// Named browser integration. [pixelRatio] is device pixels per CSS pixel.
  CanvasViewport.forCanvas({
    required ChronosGL cgl,
    required web.HTMLCanvasElement canvas,
    required Camera camera,
    RenderPass? renderPass,
    double? pixelRatio,
  }) : this(
         cgl,
         canvas,
         camera,
         renderPhase: renderPass,
         pixelRatio: pixelRatio,
       );

  @Deprecated('Use CanvasViewport.forCanvas with named arguments.')
  CanvasViewport(
    this.cgl,
    this.canvas,
    this.camera, {
    this.renderPhase,
    double? pixelRatio,
  }) : _pixelRatio = _validatePixelRatio(pixelRatio),
       _gl = canvas.getContext('webgl2') as web.WebGL2RenderingContext {
    try {
      enable();
    } catch (_) {
      try {
        dispose();
      } catch (_) {
        // Preserve the construction failure after attempting every removal.
      }
      rethrow;
    }
  }

  final ChronosGL cgl;
  final web.HTMLCanvasElement canvas;
  final Camera camera;
  final RenderPhase? renderPhase;
  final web.WebGL2RenderingContext _gl;

  web.ResizeObserver? _observer;
  web.MediaQueryList? _pixelRatioQuery;
  JSFunction? _resizeListener;
  JSFunction? _pixelRatioListener;
  double? _pixelRatio;
  bool _enabled = false;
  bool _isDisposed = false;
  bool _isReady = false;
  int _generation = 0;
  int? _regionWidth;
  int? _regionHeight;
  int _regionX = 0;
  int _regionY = 0;
  int _viewportWidth = 0;
  int _viewportHeight = 0;
  double _widthCssPixels = 0;
  double _heightCssPixels = 0;

  bool get enabled => _enabled;
  bool get isDisposed => _isDisposed;
  bool get isReady => _isReady;
  double get widthCssPixels => _widthCssPixels;
  double get heightCssPixels => _heightCssPixels;
  int get drawingBufferWidthPixels => _gl.drawingBufferWidth;
  int get drawingBufferHeightPixels => _gl.drawingBufferHeight;
  int get viewportX => _regionX;
  int get viewportY => _regionY;
  int get viewportWidthPixels => _viewportWidth;
  int get viewportHeightPixels => _viewportHeight;

  /// Explicit positive finite density, or null to follow devicePixelRatio.
  double? get pixelRatio => _pixelRatio;

  set pixelRatio(double? value) {
    _checkNotDisposed();
    _pixelRatio = _validatePixelRatio(value);
    if (_enabled) {
      _watchPixelRatio(_generation);
      update();
    }
  }

  static double? _validatePixelRatio(double? value) {
    if (value != null && (!value.isFinite || value <= 0)) {
      throw ArgumentError.value(value, 'pixelRatio', 'must be finite and > 0');
    }
    return value;
  }

  void _checkNotDisposed() {
    if (_isDisposed) throw StateError('CanvasViewport has been disposed');
  }

  /// Selects a viewport in drawing-buffer pixels, with a bottom-left origin.
  /// Zero area suspends drawing; negative dimensions throw ArgumentError.
  /// Coordinates are not clamped to the drawing buffer, matching WebGL.
  void setViewport({
    int x = 0,
    int y = 0,
    required int width,
    required int height,
  }) {
    _checkNotDisposed();
    if (width < 0 || height < 0) {
      throw ArgumentError('Viewport width and height must be nonnegative');
    }
    _regionX = x;
    _regionY = y;
    _regionWidth = width;
    _regionHeight = height;
    update();
  }

  /// Restores the full actual drawing buffer as the viewport.
  void useFullViewport() {
    _checkNotDisposed();
    _regionX = _regionY = 0;
    _regionWidth = _regionHeight = null;
    update();
  }

  /// Reattaches observers once and immediately synchronizes current dimensions.
  void enable() {
    _checkNotDisposed();
    if (_enabled) return;
    _enabled = true;
    final generation = ++_generation;
    try {
      _observer = web.ResizeObserver(
        ((
              JSArray<web.ResizeObserverEntry> entries,
              web.ResizeObserver observer,
            ) {
              if (_enabled && generation == _generation) update();
            })
            .toJS,
      );
      _observer!.observe(canvas);
      _resizeListener = ((web.Event event) {
        if (_enabled && generation == _generation) update();
      }).toJS;
      web.window.addEventListener('resize', _resizeListener);
      _watchPixelRatio(generation);
      update();
    } catch (_) {
      try {
        disable();
      } catch (_) {
        // Preserve the registration failure.
      }
      rethrow;
    }
  }

  void _watchPixelRatio(int generation) {
    _pixelRatioQuery?.removeEventListener('change', _pixelRatioListener);
    _pixelRatioQuery = null;
    _pixelRatioListener = null;
    if (_pixelRatio != null) return;
    _pixelRatioQuery = web.window.matchMedia(
      '(resolution: ${web.window.devicePixelRatio}dppx)',
    );
    _pixelRatioListener = ((web.Event event) {
      if (!_enabled || generation != _generation) return;
      _watchPixelRatio(generation);
      update();
    }).toJS;
    _pixelRatioQuery!.addEventListener('change', _pixelRatioListener);
  }

  /// Detaches all observers/listeners; queued callbacks become harmless.
  /// The borrowed objects and their last valid projection remain usable.
  void disable() {
    if (!_enabled) return;
    _enabled = false;
    _isReady = false;
    ++_generation;
    final observer = _observer;
    final resizeListener = _resizeListener;
    final ratioQuery = _pixelRatioQuery;
    final ratioListener = _pixelRatioListener;
    _observer = null;
    _resizeListener = null;
    _pixelRatioQuery = null;
    _pixelRatioListener = null;
    Object? firstError;
    StackTrace? firstStack;
    for (final remove in <void Function()>[
      if (observer != null) () => observer.disconnect(),
      if (resizeListener != null)
        () => web.window.removeEventListener('resize', resizeListener),
      if (ratioQuery != null && ratioListener != null)
        () => ratioQuery.removeEventListener('change', ratioListener),
    ]) {
      try {
        remove();
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStack!);
    }
  }

  /// Permanently detaches observers/listeners. Repeated calls are harmless.
  /// Further configuration, enabling or update calls throw StateError.
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    disable();
  }

  static double _cssNumber(String value) =>
      double.tryParse(value.replaceFirst('px', '')) ?? 0;

  /// Synchronizes current CSS size and density; returns whether drawing is ready.
  /// Disabled components do nothing. No callbacks or animation loop are scheduled.
  bool update() {
    _checkNotDisposed();
    if (!_enabled) return false;
    _isReady = false;
    final style = web.window.getComputedStyle(canvas);
    if (canvas.getClientRects().length == 0) {
      _widthCssPixels = _heightCssPixels = 0;
    } else {
      _widthCssPixels = _cssNumber(style.width);
      _heightCssPixels = _cssNumber(style.height);
      if (style.boxSizing == 'border-box') {
        _widthCssPixels -=
            _cssNumber(style.paddingLeft) +
            _cssNumber(style.paddingRight) +
            _cssNumber(style.borderLeftWidth) +
            _cssNumber(style.borderRightWidth);
        _heightCssPixels -=
            _cssNumber(style.paddingTop) +
            _cssNumber(style.paddingBottom) +
            _cssNumber(style.borderTopWidth) +
            _cssNumber(style.borderBottomWidth);
      }
      _widthCssPixels = math.max(0, _widthCssPixels);
      _heightCssPixels = math.max(0, _heightCssPixels);
    }
    if (_widthCssPixels <= 0 || _heightCssPixels <= 0) {
      _applyViewport(0, 0);
      return false;
    }
    final ratio = _pixelRatio ?? web.window.devicePixelRatio;
    _validatePixelRatio(ratio);
    final requestedWidth = _widthCssPixels * ratio;
    final requestedHeight = _heightCssPixels * ratio;
    if (!requestedWidth.isFinite ||
        !requestedHeight.isFinite ||
        requestedWidth > 0xffffffff ||
        requestedHeight > 0xffffffff) {
      throw ArgumentError('Requested drawing-buffer dimensions exceed uint32');
    }
    final width = math.max(1, requestedWidth.round());
    final height = math.max(1, requestedHeight.round());
    if (canvas.width != width) canvas.width = width;
    if (canvas.height != height) canvas.height = height;
    if (_gl.drawingBufferWidth <= 0 || _gl.drawingBufferHeight <= 0) {
      _applyViewport(0, 0);
      return false;
    }
    final viewportWidth = _regionWidth ?? _gl.drawingBufferWidth;
    final viewportHeight = _regionHeight ?? _gl.drawingBufferHeight;
    if (viewportWidth <= 0 || viewportHeight <= 0) {
      _applyViewport(viewportWidth, viewportHeight);
      return false;
    }
    final currentCamera = camera;
    final aspectRatio = viewportWidth / viewportHeight;
    if (currentCamera is PerspectiveCamera &&
        currentCamera.aspectRatio != aspectRatio) {
      currentCamera.setProjection(
        fovYRadians: currentCamera.fovYRadians,
        aspectRatio: aspectRatio,
        near: currentCamera.near,
        far: currentCamera.far,
      );
    }
    _applyViewport(viewportWidth, viewportHeight);
    return _isReady = true;
  }

  void _applyViewport(int width, int height) {
    _viewportWidth = width;
    _viewportHeight = height;
    cgl.viewport(_regionX, _regionY, width, height);
    final phase = renderPhase;
    if (phase != null) {
      phase
        ..viewPortX = _regionX
        ..viewPortY = _regionY
        ..viewPortW = width
        ..viewPortH = height;
    }
  }
}
