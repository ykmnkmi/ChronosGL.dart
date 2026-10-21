part of 'lib.dart';

/*
  Bevel Cut-View:

xxxxxxxxx             |
xxxxxxxxxxx           |
xxxxxxxxxxxxx         |
xxxxxxxxxxxxxxx       |
xxxxxxxxxxxxxxxx      |
xxxxxxxxxxxxxxxxx     |  y
xxxxxxxxxxxxxxxxxx    |
xxxxxxxxxxxxxxxxxxx   |
xxxxxxxxxxxxxxxxxxxx  |
xxxxxxxxxxxxxxxxxxxxx |
xxxxxxxxxxxxxxxxxxxxx |
---------------------------
                       x

 */
// Easing functions (aka inbetweening or tweening) map
// [0, 1] => [0, 1]
// You can visualize each function by googling the expression
// which will bring up google's graphing calculator, e.g.:
// 1 - cos(x * pi / 2)
// sin(x * pi / 2)
//
// References:
// http://gizma.com/easing/

double easingCosine(double t) => 1.0 - math.cos(t * math.pi / 2);

double easingSine(double t) => math.sin(t * math.pi / 2);

double easingLinear(double t) => t;

double easingQuadratic(double t) => t * t;

double easingCubic(double t) => t * t * t;

typedef Easing = double Function(double t);

final Map<String, Easing> mapStringToEasing = {
  "Cosine": easingCosine,
  "Sine": easingSine,
  "Quadratic": easingQuadratic,
  "Cubic": easingCubic,
  "Linear": easingLinear,
};

// returns a sequence of x,y coordinates  describing the bevel cur
// through view (see above)
List<vm.Vector2> bevelSupportPoints(
  double width,
  double height,
  int nSupports, {
  Easing widthEasing = easingCosine,
  Easing heightEasing = easingSine,
}) {
  // out[0]
  List<vm.Vector2> out = List.generate(nSupports, (i) {
    // make sure t assumes zero and one at the extremes
    double t = i / (nSupports - 1);
    return vm.Vector2(-width * widthEasing(t), height * heightEasing(t));
  });
  return out;
}

// Merges a two-dimensional contour (plus corresponding gradient) with
// a two-dimension bevel support.
// the contour remains in the x,y plane but is replicated at different
// z-levels based on the y-coordinate of the bevel support.
// At each level the contour is extended based on the gradient and the supports
// x-coordinate.
// Typically supports[0] == (0,0) which means thet contour will appear
// a level z=0 unchanged.
List<List<vm.Vector3>> bevelStrips(
  List<vm.Vector2> contour,
  List<vm.Vector2> gradient,
  List<vm.Vector2> supports,
  vm.Matrix3 m,
) {
  assert(contour.length == gradient.length);
  List<List<vm.Vector3>> out = [];
  vm.Vector3 v = vm.Vector3.zero();
  for (vm.Vector2 s in supports) {
    List<vm.Vector3> c = List.generate(contour.length, (i) {
      v.x = contour[i].x + gradient[i].x * s.x;
      v.y = contour[i].y + gradient[i].y * s.x;
      v.z = s.y;
      return m.transformed(v);
    });
    out.add(c);
  }
  return out;
}
