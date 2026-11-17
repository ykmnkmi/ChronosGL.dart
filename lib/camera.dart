/// Browser-independent cameras and reusable OpenGL projections for shadows.
///
/// Usable on the Dart VM without DOM, WebGL or rendering dependencies. Combine
/// with `core.dart` for object transformations. Rendering adapters such as
/// `CameraUniforms` are available through the browser-facing `chronosgl.dart`.
library;

export 'src/camera/camera.dart'
    show Camera, PerspectiveCamera, OrthographicCamera;
export 'src/camera/projection.dart'
    show Projection, PerspectiveProjection, OrthographicProjection;
