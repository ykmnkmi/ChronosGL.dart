@TestOn('chrome')
library;

import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

class _TrackingGL extends ChronosGL {
  _TrackingGL(super.canvas) : super(antialiasing: false);

  final events = <String>[];

  @override
  void clear(int kind) {
    events.add('clear:$kind');
    super.clear(kind);
  }
}

ShaderObject _vertex() => ShaderObject('scene-model-v')
  ..addAttributeVars([aPosition])
  ..addUniformVars([uModelMatrix])
  ..setBodyWithMain(['gl_Position = $uModelMatrix * vec4($aPosition, 1.0);']);

ShaderObject _fragment() => ShaderObject('scene-model-f')
  ..addUniformVars([uColor])
  ..setBodyWithMain(['$oFragColor = vec4($uColor, 1.0);']);

class _Draw {
  _Draw(this.mesh, this.model, this.local, this.normal, this.material);

  final MeshData mesh;
  // Retain exactly the supplied objects to catch scratch matrices shared by
  // draws or paths; expected matrices below are computed separately.
  final vm.Matrix4 model;
  final vm.Matrix4 local;
  final vm.Matrix3 normal;
  final Material material;
}

class _RecordingProgram extends RenderProgram {
  _RecordingProgram(String name, this.gl)
    : super(name, gl, _vertex(), _fragment());

  final _TrackingGL gl;
  final records = <_Draw>[];
  void Function()? onDraw;

  @override
  void draw(
    MeshData mesh,
    List<UniformGroup> uniforms, [
    List<DrawStats>? stats,
  ]) {
    final values = <String, Object>{};
    for (final group in uniforms) {
      values.addAll(group.getUniforms());
    }
    final material = uniforms.whereType<Material>().single;
    records.add(
      _Draw(
        mesh,
        values[uModelMatrix]! as vm.Matrix4,
        values[uTransformationMatrix]! as vm.Matrix4,
        values[uNormalMatrix]! as vm.Matrix3,
        material,
      ),
    );
    gl.events.add('draw:$name:${material.name}');
    onDraw?.call();
    super.draw(mesh, uniforms, stats);
  }
}

