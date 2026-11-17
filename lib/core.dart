/// Browser-independent transformations and colors, usable on the Dart VM.
///
/// Exports [Transform], [Color] and the color palette without DOM, WebGL or
/// rendering dependencies. Cameras and reusable projections are available
/// separately through `camera.dart`.
/// Use `chronosgl.dart` for the browser-facing engine and rendering adapters.
library;

export 'src/core/transform.dart';
export 'src/core/colors.dart';
