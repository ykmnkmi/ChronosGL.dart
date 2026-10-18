@TestOn("vm")
library;

import 'package:chronosgl/src/polygon/lib.dart';
import "package:test/test.dart";
import 'package:vector_math/vector_math.dart' as VM;

import 'polygon_data.dart' as DATA;

double getTrianguatedArea(List<int> triangles, List<VM.Vector2> data) {
  double area = 0.0;
  for (int i = 0; i < triangles.length; i += 3) {
    area += GetSignedArea([
      data[triangles[i]],
      data[triangles[i + 1]],
      data[triangles[i + 2]],
    ]);
  }
  return area;
}

void main() {
  var a = VM.Vector2(-1.0, -1.0);
  var b = VM.Vector2(1.0, -1.0);
  var c = VM.Vector2(1.0, 1.0);
  var d = VM.Vector2(-1.0, 1.0);
  var zero = VM.Vector2(0.0, 0.0);

  test("basic_square", () {
    expect(GetSignedArea(DATA.Square), equals(4.0));

    expect(GetBounds(DATA.Square), equals(VM.Vector4(-1.0, -1.0, 1.0, 1.0)));

    expect(IsInPolygon(DATA.Square, zero), equals(true));
    expect(IsInPolygon(DATA.Square, VM.Vector2(0.0, 0.5)), equals(true));
    expect(IsInPolygon(DATA.Square, VM.Vector2(0.0, 1.0)), equals(true));
    expect(IsInPolygon(DATA.Square, VM.Vector2(0.0, 1.5)), equals(false));
    expect(IsConvex(DATA.Square), equals(true));
  });

  test("basic_triangle", () {
    expect(GetSignedArea(DATA.Triangle), equals(2.0));
    expect(GetBounds(DATA.Triangle), equals(VM.Vector4(-1.0, -1.0, 1.0, 1.0)));
    expect(IsInPolygon(DATA.Triangle, zero), equals(true));
    expect(IsInPolygon(DATA.Triangle, VM.Vector2(0.0, 0.5)), equals(true));
    expect(IsInPolygon(DATA.Triangle, VM.Vector2(0.0, 1.0)), equals(true));
    expect(IsInPolygon(DATA.Triangle, VM.Vector2(0.0, 1.5)), equals(false));
    expect(IsConvex(DATA.Triangle), equals(true));
  });

  test("basic_triangle2", () {
    expect(GetSignedArea(DATA.Triangle2), equals(0.5));
    expect(GetBounds(DATA.Triangle2), equals(VM.Vector4(-1.0, 0.0, 1.0, 1.0)));
    expect(IsInPolygon(DATA.Triangle2, VM.Vector2(0.0, 0.0)), equals(true));
    expect(IsInPolygon(DATA.Triangle2, VM.Vector2(-1.0, 0.0)), equals(false));
    expect(IsInPolygon(DATA.Triangle2, VM.Vector2(1.0, 1.0)), equals(false));
    expect(IsInPolygon(DATA.Triangle2, VM.Vector2(0.0, 1.0)), equals(false));
    expect(IsConvex(DATA.Triangle2), equals(true));
  });

  test("line_intersection", () {
    expect(LineIntersection(a, a - b, c, c - d), equals(null));
    expect(LineIntersection(a, a - zero, a, a - c), equals(null));
    expect(LineIntersection(a, a - c, b, b - d), equals(zero));
    expect(LineIntersection(a, a - zero, b, b - zero), equals(zero));
    expect(LineIntersection(a, a - zero, b, b - c), equals(c));
    expect(LineIntersection(a, d - a, b, d - b), equals(d));
    expect(LineIntersection(a, d - a, b, b - d), equals(d));
  });

  test("contour_filter", () {
    var bc = VM.Vector2(1.0, 0.0);
    expect(FilterDupsAndColinear([a, b, c, a]).length, equals(3));
    expect(FilterDupsAndColinear([a, a, b, c, a, a]).length, equals(3));
    expect(FilterDupsAndColinear([a, b, bc, c]).length, equals(3));
    expect(FilterDupsAndColinear([c, a, b, bc]).length, equals(3));
    // known bug:
    // expect(
    //    FilterDupsAndColinear([bc, c, a, b]).length, equals(3));
    //expect(
    //    FilterDupsAndColinear([bc, c, a, a, b, b, bc, bc]).length, equals(3));
  });

  test("basic_triangulation", () {
    {
      final List<VM.Vector2> d = DATA.Triangle;
      final List<int> triangles = Triangulate(d)!;
      expect(triangles.length, equals(3 * (d.length - 2)));
      double area = GetSignedArea(d);
      double tarea = getTrianguatedArea(triangles, d);
      expect(area, equals(tarea));
    }
    {
      final List<VM.Vector2> d = DATA.Square;
      List<int> triangles = Triangulate(d)!;
      expect(triangles.length, equals(3 * (d.length - 2)));
      double area = GetSignedArea(d);
      double tarea = getTrianguatedArea(triangles, d);
      expect(area, equals(tarea));
    }
    {
      final List<VM.Vector2> d = DATA.Bird;
      List<int> triangles = Triangulate(d)!;
      expect(triangles.length, equals(3 * (d.length - 2)));
      double area = GetSignedArea(d);
      double tarea = getTrianguatedArea(triangles, d);
      expect(area, closeTo(tarea, 0.00001));
    }
  });

  print("PASS\n");
}
