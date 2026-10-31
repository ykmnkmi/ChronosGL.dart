@TestOn('chrome')
library;

import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

class _ObservedUniforms extends UniformGroup {
  _ObservedUniforms() : super('observed');

  void Function()? onRead;

  @override
  Map<String, Object> getUniforms() {
    onRead?.call();
    return super.getUniforms();
  }
}

class _Fixture {
  _Fixture() {
    final canvas = web.HTMLCanvasElement()
      ..width = 2
      ..height = 2;
    cgl = ChronosGL(canvas, antialiasing: false);
    addTearDown(() {
      (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
          ?.loseContext();
    });
    cgl.disable(glDepthTest);
    cgl.disable(glDither);
    cgl.viewport(0, 0, 2, 2);
    final vertex = ShaderObject('scene-v')
      ..addAttributeVars([aPosition])
      ..addUniformVars([uModelMatrix])
      ..setBodyWithMain([
        'gl_Position = $uModelMatrix * vec4($aPosition, 1.0);',
      ]);
    final fragment = ShaderObject('scene-f')
      ..addUniformVars([uColor])
      ..setBodyWithMain(['$oFragColor = vec4($uColor, 1.0);']);
    program = RenderProgram('scene', cgl, vertex, fragment);
    final mesh = program.makeMeshData('triangle', glTriangles)
      ..addVertices(Float32List.fromList([-1, -1, 0, 3, -1, 0, -1, 3, 0]));
    final red = Material.empty('red')..setUniform(uColor, vm.Vector3(1, 0, 0));
    final green = Material.empty('green')
      ..setUniform(uColor, vm.Vector3(0, 1, 0));
    root = Node.container('root')
      ..add(Node('first', mesh, red))
      ..add(Node('second', mesh, green));
  }

  late final ChronosGL cgl;
  late final RenderProgram program;
  late final Node root;

  void expectGreen() {
    final pixels = Uint8List(16);
    cgl.readPixels(0, 0, 2, 2, glRgba, glUnsignedByte, pixels);
    expect(pixels, [
      for (var i = 0; i < 4; i++) ...[0, 255, 0, 255],
    ]);
    expect(cgl.getError(), glNoError);
    expect(program.uninitializedInputs(), isEmpty);
  }
}

void main() {
  for (final immutable in [false, true]) {
    for (final fail in [false, true]) {
      test('Scene preserves uniforms (immutable=$immutable, fail=$fail)', () {
        final fixture = _Fixture();
        final observed = _ObservedUniforms();
        final source = <UniformGroup>[observed];
        final uniforms = immutable
            ? List<UniformGroup>.unmodifiable(source)
            : source;
        final scene = Scene('scene', fixture.program, uniforms)
          ..add(fixture.root);
        final phase = RenderPhase('phase', fixture.cgl)
          ..viewPortW = 2
          ..viewPortH = 2
          ..add(scene);
        final failure = StateError('uniform read failed');
        var reads = 0;
        observed.onRead = () {
          expect(uniforms, [observed]);
          reads++;
          if (fail && reads == 2) throw failure;
        };
        final stats = <DrawStats>[];
        if (fail) {
          expect(() => phase.draw(stats), throwsA(same(failure)));
          expect(stats.length, 1);
        } else {
          phase.draw(stats);
          expect(stats.length, 2);
          fixture.expectGreen();
        }
        expect(uniforms, [observed]);
        expect(observed.getUniforms(), isEmpty);
        observed.onRead = () => expect(uniforms, [observed]);
        phase.draw();
        fixture.expectGreen();
        expect(uniforms, [observed]);
      });
    }
  }

  test('Scene accepts a const empty uniforms list', () {
    final fixture = _Fixture();
    final scene = Scene('const', fixture.program, const [])..add(fixture.root);
    final phase = RenderPhase('const', fixture.cgl)
      ..viewPortW = 2
      ..viewPortH = 2
      ..add(scene);
    phase.draw();
    expect(scene.uniforms, isEmpty);
    fixture.expectGreen();
  });

  for (final fail in [false, true]) {
    test(
      'Direct traversal preserves list and transform group (fail=$fail)',
      () {
        final fixture = _Fixture();
        final observed = _ObservedUniforms();
        final matrix = vm.Matrix4.identity()..translateByDouble(9, 8, 7, 1);
        final transforms = UniformGroup('caller transforms')
          ..setUniform(uModelMatrix, matrix)
          ..setUniform(uTime, 123.0);
        final before = Map<String, Object>.of(transforms.getUniforms());
        final matrixBefore = List<double>.of(matrix.storage);
        final uniforms = List<UniformGroup>.unmodifiable([
          observed,
          transforms,
        ]);
        final failure = StateError('direct traversal failed');
        observed.onRead = () {
          expect(uniforms, [observed, transforms]);
          expect(transforms.getUniforms(), before);
          if (fail) throw failure;
        };
        void draw() => drawRecursively(
          fixture.program,
          fixture.root,
          vm.Matrix4.identity(),
          null,
          uniforms,
        );
        if (fail) {
          expect(draw, throwsA(same(failure)));
        } else {
          draw();
          fixture.expectGreen();
        }
        expect(transforms.getUniforms(), before);
        expect(matrix.storage, matrixBefore);
        observed.onRead = null;
        draw();
        fixture.expectGreen();
        expect(uniforms, [observed, transforms]);
        expect(transforms.getUniforms(), before);
      },
    );
  }
}
