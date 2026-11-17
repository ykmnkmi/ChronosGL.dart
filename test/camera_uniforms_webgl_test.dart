@TestOn('chrome')
library;

import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

Camera makeCamera(bool orthographic) => orthographic
    ? OrthographicCamera(
        left: -3,
        right: 7,
        bottom: -5,
        top: 1,
        near: -4,
        far: 40,
      )
    : PerspectiveCamera(
        fovYRadians: math.pi / 3,
        aspectRatio: 1.5,
        near: 0.5,
        far: 40,
      );

vm.Matrix4 referenceProjection(bool orthographic, {bool updated = false}) =>
    orthographic
    ? updated
          ? vm.makeOrthographicMatrix(-6, 2, -1, 9, 0.5, 80)
          : vm.makeOrthographicMatrix(-3, 7, -5, 1, -4, 40)
    : updated
    ? vm.makePerspectiveMatrix(math.pi / 2, 0.75, 1, 80)
    : vm.makePerspectiveMatrix(math.pi / 3, 1.5, 0.5, 40);

vm.Matrix4 referenceView(vm.Vector3 eye, vm.Vector3 target) =>
    vm.makeViewMatrix(eye, target, vm.Vector3(0, 1, 0));

void updateProjection(Camera camera) {
  if (camera is OrthographicCamera) {
    camera.setProjection(
      left: -6,
      right: 2,
      bottom: -1,
      top: 9,
      near: 0.5,
      far: 80,
    );
  } else {
    (camera as PerspectiveCamera).setProjection(
      fovYRadians: math.pi / 2,
      aspectRatio: 0.75,
      near: 1,
      far: 80,
    );
  }
}

