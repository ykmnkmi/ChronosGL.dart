/// Supported browser-facing ChronosGL API.
///
/// Use individual entrypoints to state module dependencies. Core, camera, geometry,
/// animation, importers, and shaders can run on the Dart VM. Diagnostics are
/// available separately through `debug.dart`. Implementations under `src` are internal.
library;

export 'core.dart';
export 'camera.dart';
export 'geometry.dart';
export 'animation.dart';
export 'importers.dart';
export 'shaders.dart';
export 'webgl.dart';
export 'render.dart';
export 'scene.dart';
export 'shadows.dart';
export 'web.dart';
