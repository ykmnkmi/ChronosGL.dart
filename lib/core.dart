/// Browser-independent transformations, usable on the Dart VM.
///
/// Exports [Transform] without DOM, WebGL or rendering dependencies. Cameras
/// and reusable projections are available separately through `camera.dart`.
/// Use `chronosgl.dart` for the browser-facing engine and rendering adapters.
library;

export 'src/core/transform.dart';
