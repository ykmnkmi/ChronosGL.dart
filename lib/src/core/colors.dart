import 'package:vector_math/vector_math.dart' as vm;

/// Immutable RGB components, with no implicit clamping or color conversion.
///
/// Use [toVector3] when passing a color to a uniform, light or texture factory.
/// Every conversion returns an independent mutable vector.
class Color {
  const Color(this.r, this.g, this.b);

  final double r;
  final double g;
  final double b;

  Color copyWith({double? r, double? g, double? b}) =>
      Color(r ?? this.r, g ?? this.g, b ?? this.b);

  vm.Vector3 toVector3() => vm.Vector3(r, g, b);

  @override
  bool operator ==(Object other) =>
      other is Color && r == other.r && g == other.g && b == other.b;

  @override
  int get hashCode => Object.hash(r, g, b);
}

const Color colorWhite = Color(1.0, 1.0, 1.0);
const Color colorGray8 = Color(0.8, 0.8, 0.8);
const Color colorGray6 = Color(0.6, 0.6, 0.6);
const Color colorGray4 = Color(0.4, 0.4, 0.4);
const Color colorGray2 = Color(0.2, 0.2, 0.2);
const Color colorBlack = Color(0.0, 0.0, 0.0);

const Color colorBlue = Color(0.0, 0.0, 1.0);
const Color colorLiteBlue = Color(0.0, 0.0, 0.5);
const Color colorRed = Color(1.0, 0.0, 0.0);
const Color colorLiteRed = Color(0.5, 0.0, 0.0);
const Color colorGreen = Color(0.0, 1.0, 0.0);
const Color colorLiteGreen = Color(0.0, 0.5, 0.0);
const Color colorYellow = Color(1.0, 1.0, 0.0);
const Color colorLiteYellow = Color(0.5, 0.5, 0.0);
const Color colorMagenta = Color(1.0, 0.0, 1.0);
const Color colorLiteMagenta = Color(0.5, 0.0, 0.5);
const Color colorCyan = Color(0.0, 1.0, 1.0);
const Color colorLiteCyan = Color(0.0, 0.5, 0.5);