class _Fixture {
  _Fixture() {
    final canvas = web.HTMLCanvasElement()
      ..width = 2
      ..height = 2;
    gl = _TrackingGL(canvas)
      ..disable(glDepthTest)
      ..disable(glDither);
    addTearDown(() {
      (gl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
          ?.loseContext();
    });
    program = makeProgram('first');
    mesh = program.makeMeshData('triangle', glTriangles)
      ..addVertices(Float32List.fromList([-1, -1, 0, 3, -1, 0, -1, 3, 0]));
    addTearDown(mesh.dispose);
  }

  late final _TrackingGL gl;
  late final _RecordingProgram program;
  late final MeshData mesh;

  _RecordingProgram makeProgram(String name) {
    final result = _RecordingProgram(name, gl);
    addTearDown(result.dispose);
    return result;
  }

  MeshNode node(String name, [vm.Vector3? color]) => MeshNode(
    name,
    mesh,
    Material.empty(name)..setUniform(uColor, color ?? vm.Vector3(1, 0, 0)),
  );

  RenderPass pass(RenderBatch batch) => RenderPass('pass', gl)
    ..viewPortW = 2
    ..viewPortH = 2
    ..add(batch);

  void expectColor(List<int> color) {
    final pixels = Uint8List(16);
    gl.readPixels(0, 0, 2, 2, glRgba, glUnsignedByte, pixels);
    expect(pixels, [for (var i = 0; i < 4; i++) ...color]);
    expect(gl.getError(), glNoError);
  }
}

void _expectMatrix(vm.Matrix4 actual, vm.Matrix4 expected) {
  expect(actual.storage, orderedEquals(expected.storage));
}

void main() {
  test(
    'group and drawable contracts are distinct; legacy factories redirect',
    () {
      final fixture = _Fixture();
      final group = GroupNode('group');
      final mesh = fixture.node('drawable');
      expect(group.somethingToDraw(), isFalse);
      expect(mesh.somethingToDraw(), isTrue);
      expect(mesh.mesh, same(fixture.mesh));
      expect(() => (group as dynamic).mesh, throwsNoSuchMethodError);
      expect(() => (group as dynamic).meshData, throwsNoSuchMethodError);
      expect(() => (group as dynamic).material, throwsNoSuchMethodError);
      expect(Node.container('legacy'), isA<GroupNode>());
      expect(Node('legacy', mesh.mesh, mesh.material), isA<MeshNode>());
      expect(Scene('legacy', fixture.program), isA<RenderBatch>());
      expect(RenderPhase('legacy', fixture.gl), isA<RenderPass>());
    },
  );

  test('nested transforms use parent * local and world normal matrices', () {
    final fixture = _Fixture();
    final root = GroupNode('root');
    root.transform
      ..translateByDouble(2, 3, 4, 1)
      ..rotateZ(0.4)
      ..scaleByDouble(2, 3, 4, 1);
    final middle = GroupNode('middle');
    middle.transform
      ..translateByDouble(-3, 1, 2, 1)
      ..rotateY(-0.7);
    final leaf = fixture.node('leaf');
    leaf.transform
      ..translateByDouble(0.1, 0.2, 0.3, 1)
      ..rotateX(0.2);
    root.add(middle);
    middle.add(leaf);
    final expected = vm.Matrix4.copy(root.transform)
      ..multiply(middle.transform)
      ..multiply(leaf.transform);
    final pass = fixture.pass(RenderBatch('batch', fixture.program)..add(root));
    pass.draw();
    final draw = fixture.program.records.single;
    _expectMatrix(draw.model, expected);
    _expectMatrix(draw.local, leaf.transform);
    final normal = vm.Matrix3.zero()..copyNormalMatrix(expected);
    expect(draw.normal.storage, orderedEquals(normal.storage));
    leaf.transform.setIdentity();
    _expectMatrix(draw.model, expected);
    expect(draw.local.storage, isNot(orderedEquals(leaf.transform.storage)));
  });

  test('shared nodes draw for each path without changing earlier matrices', () {
    final fixture = _Fixture();
    final shared = fixture.node('shared')..setPos(1, 2, 3);
    final left = GroupNode('left', shared)..setPos(10, 0, 0);
    final right = GroupNode('right', shared)..setPos(0, 20, 0);
    final batch = RenderBatch('shared', fixture.program)..addAll([left, right]);
    final pass = fixture.pass(batch);
    final leftWorld = vm.Matrix4.copy(left.transform)
      ..multiply(shared.transform);
    final rightWorld = vm.Matrix4.copy(right.transform)
      ..multiply(shared.transform);
    pass.draw();
    expect(fixture.program.records, hasLength(2));
    final earlier = fixture.program.records.toList();
    _expectMatrix(earlier[0].model, leftWorld);
    _expectMatrix(earlier[1].model, rightWorld);
    expect(earlier[0].model, isNot(same(earlier[1].model)));
    left.children.remove(shared);
    shared.setPos(4, 5, 6);
    pass.draw();
    expect(fixture.program.records, hasLength(3));
    _expectMatrix(earlier[0].model, leftWorld);
    _expectMatrix(earlier[1].model, rightWorld);
    expect(fixture.mesh.isDisposed, isFalse);
    expect(shared.material, same(earlier[0].material));
  });

  test('draw order is batch, root, parent, and child insertion order', () {
    final fixture = _Fixture();
    final parent = fixture.node('parent')
      ..add(fixture.node('first child'))
      ..add(fixture.node('second child'));
    final disabled = GroupNode('disabled', fixture.node('hidden'))
      ..enabled = false;
    final first = RenderBatch('first', fixture.program)
      ..addAll([parent, disabled, fixture.node('second root')]);
    final secondProgram = fixture.makeProgram('second');
    final second = RenderBatch('second', secondProgram)
      ..add(fixture.node('second batch'));
    final pass = fixture.pass(first)..add(second);
    fixture.gl.events.clear();
    pass.draw();
    expect(fixture.gl.events, [
      'clear:$glClearAll',
      'draw:first:parent',
      'draw:first:first child',
      'draw:first:second child',
      'draw:first:second root',
      'draw:second:second batch',
    ]);
    final snapshot = pass.batches;
    expect(() => snapshot.clear(), throwsUnsupportedError);
    pass.remove(second);
    expect(snapshot, [first, second]);
    expect(pass.batches, [first]);
    secondProgram.enabled = false;
    pass.add(second);
    first.enabled = false;
    fixture.gl.events.clear();
    pass.draw();
    expect(fixture.gl.events, ['clear:$glClearAll']);
  });

  test('passes clear once before batches and can preserve prior color', () {
    final fixture = _Fixture();
    final first = fixture.pass(
      RenderBatch('first', fixture.program)..add(fixture.node('red')),
    );
    final second = RenderPass('preserve', fixture.gl)
      ..viewPortW = 2
      ..viewPortH = 2
      ..clearColorBuffer = false
      ..clearDepthBuffer = false
      ..clearStencilBuffer = false;
    fixture.gl.events.clear();
    first.draw();
    second.draw();
    fixture.expectColor([255, 0, 0, 255]);
    expect(fixture.gl.events, ['clear:$glClearAll', 'draw:first:red']);
    second.clearColorBuffer = true;
    second.draw();
    fixture.expectColor([0, 0, 0, 255]);
    expect(fixture.gl.events.last, 'clear:$glColorBufferBit');
    second.clearColorBuffer = false;
    second.clearDepthBuffer = true;
    second.clearStencilBuffer = true;
    second.draw();
    expect(
      fixture.gl.events.last,
      'clear:${glDepthBufferBit | glStencilBufferBit}',
    );
  });

  test('disabled passes and empty viewports do no framebuffer work', () {
    final fixture = _Fixture();
    final pass = fixture.pass(
      RenderBatch('batch', fixture.program)..add(fixture.node('red')),
    );
    fixture.gl.events.clear();
    pass.enabled = false;
    pass.draw();
    pass.enabled = true;
    pass.viewPortH = 0;
    pass.draw();
    expect(fixture.gl.events, isEmpty);
    pass.viewPortH = -1;
    expect(pass.draw, throwsArgumentError);
    expect(fixture.gl.events, isEmpty);
  });

  test(
    'batch copies list structure and preserves borrowed groups on failure',
    () {
      final fixture = _Fixture();
      final matrix = vm.Matrix4.identity()..translateByDouble(9, 8, 7, 1);
      final group = UniformGroup('borrowed')..setUniform(uModelMatrix, matrix);
      final source = <UniformGroup>[group];
      final batch = RenderBatch('batch', fixture.program, source)
        ..addAll([fixture.node('first'), fixture.node('second')]);
      source.clear();
      expect(batch.uniforms, [group]);
      final pass = fixture.pass(batch);
      final failure = StateError('draw failed');
      fixture.program.onDraw = () {
        if (fixture.program.records.length == 2) throw failure;
      };
      final stats = <DrawStats>[];
      expect(() => pass.draw(stats), throwsA(same(failure)));
      expect(stats, hasLength(1));
      expect(source, isEmpty);
      expect(batch.uniforms, [group]);
      expect(group.getUniforms(), {uModelMatrix: matrix});
      expect(matrix.getTranslation(), vm.Vector3(9, 8, 7));
      fixture.program.onDraw = null;
      pass.draw();
      expect(fixture.program.records, hasLength(4));
      fixture.expectColor([255, 0, 0, 255]);
      final immutable = List<UniformGroup>.unmodifiable([group]);
      final fromImmutable = RenderBatch(
        'immutable',
        fixture.program,
        immutable,
      );
      fromImmutable.uniforms.clear();
      expect(immutable, [group]);
    },
  );

  test('cycle errors leave traversal ready for a corrected graph', () {
    final fixture = _Fixture();
    final shared = fixture.node('shared');
    final root = GroupNode('root', shared);
    shared.add(root);
    final pass = fixture.pass(RenderBatch('cycle', fixture.program)..add(root));
    expect(
      pass.draw,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('cycle'),
        ),
      ),
    );
    shared.children.clear();
    fixture.program.records.clear();
    pass.draw();
    expect(fixture.program.records, hasLength(1));
    fixture.expectColor([255, 0, 0, 255]);
  });
}
