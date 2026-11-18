@TestOn('chrome')
library;

import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/debug.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

void main() {
  late ChronosGL context;
  setUp(() {
    context = ChronosGL.fromCanvas(
      web.HTMLCanvasElement()
        ..width = 4
        ..height = 4,
    );
    addTearDown(
      () => (context.getExtension(
        'WEBGL_lose_context',
      ) as web.WEBGL_lose_context?)?.loseContext(),
    );
  });

  test('typed canvas texture and diagnostic panel constructors work', () {
    final texture = ImageTexture.fromCanvas(
      context: context,
      canvas: web.HTMLCanvasElement()
        ..width = 2
        ..height = 2,
    );
    addTearDown(texture.dispose);
    texture.update();
    expect(context.getError(), glNoError);
    final root = web.HTMLDivElement();
    final stats = StatsPanel.attach(root: root);
    final fps = FpsPanel.attach(root: root);
    expect(root.childElementCount, 2);
    stats.dispose();
    fps.dispose();
    expect(root.childElementCount, 0);
  });

  test('shader compilation errors have a typed stage and source', () {
    expect(
      () => context.compileWholeProgram(
        'invalid vertex source',
        'void main() {}',
        [],
      ),
      throwsA(
        isA<ShaderCompilationException>()
            .having((error) => error.stage, 'stage', ShaderStage.vertex)
            .having((error) => error.source, 'source', 'invalid vertex source'),
      ),
    );
  });

  test(
    'mesh data and readback snapshots cannot mutate retained invariants',
    () {
      final mesh = GpuMesh('snapshot', context, glTriangles, {aPosition: 0});
      addTearDown(mesh.dispose);
      final source = Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]);
      mesh.addVertices(source);
      source[0] = 99;
      final read = mesh.getAttribute(aPosition) as Float32List;
      expect(read[0], 0);
      read[0] = 88;
      expect(mesh.getAttribute(aPosition)[0], 0);
      expect(() => mesh.changeVertexData(Float32List(3)), throwsArgumentError);
      expect(mesh.getNumItems(), 3);
      expect(mesh.getAttribute(aPosition), hasLength(9));
      expect(
        () => context.changeElementArrayBuffer(
          mesh.getBuffer(aPosition),
          Float32List(3),
        ),
        throwsArgumentError,
      );
      expect(context.getError(), glNoError);
    },
  );

  test(
    'changeFaces requires an index buffer before changing mesh or GPU state',
    () {
      final vertices = Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]);
      final mesh = GpuMesh('indices', context, glTriangles, {aPosition: 0})
        ..addVertices(vertices);
      final other = GpuMesh('bound', context, glTriangles, {aPosition: 0})
        ..addVertices(vertices)
        ..addFaces([0, 1, 2]);
      addTearDown(mesh.dispose);
      addTearDown(other.dispose);

      for (final cleared in [false, true]) {
        if (cleared) mesh.clearData();
        final itemsBefore = mesh.getNumItems();
        other.activate();
        final vaoBefore = context.getParameter(glVertexArrayBinding);
        final indicesBefore = context.getParameter(glElementArrayBufferBinding);

        expect(() => mesh.changeFaces([0, 1]), throwsStateError);
        expect(mesh.getNumItems(), itemsBefore);
        expect(mesh.elementArrayBufferType, -1);
        expect(context.getParameter(glVertexArrayBinding), vaoBefore);
        expect(
          context.getParameter(glElementArrayBufferBinding),
          indicesBefore,
        );
        expect(context.getError(), glNoError);

        if (cleared) mesh.addVertices(vertices);
        mesh.addFaces([0, 1, 2]);
        mesh.changeFaces([2, 1, 0]);
        expect(mesh.getNumItems(), 3);
        expect(mesh.elementArrayBufferType, glUnsignedByte);
        expect(context.getParameter(glElementArrayBufferBinding), isNotNull);
        expect(context.getError(), glNoError);
      }
    },
  );

  test('framebuffer validation precedes GPU state changes', () {
    final framebuffer = Framebuffer.screen(context);
    addTearDown(framebuffer.dispose);
    expect(() => framebuffer.activate(0, 0, 0, 0, 1), throwsArgumentError);
    expect(
      () => framebuffer.extractByteData(Uint8List(1), 0, 0, 1, 1),
      throwsArgumentError,
    );
    expect(context.getParameter(glFramebufferBinding), isNull);
    expect(context.getError(), glNoError);
  });

  test(
    'unsupported point shadows and overflow lights give explicit errors',
    () {
      final light = PointLight.named(
        name: 'point',
        position: vm.Vector3.zero(),
        diffuse: vm.Vector3.all(1),
        specular: vm.Vector3.zero(),
        range: 10,
      );
      expect(light.extractShadowProjViewMatrix, throwsUnsupportedError);
      final lights = Illumination();
      for (var i = 0; i < kMaxLights; i++) {
        lights.addLight(light);
      }
      expect(() => lights.addLight(light), throwsStateError);
      final uniforms = lights.getUniforms();
      expect(() => uniforms.clear(), throwsUnsupportedError);
    },
  );
}
