// A standalone VM consumer: no test framework, DOM, WebGL or render adapters.
import 'package:chronosgl/camera.dart' as cameras;
import 'package:chronosgl/core.dart' as core;
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  final model = core.Transform(position: vm.Vector3(1, 2, -3));
  final point = model.matrix.transformed(vm.Vector4(0, 0, 0, 1));
  final perspective = cameras.PerspectiveProjection(near: 0.1, far: 100);
  final orthographic = cameras.OrthographicProjection(
    left: -4,
    right: 4,
    bottom: -3,
    top: 3,
    near: -1,
    far: 100,
  );
  final projections = <cameras.Projection>[perspective, orthographic];
  final views = <cameras.Camera>[
    cameras.PerspectiveCamera.fromProjection(perspective),
    cameras.OrthographicCamera.fromProjection(orthographic),
  ];
  for (final projection in projections) {
    if (projection.matrix.storage.any((value) => !value.isFinite)) {
      throw StateError('Projection is not finite');
    }
  }
  for (final camera in views) {
    camera.setPosition(0, 0, 10);
    camera.lookAt(model.position);
    final clip = camera.viewProjectionMatrix.transformed(point);
    if (clip.storage.any((value) => !value.isFinite) || clip.w <= 0) {
      throw StateError('World-to-clip calculation failed');
    }
  }
  print('VM math imports OK');
}
