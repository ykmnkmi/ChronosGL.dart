/// Page lifetime and explicit resource ownership for the demonstration scenes.
library;

import 'dart:async';
import 'dart:js_interop';

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';
import 'package:web/web.dart' as web;

/// Owns an example's resources, listeners and pending animation frames.
///
/// Unlike engine batches and passes, [ownBatch] and [ownPass] explicitly take
/// ownership of reachable programs, meshes and uniform textures. This policy
/// belongs to the examples: never register resources borrowed from another
/// application owner. Shared resources within this lifetime are released once.
/// Register resources separately when removing or replacing them between draws.
class ExampleLifetime {
  ExampleLifetime() {
    _onPageHide = ((web.Event event) {
      // A cached page retains its resources and resumes when navigated back to.
      if (event.isA<web.PageTransitionEvent>() &&
          (event as web.PageTransitionEvent).persisted) {
        return;
      }
      unawaited(dispose());
    }).toJS;
    web.window.addEventListener('pagehide', _onPageHide);
  }

  final _releases = Map<Object, FutureOr<void> Function()>.identity();
  final _passes = Set<RenderPass>.identity();
  final _batches = Set<RenderBatch>.identity();
  final _nodes = Set<Node>.identity();
  final _groups = Set<UniformGroup>.identity();
  final _frames = <int>{};
  late final JSFunction _onPageHide;
  bool _isDisposed = false;
  bool _collecting = false;
  Future<void>? _disposal;

  bool get isDisposed => _isDisposed;

  /// Registers a supported resource, returning it for use in initializers.
  ///
  /// Uniform groups retain ownership of their texture values through teardown.
  /// A resource registered after teardown is immediately released; asynchronous
  /// loaders should still check [isDisposed] before allocating or drawing.
  T own<T extends Object>(T resource) {
    switch (resource) {
      case RenderPass():
        ownPass(resource);
      case RenderBatch():
        ownBatch(resource);
      case Node():
        if (!_isDisposed) _nodes.add(resource);
        _captureNode(resource, Set<Node>.identity());
      case UniformGroup():
        if (!_isDisposed) _groups.add(resource);
        _captureGroup(resource);
      case GpuMesh():
        _register(resource, resource.dispose);
      case RenderProgram():
        _register(resource, resource.dispose);
      case Texture():
        _register(resource, resource.dispose);
      case Framebuffer():
        _register(resource, resource.dispose);
      case FullscreenPass():
        _register(resource, resource.dispose);
        own(resource.program);
        own(resource.material);
      case CanvasViewport():
        _register(resource, resource.dispose);
      case OrbitControls():
        _register(resource, resource.dispose);
      case Keyboard():
        _register(resource, resource.dispose);
      case Mouse():
        _register(resource, resource.dispose);
      case StatsPanel():
        _register(resource, resource.dispose);
      case ShadowMapVisualizer():
        _register(resource, resource.dispose);
      case LightVisualizer():
        _register(resource, resource.dispose);
      case BoneVisualizer():
        _register(resource, resource.dispose);
      case ShadowMap():
        _register(resource, resource.dispose);
      case StreamSubscription<Object?>():
        _register(resource, resource.cancel);
      default:
        throw ArgumentError.value(
          resource,
          'resource',
          'No disposal operation',
        );
    }
    return resource;
  }

  /// Explicitly owns the pass framebuffer and resources in its batches.
  RenderPass ownPass(RenderPass pass) {
    if (!_isDisposed) _passes.add(pass);
    _capturePass(pass);
    return pass;
  }

  /// Explicitly owns programs, meshes and textures reachable from this batch.
  RenderBatch ownBatch(RenderBatch batch) {
    if (!_isDisposed) _batches.add(batch);
    _captureBatch(batch);
    return batch;
  }

  /// Adds a custom cleanup, including asynchronous subscription cancellation.
  void onDispose(FutureOr<void> Function() release) {
    _register(release, release);
  }

  void _register(Object resource, FutureOr<void> Function() release) {
    if (_isDisposed && !_collecting) {
      unawaited(Future<void>.sync(release));
    } else {
      _releases.putIfAbsent(resource, () => release);
    }
  }

  void _capturePass(RenderPass pass) {
    _captureAll([
      () => own(pass.framebuffer),
      for (final batch in pass.batches) () => _captureBatch(batch),
    ]);
  }

  void _captureBatch(RenderBatch batch) {
    final visited = Set<Node>.identity();
    _captureAll([
      () => own(batch.program),
      for (final group in batch.uniforms) () => _captureGroup(group),
      for (final node in batch.nodes) () => _captureNode(node, visited),
    ]);
  }

  void _captureNode(Node node, Set<Node> visited) {
    if (!visited.add(node)) return;
    _captureAll([
      if (node is MeshNode) ...[
        () => own(node.mesh),
        () => _captureGroup(node.material),
      ],
      for (final child in node.children) () => _captureNode(child, visited),
    ]);
  }

  void _captureAll(Iterable<void Function()> captures) {
    Object? firstError;
    StackTrace? firstStack;
    for (final capture in captures) {
      try {
        capture();
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
  }

  void _captureGroup(UniformGroup group) {
    for (final value in group.getUniforms().values) {
      if (value is Texture) own(value);
    }
  }

  /// Schedules a frame that is cancelled, or ignored, after teardown.
  int requestAnimationFrame(JSFunction callback) {
    if (_isDisposed) return 0;
    late final int id;
    final guarded = ((double timeMs) {
      _frames.remove(id);
      if (!_isDisposed) callback.callAsFunction(null, timeMs.toJS);
    }).toJS;
    id = web.window.requestAnimationFrame(guarded);
    _frames.add(id);
    return id;
  }

  /// Stops callbacks immediately and attempts every registered cleanup once.
  /// Repeated calls return the same completion, including after cleanup errors.
  Future<void> dispose() {
    if (_disposal != null) return _disposal!;
    final completion = Completer<void>();
    _disposal = completion.future;
    _isDisposed = true;
    web.window.removeEventListener('pagehide', _onPageHide);
    for (final frame in _frames) {
      web.window.cancelAnimationFrame(frame);
    }
    _frames.clear();

    Object? firstError;
    StackTrace? firstStack;
    void capture(void Function() collect) {
      try {
        collect();
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }

    _collecting = true;
    for (final pass in _passes) {
      capture(() => _capturePass(pass));
    }
    for (final batch in _batches) {
      capture(() => _captureBatch(batch));
    }
    final visited = Set<Node>.identity();
    for (final node in _nodes) {
      capture(() => _captureNode(node, visited));
    }
    for (final group in _groups) {
      capture(() => _captureGroup(group));
    }
    _collecting = false;
    _passes.clear();
    _batches.clear();
    _nodes.clear();
    _groups.clear();

    final releases = _releases.values.toList().reversed.toList();
    _releases.clear();
    final pending = <Future<void>>[
      for (final release in releases)
        Future<void>.sync(release).catchError((Object error, StackTrace stack) {
          firstError ??= error;
          firstStack ??= stack;
        }),
    ];
    unawaited(
      Future.wait(pending).then((_) {
        if (firstError == null) {
          completion.complete();
        } else {
          completion.completeError(firstError!, firstStack);
        }
      }),
    );
    return _disposal!;
  }
}
