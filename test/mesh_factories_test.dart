@TestOn('chrome')
library;

import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:chronosgl/chronosgl.dart';
import 'package:chronosgl/mesh.dart' as factories;
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:web/web.dart' as web;

import '../example/shared/particles.dart' as particles;

void main() {
  late ChronosGL cgl;
  late web.WebGL2RenderingContext gl;
  late RenderProgram program;

  setUp(() {
    final canvas = web.HTMLCanvasElement()
      ..width = 2
      ..height = 2;
    cgl = ChronosGL(canvas, antialiasing: false);
    gl = canvas.getContext('webgl2') as web.WebGL2RenderingContext;
    addTearDown(() {
      (cgl.getExtension('WEBGL_lose_context') as web.WEBGL_lose_context?)
          ?.loseContext();
    });
    final vertex = ShaderObject('factory-v')
      ..addAttributeVars([aPosition, aTexUV, aNormal])
      ..setBodyWithMain(['gl_Position = vec4($aPosition, 1.0);']);
    final fragment = ShaderObject('factory-f')
      ..setBodyWithMain(['$oFragColor = vec4(1.0);']);
    program = RenderProgram('factory', cgl, vertex, fragment);
    addTearDown(program.dispose);
  });

  List<int> indices(GpuMesh mesh) {
    mesh.activate();
    switch (mesh.elementArrayBufferType) {
      case glUnsignedByte:
        final result = Uint8List(mesh.getNumItems()).toJS;
        gl.getBufferSubData(glElementArrayBuffer, 0, result);
        return result.toDart;
      case glUnsignedShort:
        final result = Uint16List(mesh.getNumItems()).toJS;
        gl.getBufferSubData(glElementArrayBuffer, 0, result);
        return result.toDart;
      case glUnsignedInt:
        final result = Uint32List(mesh.getNumItems()).toJS;
        gl.getBufferSubData(glElementArrayBuffer, 0, result);
        return result.toDart;
      default:
        throw StateError('Unexpected index type');
    }
  }

  void expectGeometry(GpuMesh mesh, GeometryBuilder expected) {
    addTearDown(mesh.dispose);
    expect(mesh.drawMode, glTriangles);
    expect(mesh.isCompatibleWith(program), isTrue);
    expect(
      mesh.getAttributes(),
      unorderedEquals([aPosition, ...expected.attributes.keys]),
    );
    final attributes = <String, List<num>>{
      aPosition: flattenVector3List(expected.vertices),
      for (final entry in expected.attributes.entries)
        entry.key: entry.key == aTexUV
            ? flattenVector2List(entry.value as List<vm.Vector2>)
            : flattenVector3List(entry.value as List<vm.Vector3>),
    };
    for (final entry in attributes.entries) {
      final actual = mesh.getAttribute(entry.key);
      expect(actual, hasLength(entry.value.length));
      for (var i = 0; i < actual.length; i++) {
        expect(actual[i], closeTo(entry.value[i], 1e-5));
      }
    }
    expect(indices(mesh), expected.generateFaceIndices());
    expect(cgl.getError(), glNoError);
  }

  for (final normals in [false, true]) {
    test('cube forwards dimensions, UV bounds and normals=$normals', () {
      expectGeometry(
        factories.shapeCube(
          program,
          x: 2,
          y: 3,
          z: 4,
          uMin: 0.2,
          uMax: 0.7,
          vMin: 0.3,
          vMax: 0.9,
          computeNormals: normals,
        ),
        cubeGeometry(
          x: 2,
          y: 3,
          z: 4,
          uMin: 0.2,
          uMax: 0.7,
          vMin: 0.3,
          vMax: 0.9,
          computeNormals: normals,
        ),
      );
    });

    test('wedge forwards dimensions, UV bounds and normals=$normals', () {
      expectGeometry(
        factories.shapeWedge(
          program,
          x: 2,
          y: 3,
          z: 4,
          uMin: 0.2,
          uMax: 0.7,
          vMin: 0.3,
          vMax: 0.9,
          computeNormals: normals,
        ),
        wedgeGeometry(
          x: 2,
          y: 3,
          z: 4,
          uMin: 0.2,
          uMax: 0.7,
          vMin: 0.3,
          vMax: 0.9,
          computeNormals: normals,
        ),
      );
    });

    test('cylinder forwards radii, height, divisions and normals=$normals', () {
      expectGeometry(
        factories.shapeCylinder(program, 1.5, 2.5, 7, 9, normals),
        cylinderGeometry(1.5, 2.5, 7, 9, normals),
      );
    });

    test('icosahedron forwards subdivisions, scale and normals=$normals', () {
      expectGeometry(
        factories.shapeIcosahedron(
          program,
          subdivisions: 1,
          scale: 2.5,
          computeNormals: normals,
        ),
        icosahedronGeometry(
          subdivisions: 1,
          scale: 2.5,
          computeNormals: normals,
        ),
      );
    });

    test('torus knot forwards curve, tube and normals=$normals', () {
      expectGeometry(
        factories.shapeTorusKnot(
          program,
          radius: 3,
          tubeRadius: 0.7,
          segmentsR: 9,
          segmentsT: 5,
          p: 3,
          q: 2,
          heightScale: 1.7,
          computeNormals: normals,
        ),
        torusKnotGeometry(
          radius: 3,
          tubeRadius: 0.7,
          segmentsR: 9,
          segmentsT: 5,
          p: 3,
          q: 2,
          heightScale: 1.7,
          computeNormals: normals,
        ),
      );
    });
  }

  for (final wrap in [false, true]) {
    test('torus knot forwards wrap=$wrap, omitted UVs and reversed faces', () {
      expectGeometry(
        factories.shapeTorusKnot(
          program,
          segmentsR: 7,
          segmentsT: 5,
          wrap: wrap,
          computeUVs: false,
          inside: true,
        ),
        torusKnotGeometry(
          segmentsR: 7,
          segmentsT: 5,
          wrap: wrap,
          computeUVs: false,
          inside: true,
        ),
      );
    });
  }

  test('quad forwards fractional half extent', () {
    expectGeometry(factories.shapeQuad(program, 2.5), quadGeometry(2.5));
  });

  test('grid forwards distinct subdivision counts and full axis lengths', () {
    expectGeometry(
      factories.shapeGrid(program, 2, 3, 7, 11),
      gridGeometry(2, 3, 7, 11),
    );
  });

  test(
    'example stars use the supplied generator and independent resources',
    () {
      final first = particles.makeStarMesh(
        program,
        5,
        10,
        random: math.Random(7),
      );
      final second = particles.makeStarMesh(
        program,
        5,
        10,
        random: math.Random(7),
      );
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      expect(first, isNot(same(second)));
      expect(first.drawMode, glPoints);
      expect(first.getAttribute(aPosition), second.getAttribute(aPosition));
      expect(first.getAttribute(aPosition), hasLength(15));
      expect(
        first.getAttribute(aPosition),
        everyElement(inInclusiveRange(-5, 5)),
      );
      first.dispose();
      expect(second.isDisposed, isFalse);
      expect(program.isDisposed, isFalse);
      expect(cgl.getError(), glNoError);
    },
  );
}
