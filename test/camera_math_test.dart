import 'dart:math' as math;

import 'package:chronosgl/camera.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

void expectComponents(
  Iterable<double> actual,
  Iterable<double> expected, {
  double tolerance = 2e-5,
  String? reason,
}) {
  expect(
    actual,
    orderedEquals(expected.map((value) => closeTo(value, tolerance))),
    reason: reason,
  );
}

// Analytic inverse projection, independent of matrix construction/inversion.
vm.Vector3 viewAtNdc(Camera camera, double x, double y, double z) {
  if (camera is PerspectiveCamera) {
    final distance =
        2 *
        camera.near *
        camera.far /
        (camera.far + camera.near - z * (camera.far - camera.near));
    final halfHeight = distance * math.tan(camera.fovYRadians / 2);
    return vm.Vector3(
      x * halfHeight * camera.aspectRatio,
      y * halfHeight,
      -distance,
    );
  }
  final ortho = camera as OrthographicCamera;
  return vm.Vector3(
    ortho.left + (x + 1) * (ortho.right - ortho.left) / 2,
    ortho.bottom + (y + 1) * (ortho.top - ortho.bottom) / 2,
    -(ortho.near + (z + 1) * (ortho.far - ortho.near) / 2),
  );
}

void main() {
  for (final orthographic in [false, true]) {
    final kind = orthographic ? 'orthographic' : 'perspective';
    Camera create() => orthographic
        ? OrthographicCamera(
            left: -3,
            right: 7,
            bottom: -5,
            top: 1,
            near: -4,
            far: 12,
          )
        : PerspectiveCamera(
            fovYRadians: math.pi / 3,
            aspectRatio: 1.75,
            near: 1,
            far: 17,
          );

    void updateProjection(Camera camera) {
      if (camera is OrthographicCamera) {
        camera.setProjection(
          left: -6,
          right: 2,
          bottom: -1,
          top: 9,
          near: 2,
          far: 30,
        );
      } else {
        (camera as PerspectiveCamera).setProjection(
          fovYRadians: math.pi / 2,
          aspectRatio: 0.6,
          near: 0.25,
          far: 24,
        );
      }
    }

    test('$kind equivalent quaternion signs preserve the world pose', () {
      final camera = create()
        ..setPosition(3, -4, 12)
        ..setRotation(vm.Quaternion(1, 1, 1, 1));
      final combined = camera.viewProjectionMatrix;
      // A 120-degree rotation about (1, 1, 1): X -> Y, Y -> Z, Z -> X.
      // Thus local (2, -1, -5) rotates to (-5, 2, -1), then adds the eye.
      for (final scale in [0.5, -0.5, 7.0, -3.0]) {
        camera.setRotation(vm.Quaternion(scale, scale, scale, scale));
        expect(camera.worldPosition.storage, [3, -4, 12]);
        expect(camera.worldRotation.length, closeTo(1, 1e-6));
        expectComponents(
          camera.worldMatrix.transformed3(vm.Vector3(2, -1, -5)).storage,
          [-2, -2, 11],
        );
        expectComponents(
          camera.viewMatrix.transformed3(vm.Vector3(-2, -2, 11)).storage,
          [2, -1, -5],
        );
        expectComponents(camera.viewProjectionMatrix.storage, combined.storage);
      }
    });

    test('$kind world and NDC round trips survive projection updates', () {
      final camera = create()
        ..setPosition(3, -4, 12)
        ..setRotation(vm.Quaternion(1, 1, 1, 1));
      final world = camera.worldMatrix;
      final view = camera.viewMatrix;
      for (final updated in [false, true]) {
        if (updated) updateProjection(camera);
        expect(camera.worldPosition.storage, [3, -4, 12]);
        expectComponents(camera.worldMatrix.storage, world.storage);
        expectComponents(camera.viewMatrix.storage, view.storage);
        for (final product in [
          vm.Matrix4.copy(view)..multiply(world),
          vm.Matrix4.copy(world)..multiply(view),
        ]) {
          expectComponents(product.storage, vm.Matrix4.identity().storage);
        }
        final combined = camera.viewProjectionMatrix;
        final inverse = vm.Matrix4.inverted(combined);
        for (final product in [
          vm.Matrix4.copy(combined)..multiply(inverse),
          vm.Matrix4.copy(inverse)..multiply(combined),
        ]) {
          expectComponents(product.storage, vm.Matrix4.identity().storage);
        }

        for (final x in [-1.0, 0.0, 1.0]) {
          for (final y in [-1.0, 0.0, 1.0]) {
            for (final z in [-1.0, -0.5, 0.0, 0.5, 1.0]) {
              final reason = 'NDC ($x, $y, $z), updated=$updated';
              final local = viewAtNdc(camera, x, y, z);
              // The known axis permutation supplies a world-space reference
              // without using Camera.worldMatrix to construct the input.
              final point = vm.Vector4(
                3 + local.z,
                -4 + local.x,
                12 + local.y,
                1,
              );
              final clip = combined.transformed(point);
              expect(
                clip.w,
                closeTo(orthographic ? 1 : -local.z, 2e-5),
                reason: reason,
              );
              expectComponents(
                [clip.x / clip.w, clip.y / clip.w, clip.z / clip.w],
                [x, y, z],
                reason: reason,
              );

              // NDC represents a homogeneous point with w=1. Perspective
              // unprojection must divide by the resulting world-space w.
              final restored = inverse.transformed(vm.Vector4(x, y, z, 1));
              expect(restored.w.abs(), greaterThan(1e-6), reason: reason);
              expectComponents(
                [
                  restored.x / restored.w,
                  restored.y / restored.w,
                  restored.z / restored.w,
                ],
                [point.x, point.y, point.z],
                tolerance: 2e-4,
                reason: reason,
              );
            }
          }
        }
      }
    });
  }
}
