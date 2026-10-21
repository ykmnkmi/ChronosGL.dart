part of 'lib.dart';

/*
References:
http://www.flipcode.com/archives/Efficient_Polygon_Triangulation.shtml
https://www.crossdart.info/p/stagexl/1.0.0/src/geom/polygon.dart.html
http://polyk.ivank.net
https://github.com/mapbox/earcut
*/

// calculate area of the list<vm.Vector2> polygon
// The sign of the area indicates clock-wise/counter clockwise orientation
double getSignedArea(List<vm.Vector2> contour) {
  double a = 0.0;
  for (int i = 0; i < contour.length; ++i) {
    int j = i - 1;
    if (j < 0) j += contour.length;
    a += contour[j].cross(contour[i]);
  }
  return a * 0.5;
}

vm.Vector4 getBounds(List<vm.Vector2> contour) {
  double maxX = double.negativeInfinity;
  double minX = double.infinity;
  double maxY = double.negativeInfinity;
  double minY = double.infinity;

  for (vm.Vector2 v in contour) {
    maxX = math.max(maxX, v.x);
    minX = math.min(minX, v.x);
    maxY = math.max(maxY, v.y);
    minY = math.min(minY, v.y);
  }

  return vm.Vector4(minX, minY, maxX, maxY);
}

bool isInTriangle(vm.Vector2 a, vm.Vector2 b, vm.Vector2 c, vm.Vector2 p) {
  vm.Vector2 ap = a - p;
  vm.Vector2 bp = b - p;
  vm.Vector2 cp = c - p;
  return cp.x * ap.y - ap.x * cp.y >= 0 &&
      ap.x * bp.y - bp.x * ap.y >= 0 &&
      bp.x * cp.y - cp.x * bp.y >= 0;
}

// http://stackoverflow.com/questions/2931573/determining-if-two-rays-intersect
// http://stackoverflow.com/questions/563198/how-do-you-detect-where-two-line-segments-intersect
vm.Vector2? lineIntersection(
  vm.Vector2 pointa,
  vm.Vector2 dira,
  vm.Vector2 pointb,
  vm.Vector2 dirb,
) {
  double det = dira.cross(dirb);
  // Parallel check
  if (det == 0.0) return null;
  double t = (pointb - pointa).cross(dirb) / det;
  return pointa + dira * t;
}

bool colinear(vm.Vector2 a, vm.Vector2 b, vm.Vector2 c) {
  vm.Vector2 ab = a - b;
  vm.Vector2 bc = b - c;
  return ab.cross(bc) == 0.0;
}

// Note: this has one known bug when the first element is colinear
// with its neighbors
List<vm.Vector2> filterDupsAndColinear(List<vm.Vector2> contour) {
  List<vm.Vector2> out = <vm.Vector2>[];
  final cl = contour.length;
  out.add(contour[0]);
  for (int i = 1; i < cl - 1; ++i) {
    final vm.Vector2 v0 = out.last;
    final vm.Vector2 v1 = contour[i];
    if (v0 == v1) continue;
    final vm.Vector2 v2 = contour[i + 1];
    if (colinear(v0, v1, v2)) continue;
    out.add(v1);
  }

  vm.Vector2 v0 = out.last;
  vm.Vector2 v1 = contour.last;
  final vm.Vector2 v2 = out.first;
  if (v1 == v2) {
    v1 = out.removeLast();
    v0 = out.last;
  }
  if (v0 == v1) {
    v1 = out.removeLast();
    v0 = out.last;
  }
  // at this point v0 != v1 != v2
  if (!colinear(v0, v1, v2)) {
    out.add(v1);
  }
  return out;
}

bool isInPolygon(List<vm.Vector2> contour, vm.Vector2 p) {
  vm.Vector2 a;
  vm.Vector2 b = contour.last - p;
  int depth = 0;
  for (final vm.Vector2 v in contour) {
    a = b;
    b = v - p;
    if (a.y < 0 && b.y < 0) continue; // both "up" or both "down"
    if (a.y > 0 && b.y > 0) continue; // both "up" or both "down"
    if (a.x < 0 && b.x < 0) continue; // both points on left

    double lx = a.x - a.y * (b.x - a.x) / (b.y - a.y);

    if (lx == 0) return true; // point on edge
    if (lx > 0) depth++;
  }
  return (depth & 1) == 1;
}

// http://mathoverflow.net/questions/44096/detecting-whether-directed-cycle-is-clockwise-or-counterclockwise
bool isCounterClockWise(vm.Vector2 a, vm.Vector2 b, vm.Vector2 c) {
  return (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x) >= 0;
}

bool isConvex(List<vm.Vector2> contour) {
  assert(contour.length >= 3);

  for (int i = 0; i < contour.length; i++) {
    int im1 = i - 1;
    if (im1 < 0) im1 += contour.length;
    int im2 = i - 2;
    if (im2 < 0) im2 += contour.length;

    if (!isCounterClockWise(contour[im2], contour[im1], contour[i])) {
      return false;
    }
  }

  return true;
}

vm.Vector2 _getMovement(vm.Vector2 prev, vm.Vector2 curr, vm.Vector2 next) {
  vm.Vector2 cp = curr - prev;
  vm.Vector2 nc = next - curr;

  // we want to move the adjacent edges further to the outside
  // and then use  their new intersection point as the place for
  // curr to go to.
  vm.Vector2 cpOrtho = vm.Vector2(cp.y, -cp.x)..normalize();
  vm.Vector2 ncOrtho = vm.Vector2(nc.y, -nc.x)..normalize();

  assert(
    nc.dot(cpOrtho) != 0.0,
    "possibly colinear points in contour? use FilterDupsAndColinear",
  );

  vm.Vector2 prevShifted = prev + cpOrtho;
  vm.Vector2 nextShifted = next + ncOrtho;

  vm.Vector2? x = lineIntersection(prevShifted, cp, nextShifted, nc);
  return x! - curr;
}

// GetContourGradient is to shrink or expand a contour.
// The output contains a direction Vector2 for each input point.
// The input must be free of colinear data.
List<vm.Vector2> getContourGradient(List<vm.Vector2> contour) {
  List<vm.Vector2> out = <vm.Vector2>[];
  final cl = contour.length;
  for (int i = 0; i < contour.length; i++) {
    int im1 = i - 1;
    if (im1 < 0) im1 += cl;
    int ip1 = i + 1;
    if (ip1 >= cl) ip1 -= cl;

    vm.Vector2 v = _getMovement(contour[im1], contour[i], contour[ip1]);

    out.add(v);
  }
  return out;
}

List<vm.Vector2> contourCircle(
  int nSegmemts,
  double radius, [
  bool ccw = true,
]) {
  List<vm.Vector2> out = List.generate(nSegmemts, (i) {
    double angle = math.pi * 2 * i / nSegmemts * (ccw ? 1.0 : -1.0);
    return vm.Vector2(radius * math.cos(angle), radius * math.sin(angle));
  });
  return out;
}

List<vm.Vector3> generalProjection(List<vm.Vector2> contour, vm.Matrix3 mat) {
  vm.Vector3 t = vm.Vector3.zero();
  t.z = 1.0;
  List<vm.Vector3> out = List.generate(contour.length, (i) {
    t.x = contour[i].x;
    t.y = contour[i].y;
    return mat.transformed(t);
  });
  return out;
}

List<vm.Vector3> simpleExtrusionAxisZ(List<vm.Vector2> contour, double z) {
  vm.Matrix3 m = vm.Matrix3.identity();
  m[8] = z;
  return generalProjection(contour, m);
}
