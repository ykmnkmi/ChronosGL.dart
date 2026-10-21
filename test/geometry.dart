@TestOn("chrome")
library;

import 'package:chronosgl/src/core/lib.dart';
import 'package:chronosgl/src/shape/lib.dart';
import "package:test/test.dart";

void main() {
  test("cube", () {
    print("@cube");
    GeometryBuilder gb = cubeGeometry(
      x: 100.0,
      y: 100.0,
      z: 100.0,
      computeNormals: true,
    );
    expect(gb.generateFaceIndices().length, equals(3 * 6 * 2));
    expect(gb.isOrientableManifoldWithBoundaries(), equals(true));
  });

  test("wedge", () {
    print("@wedge");
    GeometryBuilder gb = wedgeGeometry();
    expect(gb.generateFaceIndices().length, equals(3 * 3 * 2 + 3 * 2));
  });

  test("quad", () {
    print("@cylinder");
    GeometryBuilder gb = quadGeometry(1.0);
    expect(gb.generateFaceIndices().length, equals(3 * 2));
  });

  test("cylinder", () {
    for (int i = 3; i < 16; i++) {
      print("@cylinder $i");

      GeometryBuilder gb = cylinderGeometry(30.0, 60.0, 2.0, i, true);
      expect(gb.generateFaceIndices().length, equals(3 * i * 4));
      expect(gb.isOrientableManifoldWithBoundaries(), equals(true));
    }
  });

  test("icosahedron", () {
    // TODO: come up with a closed form
    var triangles = [0, 240, 960, 3840, 15360, 61440];
    for (int i = 1; i <= 4; ++i) {
      print("@icosaheron $i");
      GeometryBuilder gb = icosahedronGeometry(scale: 100, subdivisions: i);
      expect(gb.generateFaceIndices().length, equals(triangles[i]));
      expect(gb.isOrientableManifoldWithBoundaries(), equals(true));
    }
  });

  test("torus1", () {
    GeometryBuilder gb = torusKnotGeometry(
      radius: 20.0,
      tubeRadius: 4.0,
      segmentsR: 4,
      segmentsT: 4,
      p: 1,
      q: 0,
      wrap: false,
      heightScale: 1.0,
      computeNormals: true,
    );
    expect(gb.generateFaceIndices().length, equals(4 * 4 * 6));
    expect(gb.isOrientableManifoldWithBoundaries(), equals(true));
  });

  test("torus2", () {
    GeometryBuilder gb = torusKnotGeometry(
      radius: 20.0,
      tubeRadius: 4.0,
      segmentsR: 128,
      segmentsT: 16,
      p: 2,
      q: 3,
      wrap: false,
      heightScale: 1.0,
      computeNormals: true,
    );
    expect(gb.generateFaceIndices().length, equals(128 * 16 * 6));
    expect(gb.isOrientableManifoldWithBoundaries(), equals(true));
  });

  test("torus_wireframe", () {
    GeometryBuilder gb = torusKnotGeometryWireframeFriendly(
      radius: 20.0,
      tubeRadius: 4.0,
      segmentsR: 128,
      segmentsT: 16,
      p: 3,
      q: 4,
      heightScale: 1.0,
      computeNormals: true,
    );
    expect(gb.generateFaceIndices().length, equals(16 * 128 * 6));
    expect(gb.isOrientableManifoldWithBoundaries(), equals(true));
  });

  print("PASS");
}
