@TestOn('chrome')
library;

import 'dart:typed_data';

import 'package:chronosgl/camera.dart' as cameras;
import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

void expectMatrix(vm.Matrix4 actual, vm.Matrix4 expected) {
  expect(
    actual.storage,
    orderedEquals(expected.storage.map((value) => closeTo(value, 2e-5))),
  );
}

void main() {
  for (final orthographic in [false, true]) {
    final kind = orthographic ? 'orthographic' : 'perspective';
    cameras.Camera makeCamera() => orthographic
        ? cameras.OrthographicCamera(
            left: -4,
            right: 4,
            bottom: -3,
            top: 3,
            near: -1,
            far: 100,
          )
        : cameras.PerspectiveCamera(near: 1, far: 100);

    void changeProjection(cameras.Camera camera) {
      if (camera is cameras.OrthographicCamera) {
        camera.setProjection(
          left: -8,
          right: 6,
          bottom: -5,
          top: 7,
          near: -2,
          far: 200,
        );
      } else {
        (camera as cameras.PerspectiveCamera).setProjection(
          fovYRadians: 0.8,
          aspectRatio: 1.5,
          near: 0.5,
          far: 200,
        );
      }
    }

    test('$kind adapter follows current pose and projection', () {
      final camera = makeCamera()..setPosition(3, -4, 12);
      final UniformGroup adapter = CameraUniforms(camera, '$kind uniforms');
      expect((adapter as CameraUniforms).camera, same(camera));
      expect(adapter.name, '$kind uniforms');
      expect(adapter.hasUniform(uPerspectiveViewMatrix), isTrue);
      expect(adapter.hasUniform(uEyePosition), isTrue);
      expect(adapter.hasUniform(uModelMatrix), isFalse);
      for (final target in [vm.Vector3.zero(), vm.Vector3(-2, 1, 3)]) {
        camera.lookAt(target);
        final pose = camera.worldMatrix;
        final values = adapter.getUniforms();
        final expected = camera.projectionMatrix
          ..multiply(
            vm.makeViewMatrix(
              camera.worldPosition,
              target,
              vm.Vector3(0, 1, 0),
            ),
          );
        expect(
          values.keys,
          unorderedEquals([uPerspectiveViewMatrix, uEyePosition]),
        );
        expectMatrix(values[uPerspectiveViewMatrix]! as vm.Matrix4, expected);
        expect((values[uEyePosition]! as vm.Vector3).storage, [3, -4, 12]);
        expect(camera.worldMatrix.storage, orderedEquals(pose.storage));
      }
      camera.setPosition(-7, 2, 5);
      camera.setRotation(
        vm.Quaternion.axisAngle(vm.Vector3(1, 2, 3).normalized(), 0.6),
      );
      changeProjection(camera);
      final values = adapter.getUniforms();
      expectMatrix(
        values[uPerspectiveViewMatrix]! as vm.Matrix4,
        camera.viewProjectionMatrix,
      );
      expect((values[uEyePosition]! as vm.Vector3).storage, [-7, 2, 5]);
    });

    test('$kind snapshots own their maps, matrices and vector storage', () {
      final camera = makeCamera()
        ..setPosition(3, -4, 12)
        ..lookAt(vm.Vector3.zero());
      final adapter = CameraUniforms(camera);
      final first = adapter.getUniforms();
      final matrix = first[uPerspectiveViewMatrix]! as vm.Matrix4;
      final eye = first[uEyePosition]! as vm.Vector3;
      final savedMatrix = vm.Matrix4.copy(matrix);
      final savedEye = vm.Vector3.copy(eye);
      final other = adapter.getUniforms();
      (other[uPerspectiveViewMatrix]! as vm.Matrix4).storage.fillRange(
        0,
        16,
        0,
      );
      (other[uEyePosition]! as vm.Vector3).storage.fillRange(0, 3, 99);
      other.clear();
      expectMatrix(camera.viewProjectionMatrix, savedMatrix);
      expect(camera.worldPosition.storage, orderedEquals(savedEye.storage));
      camera.setPosition(1, 2, 3);
      changeProjection(camera);
      adapter.getUniforms();
      expect(matrix.storage, orderedEquals(savedMatrix.storage));
      expect(eye.storage, orderedEquals(savedEye.storage));
      expect(
        first.keys,
        unorderedEquals([uPerspectiveViewMatrix, uEyePosition]),
      );
    });

    test('$kind adapter recovers after a failed camera calculation', () {
      final camera = makeCamera()..setPosition(0, 0, 10);
      final adapter = CameraUniforms(camera);
      final before = adapter.getUniforms();
      final saved = vm.Matrix4.copy(
        before[uPerspectiveViewMatrix]! as vm.Matrix4,
      );
      camera.setPosition(3e38, 3e38, 3e38);
      camera.setRotation(
        vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), 0.7853981633974483),
      );
      expect(adapter.getUniforms, throwsStateError);
      expect((before[uEyePosition]! as vm.Vector3).storage, [0, 0, 10]);
      expectMatrix(before[uPerspectiveViewMatrix]! as vm.Matrix4, saved);
      expect(
        camera.worldPosition.storage.every((value) => value.isFinite),
        isTrue,
      );
      camera.setPosition(0, 0, 10);
      camera.setRotation(vm.Quaternion.identity());
      expectMatrix(
        adapter.getUniforms()[uPerspectiveViewMatrix]! as vm.Matrix4,
        saved,
      );
    });

    test('$kind adapter works with RenderProgram.draw and RenderBatch', () {
      final canvas = web.HTMLCanvasElement()
        ..width = 2
        ..height = 2;
      final cgl = ChronosGL.fromCanvas(canvas, antialiasing: false);
      addTearDown(() {
        (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
            ?.loseContext();
      });
      cgl.viewport(0, 0, 2, 2);
      cgl.disable(glDepthTest);
      cgl.disable(glDither);
      final vertex = ShaderObject.vertex('camera-v')
        ..addAttributeVars([aPosition])
        ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
        ..setBodyWithMain([
          'gl_Position = $uPerspectiveViewMatrix * $uModelMatrix * vec4($aPosition, 1.0);',
        ]);
      final fragment = ShaderObject.fragment('camera-f')
        ..addUniformVars([uEyePosition])
        ..setBodyWithMain([
          '$oFragColor = vec4($uEyePosition.z / 40.0, 0.0, 0.0, 1.0);',
        ]);
      final program = RenderProgram.create(
        name: 'camera',
        context: cgl,
        vertexShader: vertex,
        fragmentShader: fragment,
      );
      addTearDown(program.dispose);
      final mesh = program.makeGpuMesh('triangle', glTriangles)
        ..addVertices(
          Float32List.fromList([-100, -100, 0, 300, -100, 0, -100, 300, 0]),
        );
      addTearDown(mesh.dispose);
      final camera = makeCamera()..setPosition(0, 0, 10);
      final adapter = CameraUniforms(camera);
      final transforms = UniformGroup('model')
        ..setUniform(uModelMatrix, vm.Matrix4.identity());
      final groups = List<UniformGroup>.unmodifiable([adapter, transforms]);
      void expectRed(int red) {
        final pixels = Uint8List(16);
        cgl.readPixels(0, 0, 2, 2, glRgba, glUnsignedByte, pixels);
        expect(pixels, [
          for (var i = 0; i < 4; i++) ...[red, 0, 0, 255],
        ]);
        expect(cgl.getError(), glNoError);
        expect(program.uninitializedInputs(), isEmpty);
      }

      program.draw(mesh, groups);
      expectRed(64);
      camera.setPosition(0, 0, 20);
      program.draw(mesh, groups);
      expectRed(128);
      expect(groups, [adapter, transforms]);
      final scene = RenderBatch(
        'camera',
        program,
        List<UniformGroup>.unmodifiable([adapter]),
      )..add(MeshNode('triangle', mesh, Material.empty('material')));
      final phase = RenderPass('camera', cgl)
        ..viewPortW = 2
        ..viewPortH = 2
        ..add(scene);
      camera.setPosition(0, 0, 10);
      phase.draw();
      expectRed(64);
      expect(scene.uniforms, [adapter]);
      expect(adapter.hasUniform(uModelMatrix), isFalse);
    });
  }

  test(
    'camera values override setters while extra uniforms stay available',
    () {
      final camera = PerspectiveCamera(near: 1, far: 100)
        ..setPosition(0, 0, 10);
      final adapter = CameraUniforms(camera)
        ..setUniform(uTime, 2.0)
        ..forceUniform(uPerspectiveViewMatrix, vm.Matrix4.zero())
        ..forceUniform(uEyePosition, vm.Vector3.zero());
      expect(adapter.hasUniform(uTime), isTrue);
      final values = adapter.getUniforms();
      expect(values[uTime], 2.0);
      expectMatrix(
        values[uPerspectiveViewMatrix]! as vm.Matrix4,
        camera.viewProjectionMatrix,
      );
      expect((values[uEyePosition]! as vm.Vector3).storage, [0, 0, 10]);
      values[uTime] = 99.0;
      expect(adapter.getUniforms()[uTime], 2.0);
    },
  );
}
