/// Browser-independent transforms and immutable colors.
///
/// Usable on the Dart VM. Use `camera.dart` for cameras and `geometry.dart`
/// for CPU geometry; `chronosgl.dart` is the browser-facing engine import.
library;

export 'src/core/transform.dart' show Transform;
export 'src/core/colors.dart'
    show
        Color,
        colorWhite,
        colorGray8,
        colorGray6,
        colorGray4,
        colorGray2,
        colorBlack,
        colorBlue,
        colorLiteBlue,
        colorRed,
        colorLiteRed,
        colorGreen,
        colorLiteGreen,
        colorYellow,
        colorLiteYellow,
        colorMagenta,
        colorLiteMagenta,
        colorCyan,
        colorLiteCyan;
