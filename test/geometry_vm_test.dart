import 'package:chronosgl/geometry.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

GeometryBuilder _triangle() => GeometryBuilder()
  ..addVertices([vm.Vector3.zero(), vm.Vector3(1, 0, 0), vm.Vector3(0, 1, 0)])
  ..addFace3(0, 1, 2);

void main() {
  test(
    'CPU shape factories produce valid geometry without browser imports',
    () {
      final shapes = <(GeometryBuilder, int)>[
        (quadGeometry(2), 6),
        (cubeGeometry(x: 2, y: 3, z: 4), 36),
        (wedgeGeometry(), 24),
        (cylinderGeometry(2, 3, 4, 8, true), 96),
        (icosahedronGeometry(subdivisions: 1), 240),
        (torusKnotGeometry(segmentsR: 8, segmentsT: 4, p: 1, q: 0), 8 * 4 * 6),
      ];
      for (final (geometry, indexCount) in shapes) {
        geometry.validate();
        expect(geometry.generateFaceIndices(), hasLength(indexCount));
        expect(
          geometry.attributes[aNormal],
          hasLength(geometry.vertices.length),
        );
      }
    },
  );

  test(
    'rectangular grid preserves independent dimensions and positive winding',
    () {
      final geometry = gridGeometry(2, 3, 8, 6)..validate();
      expect(geometry.vertices, hasLength(12));
      expect(geometry.faces4, hasLength(6));
      expect(geometry.vertices.map((v) => v.x).toSet(), {-4.0, 0.0, 4.0});
      expect(geometry.vertices.map((v) => v.y).toSet(), {-3.0, -1.0, 1.0, 3.0});
      final indices = geometry.generateFaceIndices();
      for (var i = 0; i < indices.length; i += 3) {
        final a = geometry.vertices[indices[i]];
        final b = geometry.vertices[indices[i + 1]];
        final c = geometry.vertices[indices[i + 2]];
        expect((b - a).cross(c - a).z, greaterThan(0));
      }
    },
  );

  test('factories with disabled normals retain valid CPU attributes', () {
    final shapes = [
      cubeGeometry(computeNormals: false),
      wedgeGeometry(computeNormals: false),
      cylinderGeometry(2, 3, 4, 8, false),
      icosahedronGeometry(subdivisions: 1, computeNormals: false),
      torusKnotGeometry(segmentsR: 8, segmentsT: 4, computeNormals: false),
    ];
    for (final geometry in shapes) {
      geometry.validate();
      expect(geometry.hasAttribute(aNormal), isFalse);
    }
  });

  test('polygon algorithms are available through the same CPU entry point', () {
    final polygon = [
      vm.Vector2(-1, -1),
      vm.Vector2(1, -1),
      vm.Vector2(1, 1),
      vm.Vector2(-1, 1),
    ];
    expect(getSignedArea(polygon), 4);
    expect(isInPolygon(polygon, vm.Vector2.zero()), isTrue);
  });

  test(
    'copying additions retain no mutable caller vectors or list structure',
    () {
      final position = vm.Vector3(1, 2, 3);
      final normal = vm.Vector3(0, 0, 1);
      final positions = [position];
      final normals = [normal];
      final geometry = GeometryBuilder(true)
        ..enableAttribute(aNormal)
        ..addVertices(positions)
        ..addAttributesVector3(aNormal, normals);
      position.setZero();
      normal.setZero();
      positions.clear();
      normals.clear();
      geometry.validate();
      expect(geometry.vertices.single, vm.Vector3(1, 2, 3));
      expect(geometry.attributes[aNormal]!.single, vm.Vector3(0, 0, 1));
    },
  );

  test(
    'ownership additions retain elements while borrowing list structure',
    () {
      final position = vm.Vector3(1, 2, 3);
      final positions = [position];
      final geometry = GeometryBuilder(true)
        ..addVerticesTakeOwnership(positions);
      positions.clear();
      expect(geometry.vertices, hasLength(1));
      expect(identical(geometry.vertices.single, position), isTrue);
      geometry.validate();
    },
  );

  test(
    'merge transfers elements, offsets indices and leaves source reusable',
    () {
      final destination = _triangle();
      final source = _triangle();
      final vertex = source.vertices.first;
      final face = source.faces3.single;
      destination.mergeAndTakeOwnershipSimple(source);
      destination.validate();
      source.validate();
      expect(destination.vertices, hasLength(6));
      expect(identical(destination.vertices[3], vertex), isTrue);
      expect(identical(destination.faces3.last, face), isTrue);
      expect([face.a, face.b, face.c], [3, 4, 5]);
      expect(source.isEmpty(), isTrue);
      source.addVertex(vm.Vector3(3, 4, 5));
      expect(destination.vertices, hasLength(6));
    },
  );

  test('invalid merges fail before either builder changes', () {
    final destination = _triangle();
    final source = _triangle()..generateRadialNormals(vm.Vector3.zero());
    final first = source.vertices.first.clone();
    final transform = vm.Matrix4.translationValues(2, 3, 4);
    expect(
      () => destination.mergeAndTakeOwnership(
        source,
        transform,
        vm.Matrix3.identity(),
      ),
      throwsArgumentError,
    );
    expect(source.vertices.first, first);
    expect(source.faces3, hasLength(1));
    expect(destination.vertices, hasLength(3));
    expect(
      () => destination.mergeAndTakeOwnershipSimple(destination),
      throwsArgumentError,
    );
    expect(
      () => destination.mergeAndTakeOwnershipSimple(
        GeometryBuilder(true)..addVertex(vm.Vector3.zero()),
      ),
      throwsArgumentError,
    );
    destination.validate();
  });

  test('custom attribute registry is shared by CPU geometry metadata', () {
    const canonical = 'aCpuGeometryTestWeights';
    introduceNewShaderVar(
      canonical,
      const ShaderVarDesc(varTypeVec4, 'test weights'),
    );
    final geometry = GeometryBuilder(true)
      ..addVertex(vm.Vector3.zero())
      ..enableAttribute(canonical)
      ..addAttributeVector4(canonical, vm.Vector4(1, 2, 3, 4));
    geometry.validate();
    expect(retrieveShaderVarDesc(canonical).type, varTypeVec4);
    expect(geometry.toString(), contains('$canonical[vec4,1]'));
  });

  test('validation rejects negative and out-of-range face indices', () {
    final geometry = _triangle();
    geometry.faces3.single.a = -1;
    expect(geometry.validate, throwsStateError);
    geometry.faces3.single.a = 3;
    expect(geometry.validate, throwsStateError);
    geometry.faces3.single.a = 0;
    geometry.validate();
  });

  test(
    'validation rejects faces on point clouds and checks point attributes',
    () {
      final points = GeometryBuilder(true)..addVertex(vm.Vector3.zero());
      points.faces3.add(Face3(0, 0, 0));
      expect(points.validate, throwsStateError);
      points.faces3.clear();
      points.enableAttribute(aNormal);
      expect(points.validate, throwsStateError);
      points.addAttributeVector3(aNormal, vm.Vector3(0, 0, 1));
      points.validate();
    },
  );

  test('validation rejects non-finite positions and attribute values', () {
    final geometry = _triangle();
    geometry.vertices.first.x = double.infinity;
    expect(geometry.validate, throwsStateError);
    geometry.vertices.first.x = 0;
    geometry.generateRadialNormals(vm.Vector3(0, 0, 1));
    (geometry.attributes[aNormal]!.first as vm.Vector3).z = double.nan;
    expect(geometry.validate, throwsStateError);
  });

  test('validation rejects attribute type, length and registry mismatches', () {
    final geometry = _triangle();
    geometry.attributes[aNormal] = [1, 2, 3];
    expect(geometry.validate, throwsStateError);
    geometry.attributes[aNormal] = <vm.Vector3>[];
    expect(geometry.validate, throwsStateError);
    geometry.attributes.clear();
    geometry.attributes['aUnknownGeometryTestAttribute'] = List.filled(3, 0);
    expect(geometry.validate, throwsStateError);
    expect(() => geometry.enableAttribute('uTime'), throwsArgumentError);
    expect(
      () => geometry.enableAttribute('aUnknownGeometryTestAttribute'),
      throwsArgumentError,
    );
  });

  test(
    'validation rejects unsupported attribute types even on empty geometry',
    () {
      const canonical = 'aCpuGeometryTestUnsupported';
      introduceNewShaderVar(
        canonical,
        const ShaderVarDesc('mat4', 'not a vertex value'),
      );
      final geometry = GeometryBuilder();
      geometry.attributes[canonical] = <Object>[];
      expect(geometry.validate, throwsStateError);
    },
  );

  test('empty geometry validates with and without point mode', () {
    GeometryBuilder().validate();
    GeometryBuilder(true).validate();
  });
}
