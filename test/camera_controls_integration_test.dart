@TestOn('chrome')
library;

import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

void main() {
  test('controls, canvas resize and scene upload share one camera', () async {
    final canvas = web.HTMLCanvasElement()
      ..style.width = '80px'
      ..style.height = '40px';
    web.document.body!.appendChild(canvas);
    addTearDown(() => canvas.remove());
    final cgl = ChronosGL.fromCanvas(canvas);
    addTearDown(() {
      (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
          ?.loseContext();
    });
    final camera = PerspectiveCamera(near: 0.1, far: 100);
    final controls = OrbitControls.forCamera(
      camera: camera,
      eventTarget: canvas,
      radius: 10,
      rotationSpeed: 1,
    );
    addTearDown(controls.dispose);
    final vertex = ShaderObject.vertex('controls integration-v')
      ..addAttributeVars([aPosition])
      ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
      ..setBodyWithMain([
        'gl_Position = $uPerspectiveViewMatrix * $uModelMatrix * vec4($aPosition, 1.0);',
      ]);
    final fragment = ShaderObject.fragment('controls integration-f')
      ..addUniformVars([uEyePosition])
      ..setBodyWithMain([
        '$oFragColor = vec4(abs($uEyePosition) / 16.0, 1.0);',
      ]);
    final program = RenderProgram.create(
      name: 'controls integration',
      context: cgl,
      vertexShader: vertex,
      fragmentShader: fragment,
    );
    addTearDown(program.dispose);
    final mesh = program.makeGpuMesh('triangle', glTriangles)
      ..addVertices(Float32List.fromList([-1, -1, 0, 1, -1, 0, 0, 1, 0]));
    addTearDown(mesh.dispose);
    final scene = RenderBatch('scene', program, [CameraUniforms(camera)])
      ..add(MeshNode('triangle', mesh, Material.empty('material')));
    final phase = RenderPass('main', cgl)..add(scene);
    final viewport = CanvasViewport.forCanvas(
      cgl: cgl,
      canvas: canvas,
      camera: camera,
      renderPass: phase,
      pixelRatio: 2,
    );
    addTearDown(viewport.dispose);
    final gl = canvas.getContext('webgl2') as web.WebGL2RenderingContext;

    void expectUpload(vm.Vector3 eye, double aspect) {
      final handle = gl.getParameter(glCurrentProgram) as web.WebGLProgram;
      Float32List uniform(String name) => (gl.getUniform(
        handle,
        gl.getUniformLocation(handle, name)!,
      ) as JSFloat32Array).toDart;
      final view = vm.makeViewMatrix(
        eye,
        vm.Vector3.zero(),
        vm.Vector3(0, 1, 0),
      );
      final expected = vm.makePerspectiveMatrix(
        camera.fovYRadians,
        aspect,
        0.1,
        100,
      )..multiply(view);
      expect(
        uniform(uEyePosition),
        orderedEquals(eye.storage.map((v) => closeTo(v, 2e-5))),
      );
      expect(
        uniform(uPerspectiveViewMatrix),
        orderedEquals(expected.storage.map((v) => closeTo(v, 2e-5))),
      );
      expect(cgl.getError(), glNoError);
    }

    canvas.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(
          keyCode: Keyboard.left,
          which: Keyboard.left,
          code: 'ArrowLeft',
        ),
      ),
    );
    controls.update(0.25);
    canvas.dispatchEvent(
      web.KeyboardEvent(
        'keyup',
        web.KeyboardEventInit(
          keyCode: Keyboard.left,
          which: Keyboard.left,
          code: 'ArrowLeft',
        ),
      ),
    );
    expect(viewport.update(), isTrue);
    phase.draw();
    final eye = vm.Vector3(10 * math.cos(0.25), 0, 10 * math.sin(0.25));
    expectUpload(eye, 2);
    expect([canvas.width, canvas.height], [160, 80]);

    controls.disable();
    canvas.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(
          keyCode: Keyboard.right,
          which: Keyboard.right,
          code: 'ArrowRight',
        ),
      ),
    );
    controls.update(1);
    canvas.style
      ..width = '40px'
      ..height = '80px';
    expect(viewport.update(), isTrue);
    phase.draw();
    expectUpload(eye, 0.5);
    expect([phase.viewPortW, phase.viewPortH], [80, 160]);

    final projection = camera.projectionMatrix;
    canvas.style.display = 'none';
    expect(viewport.update(), isFalse);
    phase.draw();
    expect(camera.projectionMatrix.storage, projection.storage);
    canvas.style.display = 'block';
    expect(viewport.update(), isTrue);
    phase.draw();
    expectUpload(eye, 0.5);
    await controls.dispose();
    viewport.dispose();
    phase.framebuffer.dispose();
  });
}
