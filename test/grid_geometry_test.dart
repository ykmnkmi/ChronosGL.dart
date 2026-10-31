@TestOn('chrome')
library;

import 'package:chronosgl/chronosgl.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math.dart' as vm;

void main() {
  const tolerance = 1e-6;
  const cases = [
    (1, 1, 2.0, 2.0),
    (1, 1, 8.0, 3.0),
    (2, 2, 8.0, 3.0),
    (2, 3, 6.0, 6.0),
    (3, 2, 6.0, 6.0),
    (2, 3, 8.0, 3.0),
    (3, 2, 8.0, 3.0),
    (1, 4, 3.0, 10.0),
    (4, 1, 10.0, 3.0),
    (3, 5, 2.5, 7.5),
    (5, 3, 7.5, 2.5),
  ];

  for (final (xstrips, ystrips, xlen, ylen) in cases) {
    test('gridGeometry: $xstrips x $ystrips cells, $xlen x $ylen size', () {
      final geometry = gridGeometry(xstrips, ystrips, xlen, ylen);
      final vertices = geometry.vertices;
      final uvs = geometry.attributes[aTexUV]! as List<vm.Vector2>;
      final normals = geometry.attributes[aNormal]! as List<vm.Vector3>;
      expect(vertices, hasLength((xstrips + 1) * (ystrips + 1)));
      expect(uvs, hasLength(vertices.length));
      expect(normals, hasLength(vertices.length));

      // Check the lattice without depending on the flattened vertex order.
      final lattice = <(int, int)>{};
      for (var i = 0; i < vertices.length; i++) {
        final vertex = vertices[i];
        final uv = uvs[i];
        expect(uv.x, inInclusiveRange(0.0, 1.0));
        expect(uv.y, inInclusiveRange(0.0, 1.0));
        final column = (uv.x * xstrips).round();
        final row = (uv.y * ystrips).round();
        expect(uv.x, closeTo(column / xstrips, tolerance));
        expect(uv.y, closeTo(row / ystrips, tolerance));
        expect(vertex.x, closeTo((uv.x - 0.5) * xlen, tolerance));
        expect(vertex.y, closeTo((uv.y - 0.5) * ylen, tolerance));
        expect(vertex.z, 0.0);
        expect(normals[i], vm.Vector3(0.0, 0.0, 1.0));
        expect(
          lattice.add((column, row)),
          isTrue,
          reason: 'Every lattice point must appear exactly once',
        );
      }
      expect(
        lattice,
        unorderedEquals([
          for (var column = 0; column <= xstrips; column++)
            for (var row = 0; row <= ystrips; row++) (column, row),
        ]),
      );

      expect(geometry.faces3, isEmpty);
      expect(geometry.faces4, hasLength(xstrips * ystrips));
      final indices = geometry.generateFaceIndices();
      expect(indices, hasLength(6 * xstrips * ystrips));
      expect(indices, everyElement(inInclusiveRange(0, vertices.length - 1)));
      expect(
        indices.toSet(),
        hasLength(vertices.length),
        reason: 'Every vertex must be used by the surface',
      );

      final cellWidth = xlen / xstrips;
      final cellHeight = ylen / ystrips;
      final cells = <(int, int)>{};
      for (final face in geometry.faces4) {
        final a = vertices[face.a];
        final b = vertices[face.b];
        final c = vertices[face.c];
        final d = vertices[face.d];
        expect(b.x - a.x, closeTo(cellWidth, tolerance));
        expect(b.y, closeTo(a.y, tolerance));
        expect(c.x, closeTo(b.x, tolerance));
        expect(c.y - b.y, closeTo(cellHeight, tolerance));
        expect(d.x, closeTo(a.x, tolerance));
        expect(d.y, closeTo(c.y, tolerance));
        final uv = uvs[face.a];
        final column = (uv.x * xstrips).round();
        final row = (uv.y * ystrips).round();
        expect(column, inInclusiveRange(0, xstrips - 1));
        expect(row, inInclusiveRange(0, ystrips - 1));
        expect(
          cells.add((column, row)),
          isTrue,
          reason: 'Each cell must be covered exactly once',
        );
      }

      // The actual triangles must be non-degenerate and face +Z.
      for (var i = 0; i < indices.length; i += 3) {
        final a = vertices[indices[i]];
        final b = vertices[indices[i + 1]];
        final c = vertices[indices[i + 2]];
        final cross = (b - a).cross(c - a);
        expect(cross.x, 0.0);
        expect(cross.y, 0.0);
        expect(cross.z, greaterThan(0.0));
        expect(cross.z, closeTo(cellWidth * cellHeight, tolerance));
      }
    });
  }
}
