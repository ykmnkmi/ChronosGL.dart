import 'dart:math' as math;

import 'package:chronosgl/camera.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../example/torusknot_camera/torus_knot_controls.dart';

// The example supplies torusKnotGetPos from its browser-facing geometry import.
// An independent sampler keeps these trajectory/camera checks usable on the VM.
void sampleTorus(double parameter, vm.Vector3 out) {
  final radial = 10 * (2 + math.cos(3 * parameter));
  out.setValues(
    radial * math.cos(2 * parameter),
    radial * math.sin(2 * parameter),
    10 * math.sin(3 * parameter),
  );
}

void expectMatrix(vm.Matrix4 actual, vm.Matrix4 expected) {
  for (var i = 0; i < 16; i++) {
    expect(actual.storage[i], closeTo(expected.storage[i], 2e-5));
  }
}

void main() {
  test('samples initial position and aims ahead with radial up', () {
    final camera = PerspectiveCamera(near: 0.1, far: 1000);
    final samples = <double>[];
    TorusKnotControls(
      camera,
      positionAt: (parameter, out) {
        samples.add(parameter);
        sampleTorus(parameter, out);
      },
    );

    expect(samples, [0, 0.01]);
    expect(camera.worldPosition.storage, [30, 0, 0]);
    final ahead = vm.Vector3.zero();
    sampleTorus(0.01, ahead);
    final forward = (ahead - camera.worldPosition)..normalize();
    final world = camera.worldMatrix;
    expect((-world.getColumn(2).xyz - forward).length, lessThan(1e-6));
    final radial = camera.worldPosition..normalize();
    final up = (radial - forward * radial.dot(forward))..normalize();
    expect((world.getColumn(1).xyz - up).length, lessThan(1e-6));
  });

  test('equal seconds produce equal poses at different frame rates', () {
    final referenceCamera = PerspectiveCamera(near: 0.1, far: 1000);
    TorusKnotControls(referenceCamera, positionAt: sampleTorus).update(3);

    for (final fps in [30, 60, 120]) {
      final camera = PerspectiveCamera(near: 0.1, far: 1000);
      final controls = TorusKnotControls(camera, positionAt: sampleTorus);
      for (var frame = 0; frame < 3 * fps; frame++) {
        controls.update(1 / fps);
      }
      expectMatrix(camera.worldMatrix, referenceCamera.worldMatrix);
    }
    final irregularCamera = PerspectiveCamera(near: 0.1, far: 1000);
    final irregular = TorusKnotControls(
      irregularCamera,
      positionAt: sampleTorus,
    );
    for (final delta in [0.02, 0.68, 0.3, 0.0, 2.0]) {
      irregular.update(delta);
    }
    expectMatrix(irregularCamera.worldMatrix, referenceCamera.worldMatrix);
  });

  test('controls both camera types while preserving their projections', () {
    final cameras = <Camera>[
      PerspectiveCamera(fovYRadians: 1.3, aspectRatio: 2, near: 0.1, far: 1000),
      OrthographicCamera(
        left: -5,
        right: 10,
        bottom: -3,
        top: 4,
        near: -1,
        far: 100,
      ),
    ];
    for (final camera in cameras) {
      final projection = camera.projectionMatrix;
      final controls = TorusKnotControls(camera, positionAt: sampleTorus);
      controls.update(3);
      final expectedPosition = vm.Vector3.zero();
      sampleTorus(1, expectedPosition);
      expect((camera.worldPosition - expectedPosition).length, lessThan(1e-6));
      expectMatrix(camera.projectionMatrix, projection);
      final pose = camera.worldMatrix;
      controls.update(0);
      expectMatrix(camera.worldMatrix, pose);
    }
  });

  test('invalid time steps preserve pose and accumulated time', () {
    final camera = PerspectiveCamera(near: 0.1, far: 1000);
    final controls = TorusKnotControls(camera, positionAt: sampleTorus);
    controls.update(1);
    final pose = camera.worldMatrix;
    for (final delta in [-1.0, double.nan, double.infinity, -double.infinity]) {
      expect(() => controls.update(delta), throwsArgumentError);
      expectMatrix(camera.worldMatrix, pose);
    }
    controls.update(2);
    final expectedPosition = vm.Vector3.zero();
    sampleTorus(1, expectedPosition);
    expect((camera.worldPosition - expectedPosition).length, lessThan(1e-6));
  });
}