class Fixture {
  Fixture() {
    final canvas = web.HTMLCanvasElement()
      ..width = 2
      ..height = 2;
    cgl = ChronosGL(canvas, antialiasing: false);
    addTearDown(() {
      (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
          ?.loseContext();
    });
    gl = canvas.getContext('webgl2') as web.WebGL2RenderingContext;
    cgl.viewport(0, 0, 2, 2);
    cgl.disable(glDepthTest);
    final vertex = ShaderObject('camera readback-v')
      ..addAttributeVars([aPosition])
      ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
      ..setBodyWithMain([
        'gl_Position = $uPerspectiveViewMatrix * $uModelMatrix * vec4($aPosition, 1.0);',
      ]);
    final fragment = ShaderObject('camera readback-f')
      ..addUniformVars([uEyePosition])
      ..setBodyWithMain([
        '$oFragColor = vec4(abs($uEyePosition) / vec3(16.0, 32.0, 64.0), 1.0);',
      ]);
    program = RenderProgram('camera readback', cgl, vertex, fragment);
    addTearDown(program.dispose);
    mesh = program.makeMeshData('triangle', glTriangles)
      ..addVertices(Float32List.fromList([-1, -1, 0, 1, -1, 0, 0, 1, 0]));
    addTearDown(mesh.dispose);
  }

  late final ChronosGL cgl;
  late final web.WebGL2RenderingContext gl;
  late final RenderProgram program;
  late final MeshData mesh;

  final model = UniformGroup('model')
    ..setUniform(uModelMatrix, vm.Matrix4.identity());

  void draw(CameraUniforms adapter) => program.draw(mesh, [adapter, model]);

  Float32List readUniform(String canonical) {
    final handle = gl.getParameter(glCurrentProgram) as web.WebGLProgram;
    final location = gl.getUniformLocation(handle, canonical);
    expect(location, isNotNull, reason: '$canonical must be active');
    return (gl.getUniform(handle, location!) as JSFloat32Array).toDart;
  }

  void expectValues(String canonical, Iterable<double> expected) {
    expect(
      readUniform(canonical),
      orderedEquals(expected.map((value) => closeTo(value, 2e-5))),
      reason: '$canonical read back from WebGL',
    );
  }

  void expectCamera(vm.Matrix4 projectionView, vm.Vector3 eye) {
    expectValues(uPerspectiveViewMatrix, projectionView.storage);
    expectValues(uEyePosition, eye.storage);
    expect(program.uninitializedInputs(), isEmpty);
    expect(cgl.getError(), glNoError);
  }
}

void main() {
  for (final orthographic in [false, true]) {
    final kind = orthographic ? 'orthographic' : 'perspective';

    test('$kind WebGL uniforms follow pose and projection edits', () {
      final fixture = Fixture();
      final camera = makeCamera(orthographic);
      final adapter = CameraUniforms(camera);
      final projection = referenceProjection(orthographic);
      for (final (eye, target) in [
        (vm.Vector3(0, 0, 10), vm.Vector3.zero()),
        (vm.Vector3(3, -4, 12), vm.Vector3(-2, 1, 0)),
        (vm.Vector3(3, -4, 12), vm.Vector3(5, -1, 2)),
      ]) {
        camera.setPositionFromVector(eye);
        camera.lookAt(target);
        fixture.draw(adapter);
        fixture.expectCamera(
          vm.Matrix4.copy(projection)..multiply(referenceView(eye, target)),
          eye,
        );
        expect(camera.worldPosition.storage, orderedEquals(eye.storage));
      }

      // q=(1,1,1,1) normalizes to a known cyclic axis permutation.
      // Inverse rotation maps world X -> local Z, Y -> X, Z -> Y.
      final eye = vm.Vector3(-7, 2, 5);
      camera.setPositionFromVector(eye);
      camera.setRotation(vm.Quaternion(1, 1, 1, 1));
      final view = vm.Matrix4.columns(
        vm.Vector4(0, 0, 1, 0),
        vm.Vector4(1, 0, 0, 0),
        vm.Vector4(0, 1, 0, 0),
        vm.Vector4(-eye.y, -eye.z, -eye.x, 1),
      );
      fixture.draw(adapter);
      fixture.expectCamera(vm.Matrix4.copy(projection)..multiply(view), eye);

      updateProjection(camera);
      final updated = referenceProjection(orthographic, updated: true)
        ..multiply(view);
      fixture.draw(adapter);
      fixture.expectCamera(updated, eye);
      expect(camera.worldPosition.storage, orderedEquals(eye.storage));

      // Editing a CPU snapshot must not change the next GPU upload.
      final snapshot = adapter.getUniforms();
      (snapshot[uPerspectiveViewMatrix]! as vm.Matrix4).storage.fillRange(
        0,
        16,
        99,
      );
      (snapshot[uEyePosition]! as vm.Vector3).storage.fillRange(0, 3, 99);
      snapshot.clear();
      fixture.draw(adapter);
      fixture.expectCamera(updated, eye);
    });

    test(
      '$kind Scene keeps camera uniforms separate from object transforms',
      () {
        final fixture = Fixture();
        final eye = vm.Vector3(3, -4, 12);
        final target = vm.Vector3(-2, 1, 0);
        final camera = makeCamera(orthographic)
          ..setPositionFromVector(eye)
          ..lookAt(target);
        final adapter = CameraUniforms(camera);
        final child = Node('triangle', fixture.mesh, Material.empty('material'))
          ..setPos(1, 2, 3);
        final parent = Node.container('parent', child)
          ..setPos(2, 0, -1)
          ..rotY(0.3);
        final scene = Scene(
          'scene',
          fixture.program,
          List<UniformGroup>.unmodifiable([adapter]),
        )..add(parent);
        final phase = RenderPhase('camera readback', fixture.cgl)
          ..viewPortW = 2
          ..viewPortH = 2
          ..add(scene);
        final projectionView = referenceProjection(orthographic)
          ..multiply(referenceView(eye, target));
        for (final position in [vm.Vector3(1, 2, 3), vm.Vector3(-4, 3, 2)]) {
          child.setPosFromVec(position);
          phase.draw();
          fixture.expectCamera(projectionView, eye);
          fixture.expectValues(
            uModelMatrix,
            (vm.Matrix4.translationValues(2, 0, -1)
                  ..rotateY(0.3)
                  ..multiply(vm.Matrix4.translation(position)))
                .storage,
          );
          expect(scene.uniforms, [adapter]);
        }
        eye.setValues(7, 1, 9);
        camera.setPositionFromVector(eye);
        camera.lookAt(target);
        phase.draw();
        fixture.expectCamera(
          referenceProjection(orthographic)
            ..multiply(referenceView(eye, target)),
          eye,
        );
        expect(fixture.cgl.getError(), glNoError);
      },
    );
  }

  test(
    'alternating camera adapters replace WebGL values on the same program',
    () {
      final fixture = Fixture();
      final perspective = CameraUniforms(
        makeCamera(false)..setPosition(3, 4, 12),
      );
      final orthographic = CameraUniforms(
        makeCamera(true)..setPosition(-5, 2, 8),
      );
      final target = vm.Vector3.zero();
      for (final adapter in [
        perspective,
        orthographic,
        perspective,
        orthographic,
      ]) {
        final camera = adapter.camera;
        final eye = camera.worldPosition;
        camera.lookAt(target);
        fixture.draw(adapter);
        fixture.expectCamera(
          referenceProjection(camera is OrthographicCamera)
            ..multiply(referenceView(eye, target)),
          eye,
        );
      }
    },
  );
}
