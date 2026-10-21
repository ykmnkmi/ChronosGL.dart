@TestOn("vm")
library;

import 'package:chronosgl/src/polygon/lib.dart';
import "package:test/test.dart";
import 'package:vector_math/vector_math.dart' as vm;

import 'polygon_data.dart' as data;

double getTrianguatedArea(List<int> triangles, List<vm.Vector2> data) {
  double area = 0.0;
  for (int i = 0; i < triangles.length; i += 3) {
    area += getSignedArea([
      data[triangles[i]],
      data[triangles[i + 1]],
      data[triangles[i + 2]],
    ]);
  }
  return area;
}

void main() {
  var a = vm.Vector2(-1.0, -1.0);
  var b = vm.Vector2(1.0, -1.0);
  var c = vm.Vector2(1.0, 1.0);
  var d = vm.Vector2(-1.0, 1.0);
  var zero = vm.Vector2(0.0, 0.0);

  test("basic_square", () {
    expect(getSignedArea(data.square), equals(4.0));

    expect(getBounds(data.square), equals(vm.Vector4(-1.0, -1.0, 1.0, 1.0)));

    expect(isInPolygon(data.square, zero), equals(true));
    expect(isInPolygon(data.square, vm.Vector2(0.0, 0.5)), equals(true));
    expect(isInPolygon(data.square, vm.Vector2(0.0, 1.0)), equals(true));
    expect(isInPolygon(data.square, vm.Vector2(0.0, 1.5)), equals(false));
    expect(isConvex(data.square), equals(true));
  });

  test("basic_triangle", () {
    expect(getSignedArea(data.triangle), equals(2.0));
    expect(getBounds(data.triangle), equals(vm.Vector4(-1.0, -1.0, 1.0, 1.0)));
    expect(isInPolygon(data.triangle, zero), equals(true));
    expect(isInPolygon(data.triangle, vm.Vector2(0.0, 0.5)), equals(true));
    expect(isInPolygon(data.triangle, vm.Vector2(0.0, 1.0)), equals(true));
    expect(isInPolygon(data.triangle, vm.Vector2(0.0, 1.5)), equals(false));
    expect(isConvex(data.triangle), equals(true));
  });

  test("basic_triangle2", () {
    expect(getSignedArea(data.triangle2), equals(0.5));
    expect(getBounds(data.triangle2), equals(vm.Vector4(-1.0, 0.0, 1.0, 1.0)));
    expect(isInPolygon(data.triangle2, vm.Vector2(0.0, 0.0)), equals(true));
    expect(isInPolygon(data.triangle2, vm.Vector2(-1.0, 0.0)), equals(false));
    expect(isInPolygon(data.triangle2, vm.Vector2(1.0, 1.0)), equals(false));
    expect(isInPolygon(data.triangle2, vm.Vector2(0.0, 1.0)), equals(false));
    expect(isConvex(data.triangle2), equals(true));
  });

  test("line_intersection", () {
    expect(lineIntersection(a, a - b, c, c - d), equals(null));
    expect(lineIntersection(a, a - zero, a, a - c), equals(null));
    expect(lineIntersection(a, a - c, b, b - d), equals(zero));
    expect(lineIntersection(a, a - zero, b, b - zero), equals(zero));
    expect(lineIntersection(a, a - zero, b, b - c), equals(c));
    expect(lineIntersection(a, d - a, b, d - b), equals(d));
    expect(lineIntersection(a, d - a, b, b - d), equals(d));
  });

  test("contour_filter", () {
    var bc = vm.Vector2(1.0, 0.0);
    expect(filterDupsAndColinear([a, b, c, a]).length, equals(3));
    expect(filterDupsAndColinear([a, a, b, c, a, a]).length, equals(3));
    expect(filterDupsAndColinear([a, b, bc, c]).length, equals(3));
    expect(filterDupsAndColinear([c, a, b, bc]).length, equals(3));
    // known bug:
    // expect(
    //    filterDupsAndColinear([bc, c, a, b]).length, equals(3));
    //expect(
    //    filterDupsAndColinear([bc, c, a, a, b, b, bc, bc]).length, equals(3));
  });

  test("basic_triangulation", () {
    {
      final List<vm.Vector2> d = data.triangle;
      final List<int> triangles = triangulate(d)!;
      expect(triangles.length, equals(3 * (d.length - 2)));
      double area = getSignedArea(d);
      double tarea = getTrianguatedArea(triangles, d);
      expect(area, equals(tarea));
    }
    {
      final List<vm.Vector2> d = data.square;
      List<int> triangles = triangulate(d)!;
      expect(triangles.length, equals(3 * (d.length - 2)));
      double area = getSignedArea(d);
      double tarea = getTrianguatedArea(triangles, d);
      expect(area, equals(tarea));
    }
    {
      final List<vm.Vector2> d = data.bird;
      List<int> triangles = triangulate(d)!;
      expect(triangles.length, equals(3 * (d.length - 2)));
      double area = getSignedArea(d);
      double tarea = getTrianguatedArea(triangles, d);
      expect(area, closeTo(tarea, 0.00001));
    }
  });

  print("PASS\n");
}
