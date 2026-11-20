/// Fixed position-based coloring used by the examples.
library;

import 'package:chronosgl/chronosgl.dart';

final ShaderObject demoVertexShader = ShaderObject.vertex("FixedVertexColorV")
  ..addAttributeVars([aPosition])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..addVaryingVars([vColor])
  ..setBodyWithMain(
    [stdVertexBody, "$vColor = ColorFromPosition($aPosition);"],
    prolog: [stdLibShader],
  );

final ShaderObject demoFragmentShader =
    ShaderObject.fragment("FixedVertexColorF")
      ..addVaryingVars([vColor])
      ..setBodyWithMain(["$oFragColor = vec4( $vColor, 1.0 );"]);
