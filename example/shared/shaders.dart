/// Fixed position-based coloring used by the examples.
library;

import 'package:chronosgl/chronosgl.dart';

final ShaderObject demoVertexShader = ShaderObject("FixedVertexColorV")
  ..addAttributeVars([aPosition])
  ..addUniformVars([uPerspectiveViewMatrix, uModelMatrix])
  ..addVaryingVars([vColor])
  ..setBodyWithMain(
    [stdVertexBody, "$vColor = ColorFromPosition($aPosition);"],
    prolog: [stdLibShader],
  );

final ShaderObject demoFragmentShader = ShaderObject("FixedVertexColorF")
  ..addVaryingVars([vColor])
  ..setBodyWithMain(["$oFragColor = vec4( $vColor, 1.0 );"]);
